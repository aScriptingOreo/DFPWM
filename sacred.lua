local monitor = peripheral.wrap("left") -- Replace with the side the monitor is on
monitor.clear()

local width, height = monitor.getSize()
local centerY = math.floor(height / 2)
local mainLineFixedLength = math.floor(width * 0.75)
local mainLineCurrentX = 1 - mainLineFixedLength
local mainLineTargetX = 1
local mainLineIsStationary = false

local branches = {}

-- ASCII Art for TVA Logo
local tvaLogo = {
    " _________  __   __   ________      ",
    "/________/\\/_/\\ /_/\\ /_______/\\     ",
    "\\__.::.__\\/\\:\\ \\\\ \\ \\\\::: _  \\ \\    ",
    "   \\::\\ \\   \\:\\ \\\\ \\ \\\\::(_)  \\ \\   ",
    "    \\::\\ \\   \\:\\_/.:\\ \\\\:: __  \\ \\  ",
    "     \\::\\ \\   \\ ..::/ / \\:.\\ \\  \\ \\ ",
    "      \\__\\/    \\___/_(   \\__\\/\\__\\/ "
}
local logoHeight = #tvaLogo
local logoWidth = 0
if logoHeight > 0 then logoWidth = string.len(tvaLogo[1]) end

local logoCurrentY = 1 - logoHeight -- Start off-screen top
local logoTargetY = 2               -- Target Y for the top line of the logo
local logoStartX = width - logoWidth + 1 -- Align to top-right
local logoIsStationary = false

-- ASCII Art for Clock Digits (5x5 example)
local asciiChars = {
    ['0'] = {" ### ", "#   #", "# # #", "#   #", " ### "},
    ['1'] = {"  #  ", " ##  ", "  #  ", "  #  ", " ### "},
    ['2'] = {" ### ", "#   #", "  ## ", " #   ", "#####"},
    ['3'] = {" ### ", "#   #", "  ## ", "#   #", " ### "},
    ['4'] = {"#  # ", "#  # ", "#####", "   # ", "   # "},
    ['5'] = {"#####", "#    ", "#### ", "#   #", " ### "},
    ['6'] = {" ### ", "#    ", "#### ", "#   #", " ### "},
    ['7'] = {"#####", "   # ", "  #  ", " #   ", " #   "},
    ['8'] = {" ### ", "#   #", " ### ", "#   #", " ### "},
    ['9'] = {" ### ", "#   #", " ####", "    #", " ### "},
    [':'] = {"     ", "  #  ", "     ", "  #  ", "     "}
}
local clockAsciiHeight = 5
local clockDigitWidth = 5

local clockState = "sliding" -- "sliding", "stable" (removed "shuffling")
local clockCurrentY = 1 - clockAsciiHeight -- Start off-screen top
local clockTargetY = 2                     -- Target Y for the top line of the clock (top-left)
-- Removed clockShuffleEndTime, clockShuffleDuration
local clockDisplayString = ""

-- Boot-up sequence variables
local bootUpMessages = {
    "Activate primary and backup power.", "Run system diagnostics.", "Synchronize temporal sensors.",
    "Enable biometric and anomaly detection.", "Set target temporal coordinates.", "Engage interlocks and shutdown protocols.",
    "Activate communication systems.", "Set life support and conditions.", "Activate temporal shielding.",
    "Load and verify timeline path.", "Confirm personnel and brief mission.", "Cross-verify with command.",
    "Initiate Time Door sequence.", "Confirm gateway stability.", "Proceed with mission clearance.",
    "Adjust systems as needed.", "Review emergency procedures.", "Prepare for deactivation.",
    "Shutdown Time Door safely.", "Report mission status to TVA."
}
local currentBootMessageText = ""
local bootMessageDisplayStartTime = 0
local bootMessageDuration = 0.6 -- seconds per message
local nextBootMessageIndex = 1
local allBootMessagesDisplayed = false


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
local function drawBranchLine(branchData, length)
    local startX = branchData.startX
    local startY = branchData.startY
    local direction = branchData.direction
    local isExtraHorizontal = branchData.isExtraHorizontal

    local diagonalStepsTaken = 0
    for i = 1, length do
        local currentX = startX + i
        local currentY
        local charToDraw

        local patternLength = 3 -- Default: Diag, Joint, Horiz
        if isExtraHorizontal then patternLength = 5 end -- e.g., Diag, Joint, Horiz, Horiz, Horiz

        local segmentInPattern = (i - 1) % patternLength

        if segmentInPattern == 0 then -- Diagonal segment
            diagonalStepsTaken = diagonalStepsTaken + 1
            if direction == 1 then charToDraw = "\\" else charToDraw = "/" end
        elseif segmentInPattern == 1 then -- Joint segment
            charToDraw = "+"
        else -- Horizontal segment(s)
            charToDraw = "-"
        end
        currentY = startY + (diagonalStepsTaken * direction)

        if currentX >= 1 and currentX <= width and currentY >= 1 and currentY <= height then
            local randVal = math.random(1, 40)
            if randVal == 1 then
                charToDraw = "*"
            elseif randVal == 2 and charToDraw ~= "+" then -- Don't override structural '+' with random '+'
                charToDraw = "+"
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

        local distanceMoved = branch.spawnConnectionX - branch.startX
        local growthAmount = math.floor(distanceMoved / 3)
        local currentEffectiveLength = branch.initialLength + growthAmount
        currentEffectiveLength = math.min(currentEffectiveLength, branch.maxLength)
        currentEffectiveLength = math.max(currentEffectiveLength, 1)

        if branch.startX + currentEffectiveLength < 1 then
            table.remove(branches, i)
        else
            -- Pass the whole branch object
            drawBranchLine(branch, currentEffectiveLength)
            i = i + 1
        end
    end
