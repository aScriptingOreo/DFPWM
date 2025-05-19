-- startup.lua (formerly cookieboot.lua)
-- Fetches a designated script using 'cookie' and then runs it.
-- Relies on /cookieSuite/conf.lua for its settings.

local CONFIG_FILE_PATH = "/cookieSuite/conf.lua"
local CFG = {} -- Will hold effective configuration

local function loadConfiguration()
    if not fs.exists(CONFIG_FILE_PATH) then
        print("CRITICAL: Main config file not found: " .. CONFIG_FILE_PATH)
        print("Please run 'cookie fetch confgenerator' and then 'confgenerator' to create it.")
        return false
    end

    local func, loadErr = loadfile(CONFIG_FILE_PATH)
    if not func then
        print("CRITICAL: Error loading config file: " .. CONFIG_FILE_PATH .. " - " .. tostring(loadErr))
        return false
    end

    local success, resultTable = pcall(func)
    if not success or type(resultTable) ~= "table" then
        print("CRITICAL: Error executing or parsing config file: " .. CONFIG_FILE_PATH)
        if not success then print("  Reason: " .. tostring(resultTable)) end
        return false
    end

    print("Loaded main configuration from " .. CONFIG_FILE_PATH)

    -- Apply global settings first if they exist
    if resultTable.global and type(resultTable.global) == "table" then
        for k, v in pairs(resultTable.global) do
            CFG[k] = v
        end
    end

    -- Apply startup-specific settings
    if resultTable.startup and type(resultTable.startup) == "table" then
        for k, v in pairs(resultTable.startup) do
            CFG[k] = v
        end
    else
        print("Warning: 'startup' section not found in " .. CONFIG_FILE_PATH .. ". Using minimal defaults.")
    end
    return true
end

if not loadConfiguration() then
    -- Minimal defaults if config loading failed, to allow cookie to potentially fix things.
    CFG.cookieScriptName = CFG.cookieScriptName or "cookie"
    CFG.scriptToFetchOnBoot = CFG.scriptToFetchOnBoot or "startup" -- Default to refetching itself if no other target
    print("Attempting to run with minimal defaults due to configuration load failure.")
end

-- Configuration based on loaded CFG or minimal defaults
local COOKIE_SCRIPT_NAME = CFG.cookieScriptName
local SCRIPT_TO_FETCH_ON_BOOT = CFG.scriptToFetchOnBoot

if not COOKIE_SCRIPT_NAME or not SCRIPT_TO_FETCH_ON_BOOT then
    print("CRITICAL: Essential configuration (cookieScriptName, scriptToFetchOnBoot) missing.")
    print("Cookieboot cannot proceed.")
    return
end

-- Check if the cookie script exists
if not fs.exists(COOKIE_SCRIPT_NAME) then
    print("Error: " .. COOKIE_SCRIPT_NAME .. " script not found.")
    print("Please ensure " .. COOKIE_SCRIPT_NAME .. ".lua is in the current directory or path, or fetch it.")
    return
end

print("Running " .. COOKIE_SCRIPT_NAME .. " to fetch/update '" .. SCRIPT_TO_FETCH_ON_BOOT .. "'...")
local success, reason = shell.run(COOKIE_SCRIPT_NAME, "fetch", SCRIPT_TO_FETCH_ON_BOOT)

if success then
    print(COOKIE_SCRIPT_NAME .. " executed successfully.")
    if fs.exists(SCRIPT_TO_FETCH_ON_BOOT) then
      print("Attempting to run " .. SCRIPT_TO_FETCH_ON_BOOT .. "...")
      local runSuccess, runReason = shell.run(SCRIPT_TO_FETCH_ON_BOOT)
      if not runSuccess then
        print("Error running " .. SCRIPT_TO_FETCH_ON_BOOT .. ": " .. tostring(runReason))
      end
    else
      print("Error: " .. SCRIPT_TO_FETCH_ON_BOOT .. " not found after fetch.")
    end
else
    print("Error running " .. COOKIE_SCRIPT_NAME .. ".")
    if reason then
        print("Reason: " .. reason)
    end
end

print("Startup script finished.")
