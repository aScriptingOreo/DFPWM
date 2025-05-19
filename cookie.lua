local args = {...}

local function printUsage()
    print("Usage:")
    print("  cookie fetch <filename>   - Fetch a script from the repository")
    print("  cookie config <filename>  - Fetch and configure a script")
    print("  cookie log [filename]     - Upload logs to Pastebin")
    print("")
    print("  <filename>: Name without .lua extension for fetch/config")
    print("              With optional path for specific log file")
    print("  Examples: cookie fetch worm")
    print("           cookie config tpsmon")
    print("           cookie log       (uploads all logs)")
    print("           cookie log /cookieSuite/confgen_debug.log")
end

-- Configuration paths
local CONFIG_DIR = "/cookieSuite"
local CONFIG_CONF_DIR = CONFIG_DIR .. "/conf"
local CONFIG_LOG_DIR = CONFIG_DIR .. "/log"
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
    
    -- Remove directory creation logic - confgenerator will handle this
    
    -- First, fetch the script itself
    print("Step 1: Fetching the script...")
    local scriptSuccess = downloadFile(scriptName, ".lua", scriptName)
    if not scriptSuccess then
        print("Warning: Failed to fetch script, but will continue with config...")
    end
    
    -- Second, fetch the conf file for this script
    print("Step 2: Fetching the configuration file...")
    -- Let confgenerator determine the exact path
    local confPath = CONFIG_CONF_DIR .. "/" .. scriptName .. ".conf"
    
    -- Try to fetch from both potential locations: directly in S3 root or in conf/ subdirectory
    local configSuccess = downloadFile(scriptName, ".conf", confPath)
    if not configSuccess then
        -- Try alternative location: S3/conf/script.conf
        print("Trying alternative location for conf file...")
        configSuccess = downloadFile("conf/" .. scriptName, ".conf", confPath)
    end
    
    if not configSuccess then
        print("Warning: Failed to fetch configuration file. Configuration may not be complete.")
    end
    
    -- Third, fetch global.conf if it doesn't exist
    local globalConfPath = CONFIG_CONF_DIR .. "/global.conf"
    if not fs.exists(globalConfPath) then
        print("Step 3: Fetching global configuration...")
        -- Try both potential locations for global.conf
        local globalSuccess = downloadFile("global", ".conf", globalConfPath)
        if not globalSuccess then
            globalSuccess = downloadFile("conf/global", ".conf", globalConfPath)
        end
        if not globalSuccess then
            print("Warning: Failed to fetch global configuration.")
        end
    end
    
    -- Finally, run confgenerator to regenerate the main config file
    print("Step 4: Regenerating configuration...")
    -- Run confgenerator with more detailed output
    local confGenSuccess = runConfGenerator() 
    
    -- Check for the debug log file after running confgenerator
    local debugLogPath = CONFIG_DIR .. "/confgen_debug.log"
    if fs.exists(debugLogPath) then
        print("Configuration generator debug log:")
        print("--------------------------------")
        local debugFile = fs.open(debugLogPath, "r")
        if debugFile then
            local line = debugFile.readLine()
            while line do
                print(line)
                line = debugFile.readLine()
            end
            debugFile.close()
        end
        print("--------------------------------")
    end
    
    -- Check if main config file exists after running confgenerator
    local mainConfigPath = CONFIG_DIR .. "/conf.lua"
    if fs.exists(mainConfigPath) then
        print("Main configuration file was successfully created or updated.")
    else
        print("ERROR: Main configuration file was not created!")
    end
    
    print("Configuration process complete for: " .. scriptName)
end

