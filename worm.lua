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
local dx, dy -- Added: Current direction of the worm (dx, dy)
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

-- Helper for update: checks if a potential next head position is valid
local function isSafeMove(nextX, nextY, currentWorm)
    if nextX < 1 or nextX > W or nextY < 1 or nextY > H then
        return false -- Wall collision
    end
    -- Check collision with worm's own body.
    -- The head cannot move into any cell currently occupied by any segment.
    for _, segment in ipairs(currentWorm) do
        if segment.x == nextX and segment.y == nextY then
            return false -- Self-collision
        end
    end
    return true
end

local function update()
    if gameOver then return end

    local head = worm[1]
    local chosenNextX, chosenNextY
    local chosenDx, chosenDy = dx, dy -- Default to current direction, might be overridden

    if not food then
        -- No food: try to continue straight. If blocked, try to turn.
        -- This state should be rare if food spawns immediately.
        local currentDirX, currentDirY = head.x + dx, head.y + dy
        if isSafeMove(currentDirX, currentDirY, worm) then
            chosenNextX, chosenNextY = currentDirX, currentDirY
            -- chosenDx, chosenDy remain dx, dy
        else
            -- Try turning left (relative to current dx, dy)
            local leftTurnDx, leftTurnDy = -dy, dx
            local tryLeftX, tryLeftY = head.x + leftTurnDx, head.y + leftTurnDy
            if isSafeMove(tryLeftX, tryLeftY, worm) then
                chosenNextX, chosenNextY = tryLeftX, tryLeftY
                chosenDx, chosenDy = leftTurnDx, leftTurnDy
            else
                -- Try turning right (relative to current dx, dy)
                local rightTurnDx, rightTurnDy = dy, -dx
                local tryRightX, tryRightY = head.x + rightTurnDx, head.y + rightTurnDy
                if isSafeMove(tryRightX, tryRightY, worm) then
                    chosenNextX, chosenNextY = tryRightX, tryRightY
                    chosenDx, chosenDy = rightTurnDx, rightTurnDy
                else
                    gameOver = true -- Trapped
                    return
                end
            end
        end
    else -- Food exists, make an intelligent move
        local potentialMoves = {}

        -- Define potential directions: straight, left turn, right turn
        local directionsToTry = {
            {ddx = dx,    ddy = dy,    isStraight = true},  -- Straight
            {ddx = -dy,   ddy = dx,    isStraight = false}, -- Left relative
            {ddx = dy,    ddy = -dx,   isStraight = false}  -- Right relative
        }

        for _, dirInfo in ipairs(directionsToTry) do
            local nextX, nextY = head.x + dirInfo.ddx, head.y + dirInfo.ddy
            if isSafeMove(nextX, nextY, worm) then
                table.insert(potentialMoves, {
                    x = nextX, y = nextY,
                    newDx = dirInfo.ddx, newDy = dirInfo.ddy,
                    dist = math.abs(nextX - food.x) + math.abs(nextY - food.y),
                    isStraight = dirInfo.isStraight
                })
            end
        end

        if #potentialMoves == 0 then
            gameOver = true -- Trapped, no safe moves
            return
        end

        -- Sort moves: by distance (ascending), then prefer straight moves
        table.sort(potentialMoves, function(a, b)
            if a.dist == b.dist then
                return a.isStraight -- true comes before false (so straight is preferred)
            end
            return a.dist < b.dist
        end)
        
        local bestMove = potentialMoves[1]
        chosenNextX, chosenNextY = bestMove.x, bestMove.y
        chosenDx, chosenDy = bestMove.newDx, bestMove.newDy
    end

    dx, dy = chosenDx, chosenDy -- Update the worm's main direction

    local newHead = {x = chosenNextX, y = chosenNextY}
    table.insert(worm, 1, newHead) -- Add new head

    if food and newHead.x == food.x and newHead.y == food.y then
        score = score + 1
        if score >= (W * H) - START_LENGTH then -- Max possible score
            gameWon = true
            gameOver = true
            food = nil -- No more food to spawn
        else
            spawnFood()
        end
    else
        -- Remove tail if not eating food
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
