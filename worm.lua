local monitor = peripheral.wrap("left")
if not monitor then
    error("Monitor not found on the left. Please attach one or change the side.")
end

local term_target = term.redirect(monitor) -- Redirect terminal output to the monitor

local W, H = monitor.getSize()

-- Game Configuration
local WORM_CHAR = "\140" -- Solid block character '█'
local FOOD_CHAR = "\042" -- Asterisk '*'
local EMPTY_CHAR = " "
local INITIAL_SPEED = 0.1 -- Seconds per frame
local START_LENGTH = 1

-- Game State
local worm
local food
local dx, dy -- Current direction of the worm (dx, dy)
local targetPath -- Added: Stores the calculated path to food
local score
local gameOver
local gameWon
local gameSpeed

local function isPositionOccupied(posX, posY, currentWorm) -- Renamed for clarity, or keep as isPositionInWorm
    for _, segment in ipairs(currentWorm) do
        if segment.x == posX and segment.y == posY then
            return true
        end
    end
    return false
end

local function spawnFood()
    if score == (W * H) - START_LENGTH then 
        food = nil 
        return
    end

    local foodX, foodY
    repeat
        foodX = math.random(1, W)
        foodY = math.random(1, H)
    until not isPositionOccupied(foodX, foodY, worm) -- Use the general check
    food = {x = foodX, y = foodY}
end

local function initGame()
    monitor.clear()
    monitor.setCursorPos(1,1)

    worm = {}
    -- Initialize worm at the center, facing right
    local startX = math.floor(W / 2)
    local startY = math.floor(H / 2)
    for i = 1, START_LENGTH do
        -- Worm segments are added to the front, so build it backwards from head
        table.insert(worm, 1, {x = startX - (i-1), y = startY}) 
    end
    dx = 1 -- Initial direction: right
    dy = 0
    
    targetPath = nil -- Initialize targetPath

    score = 0
    gameOver = false
    gameWon = false
    gameSpeed = INITIAL_SPEED

    spawnFood()
end

local function draw()
    monitor.clear()

    -- Draw worm
    for _, segment in ipairs(worm) do
        monitor.setCursorPos(segment.x, segment.y)
        monitor.write(WORM_CHAR)
    end

    -- Draw food
    if food then
        monitor.setCursorPos(food.x, food.y)
        monitor.write(FOOD_CHAR)
    end

    -- Draw score
    monitor.setCursorPos(1, 1) -- Top-left for score
    monitor.write("Score: " .. score)

    if gameOver then
        local message = gameWon and "YOU WON! SCREEN FILLED!" or "GAME OVER"
        local msgX = math.floor((W - string.len(message)) / 2) + 1
        local msgY = math.floor(H / 2)
        monitor.setCursorPos(msgX, msgY)
        monitor.write(message)
    end
end

-- Helper for pathfinding: checks if a cell is safe to move into during path search
local function isSafeForPathfinding(nextX, nextY, currentWorm)
    if nextX < 1 or nextX > W or nextY < 1 or nextY > H then
        return false -- Wall collision
    end
    -- Check collision with worm's body, EXCLUDING the tail segment
    -- because the tail will move by the time the head gets there.
    for i = 1, #currentWorm - 1 do -- Iterate up to the segment before the tail
        local segment = currentWorm[i]
        if segment.x == nextX and segment.y == nextY then
            return false -- Collision with non-tail part of worm
        end
    end
    return true
end

