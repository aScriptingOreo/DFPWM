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

        if currentX >= 1 and currentX <= width and currentY >= 1 and currentY <= height then
            local charToDraw
            if direction == 1 then
                charToDraw = "\\" -- Downwards
            else
                charToDraw = "/"  -- Upwards
            end

            -- Add variance
            local randVal = math.random(1, 40)
            if randVal == 1 then
                charToDraw = "*" -- Glitch
            elseif randVal == 2 then
                charToDraw = "+" -- Junction/instability
            end

            monitor.setCursorPos(currentX, currentY)
            monitor.write(charToDraw)
        end
    end
end

-- Function to update branches
local function updateBranches()
    local i = 1
    while i <= #branches do
        local branch = branches[i]
        branch.startX = branch.startX - 1

        -- Calculate effective length for growth
        local distanceMoved = branch.spawnConnectionX - branch.startX
        local growthAmount = math.floor(distanceMoved / 3) -- Grows 1 unit for every 3 units moved left
        local currentEffectiveLength = branch.initialLength + growthAmount
        currentEffectiveLength = math.min(currentEffectiveLength, branch.maxLength)
        currentEffectiveLength = math.max(currentEffectiveLength, 1) -- Ensure length is at least 1

        -- Remove branch if it's completely off-screen to the left
        if branch.startX + currentEffectiveLength < 1 then
            table.remove(branches, i)
            -- No increment for i, as the next element is now at current i
        else
            drawBranchLine(branch.startX, branch.startY, currentEffectiveLength, branch.direction)
            i = i + 1
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
        local initialLength = math.random(2, 5) -- Start smaller
        local maxLength = initialLength + math.random(3, 7) -- Max growth
        local direction = math.random(0, 1) == 1 and 1 or -1
        local spawnConnectionPointX = mainLineCurrentX + mainLineFixedLength - 1
        local startY = centerY
        
        if mainLineIsStationary or spawnConnectionPointX >= 1 then
            table.insert(branches, {
                startX = spawnConnectionPointX,
                startY = startY,
                initialLength = initialLength,
                maxLength = maxLength,
                direction = direction,
                spawnConnectionX = spawnConnectionPointX -- Store the X at which it connected to the main line
            })
        end
    end

    sleep(0.1) -- Adjust the speed of the animation
end
