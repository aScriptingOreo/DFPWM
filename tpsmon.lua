-- tpsmon.lua
-- Reads redstone signal from a specified side and displays it on a monitor.

-- Configuration
local MONITOR_SIDE = "left"          -- Side the monitor is attached to
local REDSTONE_SOURCE_SIDE = "bottom" -- Side the redstone emitting block is on
local UPDATE_INTERVAL = 1           -- Seconds between updates

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
local сигналFunction
if rsSource.getAnalogInput then
    сигналFunction = function() return rsSource.getAnalogInput(REDSTONE_SOURCE_SIDE) end
elseif rsSource.getInput then -- Fallback for simple on/off if getAnalogInput isn't there
    сигналFunction = function() return rsSource.getInput(REDSTONE_SOURCE_SIDE) and 15 or 0 end
else
    error("Peripheral on side '" .. REDSTONE_SOURCE_SIDE .. "' does not support getAnalogInput or getInput. Cannot read redstone signal.")
end

local term_target_mon = term.current() -- Save current terminal target
term.redirect(mon) -- Redirect terminal output to the monitor

mon.clear()
mon.setCursorPos(1, 1)
mon.write("Redstone Signal Monitor")

local function displaySignalStrength()
    local strength = сигналFunction()

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