-- BFS pathfinding function
local function findPathToFood(headX, headY, foodX, foodY, currentWorm)
    local queue = {}
    local visited = {} -- To store visited cells as "x,y" strings

    -- Initial node: current head position, path starts with head
    table.insert(queue, {x = headX, y = headY, path = {{x = headX, y = headY}}})
    visited[headX .. "," .. headY] = true

    while #queue > 0 do
        local current = table.remove(queue, 1) -- Dequeue (FIFO)

        if current.x == foodX and current.y == foodY then
            return current.path -- Path found
        end

        -- Explore neighbors (Up, Down, Left, Right)
        local neighbors = {
            {nx = current.x, ny = current.y - 1}, -- Up
            {nx = current.x, ny = current.y + 1}, -- Down
            {nx = current.x - 1, ny = current.y}, -- Left
            {nx = current.x + 1, ny = current.y}  -- Right
        }

        for _, neighbor in ipairs(neighbors) do
            local visitedKey = neighbor.nx .. "," .. neighbor.ny
            if not visited[visitedKey] and isSafeForPathfinding(neighbor.nx, neighbor.ny, currentWorm) then
                visited[visitedKey] = true
                local newPath = {}
                for _, p_node in ipairs(current.path) do table.insert(newPath, p_node) end
                table.insert(newPath, {x = neighbor.nx, y = neighbor.ny})
                table.insert(queue, {x = neighbor.nx, y = neighbor.ny, path = newPath})
            end
        end
    end
    return nil -- No path found
end


local function update()
    if gameOver then return end

    local head = worm[1]
    local newHeadX, newHeadY

    -- Manage Path
    if not targetPath or #targetPath == 0 then
        if food then
            local pathFound = findPathToFood(head.x, head.y, food.x, food.y, worm)
            if pathFound and #pathFound > 1 then -- Path includes current head, so need at least 2 nodes
                targetPath = pathFound
                table.remove(targetPath, 1) -- Remove current head's position from path to follow
            else
                gameOver = true -- No path to food, or path is just the current spot (shouldn't happen if food exists)
                return
            end
        else
            -- No food (e.g., game won, or just eaten and new one hasn't spawned)
            -- For now, if no food and no path, worm effectively stops or game ends.
            -- If game is won, gameOver would be true.
            -- If food was just eaten, spawnFood should be called before next update.
            -- If somehow no food and game not over, this is a trap state.
            gameOver = true -- Or implement a default "safe move" if no food
            return
        end
    end

    if targetPath and #targetPath > 0 then
        local nextStep = table.remove(targetPath, 1)
        newHeadX, newHeadY = nextStep.x, nextStep.y
        -- Update dx, dy based on the move (optional, but good for consistency if used elsewhere)
        dx = newHeadX - head.x
        dy = newHeadY - head.y
    else
        -- Should have been caught by path finding logic or game over
        gameOver = true 
        return
    end

    local newHead = {x = newHeadX, y = newHeadY}
    
    -- Final safety check before committing the move from path (should be redundant if BFS is correct)
    if not isSafeMove(newHead.x, newHead.y, worm) then
         -- This implies the path became invalid, perhaps due to worm growth not perfectly handled by isSafeForPathfinding
         -- or an edge case. Recalculate path or end game.
         targetPath = nil -- Force recalculation
         -- For simplicity, let's try one more time to find a path from the current head.
         -- If this also fails, then game over.
         local emergencyPath = findPathToFood(head.x, head.y, food.x, food.y, worm)
         if emergencyPath and #emergencyPath > 1 then
            targetPath = emergencyPath
            table.remove(targetPath, 1)
            local nextEmergencyStep = table.remove(targetPath,1)
            newHead = {x = nextEmergencyStep.x, y = nextEmergencyStep.y}
            dx = newHead.x - head.x
            dy = newHead.y - head.y
         else
            gameOver = true
            return
         end
    end


    table.insert(worm, 1, newHead) -- Add new head

    if food and newHead.x == food.x and newHead.y == food.y then
        score = score + 1
        targetPath = nil -- Food eaten, need to recalculate path for new food
        if score >= (W * H) - START_LENGTH then
            gameWon = true
            gameOver = true
            food = nil
        else
            spawnFood() -- New food will be spawned, path recalculated in next update cycle
        end
    else
        table.remove(worm) 
    end
end

-- Main Game Loop
initGame()
while true do
    draw()
    if not gameOver then
        update()
    else
        -- Wait for a key press to restart after game over/win
        local event, key = os.pullEvent("key")
        if key then
            initGame() -- Restart the game
        end
    end
    sleep(gameSpeed)
end

-- Restore terminal output to default if script exits (e.g., via Ctrl+T)
term.redirect(term_target)
