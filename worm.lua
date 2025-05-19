-- worm.lua
-- Strictly relies on /cookieSuite/conf.lua for settings with no fallbacks.

local CONFIG_DIR = "/cookieSuite"
local CONFIG_FILE_PATH = CONFIG_DIR .. "/conf.lua"
local LOG_DIR = CONFIG_DIR .. "/log"
local LOG_FILE_PATH = LOG_DIR .. "/worm.log"

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
logMessage("Starting worm.lua")

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

-- Check for worm section
if not config.worm or type(config.worm) ~= "table" then
    local errMsg = "CRITICAL: Missing 'worm' section in configuration"
    logMessage(errMsg)
    error(errMsg)
end

-- Extract required configuration values
local monitorSide = config.worm.monitorSide
local INITIAL_SPEED = config.worm.initialSpeed
local START_LENGTH = config.worm.startLength
local FOOD_CHAR = config.worm.foodChar
local WORM_CHARS = config.worm.wormChars
local EMPTY_CHAR = " "

-- Validate required configuration
if not monitorSide or not INITIAL_SPEED or not START_LENGTH or not FOOD_CHAR or not WORM_CHARS then
    local errMsg = "CRITICAL: Missing required configuration values in worm section"
    logMessage(errMsg)
    error(errMsg)
end

logMessage("Using configuration: monitorSide=" .. monitorSide .. 
           ", initialSpeed=" .. INITIAL_SPEED .. ", startLength=" .. START_LENGTH)

-- Initialize monitor
local monitor = peripheral.wrap(monitorSide)
if not monitor then
    local errMsg = "Monitor not found on side: " .. monitorSide
    logMessage(errMsg)
    error(errMsg)
end

local term_target = term.redirect(monitor)
local W, H = monitor.getSize()
logMessage("Monitor size: " .. W .. "x" .. H)

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
    for i = 1, #worm do
        local segment = worm[i]
        local charToDraw = WORM_CHARS.DOT -- Default character

        if #worm == 1 then -- Single segment worm
            if dx == 1 or dx == -1 then -- Moving horizontally
                charToDraw = WORM_CHARS.HORIZONTAL
            elseif dy == 1 or dy == -1 then -- Moving vertically
                charToDraw = WORM_CHARS.VERTICAL
            end
        else
            local prevSegment = worm[i-1] -- nil for head
            local nextSegment = worm[i+1] -- nil for tail

            if not prevSegment then -- Head (i == 1)
                local nextSeg = worm[2] -- Must exist if #worm > 1
                if segment.x == nextSeg.x then -- Vertical movement relative to next segment
                    charToDraw = WORM_CHARS.VERTICAL
                elseif segment.y == nextSeg.y then -- Horizontal movement relative to next segment
                    charToDraw = WORM_CHARS.HORIZONTAL
                end
            elseif not nextSegment then -- Tail (i == #worm)
                local prevSeg = worm[#worm-1] -- Must exist
                if segment.x == prevSeg.x then -- Vertical connection to previous
                    charToDraw = WORM_CHARS.VERTICAL
                elseif segment.y == prevSeg.y then -- Horizontal connection to previous
                    charToDraw = WORM_CHARS.HORIZONTAL
                end
            else -- Body segment (has previous and next)
                local v_prev_x = segment.x - prevSegment.x
                local v_prev_y = segment.y - prevSegment.y
                local v_next_x = nextSegment.x - segment.x
                local v_next_y = nextSegment.y - segment.y

                if v_prev_y == 0 and v_next_y == 0 then -- Straight horizontal
                    charToDraw = WORM_CHARS.HORIZONTAL
                elseif v_prev_x == 0 and v_next_x == 0 then -- Straight vertical
                    charToDraw = WORM_CHARS.VERTICAL
                else -- Corner piece
                    if (v_prev_x == 0 and v_prev_y == 1 and v_next_x == 1 and v_next_y == 0) or  -- From Up, To Right
                       (v_prev_x == -1 and v_prev_y == 0 and v_next_x == 0 and v_next_y == -1) then -- From Right, To Up
                        charToDraw = WORM_CHARS.BOTTOM_LEFT -- └
                    elseif (v_prev_x == 0 and v_prev_y == 1 and v_next_x == -1 and v_next_y == 0) or -- From Up, To Left
                           (v_prev_x == 1 and v_prev_y == 0 and v_next_x == 0 and v_next_y == -1) then  -- From Left, To Up
                        charToDraw = WORM_CHARS.BOTTOM_RIGHT -- ┘
                    elseif (v_prev_x == 0 and v_prev_y == -1 and v_next_x == 1 and v_next_y == 0) or -- From Down, To Right
                           (v_prev_x == -1 and v_prev_y == 0 and v_next_x == 0 and v_next_y == 1) then -- From Right, To Down
                        charToDraw = WORM_CHARS.TOP_LEFT -- ┌
                    elseif (v_prev_x == 0 and v_prev_y == -1 and v_next_x == -1 and v_next_y == 0) or -- From Down, To Left
                           (v_prev_x == 1 and v_prev_y == 0 and v_next_x == 0 and v_next_y == 1) then  -- From Left, To Down
                        charToDraw = WORM_CHARS.TOP_RIGHT -- ┐
                    end
                end
            end
        end
        monitor.setCursorPos(segment.x, segment.y)
        monitor.write(charToDraw)
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
                gameOver = true -- No path to food, or path is just the current spot
                return
            end
        else
            gameOver = true -- No food and no path, or game won
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
        -- This case should ideally be covered by the path finding logic setting gameOver
        gameOver = true 
        return
    end

    local newHead = {x = newHeadX, y = newHeadY}

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
