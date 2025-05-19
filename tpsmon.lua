-- tpsmon.lua
-- Reads redstone signal from a specified side and displays it on a monitor.

-- Load Configuration
local CONFIG_FILE_PATH = "/cookieSuite/conf.lua"

-- Internal defaults, to be used if not found in config files
local internalDefaults = {
    monitorSide = "top",
    redstoneSourceSide = "bottom",
    updateInterval = 1,
    title = "Redstone Signal Monitor"
}

local CFG = {}
local loadedMainConfig = nil

if fs.exists(CONFIG_FILE_PATH) then
    local func, loadErr = loadfile(CONFIG_FILE_PATH)
    if func then
        local success, resultTable = pcall(func)
        if success and type(resultTable) == "table" then
            loadedMainConfig = resultTable
            print("Loaded main configuration from " .. CONFIG_FILE_PATH)
        elseif not success then
            print("Error executing config file: " .. CONFIG_FILE_PATH .. " - " .. tostring(resultTable))
        else
            print("Config file did not return a table: " .. CONFIG_FILE_PATH)
        end
    elseif loadErr then
        print("Error loading config file: " .. CONFIG_FILE_PATH .. " - " .. loadErr)
    end
else
    print("Main config file not found: " .. CONFIG_FILE_PATH .. ". Using internal defaults only.")
end

-- 1. Start with internal defaults
for key, value in pairs(internalDefaults) do
    CFG[key] = value
end

-- 2. Override with global settings from conf.lua
if loadedMainConfig and loadedMainConfig.global and type(loadedMainConfig.global) == "table" then
    print("Applying global settings...")
    for key, value in pairs(loadedMainConfig.global) do
        CFG[key] = value
    end
end

-- 3. Override with script-specific (tpsmon) settings from conf.lua
if loadedMainConfig and loadedMainConfig.tpsmon and type(loadedMainConfig.tpsmon) == "table" then
    print("Applying tpsmon-specific settings...")
    for key, value in pairs(loadedMainConfig.tpsmon) do
        CFG[key] = value
    end
end

-- Use CFG for script operation
local MONITOR_SIDE = CFG.monitorSide
local REDSTONE_SOURCE_SIDE = CFG.redstoneSourceSide
local UPDATE_INTERVAL = CFG.updateInterval
local MONITOR_TITLE = CFG.title

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
