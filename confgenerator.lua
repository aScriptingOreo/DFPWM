-- confgenerator.lua
-- Dynamically fetches configurations from S3 and generates the /cookieSuite/conf.lua file

local CONFIG_DIR_MAIN = "/cookieSuite"
local CONFIG_FILE_PATH_MAIN = CONFIG_DIR_MAIN .. "/conf.lua"
local CONFIG_LOG_DIR = CONFIG_DIR_MAIN .. "/log"
local DEBUG_LOG_FILE = CONFIG_LOG_DIR .. "/confgenerator.log"
local GLOBAL_CONFIG_KEY = "global"

-- Base URL for S3 bucket
local BASE_URL = "https://s3.7thseraph.org/wiki.avakot.org/oreo.temp/"
local AVAILABLE_FILES_URL = BASE_URL .. "available_files.json"
local SCRIPTS_LIST_URL = BASE_URL .. "scripts.list"
local CONFIGS_LIST_URL = BASE_URL .. "configs.list"

-- Initialize debug log (create new file each time)
local function logDebug(message)
    if not fs.isDir(CONFIG_LOG_DIR) then
        fs.makeDir(CONFIG_LOG_DIR)
    end
    
    local file = fs.open(DEBUG_LOG_FILE, fs.exists(DEBUG_LOG_FILE) and "a" or "w")
    if file then
        file.writeLine("[" .. os.date("%H:%M:%S") .. "] " .. message)
        file.close()
    end
end

-- Create a fresh log file at the start of execution
if fs.exists(DEBUG_LOG_FILE) then
    fs.delete(DEBUG_LOG_FILE)
end
logDebug("Starting confgenerator.lua")

local function ensureConfigDir(path)
    logDebug("Ensuring directory exists: " .. path)
    if not fs.isDir(path) then
        fs.makeDir(path)
        logDebug("Created directory: " .. path)
        print("Created directory: " .. path)
    else
        logDebug("Directory already exists: " .. path)
    end
end

-- Helper function to download a file from S3
local function downloadFile(url, targetPath)
    logDebug("Downloading: " .. url .. " -> " .. targetPath)
    
    local response, err = http.get(url)
    if not response then
        logDebug("Failed to download: " .. url .. " - " .. (err or "Unknown error"))
        return nil, err
    end
    
    local content = response.readAll()
    response.close()
    
    if not content or content == "" then
        logDebug("Downloaded file was empty: " .. url)
        return nil, "Empty content"
    end
    
    local file = fs.open(targetPath, "w")
    if not file then
        logDebug("Failed to open file for writing: " .. targetPath)
        return nil, "Could not open file for writing"
    end
    
    file.write(content)
    file.close()
    
    logDebug("Successfully downloaded: " .. url)
    return content
end

