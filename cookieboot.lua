-- cookieboot.lua
-- This script runs the 'cookie' utility to fetch/update a designated script on startup.

-- Configuration
local COOKIE_SCRIPT_NAME = "cookie"          -- The name of your cookie utility script
local SCRIPT_TO_FETCH_ON_BOOT = "startup" -- The name of the script (without .lua) to fetch on boot

-- Check if the cookie script exists
if not fs.exists(COOKIE_SCRIPT_NAME) then
    print("Error: " .. COOKIE_SCRIPT_NAME .. " script not found.")
    print("Please ensure " .. COOKIE_SCRIPT_NAME .. ".lua is in the current directory or path.")
    return
end

print("Running " .. COOKIE_SCRIPT_NAME .. " to fetch/update '" .. SCRIPT_TO_FETCH_ON_BOOT .. "'...")

-- Construct the command to run: cookie fetch <SCRIPT_TO_FETCH_ON_BOOT>
local success, reason = shell.run(COOKIE_SCRIPT_NAME, "fetch", SCRIPT_TO_FETCH_ON_BOOT)

if success then
    print(COOKIE_SCRIPT_NAME .. " executed successfully.")
    -- Run the fetched script
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

print("Cookieboot finished.")
