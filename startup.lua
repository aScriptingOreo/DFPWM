-- startup.lua
-- Fetches a designated script using 'cookie' and then runs it.
-- Strictly relies on /cookieSuite/conf.lua for its settings with no fallbacks.

local CONFIG_DIR = "/cookieSuite"
local CONFIG_FILE_PATH = CONFIG_DIR .. "/conf.lua"
local LOG_DIR = CONFIG_DIR .. "/log"
local LOG_FILE_PATH = LOG_DIR .. "/startup.log"

-- Initialize logging
local function ensureLogDir()
    if not fs.isDir(LOG_DIR) then
        fs.makeDir(LOG_DIR)
    end
end

local function logMessage(message)
    ensureLogDir()
    
    -- Create a new log file each time startup runs
    local mode = fs.exists(LOG_FILE_PATH) and "a" or "w"
    local file = fs.open(LOG_FILE_PATH, mode)
    if file then
        file.writeLine("[" .. os.date("%H:%M:%S") .. "] " .. message)
        file.close()
    end
end

-- Start fresh log
if fs.exists(LOG_FILE_PATH) then
    fs.delete(LOG_FILE_PATH)
end
logMessage("Starting startup.lua")

-- Load configuration strictly from conf.lua
logMessage("Attempting to load configuration from: " .. CONFIG_FILE_PATH)
if not fs.exists(CONFIG_FILE_PATH) then
    local errMsg = "CRITICAL: Configuration file not found: " .. CONFIG_FILE_PATH
    logMessage(errMsg)
    error(errMsg)
end

local func, loadErr = loadfile(CONFIG_FILE_PATH)
if not func then
    local errMsg = "CRITICAL: Error loading config file: " .. CONFIG_FILE_PATH .. " - " .. tostring(loadErr)
    logMessage(errMsg)
    error(errMsg)
end

local success, config = pcall(func)
if not success or type(config) ~= "table" then
    local errMsg = "CRITICAL: Error executing config file: " .. CONFIG_FILE_PATH
    if not success then errMsg = errMsg .. " - " .. tostring(config) end
    logMessage(errMsg)
    error(errMsg)
end

logMessage("Successfully loaded configuration")

-- Check for startup section
if not config.startup or type(config.startup) ~= "table" then
    local errMsg = "CRITICAL: Missing 'startup' section in configuration"
    logMessage(errMsg)
    error(errMsg)
end

-- Extract required configuration values
local COOKIE_SCRIPT_NAME = config.startup.cookieScriptName
local SCRIPT_TO_FETCH_ON_BOOT = config.startup.scriptToFetchOnBoot

-- Validate required configuration is present
if not COOKIE_SCRIPT_NAME or not SCRIPT_TO_FETCH_ON_BOOT then
    local errMsg = "CRITICAL: Missing required configuration values (cookieScriptName, scriptToFetchOnBoot)"
    logMessage(errMsg)
    error(errMsg)
end

logMessage("Using configuration: cookieScriptName=" .. tostring(COOKIE_SCRIPT_NAME) .. 
           ", scriptToFetchOnBoot=" .. tostring(SCRIPT_TO_FETCH_ON_BOOT))

-- Check if cookie script exists
if not fs.exists(COOKIE_SCRIPT_NAME) then
    local errMsg = "Error: " .. COOKIE_SCRIPT_NAME .. " script not found."
    logMessage(errMsg)
    error(errMsg)
end

-- Run cookie to fetch the target script
logMessage("Running " .. COOKIE_SCRIPT_NAME .. " to fetch/update '" .. SCRIPT_TO_FETCH_ON_BOOT .. "'...")
print("Running " .. COOKIE_SCRIPT_NAME .. " to fetch/update '" .. SCRIPT_TO_FETCH_ON_BOOT .. "'...")
local success, reason = shell.run(COOKIE_SCRIPT_NAME, "fetch", SCRIPT_TO_FETCH_ON_BOOT)

if success then
    logMessage(COOKIE_SCRIPT_NAME .. " executed successfully.")
    print(COOKIE_SCRIPT_NAME .. " executed successfully.")
    
    -- Run the fetched script if it exists
    if fs.exists(SCRIPT_TO_FETCH_ON_BOOT) then
        logMessage("Executing " .. SCRIPT_TO_FETCH_ON_BOOT)
        print("Executing " .. SCRIPT_TO_FETCH_ON_BOOT)
        shell.run(SCRIPT_TO_FETCH_ON_BOOT)
    else
        local errMsg = "Error: " .. SCRIPT_TO_FETCH_ON_BOOT .. " not found after fetch."
        logMessage(errMsg)
        error(errMsg)
    end
else
    local errMsg = "Error running " .. COOKIE_SCRIPT_NAME .. "."
    if reason then errMsg = errMsg .. " Reason: " .. reason end
    logMessage(errMsg)
    error(errMsg)
end
