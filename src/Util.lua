function GenerateQuads(atlas, tileWidth, tileHeight)
    local sheetWidth = atlas:getWidth() / tileWidth
    local sheetHeight = atlas:getHeight() / tileHeight
    local sheetCounter = 1
    local tile = {}

    for y = 0, sheetHeight - 1 do
        for x = 0, sheetWidth - 1 do
            tile[sheetCounter] =
            love.graphics.newQuad(x * tileWidth, y * tileHeight, tileWidth, tileHeight, atlas:getDimensions())
            sheetCounter = sheetCounter + 1
        end
    end

    return tile
end


function GenerateTileSets(quads, setsX, setsY, sizeX, sizeY)
    local tilesets = {}
    local tableCounter = 0
    local sheetWidth = setsX * sizeX

    for tilesetY = 1, setsY do
        for tilesetX = 1, setsX do
            table.insert(tilesets, {})
            tableCounter = tableCounter + 1

            for y = sizeY * (tilesetY - 1) + 1, sizeY * tilesetY do
                for x = sizeX * (tilesetX - 1) + 1, sizeX * tilesetX do
                    table.insert(tilesets[tableCounter], quads[sheetWidth * (y - 1) + x])
                end
            end
        end
    end

    return tilesets
end


function GeneratePipeQuads(atlas, frameWidth, frameHeight)
    local sheetWidth = atlas:getWidth()
    local sheetHeight = atlas:getHeight()
    local quads = {}
    local frame = 1
    
    for y = 0, sheetHeight - frameHeight, frameHeight do
        for x = 0, sheetWidth - frameWidth, frameWidth do
            quads[frame] = love.graphics.newQuad(x, y, frameWidth, frameHeight, sheetWidth, sheetHeight)
            frame = frame + 1
        end
    end
    
    return quads
end


function GenerateGemQuads(atlas, frameWidth, frameHeight)
    local sheetWidth = atlas:getWidth()
    local sheetHeight = atlas:getHeight()
    local quads = {}
    local frame = 1
    
    for y = 0, sheetHeight - frameHeight, frameHeight do
        for x = 0, sheetWidth - frameWidth, frameWidth do
            quads[frame] = love.graphics.newQuad(x, y, frameWidth, frameHeight, sheetWidth, sheetHeight)
            frame = frame + 1
        end
    end
    
    return quads
end

function GenerateSpringQuads(atlas)
    local sheetWidth = atlas:getWidth()
    local sheetHeight = atlas:getHeight()

    return {
        love.graphics.newQuad(0, 0, 16, 32, sheetWidth, sheetHeight),
        love.graphics.newQuad(17, 0, 16, 32, sheetWidth, sheetHeight),
        love.graphics.newQuad(34, 0, 16, 32, sheetWidth, sheetHeight)
    }
end


function print_r(t)
    local print_r_cache = {}
    local function sub_print_r(t, indent)
        if (print_r_cache[tostring(t)]) then
            print(indent .. "*" .. tostring(t))
        else
            print_r_cache[tostring(t)] = true
            if (type(t) == "table") then
                for pos, val in pairs(t) do
                    if (type(val) == "table") then
                        print(indent .. "[" .. pos .. "] => " .. tostring(t) .. " {")
                        sub_print_r(val, indent .. string.rep(" ", string.len(pos) + 8))
                        print(indent .. string.rep(" ", string.len(pos) + 6) .. "}")
                    elseif (type(val) == "string") then
                        print(indent .. "[" .. pos .. '] => "' .. val .. '"')
                    else
                        print(indent .. "[" .. pos .. "] => " .. tostring(val))
                    end
                end
            else
                print(indent .. tostring(t))
            end
        end
    end
    if (type(t) == "table") then
        print(tostring(t) .. " {")
        sub_print_r(t, "  ")
        print("}")
    else
        sub_print_r(t, "  ")
    end
    print()
end
