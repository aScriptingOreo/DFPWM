local monitor = peripheral.wrap("left") -- Replace with the side the monitor is on
monitor.clear()

local width, height = monitor.getSize()
local centerY = math.floor(height / 2)
local mainLineFixedLength = math.floor(width * 0.75) -- The fixed length of the main line
local mainLineCurrentX = 1 - mainLineFixedLength     -- Current X-coordinate of the main line's start (initially off-screen left)
local mainLineTargetX = 1                            -- Target X-coordinate for the main line's start
local mainLineIsStationary = false                   -- Flag to indicate if the main line has reached its final position

local branches = {}

-- Function to draw the main line
local function drawMainLine()
    for i = 0, mainLineFixedLength - 1 do
        local xPos = mainLineCurrentX + i
        if xPos >= 1 and xPos <= width then -- Only draw if the character is within screen bounds
            monitor.setCursorPos(xPos, centerY)
            monitor.write("=")
        end
    end
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

-- Function to update branches
local function updateBranches()
    for i, branch in ipairs(branches) do
        branch.startX = branch.startX - 1
        if branch.startX < 1 then
            table.remove(branches, i)
        else
            drawBranchLine(branch.startX, branch.startY, branch.length, branch.direction)
        end
    end
end

-- Main loop
while true do
    monitor.clear()

    -- Update main line position until it reaches its target and becomes stationary
    if not mainLineIsStationary then
        mainLineCurrentX = mainLineCurrentX + 1
        if mainLineCurrentX >= mainLineTargetX then
            mainLineCurrentX = mainLineTargetX
            mainLineIsStationary = true
        end
    end

    -- Draw the main line
    drawMainLine()

    -- Update and draw branches
    updateBranches()

    -- Randomly spawn branching lines
    if math.random(1, 10) == 1 then
        local branchLength = math.random(3, 7)
        local direction = math.random(0, 1) == 1 and 1 or -1
        -- Branches spawn from the current end of the main line
        local spawnStartX = mainLineCurrentX + mainLineFixedLength - 1
        local startY = centerY
        -- Only spawn branches if the main line is somewhat formed or fully stationary
        if mainLineIsStationary or spawnStartX >= 1 then 
            table.insert(branches, {startX = spawnStartX, startY = startY, length = branchLength, direction = direction})
        end
    end

    sleep(0.1) -- Adjust the speed of the animation
end
