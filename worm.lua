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
local path
local pathIndex
local score
local gameOver
local gameWon
local gameSpeed

local function generateHamiltonianPath(gridW, gridH)
    local p = {}
    for y = 1, gridH do
        if y % 2 == 1 then -- Move right
            for x = 1, gridW do
                table.insert(p, {x = x, y = y})
            end
        else -- Move left
            for x = gridW, 1, -1 do
                table.insert(p, {x = x, y = y})
            end
        end
    end
    return p
end

local function isPositionInWorm(posX, posY, currentWorm)
    for _, segment in ipairs(currentWorm) do
        if segment.x == posX and segment.y == posY then
            return true
        end
    end
    return false
end

local function spawnFood()
    if score == (W * H) - START_LENGTH then -- No space left for food if screen is almost full
        food = nil -- Or handle win condition more explicitly
        return
    end

    local foodX, foodY
    repeat
        foodX = math.random(1, W)
        foodY = math.random(1, H)
    until not isPositionInWorm(foodX, foodY, worm)
    food = {x = foodX, y = foodY}
end

local function initGame()
    monitor.clear()
    monitor.setCursorPos(1,1)

    path = generateHamiltonianPath(W, H)
    pathIndex = START_LENGTH

    worm = {}
    for i = 1, START_LENGTH do
        -- Initialize worm segments based on the start of the path
        if path[i] then
             table.insert(worm, 1, {x = path[i].x, y = path[i].y}) -- Head is worm[1]
        else
            -- This case should ideally not happen if START_LENGTH is small
            -- and path is generated correctly. For safety, place at a default.
            table.insert(worm, 1, {x = math.floor(W/2) + 1 - i, y = math.floor(H/2)})
        end
    end
    
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

local function update()
    if gameOver then return end

    if pathIndex > #path then
        -- This means the worm has traversed the entire path.
        -- If it hasn't filled the screen, it's a form of game over or win based on score.
        if score >= (W * H) - START_LENGTH then
            gameWon = true
        end
        gameOver = true
        return
    end

    local nextHeadPos = path[pathIndex]
    if not nextHeadPos then -- Should not happen if pathIndex is managed correctly
        gameOver = true
        return
    end

    local newHead = {x = nextHeadPos.x, y = nextHeadPos.y}

    -- Check for collision with walls (shouldn't happen with this path logic if grid is standard)
    if newHead.x < 1 or newHead.x > W or newHead.y < 1 or newHead.y > H then
        gameOver = true
        return
    end
    
    -- Self-collision is theoretically avoided by the Hamiltonian path if the worm isn't too long
    -- for a "loop" in the path on small grids. For a simple boustrophedon, this is safe.

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
        local tail = table.remove(worm)
        -- No need to clear the tail's old position on screen as monitor.clear() handles it
    end

    pathIndex = pathIndex + 1
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
