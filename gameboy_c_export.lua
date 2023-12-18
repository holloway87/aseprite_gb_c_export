if app.apiVersion < 1 then
    return app.alert("This script requires at least Aseprite v1.2.10-beta3")
end

-- Functions declaration below, scroll down for code execution

GameBoyCExport = {
    color_palettes = {},
    dialog = Dialog(),
    frame = nil,
    image = nil,
    image_offset_x = 0,
    image_offset_y = 0,
    sprite = nil,
    tiles = {},
    tiles_attributes_map = {},
    tiles_map = {},
    tiles_size_x = 0,
    tiles_size_y = 0
}

function GameBoyCExport:checkColorMode()
    if self.sprite.colorMode ~= ColorMode.INDEXED then
        error({message = "The sprite must be in indexed color mode"})
    end
end

function GameBoyCExport:checkTileSize()
    local tiles_size_x, tiles_check_x = math.modf(self.sprite.width / 8)
    local tiles_size_y, tiles_check_y = math.modf(self.sprite.height / 8)
    if tiles_check_x ~= 0 or tiles_check_y ~= 0 then
        error({message = "The sprite resolution needs to be divisible by 8x8"})
    end

    self.tiles_size_x = tiles_size_x
    self.tiles_size_y = tiles_size_y
end

function GameBoyCExport:fillLastColorPalette()
    if #self.color_palettes[#self.color_palettes] < 4 then
        for c = 1, 4 - #self.color_palettes[#self.color_palettes] do
            table.insert(self.color_palettes[#self.color_palettes], Color{r=0, g=0, b=0, a=255})
        end
    end
end

function GameBoyCExport:getColorIndexFromPalette(color, palette)
    for c = 1, #palette do
        if self:isSameColor(color, palette[c]) then
            return c
        end
    end

    return nil
end

function GameBoyCExport:getColorPaletteIndex(colors)
    for p = 1, #self.color_palettes do
        local colors_found_cnt = 0
        local colors_not_found = {}
        for c = 1, #colors do
            local color_found = 0
            for pc = 1, #self.color_palettes[p] do
                if self:isSameColor(colors[c], self.color_palettes[p][pc]) then
                    color_found = 1
                    colors_found_cnt = colors_found_cnt + 1
                end
            end

            if color_found == 0 then
                table.insert(colors_not_found, colors[c])
            end
        end

        if colors_found_cnt == #colors then
            return p
        elseif #self.color_palettes[p] + #colors_not_found <= 4 then
            for c = 1, #colors_not_found do
                table.insert(self.color_palettes[p], colors_not_found[c])
            end

            return p
        end
    end

    table.insert(self.color_palettes, colors)

    return #self.color_palettes
end

function GameBoyCExport:isSameColor(a, b)
    return a.red == b.red and a.green == b.green and a.blue == b.blue
end

function GameBoyCExport:processSprite()
    self.image = Image(self.sprite.width, self.sprite.height, self.sprite.colorMode)
    self.image:drawSprite(self.sprite, self.frame)

    self.color_palettes = {}
    self.image_offset_x = 0
    self.image_offset_y = 0
    self.tiles = {}
    self.tiles_map = {}

    repeat
        self:processTile()

        self.image_offset_x = self.image_offset_x + 8
        if self.image_offset_x == self.sprite.width then
            self.image_offset_x = 0
            self.image_offset_y = self.image_offset_y + 8
        end
    until self.image_offset_x == 0 and self.image_offset_y == self.sprite.height
end

function GameBoyCExport:processTile()
    local tile_colors = self:processTileColors()
    local color_palette_index = self:getColorPaletteIndex(tile_colors)

    local tile = ""
    for y = 0, 7 do
        local row_high = 0
        local row_low = 0
        for x = 0, 7 do
            local pixel = self.image:getPixel(x + self.image_offset_x, y + self.image_offset_y)
            local pixel_color_index = 0

            if self.dialog.data.color_mode then
                local pixel_color = self.palette:getColor(pixel)
                pixel_color_index = self:getColorIndexFromPalette(pixel_color, self.color_palettes[color_palette_index])
                if pixel_color_index == nil then
                    error({message = "could not find color for pixel " .. (x + self.image_offset_x) .. "x"
                        .. (y + self.image_offset_y)})
                end
                pixel_color_index = pixel_color_index -1
            else
                pixel_color_index = pixel % 4
            end

            if pixel_color_index >= 2 then
                row_high = row_high + 2 ^ (7 - x)
            end
            if pixel_color_index == 1 or pixel_color_index == 3 then
                row_low = row_low + 2 ^ (7 - x)
            end
        end

        tile = tile .. "0x" .. string.format("%02x", row_low) .. ", " .. "0x" .. string.format("%02x", row_high) .. ", "
    end

    local found_tile = 0
    for t = 1, #self.tiles do
        if self.tiles[t] == tile then
            found_tile = t
        end
    end
    if found_tile == 0 then
        table.insert(self.tiles, tile)
        table.insert(self.tiles_map, #self.tiles)
    else
        table.insert(self.tiles_map, found_tile)
    end
    table.insert(self.tiles_attributes_map, color_palette_index)
end

function GameBoyCExport:processTileColors()
    local tile_colors = {}

    for y = 0, 7 do
        for x = 0, 7 do
            local color = self.palette:getColor(self.image:getPixel(x + self.image_offset_x, y + self.image_offset_y))
            local color_found = 0

            for t = 1, #tile_colors do
                if self:isSameColor(tile_colors[t], color) then
                    color_found = 1
                end
            end

            if color_found == 0 then
                table.insert(tile_colors, color)
            end
        end
    end

    if #tile_colors > 4 then
        error({message  = "There are more than 4 colors in the tile at offset " .. self.image_offset_x .. "x"
            .. self.image_offset_y})
    end

    return tile_colors
end

function GameBoyCExport:setActiveFrame()
    self.frame = app.activeFrame
    if self.frame == nil then
        self.frame = 1
    end
end

function GameBoyCExport:setActiveSprite()
    self.sprite = app.activeSprite
    if not self.sprite then
        error({message = "No active sprite"})
    end
end

function GameBoyCExport:setColorPalette()
    self.palette = self.sprite.palettes[1]
end

function GameBoyCExport:showDialog()
    self.dialog:label{text="Select the filename to create the c source code."}:newrow()
    self.dialog:label{text="It will also create the .h header file."}
    self.dialog:file{id="file", label="Filename", entry=true, save=true, filetypes={"c"}}
    self.dialog:check{id="include_map", label="Include map", selected=true}
    self.dialog:check{id="color_mode", label="Color mode", selected=true}
    self.dialog:button{id="confirm", text="Create"}
    self.dialog:button{text="Cancel"}
    self.dialog:show()

    if not self.dialog.data.confirm then
        error({message = ""})
    end

    if self.dialog.data.file == "" then
        error({message = "Choose a file to create the source code"})
    end
end

function GameBoyCExport:writeFiles()
    local var_name = string.reverse(self.dialog.data.file)
    var_name = string.sub(var_name, 0, string.find(var_name, "/", 1, true) - 1)
    var_name = string.reverse(var_name)
    var_name = string.sub(var_name, 0, -3)

    local file = io.open(self.dialog.data.file, "w")

    file:write("/*\ntile size: " .. #self.tiles .. "\n")
    if self.dialog.data.include_map then
        file:write("map size: " .. self.tiles_size_x .. "x" .. self.tiles_size_y .. "\n")
    end
    file:write("*/\n\n")
    if self.dialog.data.color_mode then
        file:write("#include <gb/cgb.h>\n\n")
    end
    file:write("#include \"" .. var_name .. ".h\"\n\nconst unsigned char " .. var_name .. "_tiles[] = {\n")
    for t = 1, #self.tiles do
        file:write("    " .. self.tiles[t] .. "\n")
    end
    file:write("\n};\n")

    if self.dialog.data.include_map then
        file:write("\nconst unsigned char " .. var_name .. "_map[" .. (#self.tiles_map) .. "] = {")
        for t = 1, #self.tiles_map do
            if (t - 1) % 16 == 0 then
                file:write("\n    ")
            end
            file:write((self.tiles_map[t] - 1) .. ", ")
        end
        file:write("\n};\n")
    end

    if self.dialog.data.color_mode then
        file:write("\nconst unsigned short " .. var_name .. "_palettes[" .. (#self.color_palettes * 4) .. "] = {")
        for t = 1, #self.color_palettes do
            file:write("\n    ")
            for c = 1, #self.color_palettes[t] do
                file:write("RGB8(" .. self.color_palettes[t][c].red .. ", " .. self.color_palettes[t][c].green .. ", "
                    .. self.color_palettes[t][c].blue .. "), ")
            end
        end
        file:write("\n};\n")

        if self.dialog.data.include_map then
            file:write("\nconst unsigned char " .. var_name .. "_attributes[" .. (#self.tiles_attributes_map) .. "] = {")
            for a = 1, #self.tiles_attributes_map do
                if (a - 1) % 16 == 0 then
                    file:write("\n    ")
                end
                file:write((self.tiles_attributes_map[a] -1) .. ", ")
            end
            file:write("\n};\n")
        end
    end

    file:close()

    file = io.open(string.sub(self.dialog.data.file, 0, -2) .. "h", "w")
    file:write("#define " .. var_name .. "_tiles_count " .. #self.tiles .. "\n")
    if self.dialog.data.include_map then
        file:write("#define " .. var_name .. "_tiles_width " .. self.tiles_size_x .. "\n")
        file:write("#define " .. var_name .. "_tiles_height " .. self.tiles_size_y .. "\n")
    end
    if self.dialog.data.color_mode then
        file:write("#define " .. var_name .. "_palettes_cnt " .. #self.color_palettes .. "\n")
    end
    file:write("\nextern const unsigned char " .. var_name .. "_tiles[];\n")
    if self.dialog.data.include_map then
        file:write("\nextern const unsigned char " .. var_name .. "_map[];\n")
    end
    if self.dialog.data.color_mode then
        file:write("\nextern const unsigned short " .. var_name .. "_palettes[];\n")
        if self.dialog.data.include_map then
            file:write("\nextern const unsigned char " .. var_name .. "_attributes[];\n")
        end
    end
    file:close()
end

-- code execution

local status, err = pcall(function ()
    GameBoyCExport:setActiveSprite()
    GameBoyCExport:checkColorMode()
    GameBoyCExport:checkTileSize()
    GameBoyCExport:setColorPalette()
    GameBoyCExport:showDialog()
    GameBoyCExport:processSprite()
    GameBoyCExport:fillLastColorPalette()
    GameBoyCExport:writeFiles()
end)
if err and err.message then
    return app.alert(err.message)
end

app.alert("Code creation completed.")
