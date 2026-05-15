Camera = Class{}

local LERP_SPEED = 35

function Camera:init(mapWidth, mapHeight, levelNum)
    self.x = 0
    self.y = 0
    self.mapWidth = mapWidth
    self.mapHeight = mapHeight

    self.y = 0
end

function Camera:update(dt, player, levelNum)
    local targetX = math.max(0, math.min(TILE_SIZE * self.mapWidth - VIRTUAL_WIDTH,
        player.x - (VIRTUAL_WIDTH / 2 - 8)))

    local baselineY = math.max(0, (self.mapHeight * TILE_SIZE) - VIRTUAL_HEIGHT)
    local targetY = 0

    if levelNum < 10 then
        baselineY = 0
        if player.y < 0 then
            targetY = player.y - (VIRTUAL_HEIGHT / 2 - 8)
        else
            targetY = baselineY
        end
    elseif levelNum >= UNDERGROUND_LEVEL_START then
        targetY = math.max(0, math.min(baselineY, 
            player.y - (VIRTUAL_HEIGHT / 2 - 8)))
    else
        targetY = math.max(0, math.min(baselineY, player.y - (VIRTUAL_HEIGHT / 2 - 8)))
    end

    if math.abs(targetX - self.x) < 0.1 then
        self.x = targetX
    else
        self.x = self.x + (targetX - self.x) * LERP_SPEED * dt
    end

    if math.abs(targetY - self.y) < 0.1 then
        self.y = targetY
    else
        self.y = self.y + (targetY - self.y) * LERP_SPEED * dt
    end
end