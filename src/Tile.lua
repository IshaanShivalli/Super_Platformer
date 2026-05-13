Tile = Class{}

function Tile:init(x, y, id, topper, tileset, topperset)
    self.x = x
    self.y = y

    self.width = TILE_SIZE
    self.height = TILE_SIZE

    self.id = id
    self.tileset = tileset
    self.topper = topper
    self.topperset = topperset
end

function Tile:collidable(target)
    for k, v in pairs(COLLIDABLE_TILES) do
        if v == self.id then
            return true
        end
    end
    return false
end

function Tile:render()
    if self.id == TILE_ID_GROUND then
        -- draw ground tile (index 1 of tiles.png)
        love.graphics.draw(gTextures['tiles'], gFrames['tiles'][1],
            (self.x - 1) * TILE_SIZE, (self.y - 1) * TILE_SIZE)

        -- draw topper on top if flagged, using the selected topperset
        if self.topper then
            love.graphics.draw(gTextures['toppers'], gFrames['toppersets'][self.topperset][1],
                (self.x - 1) * TILE_SIZE, (self.y - 1) * TILE_SIZE)
        end
    elseif self.id == TILE_ID_UNDERGROUND_GROUND then
        love.graphics.draw(gTextures['underground-tiles'], gFrames['underground-tiles'][1],
            (self.x - 1) * TILE_SIZE, (self.y - 1) * TILE_SIZE)
        if self.topper then
            love.graphics.draw(gTextures['underground-tiles'], gFrames['underground-tiles'][2],
                (self.x - 1) * TILE_SIZE, (self.y - 1) * TILE_SIZE)
        end
    elseif self.id == TILE_ID_UNDERGROUND_CEILING then
        love.graphics.draw(gTextures['underground-tiles'], gFrames['underground-tiles'][2], -- Assuming frame 2 is the ceiling tile
            (self.x - 1) * TILE_SIZE, (self.y - 1) * TILE_SIZE)
        -- No specific topper for ceiling, just draw the tile

    end
end