-- tpsmon.lua
-- Reads redstone signal from a specified side and displays it on a monitor.
-- Relies on /cookieSuite/conf.lua for its settings.

local CONFIG_FILE_PATH = "/cookieSuite/conf.lua"
local CFG = {} -- Will hold effective configuration

local function loadConfiguration()
    if not fs.exists(CONFIG_FILE_PATH) then
        print("CRITICAL: Main config file not found: " .. CONFIG_FILE_PATH)
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

    if resultTable.global and type(resultTable.global) == "table" then
        for k, v in pairs(resultTable.global) do CFG[k] = v end
    end
    if resultTable.tpsmon and type(resultTable.tpsmon) == "table" then
        for k, v in pairs(resultTable.tpsmon) do CFG[k] = v end
    else
        print("Warning: 'tpsmon' section not found in " .. CONFIG_FILE_PATH .. ". Critical settings might be missing.")
    end
    return true
end

if not loadConfiguration() then
    -- Provide absolutely essential defaults or error out
    CFG.monitorSide = CFG.monitorSide or "top" -- Critical default
    CFG.redstoneSourceSide = CFG.redstoneSourceSide or "bottom" -- Critical default
    CFG.updateInterval = CFG.updateInterval or 1
    CFG.title = CFG.title or "TPS Monitor (Config Error)"
    print("Attempting to run with minimal defaults due to configuration load failure.")
end

-- Use CFG for script operation
local MONITOR_SIDE = CFG.monitorSide
local REDSTONE_SOURCE_SIDE = CFG.redstoneSourceSide
local UPDATE_INTERVAL = CFG.updateInterval
local MONITOR_TITLE = CFG.title

if not MONITOR_SIDE or not REDSTONE_SOURCE_SIDE or not UPDATE_INTERVAL or not MONITOR_TITLE then
    error("Essential tpsmon configuration missing. Please check /cookieSuite/conf.lua")
end

-- Attempt to wrap peripherals
local mon = peripheral.wrap(MONITOR_SIDE)
if not mon then
    error("Monitor not found on side: " .. MONITOR_SIDE .. ". Please attach one or change the side.")
end

local rsSource = peripheral.wrap(REDSTONE_SOURCE_SIDE)
if not rsSource then
    error("Redstone source not found on side: " .. REDSTONE_SOURCE_SIDE .. ". Please attach one.")
end

-- Check if the redstone source has a method to get redstone input
-- Common methods are getAnalogInput (for direct strength) or getInput (for boolean state)
-- We'll prioritize getAnalogInput for strength 0-15
local readSignalFunction -- Renamed for clarity
if rsSource.getAnalogInput then
    readSignalFunction = function() return rsSource.getAnalogInput(REDSTONE_SOURCE_SIDE) end
elseif rsSource.getInput then -- Fallback for simple on/off if getAnalogInput isn't there
    readSignalFunction = function() return rsSource.getInput(REDSTONE_SOURCE_SIDE) and 15 or 0 end
else
    error("Peripheral on side '" .. REDSTONE_SOURCE_SIDE .. "' does not support getAnalogInput or getInput. Cannot read redstone signal.")
end

local term_target_mon = term.current() -- Save current terminal target
term.redirect(mon) -- Redirect terminal output to the monitor

mon.clear()
mon.setCursorPos(1, 1)
mon.write(MONITOR_TITLE) -- Use configured title

local function displaySignalStrength()
    local strength = readSignalFunction()

    mon.setCursorPos(1, 3)
    mon.clearLine()
    mon.write("Signal (0-15): " .. string.format("%2d", strength)) -- Format to take 2 spaces

    -- Visual bar
    local w, h = mon.getSize()
    local barWidth = w - 2 -- Max width for bar, leaving space for borders [ ]
    local filledWidth = 0
    if strength > 0 then -- Avoid division by zero if max is 0 or strength is 0
        filledWidth = math.floor((strength / 15) * barWidth)
    end
    
    mon.setCursorPos(1, 5)
    mon.clearLine()
    mon.write("[" .. string.rep("=", filledWidth) .. string.rep(" ", barWidth - filledWidth) .. "]")
end

-- Main loop
local running = true
while running do
    displaySignalStrength()
    
    -- Handle events to allow exiting (e.g., Ctrl+T)
    local event, p1 = os.pullEvent("timer")
    if event == "terminate" then
        running = false
    end
    sleep(UPDATE_INTERVAL)
end

-- Restore terminal
mon.clear()
term.redirect(term_target_mon)
print("TPS Monitor stopped.")