end

-- Function to draw the TVA Logo
local function drawTVALogo()
    if logoWidth == 0 or logoStartX < 1 then return end
    for i = 1, logoHeight do
        local yPos = logoCurrentY + i - 1
        if yPos >= 1 and yPos <= height then
            -- Ensure the line is not wider than the screen from its start position
            local lineContent = tvaLogo[i]
            local availableWidth = width - logoStartX + 1
            if string.len(lineContent) > availableWidth then
                lineContent = string.sub(lineContent, 1, availableWidth)
            end
            if string.len(lineContent) > 0 then
                 monitor.setCursorPos(logoStartX, yPos)
                 monitor.write(lineContent)
            end
        end
    end
end

-- Function to draw the Clock
local function drawClock()
    local timeStr = textutils.formatTime(os.time(), false) -- HH:MM (no shuffling)
    clockDisplayString = timeStr

    local totalClockWidth = (string.len(clockDisplayString) * clockDigitWidth)
    local currentClockStartX = 1 -- Align to top-left

    for charIdx = 1, string.len(clockDisplayString) do
        local char = string.sub(clockDisplayString, charIdx, charIdx)
        local asciiArtForChar = asciiChars[char]
        if asciiArtForChar then
            for lineIdx = 1, clockAsciiHeight do
                local yPos = clockCurrentY + lineIdx - 1
                local xPos = currentClockStartX + (charIdx-1)*clockDigitWidth
                if yPos >=1 and yPos <= height and xPos >=1 and (xPos + clockDigitWidth -1) <= width then
                    monitor.setCursorPos(xPos, yPos)
                    monitor.write(asciiArtForChar[lineIdx])
                end
            end
        end
    end
end

-- Function to draw boot message
local function drawBootMessage()
    if not mainLineIsStationary and currentBootMessageText ~= "" and string.len(currentBootMessageText) > 0 then
        local msgX = math.floor((width - string.len(currentBootMessageText)) / 2) + 1
        local msgY = math.floor(height / 2) -- Centered vertically
        if msgX > 0 and msgY > 0 and msgY <= height then
             monitor.setCursorPos(msgX, msgY)
             monitor.write(currentBootMessageText)
        end
    end
end


-- Main loop
while true do
    monitor.clear()

    -- Update main line position
    if not mainLineIsStationary then
        mainLineCurrentX = mainLineCurrentX + 1
        if mainLineCurrentX >= mainLineTargetX then
            mainLineCurrentX = mainLineTargetX
            mainLineIsStationary = true
        end
    end

    -- Update TVA Logo position
    if mainLineIsStationary then
        logoCurrentY = logoTargetY
        logoIsStationary = true
    elseif not logoIsStationary then -- Only try to slide if not yet stationary
        logoCurrentY = logoCurrentY + 1 -- Moving down
        if logoCurrentY >= logoTargetY then
            logoCurrentY = logoTargetY -- Don't overshoot
        end
    end

    -- Update Clock position and state
    if mainLineIsStationary then
        clockCurrentY = clockTargetY
        clockState = "stable"
    elseif clockState == "sliding" then -- Only try to slide if not yet stationary
        clockCurrentY = clockCurrentY + 1 -- Moving down
        if clockCurrentY >= clockTargetY then
            clockCurrentY = clockTargetY -- Don't overshoot
        end
    end
    
    -- Update Boot-up Message
    if not mainLineIsStationary then
        if not allBootMessagesDisplayed then
            if os.time() >= bootMessageDisplayStartTime + bootMessageDuration then
                if nextBootMessageIndex <= #bootUpMessages then
                    currentBootMessageText = bootUpMessages[nextBootMessageIndex]
                    bootMessageDisplayStartTime = os.time()
                    nextBootMessageIndex = nextBootMessageIndex + 1
                else
                    currentBootMessageText = "" -- Clear last message
                    allBootMessagesDisplayed = true
                end
            end
        else
            currentBootMessageText = "" -- Ensure it's clear after all displayed
        end
    elseif currentBootMessageText ~= "" then -- Clear boot message once main line is stationary
        currentBootMessageText = ""
    end

    -- Draw elements
    drawTVALogo()
    drawClock()
    drawBootMessage() -- Drawn after logo/clock so it can overlay if needed, though unlikely with positioning
    drawMainLine()
    updateBranches() -- This also draws branches

    -- Randomly spawn branching lines only after main line is stationary
    if mainLineIsStationary and math.random(1, 10) == 1 then
        local initialLength = math.random(2, 5)
        local maxLength = initialLength + math.random(3, 7)
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
                spawnConnectionX = spawnConnectionPointX,
                isExtraHorizontal = (math.random(1, 4) == 1) -- 25% chance for more horizontal branches
            })
        end
    end

    sleep(0.2)
end
