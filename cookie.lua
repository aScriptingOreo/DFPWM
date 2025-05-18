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

local baseURL = "https://s3.7thseraph.org/browser/wiki.avakot.org/oreo.temp/" -- Updated baseURL
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

-- Step 2: Fetch the new file using http.get
print("Fetching " .. downloadURL .. " -> " .. localFilename)

local handle, err = http.get(downloadURL)

if handle then
    local content = handle.readAll()
    handle.close()

    if content then
        local file, writeErr = fs.open(localFilename, "w")
        if file then
            file.write(content)
            file.close()
            print("Successfully fetched and saved: " .. localFilename)
        else
            print("Error: Failed to open local file for writing: " .. localFilename)
            if writeErr then
                print("Reason: " .. writeErr)
            end
        end
    else
        print("Error: Failed to read content from URL.")
        -- err from http.get might be more relevant here if content is nil after successful handle
        if err then print("Initial HTTP Error (if any): " .. err) end
    end
else
    print("Error: Failed to fetch file using http.get.")
    if err then
        print("Reason: " .. err)
    end
    print("Please check the URL and your network connection.")
    print("URL attempted: " .. downloadURL)
end
