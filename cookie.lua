local args = {...}

local function printUsage()
    print("Usage:")
    print("  cookie fetch <filename>   - Fetch a script from the repository")
    print("  cookie config <filename>  - Fetch and configure a script")
    print("")
    print("  <filename>: Name without .lua extension")
    print("  Examples: cookie fetch worm")
    print("           cookie config tpsmon")
end

-- Configuration paths
local CONFIG_DIR = "/cookieSuite"
local CONFIG_CONF_DIR = CONFIG_DIR .. "/conf"
local baseURL = "https://s3.7thseraph.org/wiki.avakot.org/oreo.temp/"

-- Function to download a file from the repository
local function downloadFile(filename, extension, localPath)
    local remoteURL = baseURL .. filename .. extension
    local localFilename = localPath or filename
    
    print("Fetching " .. remoteURL .. " -> " .. localFilename)
    
    -- Delete existing file if any
    if fs.exists(localFilename) then
        if fs.delete(localFilename) then
            print("Deleted existing file: " .. localFilename)
        else
            print("Error: Failed to delete existing file: " .. localFilename)
            return false
        end
    end
    
    local handle, err = http.get(remoteURL)
    if not handle then
        print("Error: Failed to fetch file using http.get.")
        if err then print("Reason: " .. err) end
        print("URL attempted: " .. remoteURL)
        return false
    end
    
    local content = handle.readAll()
    handle.close()
    
    if not content then
        print("Error: Failed to read content from URL.")
        return false
    end
    
    local file, writeErr = fs.open(localFilename, "w")
    if not file then
        print("Error: Failed to open local file for writing: " .. localFilename)
        if writeErr then print("Reason: " .. writeErr) end
        return false
    end
    
    file.write(content)
    file.close()
    print("Successfully fetched and saved: " .. localFilename)
    return true
end

-- Function to run confgenerator
local function runConfGenerator()
    print("Running configuration generator...")
    
    -- Temporarily download confgenerator.lua
    local confGenURL = baseURL .. "confgenerator.lua"
    print("Fetching configuration generator from: " .. confGenURL)
    
    local success = downloadFile("confgenerator", ".lua", "_temp_confgenerator")
    if not success then
        print("Error: Failed to download configuration generator.")
        return false
    end
    
    -- Run the generator
    print("Executing configuration generator...")
    local confGenSuccess = shell.run("_temp_confgenerator")
    
    -- Clean up
    print("Cleaning up temporary files...")
    fs.delete("_temp_confgenerator")
    
    if confGenSuccess then
        print("Configuration generator ran successfully.")
        return true
    else
        print("Error running configuration generator.")
        return false
    end
end

-- Command: fetch
local function commandFetch(scriptName)
    if not scriptName or string.len(scriptName) == 0 then
        print("Error: Filename cannot be empty.")
        printUsage()
        return
    end
    
    local success = downloadFile(scriptName, ".lua", scriptName)
    if success and scriptName ~= "confgenerator" then
        -- Don't run config generator if we just downloaded it
        runConfGenerator()
    end
end

-- Command: config
local function commandConfig(scriptName)
    if not scriptName or string.len(scriptName) == 0 then
        print("Error: Filename cannot be empty.")
        printUsage()
        return
    end
    
    -- Ensure config directories exist
    if not fs.isDir(CONFIG_DIR) then
        fs.makeDir(CONFIG_DIR)
    end
    
    if not fs.isDir(CONFIG_CONF_DIR) then
        fs.makeDir(CONFIG_CONF_DIR)
    end
    
    -- First, fetch the script itself
    print("Step 1: Fetching the script...")
    local scriptSuccess = downloadFile(scriptName, ".lua", scriptName)
    if not scriptSuccess then
        print("Warning: Failed to fetch script, but will continue with config...")
    end
    
    -- Second, fetch the conf file for this script
    print("Step 2: Fetching the configuration file...")
    local confPath = CONFIG_CONF_DIR .. "/" .. scriptName .. ".conf"
    local configSuccess = downloadFile(scriptName, ".conf", confPath)
    if not configSuccess then
        print("Warning: Failed to fetch configuration file. Configuration may not be complete.")
    end
    
    -- Third, fetch global.conf if it doesn't exist
    local globalConfPath = CONFIG_CONF_DIR .. "/global.conf"
    if not fs.exists(globalConfPath) then
        print("Step 3: Fetching global configuration...")
        downloadFile("global", ".conf", globalConfPath)
    end
    
    -- Finally, run confgenerator to regenerate the main config file
    print("Step 4: Regenerating configuration...")
    runConfGenerator()
    
    print("Configuration process complete for: " .. scriptName)
end

-- Main command processing
if #args < 1 then
    printUsage()
    return
end

local command = args[1]

if command == "fetch" and #args >= 2 then
    commandFetch(args[2])
elseif command == "config" and #args >= 2 then
    commandConfig(args[2])
else
    printUsage()
end
