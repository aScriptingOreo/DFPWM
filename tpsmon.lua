-- tpsmon.lua
-- Reads redstone signal from a specified side and displays it on a monitor.
-- Strictly relies on /cookieSuite/conf.lua for its settings with no fallbacks.

local CONFIG_DIR = "/cookieSuite"
local CONFIG_FILE_PATH = CONFIG_DIR .. "/conf.lua"
local LOG_DIR = CONFIG_DIR .. "/log"
local LOG_FILE_PATH = LOG_DIR .. "/tpsmon.log"

-- Initialize logging
local function ensureLogDir()
    if not fs.isDir(LOG_DIR) then
        fs.makeDir(LOG_DIR)
    end
end

local function logMessage(message)
    ensureLogDir()
    
    -- Create a new log file each time the script runs
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
logMessage("Starting tpsmon.lua")

-- Load configuration strictly from conf.lua
logMessage("Loading configuration from: " .. CONFIG_FILE_PATH)
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

-- Check for tpsmon section
if not config.tpsmon or type(config.tpsmon) ~= "table" then
    local errMsg = "CRITICAL: Missing 'tpsmon' section in configuration"
    logMessage(errMsg)
    error(errMsg)
end

-- Extract required configuration values
local MONITOR_SIDE = config.tpsmon.monitorSide
local REDSTONE_SOURCE_SIDE = config.tpsmon.redstoneSourceSide
local UPDATE_INTERVAL = config.tpsmon.updateInterval
local MONITOR_TITLE = config.tpsmon.title

-- Validate required configuration
if not MONITOR_SIDE or not REDSTONE_SOURCE_SIDE or not UPDATE_INTERVAL or not MONITOR_TITLE then
    local errMsg = "CRITICAL: Missing required configuration values in tpsmon section"
    logMessage(errMsg)
    error(errMsg)
end

logMessage("Using configuration: monitorSide=" .. MONITOR_SIDE .. ", redstoneSourceSide=" .. 
           REDSTONE_SOURCE_SIDE .. ", updateInterval=" .. UPDATE_INTERVAL)

-- Attempt to wrap peripherals
local mon = peripheral.wrap(MONITOR_SIDE)
if not mon then
    local errMsg = "Monitor not found on side: " .. MONITOR_SIDE
    logMessage(errMsg)
    error(errMsg)
end

local rsSource = peripheral.wrap(REDSTONE_SOURCE_SIDE)
if not rsSource then
    local errMsg = "Redstone source not found on side: " .. REDSTONE_SOURCE_SIDE
    logMessage(errMsg)
    error(errMsg)
end

-- Determine method to read redstone signal
local readSignalFunction
if rsSource.getAnalogInput then
    readSignalFunction = function() return rsSource.getAnalogInput(REDSTONE_SOURCE_SIDE) end
    logMessage("Using getAnalogInput method for redstone reading")
elseif rsSource.getInput then
    readSignalFunction = function() return rsSource.getInput(REDSTONE_SOURCE_SIDE) and 15 or 0 end
    logMessage("Using getInput method for redstone reading")
else
    local errMsg = "Peripheral on side '" .. REDSTONE_SOURCE_SIDE .. "' does not support redstone input methods"
    logMessage(errMsg)
    error(errMsg)
end

-- Redirect output to monitor
local term_target_mon = term.current()
term.redirect(mon)
mon.clear()

-- Display title
mon.setCursorPos(1, 1)
mon.write(MONITOR_TITLE)
logMessage("Started monitoring with title: " .. MONITOR_TITLE)

local function displaySignalStrength()
    local strength = readSignalFunction()
    logMessage("Read signal strength: " .. strength)

    mon.setCursorPos(1, 3)
    mon.clearLine()
    mon.write("Signal (0-15): " .. string.format("%2d", strength))

    -- Visual bar
    local w, h = mon.getSize()
    local barWidth = w - 2
    local filledWidth = 0
    if strength > 0 then
        filledWidth = math.floor((strength / 15) * barWidth)
    end
    
    mon.setCursorPos(1, 5)
    mon.clearLine()
    mon.write("[" .. string.rep("=", filledWidth) .. string.rep(" ", barWidth - filledWidth) .. "]")
end

-- Main loop
local running = true
logMessage("Entering main monitoring loop")
while running do
    displaySignalStrength()
    
    -- Handle events
    local timer_id = os.startTimer(UPDATE_INTERVAL)
    local event, p1 = os.pullEvent()
    
    if event == "terminate" then
        running = false
        logMessage("Received terminate signal, stopping")
    end
end

-- Cleanup
mon.clear()
term.redirect(term_target_mon)
logMessage("TPS Monitor stopped")
print("TPS Monitor stopped.")
