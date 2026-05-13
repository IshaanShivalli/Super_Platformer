Camera = Class{}

-- Higher values = faster, snappier following. Lower values = smoother, slower following.
local LERP_SPEED = 10

function Camera:init(mapWidth, mapHeight, levelNum)
    self.x = 0
    self.y = 0
    self.mapWidth = mapWidth
    self.mapHeight = mapHeight

    -- Start the camera at the top of the map
    self.y = 0
end

function Camera:update(dt, player, levelNum)
    -- Horizontal Follow (Standard centering)
    local targetX = math.max(0, math.min(TILE_SIZE * self.mapWidth - VIRTUAL_WIDTH,
        player.x - (VIRTUAL_WIDTH / 2 - player.width / 2)))

    local targetY = self.y -- Default to current position
    local baselineY = math.max(0, (self.mapHeight * TILE_SIZE) - VIRTUAL_HEIGHT)

    if levelNum < 10 then
        baselineY = 0
        -- OVERWORLD: Only follow if player is "above the game" (y < 0)
        if player.y < 0 then
            targetY = player.y - (VIRTUAL_HEIGHT / 2 - player.height / 2)
        else
            -- Otherwise, stay at the bottom baseline
            targetY = baselineY
        end
    elseif levelNum >= UNDERGROUND_LEVEL_START then
        -- UNDERGROUND: Free bidirectional follow (center player)
        targetY = math.max(0, math.min(baselineY, 
            player.y - (VIRTUAL_HEIGHT / 2 - player.height / 2)))
    else
        -- BOSS (Level 10): Only follow Downward
        local idealY = player.y - (VIRTUAL_HEIGHT / 2 - player.height / 2)
        targetY = math.max(self.y, math.max(0, math.min(baselineY, idealY)))
    end

    -- Apply Smooth Interpolation (Lerp)
    -- Instead of snapping, we move a percentage of the distance to the target each frame
    self.x = self.x + (targetX - self.x) * LERP_SPEED * dt
    self.y = self.y + (targetY - self.y) * LERP_SPEED * dt
end