-- Parse JSON string (improved implementation)
local function parseJSON(jsonString)
    -- Safety check
    if not jsonString or type(jsonString) ~= "string" then
        logDebug("Invalid JSON input: " .. tostring(jsonString))
        return nil, "Invalid JSON input"
    end
    
    -- Log the first part of the JSON to debug
    logDebug("JSON content sample: " .. string.sub(jsonString, 1, 200))

    -- Create result structure
    local result = {
        scripts = {},
        configs = {}
    }
    
    -- Manual JSON parsing for our specific format
    -- First, extract the scripts array
    local scriptsList = jsonString:match('"scripts"%s*:%s*%[(.-)%]')
    if scriptsList then
        logDebug("Found scripts list: " .. scriptsList)
        for name in scriptsList:gmatch('"([^"]+)"') do
            table.insert(result.scripts, name)
            logDebug("Added script: " .. name)
        end
    else
        logDebug("Failed to find scripts list in JSON")
    end
    
    -- Then extract the configs array
    local configsList = jsonString:match('"configs"%s*:%s*%[(.-)%]')
    if configsList then
        logDebug("Found configs list: " .. configsList)
        for name in configsList:gmatch('"([^"]+)"') do
            table.insert(result.configs, name)
            logDebug("Added config: " .. name)
        end
    else
        logDebug("Failed to find configs list in JSON")
    end
    
    logDebug("Parsed JSON: found " .. #result.scripts .. " scripts and " .. #result.configs .. " configs")
    return result
end

-- Function to try multiple ways to parse config content
local function tryParseConfig(content, tmpPath, configName)
    -- First try: Direct loading with load()
    local func, err = load(content)
    if func then
        local success, result = pcall(func)
        if success and type(result) == "table" then
            logDebug("Successfully parsed config using load() directly")
            return result
        else
            logDebug("Failed with direct load() - Error: " .. tostring(result))
        end
    else
        logDebug("Failed to load with direct load() - Error: " .. tostring(err))
    end
    
    -- Second try: Check if content starts with "return "
    if content:sub(1, 7) == "return " then
        local configTable = content:sub(8) -- Strip "return "
        local func, err = load("return " .. configTable)
        if func then
            local success, result = pcall(func)
            if success and type(result) == "table" then
                logDebug("Successfully parsed after stripping 'return'")
                return result
            end
        end
    end
    
    -- Third try: Inject the content into a table constructor
    local func, err = load("return " .. content)
    if func then
        local success, result = pcall(func)
        if success and type(result) == "table" then
            logDebug("Successfully parsed using 'return " .. content:sub(1, 20) .. "...'")
            return result
        end
    end
    
    -- Final attempt: Create a simple default
    logDebug("All parsing attempts failed. Creating minimal default for " .. configName)
    logDebug("Config content snippet: " .. content:sub(1, 100))
    return {
        _parseError = "Could not parse original config",
        _originalContent = content:sub(1, 30) .. "..." -- Store a sample for debugging
    }
end

-- Load Lua content as a table (used for remote config files)
local function loadLuaStringAsTable(luaString, sourceName)
    logDebug("Loading Lua string as table from: " .. sourceName)
    
    -- Don't add 'return' to the string - assume the config file already has it
    local func, err = load(luaString, sourceName)
    if not func then
        logDebug("Error loading Lua string: " .. (err or "Unknown error"))
        return nil
    end
    
    local success, result = pcall(func)
    if not success or type(result) ~= "table" then
        logDebug("Error executing Lua string: " .. tostring(result))
        return nil
    end
    
    logDebug("Successfully loaded table from Lua string: " .. sourceName)
    return result
end

local function loadLuaFileAsTable(filePath)
    if fs.exists(filePath) then
        local file = fs.open(filePath, "r")
        if not file then 
            logDebug("Failed to open file: " .. filePath)
            return nil
        end
        
        local content = file.readAll()
        file.close()
        
        return loadLuaStringAsTable(content, filePath)
    end
    
    logDebug("File not found: " .. filePath)
    return nil
end

local function serializeValue(value)
    local t = type(value)
    if t == "string" then
        return string.format("%q", value)
    elseif t == "number" or t == "boolean" then
        return tostring(value)
    elseif t == "table" then
        -- Basic table serialization (not handling nested tables deeply or metatables)
        local parts = {}
        -- Check if it's an array-like table
        local isArray = true
        local maxIndex = 0
        for k, _ in pairs(value) do
            if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
                isArray = false
                break
            end
            maxIndex = math.max(maxIndex, k)
        end
        if #value ~= maxIndex then isArray = false end -- Check for holes if it looked like an array

        if isArray then
            for i = 1, #value do
                table.insert(parts, serializeValue(value[i]))
            end
            return "{ " .. table.concat(parts, ", ") .. " }"
        else -- Dictionary-like table
            for k, v in pairs(value) do
                local keyStr
                if type(k) == "string" and k:match("^[a-zA-Z_][a-zA-Z0-9_]*$") then
                    keyStr = k -- Simple identifier
                else
                    keyStr = "[" .. serializeValue(k) .. "]" -- Needs brackets
                end
                table.insert(parts, keyStr .. " = " .. serializeValue(v))
            end
            return "{ " .. table.concat(parts, ", ") .. " }"
        end
    else
        return "nil --[[ UNSUPPORTED TYPE: " .. t .. " ]]"
    end
end

local function saveConfig(configTable, filePath)
    logDebug("Saving configuration to: " .. filePath)
    local lines = {"-- CookieSuite Configuration File", "-- Generated by confgenerator.lua", "return {"}
    for scriptName, scriptConfig in pairs(configTable) do
        if type(scriptConfig) == "table" then -- Ensure it's a table
            table.insert(lines, string.format("  %s = {", scriptName))
            for key, value in pairs(scriptConfig) do
                table.insert(lines, string.format("    %s = %s,", key, serializeValue(value)))
            end
            table.insert(lines, "  },")
            logDebug("Added configuration section for: " .. scriptName)
        end
    end
    table.insert(lines, "}")

    local file, err = fs.open(filePath, "w")
    if file then
        file.write(table.concat(lines, "\n"))
        file.close()
        local msg = "Configuration saved to: " .. filePath
        logDebug(msg)
        print(msg)
        return true
    else
        local errMsg = "Error saving config file: " .. filePath
        if err then errMsg = errMsg .. " - " .. err end
        logDebug(errMsg)
        print(errMsg) 
        return false
    end
end

-- Function to download and process a configuration from S3
local function downloadAndProcessConfig(configPath, configName)
    logDebug("Processing configuration for: " .. configName)
    
    local configUrl = BASE_URL .. configPath
    local tmpPath = os.tmpname and os.tmpname() or "__tmp_config" .. math.random(1000, 9999)
    
    local content, err = downloadFile(configUrl, tmpPath)
    if not content then
        logDebug("Failed to download config: " .. configUrl .. " - " .. (err or "Unknown error"))
        if fs.exists(tmpPath) then fs.delete(tmpPath) end
        return nil
    end
    
    -- Try various ways to parse the config
    local configTable = tryParseConfig(content, tmpPath, configName)
    
    -- Clean up temp file
    if fs.exists(tmpPath) then fs.delete(tmpPath) end
    
    if not configTable then
        logDebug("All parsing methods failed for: " .. configName)
        return nil
    end
    
    logDebug("Successfully processed config for: " .. configName)
    return configTable
end

-- Main logic - ensure required directories exist
ensureConfigDir(CONFIG_DIR_MAIN)
ensureConfigDir(CONFIG_LOG_DIR)

-- Load existing configuration if available
local currentMainConfig = loadLuaFileAsTable(CONFIG_FILE_PATH_MAIN) or {}
local configChanged = false

-- Download available files metadata
logDebug("Downloading available files metadata...")
print("Downloading available files metadata...")

local tmpAvailableFilesPath = os.tmpname and os.tmpname() or "__tmp_available_files"
local availableFilesContent, err = downloadFile(AVAILABLE_FILES_URL, tmpAvailableFilesPath)

if not availableFilesContent then
    logDebug("Failed to download available files list: " .. (err or "Unknown error"))
    print("Failed to download available files list. Cannot continue without knowing what's available.")
    
    -- If we have existing configuration, don't lose it
    if fs.exists(CONFIG_FILE_PATH_MAIN) then
        logDebug("Keeping existing configuration file")
        print("Keeping existing configuration file.")
    end
    return 1
end

-- Parse the available files metadata
local availableFiles, parseErr = parseJSON(availableFilesContent)
if not availableFiles or #availableFiles.scripts == 0 then
    logDebug("Failed to parse available files JSON or no scripts found: " .. (parseErr or "Unknown error"))
    print("Failed to parse available files list. Cannot continue.")
    
    -- As a fallback, try to get files lists directly
    logDebug("Trying fallback method to get scripts and configs lists")
    print("Trying fallback method to get file lists...")
    
    local scriptsListContent = http.get(SCRIPTS_LIST_URL)
    local configsListContent = http.get(CONFIGS_LIST_URL)
    
    if scriptsListContent and configsListContent then
        availableFiles = {
            scripts = {},
            configs = {}
        }
        
        -- Parse scripts list
        local scriptsText = scriptsListContent.readAll()
        scriptsListContent.close()
        for line in scriptsText:gmatch("([^\r\n]+)") do
            if line and line:match("%.lua$") then
                table.insert(availableFiles.scripts, line)
                logDebug("Added script from fallback: " .. line)
            end
        end
        
        -- Parse configs list
        local configsText = configsListContent.readAll()
        configsListContent.close()
        for line in configsText:gmatch("([^\r\n]+)") do
            if line and line:match("%.conf$") then
                table.insert(availableFiles.configs, line)
                logDebug("Added config from fallback: " .. line)
            end
        end
        
        if #availableFiles.scripts == 0 and #availableFiles.configs == 0 then
            logDebug("Fallback method also failed to find scripts/configs")
            print("Fallback method also failed. Keeping existing configuration.")
            return 1
        end
    else
        logDebug("Fallback method failed")
        print("All methods failed. Keeping existing configuration.")
        return 1
    end
end

-- Log what we found
logDebug("Found " .. #availableFiles.scripts .. " scripts and " .. #availableFiles.configs .. " configuration files")
print("Found " .. #availableFiles.scripts .. " scripts and " .. #availableFiles.configs .. " configuration files")

-- First, process global configuration if available
local globalConfFound = false
for _, configPath in ipairs(availableFiles.configs) do
    if configPath:match("global%.conf$") then
        globalConfFound = true
        logDebug("Found global configuration file: " .. configPath)
        print("Processing global configuration...")
        
        if not currentMainConfig[GLOBAL_CONFIG_KEY] then
            local globalConfig = downloadAndProcessConfig(configPath, "global")
            if globalConfig then
                currentMainConfig[GLOBAL_CONFIG_KEY] = globalConfig
                configChanged = true
                logDebug("Added global configuration")
                print("Added global configuration")
            end
        else
            logDebug("Global configuration already exists in main config. Skipping.")
            print("Global configuration already exists in main config. Skipping.")
        end
        
        break
    end
end

if not globalConfFound then
    logDebug("No global configuration file found")
    print("No global configuration file found")
end

-- Process each script found in the scripts list
for _, scriptPath in ipairs(availableFiles.scripts) do
    local scriptName = scriptPath:match("([^/]+)%.lua$")
    if scriptName and scriptName ~= "confgenerator" then -- Skip confgenerator itself
        logDebug("Checking configuration for script: " .. scriptName)
        
        -- Look for a matching config file
        local configFound = false
        for _, configPath in ipairs(availableFiles.configs) do
            if configPath:match(scriptName .. "%.conf$") then
                configFound = true
                logDebug("Found configuration file for " .. scriptName .. ": " .. configPath)
                
                if not currentMainConfig[scriptName] then
                    print("Processing configuration for " .. scriptName .. "...")
                    local scriptConfig = downloadAndProcessConfig(configPath, scriptName)
                    if scriptConfig then
                        currentMainConfig[scriptName] = scriptConfig
                        configChanged = true
                        logDebug("Added configuration for " .. scriptName)
                        print("Added configuration for " .. scriptName)
                    end
                else
                    logDebug("Configuration for " .. scriptName .. " already exists in main config. Skipping.")
                    print("Configuration for " .. scriptName .. " already exists in main config. Skipping.")
                end
                
                break
            end
        end
        
        if not configFound then
            logDebug("No configuration file found for " .. scriptName)
        end
    end
end

-- Make sure we don't generate an empty config file
if configChanged then
    -- Check if the config is actually populated (not just empty tables)
    local hasActualContent = false
    for scriptName, scriptConfig in pairs(currentMainConfig) do
        if type(scriptConfig) == "table" and next(scriptConfig) ~= nil then
            hasActualContent = true
            break
        end
    end
    
    if not hasActualContent then
        logDebug("Warning: Generated config would be empty! Aborting save.")
        print("Warning: Generated configuration would be empty. Not saving to avoid data loss.")
        return 1
    end
    
    logDebug("Saving updated configuration")
    local saveSuccess = saveConfig(currentMainConfig, CONFIG_FILE_PATH_MAIN)
    if not saveSuccess then
        logDebug("Failed to save configuration!")
        print("CRITICAL ERROR: Failed to save configuration!")
        return 1
    end
    logDebug("Configuration saved successfully")
else
    logDebug("No configuration changes needed")
    print("No configuration changes needed for main config file.")
end

logDebug("Configuration generation finished successfully")
print("Configuration generation finished successfully.")
print("Debug log written to: " .. DEBUG_LOG_FILE)
print("To view/share logs, run: cookie log")
return 0

