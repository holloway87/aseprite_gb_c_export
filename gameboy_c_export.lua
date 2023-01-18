if app.apiVersion < 1 then
    return app.alert("This script requires at least Aseprite v1.2.10-beta3")
end

local sprite = app.activeSprite
if not sprite then
    return app.alert("No active sprite")
end

if sprite.colorMode ~= ColorMode.INDEXED then
    return app.alert("The sprite must be in indexed color mode")
end

local tiles_size_x, tiles_check_x = math.modf(sprite.width / 8)
local tiles_size_y, tiles_check_y = math.modf(sprite.height / 8)
if tiles_check_x ~= 0 or tiles_check_y ~= 0 then
    return app.alert("The sprite resolution needs to be divisible by 8x8")
end

local dialog = Dialog()
dialog:label{text="Select the filename to create the c source code."}:newrow()
dialog:label{text="It will also create the .h header file."}
dialog:file{id="file", label="Filename", entry=true, save=true, filetypes={"c"}}
dialog:check{id="include_map", label="Include map", selected=true}
dialog:button{id="confirm", text="Create"}
dialog:button{text="Cancel"}
dialog:show()
if not dialog.data.confirm then
    return
end

if dialog.data.file == "" then
    return app.alert("Choose a file to create the source code")
end

local frame = app.activeFrame
if frame == nil then
    frame = 1
end
local image = Image(sprite.width, sprite.height, sprite.colorMode)
image:drawSprite(sprite, app.activeFrame)

local offset_x = 0
local offset_y = 0

local tiles = {}
local tiles_map = {}

repeat
    local tile = ""
    for y = 0, 7 do
        local row_high = 0
        local row_low = 0
        for x = 0, 7 do
            local pixel = image:getPixel(x + offset_x, y + offset_y)
            pixel = pixel % 4

            if pixel >= 2 then
                row_high = row_high + 2 ^ (7 - x)
            end
            if pixel == 1 or pixel == 3 then
                row_low = row_low + 2 ^ (7 - x)
            end
        end

        tile = tile .. "0x" .. string.format("%02x", row_low) .. ", " .. "0x" .. string.format("%02x", row_high) .. ", "
    end
    local found_tile = 0
    for t = 1, #tiles do
        if tiles[t] == tile then
            found_tile = t
        end
    end
    if found_tile == 0 then
        table.insert(tiles, tile)
        table.insert(tiles_map, #tiles)
    else
        table.insert(tiles_map, found_tile)
    end

    offset_x = offset_x + 8
    if offset_x == sprite.width then
        offset_x = 0
        offset_y = offset_y + 8
    end
until offset_x == 0 and offset_y == sprite.height


local var_name = string.reverse(dialog.data.file)
var_name = string.sub(var_name, 0, string.find(var_name, "/", 1, true) - 1)
var_name = string.reverse(var_name)
var_name = string.sub(var_name, 0, -3)

local file = io.open(dialog.data.file, "w")

file:write("/*\ntile size: " .. #tiles .. "\n")
if dialog.data.include_map then
    file:write("map size: " .. tiles_size_x .. "x" .. tiles_size_y .. "\n")
end
file:write("*/\n\nconst unsigned char " .. var_name .. "_tiles[] = {\n")
for t = 1, #tiles do
    file:write("    " .. tiles[t] .. "\n")
end
file:write("\n};\n")

if dialog.data.include_map then
    file:write("\nconst unsigned char " .. var_name .. "_map[" .. (#tiles_map) .. "] = {")
    for t = 1, #tiles_map do
        if (t - 1) % 16 == 0 then
            file:write("\n    ")
        end
        file:write((tiles_map[t] - 1) .. ", ")
    end
    file:write("\n};\n")
end

file:close()

file = io.open(string.sub(dialog.data.file, 0, -2) .. "h", "w")
file:write("#define " .. var_name .. "_tiles_count " .. #tiles .. "\n")
if dialog.data.include_map then
    file:write("#define " .. var_name .. "_tiles_width " .. tiles_size_x .. "\n")
    file:write("#define " .. var_name .. "_tiles_height " .. tiles_size_y .. "\n")
end
file:write("extern unsigned char " .. var_name .. "_tiles[];\n")
if dialog.data.include_map then
    file:write("\nextern unsigned char " .. var_name .. "_map[];\n")
end
file:close()

app.alert("Code creation completed.")