-- Command: log (formerly paste)
local function commandLog(specificFile)
    -- Ensure log directory exists
    if not fs.isDir(CONFIG_LOG_DIR) then
        fs.makeDir(CONFIG_LOG_DIR)
        print("Created log directory: " .. CONFIG_LOG_DIR)
    end
    
    -- If a specific file is provided, just upload that
    if specificFile and string.len(specificFile) > 0 then
        if not fs.exists(specificFile) then
            print("Error: File not found: " .. specificFile)
            return
        end
        
        -- Upload to Pastebin
        print("Uploading " .. specificFile .. " to Pastebin...")
        local success, pastebinId = shell.run("pastebin", "put", specificFile)
        
        if success then
            print("Successfully uploaded to Pastebin!")
            print("Pastebin ID: " .. pastebinId)
            print("URL: https://pastebin.com/" .. pastebinId)
        else
            print("Error uploading to Pastebin. Please check your network connection.")
            print("Output: " .. tostring(pastebinId))
        end
        return
    end
    
    -- If no specific file, collect and combine all logs
    print("Collecting all log files...")
    
    -- Create a temporary combined log file
    local tempLogFile = CONFIG_LOG_DIR .. "/combined_logs.tmp"
    local combinedLog = fs.open(tempLogFile, "w")
    if not combinedLog then
        print("Error: Could not create combined log file.")
        return
    end
    
    combinedLog.writeLine("=== CookieSuite Combined Log File ===")
    combinedLog.writeLine("Generated: " .. os.date())
    combinedLog.writeLine("")
    
    -- First check the main cookieSuite directory for log files
    local foundLogs = false
    local function processLogsInDir(directory, dirLabel)
        local files = fs.list(directory)
        local logFilesInDir = false
        
        for _, filename in ipairs(files) do
            local path = fs.combine(directory, filename)
            if not fs.isDir(path) and string.match(filename, "%.log$") then
                logFilesInDir = true
                foundLogs = true
                
                combinedLog.writeLine("=== " .. dirLabel .. ": " .. filename .. " ===")
                combinedLog.writeLine("")
                
                local logFile = fs.open(path, "r")
                if logFile then
                    local line = logFile.readLine()
                    while line do
                        combinedLog.writeLine(line)
                        line = logFile.readLine()
                    end
                    logFile.close()
                else
                    combinedLog.writeLine("ERROR: Could not read file.")
                end
                
                combinedLog.writeLine("")
                combinedLog.writeLine("")
            end
        end
        
        return logFilesInDir
    end
    
    -- Process logs in main directory and log directory
    local mainDirHasLogs = processLogsInDir(CONFIG_DIR, "CookieSuite Directory")
    local logDirHasLogs = processLogsInDir(CONFIG_LOG_DIR, "Log Directory")
    
    -- Also check the current directory for logs
    if fs.getDir("") ~= CONFIG_DIR and fs.getDir("") ~= CONFIG_LOG_DIR then
        local currentDirHasLogs = processLogsInDir("", "Current Directory")
        if currentDirHasLogs then
            foundLogs = true
        end
    end
    
    combinedLog.close()
    
    if not foundLogs then
        print("No log files found.")
        fs.delete(tempLogFile)
        return
    end
    
    -- Upload the combined log file to Pastebin
    print("Uploading combined logs to Pastebin...")
    
    -- Capture output from pastebin separately to avoid nil errors
    -- We'll redirect the output to a temporary file
    local tempOutputFile = os.tmpname and os.tmpname() or "__pastebin_output.tmp"
    local redirectCommand = "pastebin put " .. tempLogFile .. " > " .. tempOutputFile
    local success = shell.run(redirectCommand)
    
    if success then
        -- Read the output file to get the pastebin ID
        local outputFile = fs.open(tempOutputFile, "r")
        local outputText = outputFile and outputFile.readAll() or ""
        if outputFile then outputFile.close() end
        
        -- Clean up
        if fs.exists(tempOutputFile) then fs.delete(tempOutputFile) end
        
        -- Extract pastebin ID from output text if possible
        local pastebinId = outputText:match("pastebin%.com/(%w+)")
        
        if pastebinId then
            print("Successfully uploaded combined logs to Pastebin!")
            print("Pastebin ID: " .. pastebinId)
        else
            print("Successfully uploaded to Pastebin, but couldn't extract URL.")
            print("Please check the command line for the URL.")
        end
        
        -- Save a copy of the combined log with timestamp
        local timestamp = os.date("%Y%m%d_%H%M%S")
        local savedCopy = CONFIG_LOG_DIR .. "/combined_" .. timestamp .. ".log"
        fs.copy(tempLogFile, savedCopy)
        print("Saved a copy of combined logs to: " .. savedCopy)
    else
        print("Error uploading to Pastebin. Please check your network connection.")
    end
    
    -- Clean up the temporary file
    fs.delete(tempLogFile)
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
elseif command == "log" then
    commandLog(args[2]) -- args[2] might be nil, which is fine
else
    printUsage()
end
