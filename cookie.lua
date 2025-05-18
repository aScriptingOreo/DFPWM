local shell = require("shell")
local fs = require("fs")
local http = require("http") -- Required if wget is not available or for manual fallback

local args = {...}

local function printUsage()
    print("Usage: cookie fetch <filename>")
    print("  <filename>: The name of the file without the .lua extension.")
    print("  Example: cookie fetch worm")
end

if #args < 2 or args[1] ~= "fetch" then
    printUsage()
    return
end

local baseFilename = args[2]
if not baseFilename or string.len(baseFilename) == 0 then
    print("Error: Filename cannot be empty.")
    printUsage()
    return
end

local localFilename = baseFilename -- File will be saved locally as <filename> (e.g., "worm")
local remoteFilenameForURL = baseFilename .. ".lua" -- File on GitHub is <filename>.lua (e.g., "worm.lua")

local baseURL = "https://raw.githubusercontent.com/aScriptingOreo/DFPWM/refs/heads/main/"
local downloadURL = baseURL .. remoteFilenameForURL

-- Step 1: Delete the existing local file
if fs.exists(localFilename) then
    if fs.delete(localFilename) then
        print("Deleted existing file: " .. localFilename)
    else
        print("Error: Failed to delete existing file: " .. localFilename)
        -- Optionally, you might want to stop here or allow wget to try overwriting
    end
else
    print("Local file not found, no deletion needed: " .. localFilename)
end

-- Step 2: Fetch the new file using wget
print("Fetching " .. downloadURL .. " -> " .. localFilename)

local success, reason = shell.run("wget", downloadURL, localFilename)

if success then
    if fs.exists(localFilename) then
        print("Successfully fetched and saved: " .. localFilename)
    else
        -- This case might happen if wget reported success but the file wasn't created
        -- (unlikely with standard wget behavior but good to be aware of)
        print("Error: wget reported success, but file not found: " .. localFilename)
        print("Reason from wget (if any): " .. tostring(reason))
    end
else
    print("Error: Failed to fetch file.")
    if reason then
        print("Reason: " .. reason)
    end
    print("Please check the URL and your network connection.")
    print("URL attempted: " .. downloadURL)
end
