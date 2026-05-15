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

    -- Lava animation state
    self.lavaTimer = 0
    self.lavaFrame = 1
    self.lavaAnimInterval = 0.35
end

function Tile:collidable(target)
    for k, v in pairs(COLLIDABLE_TILES) do
        if v == self.id then
            return true
        end
    end
    return false
end

function Tile:update(dt)
    -- Animate lava tiles
    if self.id == TILE_ID_LAVA or self.id == TILE_ID_LAVA_TOP then
        self.lavaTimer = self.lavaTimer + dt
        if self.lavaTimer >= self.lavaAnimInterval then
            self.lavaTimer = 0
            self.lavaFrame = self.lavaFrame == 1 and 2 or 1
        end
    end
end

function Tile:render()
    if self.id == TILE_ID_GROUND then
        love.graphics.draw(gTextures['tiles'], gFrames['tiles'][1],
            (self.x - 1) * TILE_SIZE, (self.y - 1) * TILE_SIZE)

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
        -- FIX: Draw the solid base block first so the ceiling is visible,
        -- then overlay the decorative pillar topper (stalactites) on top.
        love.graphics.draw(gTextures['underground-tiles'], gFrames['underground-tiles'][1],
            (self.x - 1) * TILE_SIZE, (self.y - 1) * TILE_SIZE)
        if gFrames['underground-pillar'] and gFrames['underground-pillar'][1] then
            love.graphics.draw(gTextures['underground-pillar'], gFrames['underground-pillar'][1],
                (self.x - 1) * TILE_SIZE, (self.y - 1) * TILE_SIZE)
        end

    elseif self.id == TILE_ID_CASTLE_GROUND then
        if self.isCeiling then
            love.graphics.draw(gTextures['castle-brick'], gFrames['castle-brick'][1],
                (self.x - 1) * TILE_SIZE, (self.y - 1) * TILE_SIZE)
        else
            love.graphics.draw(gTextures['castle-ground'], gFrames['castle-ground'][1],
                (self.x - 1) * TILE_SIZE, (self.y - 1) * TILE_SIZE)
        end

    elseif self.id == TILE_ID_LAVA then
        -- Animated lava body (below-surface rows of a lava pit)
        if gFrames['lava'] and gFrames['lava'][self.lavaFrame] then
            love.graphics.draw(gTextures['lava'], gFrames['lava'][self.lavaFrame],
                (self.x - 1) * TILE_SIZE, (self.y - 1) * TILE_SIZE)
        end

    elseif self.id == TILE_ID_LAVA_TOP then
        -- Top row of a lava pit: draw the body tile first so there's no gap,
        -- then overlay the animated lava-topper (bubbling surface).
        if gFrames['lava'] and gFrames['lava'][self.lavaFrame] then
            love.graphics.draw(gTextures['lava'], gFrames['lava'][self.lavaFrame],
                (self.x - 1) * TILE_SIZE, (self.y - 1) * TILE_SIZE)
        end
        if gFrames['lava-topper'] and gFrames['lava-topper'][self.lavaFrame] then
            love.graphics.draw(gTextures['lava-topper'], gFrames['lava-topper'][self.lavaFrame],
                (self.x - 1) * TILE_SIZE, (self.y - 1) * TILE_SIZE)
        end
    end
end