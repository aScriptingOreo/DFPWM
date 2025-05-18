local monitor = peripheral.wrap("left") -- Replace with the side the monitor is on
monitor.clear()

local width, height = monitor.getSize()
local centerY = math.floor(height / 2)
local lineLength = width
local mainLinePos = 1

-- Function to draw the main line
local function drawMainLine()
    monitor.setCursorPos(mainLinePos, centerY)
    monitor.write("=")
end

-- Function to draw a branching line
local function drawBranchLine(startX, startY, length, direction)
    for i = 1, length do
        local currentX = startX + i
        local currentY = startY + (i * direction)
        if currentX <= width and currentY >= 1 and currentY <= height then
            monitor.setCursorPos(currentX, currentY)
            monitor.write("/")
        end
    end
end

-- Main loop
while true do
    monitor.clear()

    -- Draw the main line
    drawMainLine()

    -- Randomly spawn branching lines
    if math.random(1, 10) == 1 then
        local branchLength = math.random(3, 7)
        local direction = math.random(0, 1) == 1 and 1 or -1
        drawBranchLine(mainLinePos, centerY, branchLength, direction)
    end

    -- Move the main line to the right
    mainLinePos = mainLinePos + 1
    if mainLinePos > width then
        mainLinePos = 1
    end

    sleep(0.1) -- Adjust the speed of the animation
end
