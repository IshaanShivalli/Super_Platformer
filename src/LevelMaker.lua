LevelMaker = Class{}

function LevelMaker.generate(width, height, levelNum)
    local tiles = {}
    local entities = {}
    local objects = {}
    local decorativePipes = {}

    local tileID = TILE_ID_GROUND
    local topper = false
    local tileset = 1
    local topperset = 1

    local hasGround = {}
    local busyColumns = {}
    local consecutiveChasms = 0
    
    local pyramidWidth = 0
    local pyramidHeight = 0
    local pyramidStep = 0
    local skyPlatformWidth = 0
    local skyPlatformY = 0

    if levelNum == 10 or levelNum == 20 then
        local arenaWidth = 30
        
        for y = 1, height do table.insert(tiles, {}) end
        for x = 1, arenaWidth do
            for y = 1, height do
                local id = y >= 7 and TILE_ID_UNDERGROUND_GROUND or TILE_ID_EMPTY
                table.insert(tiles[y], Tile(x, y, id, y == 7, 1, 1))
            end
        end

        if levelNum == 20 then
            table.insert(objects, GameObject {
                texture = 'Cannon',
                x = TILE_SIZE * 2,
                y = (7 - 1) * TILE_SIZE - 48,
                width = 16, height = 48, frame = 1,
                collidable = true, solid = true
            })
            table.insert(objects, GameObject {
                texture = 'Cannon',
                x = (arenaWidth - 4) * TILE_SIZE,
                y = (7 - 1) * TILE_SIZE - 48,
                width = 16, height = 48, frame = 1,
                collidable = true, solid = true
            })

            for x = 7, arenaWidth - 12 do
                if math.random(6) == 1 then
                    table.insert(objects, GameObject {
                        texture = 'jump-blocks',
                        x = (x - 1) * TILE_SIZE,
                        y = (4 - 1) * TILE_SIZE,
                        width = 16, height = 16, frame = 1,
                        collidable = true, hit = false, solid = true,
                        onCollide = function(obj)
                            if not obj.hit then
                                local powerupType = math.random(2) == 1 and POWERUP_SIZE_ID or POWERUP_FIRE_ID
                                local powerupTexture = powerupType == POWERUP_SIZE_ID and 'powerup' or 'fire-powerup'
                                local powerup = GameObject {
                                    texture = powerupTexture,
                                    x = obj.x,
                                    y = obj.y - 2,
                                    width = 16, height = 16, frame = 1,
                                    collidable = true, consumable = true, isPowerup = true,
                                    powerupType = powerupType, solid = false,
                                    onConsume = function(player, pObj) player:gainPowerup(pObj.powerupType) end
                                }
                                Timer.tween(0.3, {[powerup] = {y = obj.y - 16}})
                                gSounds['powerup-reveal']:play()
                                table.insert(objects, powerup)
                                
                                obj.hit = true
                                obj.texture = 'toppers'
                                obj.frame = (topperset - 1) * 20 + 1
                                gSounds['empty-block']:play()
                            else
                                gSounds['empty-block']:play()
                            end
                        end
                    })
                end
            end
        end

        if levelNum == 20 then
            local wallY = 0
            
            for _, obj in pairs(objects) do
                if obj.texture == 'Cannon' then
                    local wallHeight = obj.y - wallY
                    
                    table.insert(objects, GameObject {
                        x = obj.x,
                        y = wallY,
                        width = obj.width,
                        height = wallHeight,
                        collidable = true,
                        solid = true
                    })
                end
            end
        end

        local map = TileMap(arenaWidth, height)
        map.tiles = tiles
        map.render = function(this)
            for y = 1, this.height do
                for x = 1, this.width do
                    local tile = this.tiles[y][x]
                    if tile.id ~= TILE_ID_EMPTY then
                        love.graphics.draw(gTextures['castle-ground'], gFrames['castle-ground'][1], (x - 1) * TILE_SIZE, (y - 1) * TILE_SIZE)
                    end
                end
            end
        end
        return GameLevel(entities, objects, map, levelNum)
    end

    if levelNum >= 21 and levelNum <= 25 then
        for y = 1, height do table.insert(tiles, {}) end

        for x = 1, width do
            local isChasm = math.random(10) == 1 and x > 10 and x < width - 20
            for y = 1, height do
                local id = TILE_ID_EMPTY
                if y >= 11 and not isChasm then
                    id = TILE_ID_GROUND
                end
                table.insert(tiles[y], Tile(x, y, id, y == 11, 1, 1))
            end

            if not isChasm and math.random(8) == 1 then
                local coralHeight = math.random(2) == 1 and 16 or 32
                table.insert(objects, GameObject {
                    texture = 'coral',
                    x = (x - 1) * TILE_SIZE,
                    y = (11 - 1) * TILE_SIZE - (coralHeight - 16),
                    width = 16, height = coralHeight, 
                    frame = math.random(2),
                    collidable = false, solid = false
                })
            end

            if x % 8 == 0 and x < width - 25 then
                local platY = math.random(4, 7)
                local platWidth = math.random(2, 4)
                for i = 0, platWidth do
                    table.insert(objects, GameObject {
                        texture = 'underwater-brick',
                        x = (x + i - 1) * TILE_SIZE,
                        y = (platY - 1) * TILE_SIZE,
                        width = 16, height = 16, frame = 1,
                        collidable = true, solid = true
                    })
                    table.insert(objects, GameObject {
                        texture = 'gems',
                        x = (x + i - 1) * TILE_SIZE + 4,
                        y = (platY - 1) * TILE_SIZE - 16,
                        width = 9, height = 16, frame = 1,
                        collidable = true, consumable = true,
                        onConsume = function(player, gem)
                            gSounds['pickup']:play()
                            player:addScore(100)
                        end
                    })
                end
            end
        end

        local exitPipeX = (width - 4) * TILE_SIZE 
        local exitPipeY = (11 - 1) * TILE_SIZE - 32
        table.insert(objects, GameObject {
            texture = 'pipes',
            x = exitPipeX,
            y = exitPipeY,
            width = 32, height = 48, frame = 1,
            collidable = true, solid = true,
            isVictoryPipe = true,
            render = function(svc)
                love.graphics.draw(gTextures['pipes'], gFrames['pipes'][svc.frame], svc.x, svc.y)
            end
        })

        local map = TileMap(width, height)
        map.tiles = tiles
        map.render = function(self)
            for y = 1, self.height do
                for x = 1, self.width do
                    local tile = self.tiles[y][x]
                    if tile.id ~= TILE_ID_EMPTY then
                        love.graphics.draw(gTextures['underwater-ground'], gFrames['underwater-ground'][1], (x - 1) * TILE_SIZE, (y - 1) * TILE_SIZE)
                    end
                end
            end
        end
        return GameLevel(entities, objects, map, levelNum)
    end
    
    if levelNum == 26 then
        local arenaWidth = width
        local groundRow = 10
        local ceilingRow = 3
        local bowserCol = arenaWidth - 25

        for y = 1, height do table.insert(tiles, {}) end
        for x = 1, arenaWidth do
            for y = 1, height do
                local id = TILE_ID_EMPTY
                local isCeiling = false

                if y <= 3 then
                    id = TILE_ID_CASTLE_BRICK
                elseif y >= groundRow then
                    id = TILE_ID_CASTLE_GROUND
                end

                local hasTopper = (y == ceilingRow or y == groundRow)

                local tile = Tile(x, y, id, hasTopper, 1, 1)
                tile.isCeiling = isCeiling
                table.insert(tiles[y], tile)
            end
        end

        local castlePlatformColumns = {}
        local lavaColumns = {}

        local gate = GameObject {
            texture = 'gate',
            x = (bowserCol + 2) * TILE_SIZE,
            y = (groundRow - 7) * TILE_SIZE,
            width = 16,
            height = 96,
            frame = 1,
            collidable = true,
            solid = true,
            isGate = true,
            render = function(self)
                for i = 0, 5 do
                    love.graphics.draw(gTextures['gate'], gFrames['gate'][1], self.x, self.y + (i * 16))
                end
            end
        }
        table.insert(objects, gate)

        table.insert(entities, Entity {
            texture = 'princess',
            x = (bowserCol + 4) * TILE_SIZE,
            y = (groundRow - 1) * TILE_SIZE - 24,
            width = 16,
            height = 24,
            animations = {['idle'] = Animation{frames={1}, interval=1}}
        })

        table.insert(objects, GameObject {
            texture = 'luigi',
            x = (bowserCol + 5) * TILE_SIZE,
            y = (groundRow - 1) * TILE_SIZE - 16,
            width = 16,
            height = 16,
            frame = 1
        })

        table.insert(entities, Entity {
            texture = 'mushroom-friend',
            x = (bowserCol + 6) * TILE_SIZE,
            y = (groundRow - 1) * TILE_SIZE - 24,
            width = 16,
            height = 24,
            animations = {['idle'] = Animation{frames={1}, interval=1}},
            isMushroomFriend = true
        })

        local map = TileMap(arenaWidth, height)
        map.tiles = tiles

        map.render = function(self)
            for y = 1, self.height do
                for x = 1, self.width do
                    local tile = self.tiles[y][x]

                    if tile.id == TILE_ID_CASTLE_GROUND then
                        love.graphics.draw(
                            gTextures['castle-ground'],
                            gFrames['castle-ground'][1],
                            (x - 1) * TILE_SIZE,
                            (y - 1) * TILE_SIZE
                        )

                    elseif tile.id == TILE_ID_CASTLE_BRICK then
                        love.graphics.draw(
                            gTextures['castle-brick'],
                            gFrames['castle-brick'][1],
                            (x - 1) * TILE_SIZE,
                            (y - 2) * TILE_SIZE
                        )
                    end
                end
            end
        end
        local x = 8
        while x < arenaWidth - 10 do
            local spawnedLava = false

            if math.random(12) == 1 and (x < bowserCol - 5 or x > bowserCol + 5) then

                local lavaWidth = math.random(1, 2)
                local canSpawn = true
                for checkX = x - 2, x + lavaWidth + 1 do
                    if lavaColumns[checkX] then
                        canSpawn = false
                        break
                    end
                end

                if canSpawn then
                    spawnedLava = true
                    for reserveX = x - 2, x + lavaWidth + 3 do
                        lavaColumns[reserveX] = true
                    end

                    for i = 0, lavaWidth - 1 do
                        local lavaX = x + i

                        lavaColumns[lavaX] = true

                        for y = groundRow, height do
                            tiles[y][lavaX].id = TILE_ID_EMPTY
                        end

                        table.insert(objects, GameObject {
                            texture = 'lava-topper',
                            x = (lavaX - 1) * TILE_SIZE,
                            y = (groundRow - 1) * TILE_SIZE + 6,
                            width = 16,
                            height = 10,
                            frame = 1,
                            collidable = false,
                            solid = false,
                            isLava = true
                        })

                        for lavaY = groundRow + 1, height do
                            table.insert(objects, GameObject {
                                texture = 'lava',
                                x = (lavaX - 1) * TILE_SIZE,
                                y = (lavaY - 1) * TILE_SIZE + 6,
                                width = 16,
                                height = 10,
                                frame = 1,
                                collidable = false,
                                solid = false,
                                isLava = true
                            })
                        end
                    end

                    local middleX = x + math.floor(lavaWidth / 2)

                    table.insert(objects, GameObject {
                        texture = 'gems',
                        x = (middleX - 1) * TILE_SIZE + 4,
                        y = (groundRow - 4) * TILE_SIZE,
                        width = 9,
                        height = 16,
                        frame = 1,
                        collidable = true,
                        consumable = true,

                        onConsume = function(player, gem)
                            gSounds['pickup']:play()
                            player:addScore(100)
                        end
                    })

                    x = x + lavaWidth + 5
                end
            end

            if not spawnedLava then
                x = x + 1
            end
        end


        for x = 8, arenaWidth - 12 do
            if math.random(8) == 1 and not lavaColumns[x] and (x < bowserCol - 5 or x > bowserCol + 5) then

                local platformWidth = math.random(2, 4)
                local platformY = math.random(4, 6)

                for i = 0, platformWidth - 1 do
                    local platformX = x + i

                    table.insert(objects, GameObject {
                        texture = 'castle-brick',
                        x = (platformX - 1) * TILE_SIZE,
                        y = (platformY - 1) * TILE_SIZE,
                        width = 16,
                        height = 16,
                        frame = 1,
                        collidable = true,
                        solid = true
                    })

                    castlePlatformColumns[platformX] = true
                end
            end
        end

        for x = 6, arenaWidth - 8 do
            if math.random(6) == 1 and not castlePlatformColumns[x] and not lavaColumns[x] and (x < bowserCol - 5 or x > bowserCol + 5) then
                local blockY = math.random(groundRow - 4, groundRow - 3)
                table.insert(objects, GameObject {
                    texture = 'jump-blocks',
                    x = (x - 1) * TILE_SIZE,
                    y = (blockY - 1) * TILE_SIZE,
                    width = 16,
                    height = 16,
                    frame = 1,
                    collidable = true,
                    hit = false,
                    solid = true,

                    onCollide = function(obj)
                        if not obj.hit then
                            local powerupType =
                                math.random(2) == 1 and POWERUP_SIZE_ID or POWERUP_FIRE_ID

                            local powerupTexture =
                                powerupType == POWERUP_SIZE_ID and 'powerup'
                                or 'fire-powerup'

                            local powerup = GameObject {
                                texture = powerupTexture,
                                x = obj.x,
                                y = obj.y - 2,
                                width = 16,
                                height = 16,
                                frame = 1,
                                collidable = true,
                                consumable = true,
                                isPowerup = true,
                                powerupType = powerupType,
                                solid = false,

                                onConsume = function(player, pObj)
                                    player:gainPowerup(pObj.powerupType)
                                end
                            }

                            Timer.tween(0.3, {
                                [powerup] = { y = obj.y - 16 }
                            })

                            gSounds['powerup-reveal']:play()
                            table.insert(objects, powerup)

                            obj.hit = true
                            obj.texture = 'castle-brick'
                            obj.frame = 1

                            gSounds['empty-block']:play()
                        else
                            gSounds['empty-block']:play()
                        end
                    end
                })
            end
        end
    for x = 8, arenaWidth - 12 do
        if not lavaColumns[x] and math.random(3) == 1 and (x < bowserCol - 5 or x > bowserCol + 5) then
            local coinY = math.random(3, 6)
            table.insert(objects, GameObject {
                texture = 'gems',
                x = (x - 1) * TILE_SIZE + 4,
                y = (coinY - 1) * TILE_SIZE,
                width = 9,
                height = 16,
                frame = 1,
                collidable = true,
                consumable = true,
                onConsume = function(player, gem)
                    gSounds['pickup']:play()
                    player:addScore(100)
                end
            })
        end
    end
    for x = 10, arenaWidth - 15 do
        if not lavaColumns[x]
        and not castlePlatformColumns[x]
        and (x < bowserCol - 5 or x > bowserCol + 5)
        and math.random(18) == 1 then
            local spawnY = (groundRow - 2) * TILE_SIZE
            local enemy = Goomba {
                texture = 'creatures',
                x = (x - 1) * TILE_SIZE,
                y = spawnY,
                width = 16,
                height = 16,
                level = nil
            }
            table.insert(entities, enemy)
        end
    end

        local level26 = GameLevel(entities, objects, map, levelNum)
        level26.fireballs = level26.fireballs or {}

        local bowser = Bowser {
            texture = 'bowser',
            x = bowserCol * TILE_SIZE,
            y = (groundRow - 3) * TILE_SIZE,
            width = 32, height = 32,
            level = level26,
            dx = 25,
            minX = (bowserCol - 4) * TILE_SIZE,
            maxX = (bowserCol + 4) * TILE_SIZE
        }
        table.insert(level26.entities, bowser)

        for _, entity in pairs(level26.entities) do
            if entity.class == 'Goomba' then
                entity.level = level26
            end
        end

        return level26
    end

    if levelNum >= UNDERGROUND_LEVEL_START then
        local arenaWidth = width

        for y = 1, height do table.insert(tiles, {}) end
        
        local ceilingBottom = 2 
        local floorRow = height - 2 
        
        for x = 1, arenaWidth do
            for y = 1, height do
                local id = TILE_ID_EMPTY
                local topper = nil
                local tileset = 1
                local topperset = 1

                if y <= ceilingBottom then
                    id = TILE_ID_UNDERGROUND_GROUND
                    topper = true
                elseif y >= floorRow then 
                    id = TILE_ID_UNDERGROUND_GROUND
                    topper = y == floorRow
                end

                table.insert(tiles[y], Tile(x, y, id, topper, tileset, topperset))
            end
        end

        for x = 10, arenaWidth - 22 do
            if not busyColumns[x] and not busyColumns[x + 1] then
                for y = ceilingBottom + 2, floorRow do
                    local isSurface = tiles[y][x].id ~= TILE_ID_EMPTY and tiles[y][x+1].id ~= TILE_ID_EMPTY
                    if isSurface then
                        local hasHeadroom = true
                        for hy = y - 4, y - 1 do
                            if hy > 0 and tiles[hy] and tiles[hy][x] and tiles[hy][x].id ~= TILE_ID_EMPTY then
                                hasHeadroom = false
                            end
                        end
                        if hasHeadroom and math.random(12) == 1 then
                            busyColumns[x], busyColumns[x+1] = true, true
                            table.insert(objects, Pipe {
                                texture = 'pipes',
                                x = (x - 1) * TILE_SIZE,
                                y = (y - 1) * TILE_SIZE - 32,
                                width = 32, height = 48, frame = 1,
                                collidable = true, solid = true,
                                hasPlant = math.random(2) == 1
                            })
                            break
                        end
                    end
                end
            end
        end

        local gapFrequency = math.random(15, 25)
        local gapPlacement = math.random(5, 10)

        for x = 1, arenaWidth do
            local isVerticalGap = (x % gapFrequency >= gapPlacement and x % gapFrequency <= gapPlacement + 1)

            for y = ceilingBottom + 1, floorRow - 1 do
                local topPathY = math.random(ceilingBottom + 1, ceilingBottom + 2)
                local bottomPathY = math.random(floorRow - 4, floorRow - 3)
                
                local isTopPath = (y >= topPathY and y <= topPathY + 2)
                local isBottomPath = (y >= bottomPathY and y <= bottomPathY + 2)
                
                local isSpawnClear = (x <= 6)
                local isPipeArea = busyColumns[x]

                local shouldPlaceBrick = not (isSpawnClear or isTopPath or isBottomPath or isVerticalGap or isPipeArea)

                if shouldPlaceBrick then
                    if math.random(10) == 1 and y > ceilingBottom + 1 and y < floorRow - 1 then
                        table.insert(objects, GameObject {
                            texture = 'jump-blocks',
                            x = (x - 1) * TILE_SIZE,
                            y = (y - 1) * TILE_SIZE,
                            width = 16,
                            height = 16,
                            frame = 1,
                            collidable = true,
                            hit = false,
                            solid = true,
                            onCollide = function(obj)
                                if not obj.hit then
                                    local powerupType = math.random(2) == 1 and POWERUP_SIZE_ID or POWERUP_FIRE_ID
                                    local powerupTexture = powerupType == POWERUP_SIZE_ID and 'powerup' or 'fire-powerup'
                                    local powerup = GameObject {
                                        texture = powerupTexture,
                                        x = obj.x,
                                        y = obj.y - 2,
                                        width = 16, height = 16, frame = 1,
                                        collidable = true, consumable = true, isPowerup = true,
                                        powerupType = powerupType, solid = false,
                                        onConsume = function(player, pObj) player:gainPowerup(pObj.powerupType) end
                                    }
                                    Timer.tween(0.3, {[powerup] = {y = obj.y - 16}})
                                    gSounds['powerup-reveal']:play()
                                    table.insert(objects, powerup)
                                    obj.hit = true
                            obj.texture = 'toppers'
                            obj.frame = (topperset - 1) * 20 + 1
                                    gSounds['empty-block']:play()
                                end
                            end
                        })
                    else
                        table.insert(objects, GameObject {
                            texture = 'underground-bricks',
                            x = (x - 1) * TILE_SIZE,
                            y = (y - 1) * TILE_SIZE,
                            width = 16,
                            height = 15, 
                            frame = 1,
                            collidable = true,
                            solid = true
                        })
                    end

                    local yAbove = y - 1
                    local isTopPathAbove = (yAbove >= ceilingBottom + 1 and yAbove <= ceilingBottom + 4)
                    local isBottomPathAbove = (yAbove >= floorRow - 4 and yAbove <= floorRow - 1)
                    local isVerticalGapAbove = isVerticalGap
                    local isSpawnClearAbove = (x <= 6)

                    local isPathAbove = isTopPathAbove or isBottomPathAbove
                    local shouldPlaceBrickAbove = not (isSpawnClearAbove or isPathAbove or isVerticalGapAbove or yAbove <= ceilingBottom)

                    if (isPathAbove or isVerticalGapAbove or isSpawnClearAbove) and not shouldPlaceBrickAbove and math.random(10) == 1 then
                        table.insert(objects, GameObject {
                            texture = 'gems',
                            x = (x - 1) * TILE_SIZE + 4,
                            y = (y - 1) * TILE_SIZE - 16,
                            width = 9,
                            height = 16,
                            frame = 1,
                            collidable = true,
                            consumable = true,
                            onConsume = function(player, gem)
                                gSounds['pickup']:play()
                                player:addScore(100)
                            end
                        })
                    end
                end
            end
        end

        for x = 10, arenaWidth - 22 do
            if not busyColumns[x] and not busyColumns[x + 1] then
                for y = ceilingBottom + 2, floorRow do
                    local isSurface = false
                    
                    if tiles[y][x].id ~= TILE_ID_EMPTY and tiles[y][x+1].id ~= TILE_ID_EMPTY then
                        isSurface = true
                    end
                    
                    if not isSurface then
                        local brickL, brickR = false, false
                        for _, obj in pairs(objects) do
                            if obj.texture == 'underground-bricks' or obj.texture == 'bricks' then
                                local tx, ty = math.floor(obj.x / TILE_SIZE) + 1, math.floor(obj.y / TILE_SIZE) + 1
                                if ty == y then
                                    if tx == x then brickL = true end
                                    if tx == x + 1 then brickR = true end
                                end
                            end
                        end
                        isSurface = brickL and brickR
                    end

                    if isSurface then
                        local hasHeadroom = true
                        for hy = y - 3, y - 1 do
                            if hy > 0 and (tiles[hy][x].id ~= TILE_ID_EMPTY or tiles[hy][x+1].id ~= TILE_ID_EMPTY) then
                                hasHeadroom = false
                            end
                        end

                        if hasHeadroom and math.random(12) == 1 then
                            busyColumns[x], busyColumns[x+1] = true, true
                            table.insert(objects, Pipe {
                                texture = 'pipes',
                                x = (x - 1) * TILE_SIZE,
                                y = (y - 1) * TILE_SIZE - 32,
                                width = 32, height = 48, frame = 1,
                                collidable = true, solid = true,
                                hasPlant = math.random(2) == 1
                            })
                            break 
                        end
                    end
                end
            end
        end

        local exitPipeX = (arenaWidth - 4) * TILE_SIZE 
        local exitPipeY = (floorRow) * TILE_SIZE - 32
        table.insert(objects, GameObject {
            texture = 'pipes',
            x = exitPipeX,
            y = exitPipeY,
            width = 32,
            height = 48,
            frame = 1,
            collidable = true,
            solid = true,
            isVictoryPipe = true,
            render = function(svc)
                love.graphics.draw(gTextures['pipes'], gFrames['pipes'][svc.frame], svc.x, svc.y)
            end
        })
        
        local map = TileMap(arenaWidth, height)
        map.tiles = tiles
        return GameLevel(entities, objects, map, levelNum)
    end

    local function markBusyColumn(column)
        if column >= 1 and column <= width then
            busyColumns[column] = true
        end
    end

    local function hasVerticalClearance(column, gapTiles)
        if column < 1 or column > width then
            return false
        end

        for y = 1, gapTiles do
            if not tiles[y] or not tiles[y][column] or tiles[y][column].id ~= TILE_ID_EMPTY then
                return false
            end
        end

        local columnLeft = (column - 1) * TILE_SIZE
        local columnRight = columnLeft + TILE_SIZE
        local clearanceBottom = gapTiles * TILE_SIZE

        for _, object in pairs(objects) do
            if object.collidable and
               object.x < columnRight and
               object.x + object.width > columnLeft and
               object.y < clearanceBottom then
                return false
            end
        end

        return true
    end

    local function hasPipeHeadroom(column, groundTop)
        if column < 1 or column >= width then
            return false
        end

        -- Check from the very top of the map down to row 3 (just above the pipe)
        local headroomTopRow = 1
        local headroomBottomRow = groundTop - 1

        for testColumn = column, column + 1 do
            for y = headroomTopRow, headroomBottomRow do
                if tiles[y] and tiles[y][testColumn] and tiles[y][testColumn].id ~= TILE_ID_EMPTY then
                    return false
                end
            end
        end

        local areaLeft = (column - 1) * TILE_SIZE
        local areaRight = areaLeft + (2 * TILE_SIZE)
        local areaTop = 0
        local areaBottom = (groundTop - 1) * TILE_SIZE

        for _, object in pairs(objects) do
            if object.collidable and
               object.x < areaRight and
               object.x + object.width > areaLeft and
               object.y < areaBottom and
               object.y + object.height > areaTop then
                return false
            end
        end

        return true
    end

    local function spawnSpringAt(column)
        if column < 1 or column > width then
            return
        end

        table.insert(objects, Spring {
            texture = 'spring',
            x = (column - 1) * TILE_SIZE,
            y = (7 - 1) * TILE_SIZE - 16,
            width = 16,
            height = 16,
            frame = 1,
            collidable = true,
            solid = true,
            isSpring = true
        })
        markBusyColumn(column)
    end

    local function hasSpringAt(column)
        for _, object in pairs(objects) do
            if object and object.isSpring then
                local objTileX = math.floor(object.x / TILE_SIZE) + 1
                if objTileX == column then
                    return true
                end
            end
        end

        return false
    end

    local function findSpringColumnBefore(platformColumn)
        for springColumn = platformColumn - 1, math.max(1, platformColumn - 6), -1 do
            if hasGround[springColumn] and
               not busyColumns[springColumn] and
               not hasSpringAt(springColumn) and
               hasVerticalClearance(springColumn, 6) then
                return springColumn
            end
        end

        return nil
    end

    for x = 1, height do
        table.insert(tiles, {})
    end

    for x = 1, width do
        local tileID = TILE_ID_EMPTY
        local blockHeight = 4 -- Default height for jump blocks

        -- Restore randomness to chasms (1 in 10 chance)
        local isChasm = math.random(10) == 1
        if math.random(10) == 1 then
            isChasm = true
        end

        -- Ensure the first 6 and last 20 blocks are always ground to clear the castle/flag area
        if x < 7 or x > width - 20 then
            isChasm = false
        end


        -- Limit chasm width to max 3 blocks
        if isChasm and consecutiveChasms >= 3 then
            isChasm = false
        end

        -- Don't allow chasms if we are currently building a pyramid
        if pyramidWidth > 0 then isChasm = false end

        if isChasm then
            hasGround[x] = false
            consecutiveChasms = consecutiveChasms + 1
            for y = 1, height do
                -- Sky platforms can still spawn over chasms
                local isSky = skyPlatformWidth > 0 and y == skyPlatformY

                -- Fix: Only spawn 32px bricks on odd columns to prevent overlapping "invisible" hitboxes
                if isSky and x % 2 == 1 then
                    -- Bricks should be GameObjects, not background Tiles, to maintain physics consistency
                    table.insert(tiles[y], Tile(x, y, TILE_ID_EMPTY, nil, tileset, topperset))
                    table.insert(objects, GameObject {
                        texture = 'bricks',
                        x = (x - 1) * TILE_SIZE,
                        y = (y - 1) * TILE_SIZE,
                        width = 32, height = 15, frame = 1, -- Match GenerateQuads
                        collidable = true, solid = true
                    })

                    -- Add gems on top of sky platforms over chasms
                    if math.random(3) == 1 then
                        table.insert(objects, GameObject {
                            texture = 'gems',
                            x = (x - 1) * TILE_SIZE + 4,
                            y = (y - 1) * TILE_SIZE - 16,
                            width = 9,
                            height = 16,
                            frame = 1,
                            collidable = true,
                            consumable = true,
                            onConsume = function(player, gemObject)
                                gSounds['pickup']:play()
                                player:addScore(100)
                            end
                        })
                    end
                else
                    table.insert(tiles[y], Tile(x, y, TILE_ID_EMPTY, nil, tileset, topperset))
                end
            end
        else
            consecutiveChasms = 0
            -- Check if we should start a new pyramid (4 or 5 blocks tall)
            -- Ensure pyramids don't obstruct the start or end pipes
            if pyramidWidth == 0 and skyPlatformWidth == 0 and not busyColumns[x] and math.random(50) == 1 and x > 5 and x < width - 20 then
                pyramidHeight = math.random(4, 5)
                pyramidWidth = pyramidHeight * 2 - 1
                pyramidStep = 1

                -- Mark entire pyramid area as busy immediately (with gap)
                for i = -2, pyramidWidth + 2 do
                    if x + i > 0 and x + i <= width then
                        busyColumns[x + i] = true
                    end
                end

                -- Spawn a spring in front of tall pyramids so player can get over
                if pyramidHeight > 4 and hasGround[x - 1] and hasVerticalClearance(x - 1, 6) then
                    spawnSpringAt(x - 1)
                end
            end

            hasGround[x] = true
            tileID = TILE_ID_GROUND
            
            -- Determine pyramid height for this column
            local currentHeight = 0
            if pyramidWidth > 0 then
                currentHeight = pyramidStep <= pyramidHeight and pyramidStep or (pyramidHeight * 2 - pyramidStep)
                pyramidStep = pyramidStep + 1
                pyramidWidth = pyramidWidth - 1
            end

            for y = 1, height do
                -- Ground Tiles stay at row 7
                if y >= 7 then
                    table.insert(tiles[y], Tile(x, y, tileID, y == 7 and topper or nil, tileset, topperset))
                else
                    table.insert(tiles[y], Tile(x, y, TILE_ID_EMPTY, nil, tileset, topperset))
                    
                    -- Sky platform check: convert ground tiles to bricks
                    local isSky = skyPlatformWidth > 0 and y == skyPlatformY
                    if isSky and x % 2 == 1 then
                        table.insert(objects, GameObject {
                            texture = 'bricks',
                            x = (x - 1) * TILE_SIZE,
                            y = (y - 1) * TILE_SIZE,
                            width = 32,
                            height = 15, -- Match GenerateQuads
                            frame = 1,
                            collidable = true,
                            solid = true
                        })

                        -- Spawn coins on top of sky bricks
                        if math.random(5) == 1 then
                            table.insert(objects, GameObject {
                                texture = 'gems',
                                x = (x - 1) * TILE_SIZE + 4,
                            y = (y - 1) * TILE_SIZE - 16,
                                width = 9,
                                height = 16,
                                frame = 1,
                                collidable = true,
                                consumable = true,
                                onConsume = function(player, gem)
                                    gSounds['pickup']:play()
                                    player:addScore(100)
                                end
                            })
                        end
                    end
                end
            end

            -- Add pyramid blocks as GameObjects using the pyramid texture
            for h = 1, currentHeight do
                table.insert(objects, GameObject {
                    texture = 'pyramid',
                    x = (x - 1) * TILE_SIZE,
                    y = (7 - h - 1) * TILE_SIZE,
                    width = 16,
                    height = 16,
                    frame = 1,
                    collidable = true,
                    solid = true
                })
            end

            -- chance to generate a pillar
            -- Only generate on flat ground (not on pyramids)
            -- Ensure pillars don't obstruct start/end pipes
            if pyramidWidth == 0 and skyPlatformWidth == 0 and not busyColumns[x] and currentHeight == 0 and math.random(8) == 1 and x > 4 and x < width - 20 then
                blockHeight = 2
                for i = -2, 2 do
                    if x + i > 0 and x + i <= width then
                        busyColumns[x + i] = true
                    end
                end

                -- pillar GameObjects using the toppers texture
                table.insert(objects, GameObject {
                    texture = 'toppers',
                    x = (x - 1) * TILE_SIZE,
                    y = (5 - 1) * TILE_SIZE,
                    width = 16, height = 16,
                    frame = (topperset - 1) * 24 + 1,
                    collidable = true, solid = true
                })
                table.insert(objects, GameObject {
                    texture = 'toppers',
                    x = (x - 1) * TILE_SIZE,
                    y = (6 - 1) * TILE_SIZE,
                    width = 16, height = 16,
                    frame = (topperset - 1) * 24 + 1,
                    collidable = true, solid = true
                })
                tiles[7][x].topper = nil
            end

            -- chance to generate a small decorative pipe on flat ground
            if pyramidWidth == 0 and currentHeight == 0 and hasPipeHeadroom(x, 7) and x > 5 and x < width - 22 and
               not busyColumns[x] and not busyColumns[x + 1] and hasGround[x] and hasGround[x + 1] and math.random(10) == 1 then
                busyColumns[x] = true
                busyColumns[x + 1] = true
                if x > 1 then busyColumns[x - 1] = true end

                table.insert(decorativePipes, Pipe {
                    texture = 'pipes',
                    x = (x - 1) * TILE_SIZE,
                    y = (7 - 2) * TILE_SIZE,
                    width = 32,
                    height = 48,
                    frame = 1,
                    collidable = true,
                    solid = true,
                    hasPlant = math.random(2) == 1
                })
            end

            -- chance to spawn a jump block (not on pyramids)
            -- Ensure jump blocks don't obstruct start/end pipes
            -- Ensure jump blocks have at least 1 block of space from other structures
            local nearHighBlock = skyPlatformWidth > 0
            if pyramidWidth == 0 and currentHeight == 0 and (not nearHighBlock) and not busyColumns[x] and
               math.random(10) == 1 and x > 4 and x < width - 20 and 
               not busyColumns[x - 1] and not busyColumns[x + 1] then
                blockHeight = 4 -- Row 4 is reachable by Mario's jump (Row 7 is ground)
                
                table.insert(objects,
                    GameObject {
                        texture = 'jump-blocks',
                        x = (x - 1) * TILE_SIZE,
                        y = (blockHeight - 1) * TILE_SIZE,
                        width = 16,
                        height = 16,
                        frame = 1,
                        collidable = true,
                        hit = false,
                        solid = true,

                    onCollide = function(obj)
                        if not obj.hit then
                            -- Randomly spawn a Size Powerup or a Fire Powerup
                            local powerupType = math.random(2) == 1 and POWERUP_SIZE_ID or POWERUP_FIRE_ID
                            local powerupTexture = powerupType == POWERUP_SIZE_ID and 'powerup' or 'fire-powerup'
                            local powerupFrame = 1 -- Assuming single frame for powerups

                            local powerup = GameObject {
                                texture = powerupTexture,
                                x = (x - 1) * TILE_SIZE, -- Powerup is 16x16, block is 16x16, so no offset needed
                                y = (blockHeight - 1) * TILE_SIZE - 2, -- Start popping out
                                width = 16, -- Powerups are 16x16
                                height = 16, -- Powerups are 16x16
                                frame = powerupFrame,
                                collidable = true,
                                consumable = true,
                                isPowerup = true,
                                powerupType = powerupType,
                                solid = false,
                                onConsume = function(player, powerupObject)
                                    player:gainPowerup(powerupObject.powerupType)
                                end
                            }

                            -- Animate the gem popping out to rest on top of the block
                            Timer.tween(0.3, {
                                [powerup] = {y = (blockHeight - 1) * TILE_SIZE - 16}
                            })
                            gSounds['powerup-reveal']:play()
                            table.insert(objects, powerup)
                            
                            obj.hit = true
                            obj.texture = 'toppers'
                            obj.frame = (topperset - 1) * 24 + 1
                            gSounds['empty-block']:play()
                        else
                            gSounds['empty-block']:play()
                        end
                    end
                    }
                )
            end

        end

        -- Update sky platform state
        if skyPlatformWidth > 0 then
            skyPlatformWidth = skyPlatformWidth - 1
        elseif math.random(5) == 1 and x > 10 and x < width - 25 and x % 2 == 1 and pyramidWidth == 0 then
            local potentialWidth = math.random(2, 4) * 2
            local canStart = true
            -- Check if any part of the platform would overlap a busy column (plus a 2-tile gap)
            for i = -2, potentialWidth + 2 do
                if x + i > width or busyColumns[x + i] then
                    canStart = false
                    break
                end
            end
            
            if canStart then
                skyPlatformWidth = potentialWidth
                skyPlatformY = math.random(2, 4)
                -- Reserve the platform area immediately
                for i = -2, potentialWidth + 2 do
                    if x + i > 0 and x + i <= width then
                        busyColumns[x + i] = true
                    end
                end
            end
        end

    end

    -- Second pass: Generate Overworld pipes now that ground/chasms/pyramids are finalized
    for x = 6, width - 22 do
        -- Check for flat ground, no busy columns, and headroom
        local isFlatGround = hasGround[x] and hasGround[x+1]
        local isNotBusy = not busyColumns[x] and not busyColumns[x+1]
        
        -- Verify no pyramids or pillars are in the way (checking for solid objects)
        if isFlatGround and isNotBusy and hasPipeHeadroom(x, 7) then
            -- Enforce the "2 solid blocks below" law for the footing
            -- Row 7 is surface, so rows 8 and 9 must be solid
            local hasFooting = true
            for testX = x, x + 1 do
                for testY = 7, 9 do
                    if not tiles[testY] or not tiles[testY][testX] or tiles[testY][testX].id ~= TILE_ID_GROUND then
                        hasFooting = false
                    end
                end
            end

            if hasFooting and math.random(10) == 1 then
                busyColumns[x] = true
                busyColumns[x + 1] = true
                table.insert(decorativePipes, Pipe {
                    texture = 'pipes',
                    x = (x - 1) * TILE_SIZE,
                    y = (7 - 2) * TILE_SIZE,
                    width = 32,
                    height = 48,
                    frame = 1,
                    collidable = true,
                    solid = true,
                    hasPlant = math.random(2) == 1
                })
            end
        end
    end

    -- Add springs in front of any high floating platforms that Mario cannot reach normally.
    for x = 2, width do
        local platformStartsHere = false
        local highestPlatformRow = nil

        for y = 1, 2 do
            if tiles[y] and tiles[y][x] and tiles[y][x].id == TILE_ID_GROUND and
               tiles[y + 1] and tiles[y + 1][x] and tiles[y + 1][x].id == TILE_ID_EMPTY and
               (not tiles[y][x - 1] or tiles[y][x - 1].id ~= TILE_ID_GROUND) then
                platformStartsHere = true
                highestPlatformRow = y
                break
            end
        end

        if platformStartsHere then
            local springColumn = findSpringColumnBefore(x)
            if springColumn then
                spawnSpringAt(springColumn)
            end
        end
    end

    -- Add springs for unreachable floating solid-object platforms like jump blocks.
    for _, object in pairs(objects) do
        if object and object.solid and object.texture == 'jump-blocks' then
            local platformColumn = math.floor(object.x / TILE_SIZE) + 1
            local platformRow = math.floor(object.y / TILE_SIZE) + 1
            local isPlatformStart = platformColumn == 1

            if platformColumn > 1 then
                isPlatformStart = true
                for _, neighbor in pairs(objects) do
                    if neighbor and neighbor ~= object and neighbor.solid and neighbor.texture == object.texture and
                       neighbor.x + neighbor.width == object.x and neighbor.y == object.y then
                        isPlatformStart = false
                        break
                    end
                end
            end

            if isPlatformStart and platformRow <= 3 then
                local springColumn = findSpringColumnBefore(platformColumn)
                if springColumn then
                    spawnSpringAt(springColumn)
                end
            end
        end
    end

    -- second pass: spawn bushes based on neighbour ground tiles
    -- Skip start and end areas to keep pipes clear
    for x = 1, width do
        if hasGround[x] and math.random(3) == 1 and x > 4 and x < width - 20 and not busyColumns[x] then
            local leftHasGround  = hasGround[x - 1] == true
            local rightHasGround = hasGround[x + 1] == true

            if rightHasGround then
                -- 2 consecutive ground tiles: spawn full 34px bush
                table.insert(objects,
                    GameObject {
                        texture = 'bushes',
                        x = (x - 1) * TILE_SIZE - 1,
                        y = (6 * TILE_SIZE) - TILE_SIZE,
                        width = 34,
                        height = 16,
                        frame = 1,
                        collidable = false
                    }
                )
            end

            -- spawn small bush on isolated tiles or the right edge of platforms
            if not rightHasGround then
                table.insert(objects,
                    GameObject {
                        texture = 'small-bushes',
                        x = (x - 1) * TILE_SIZE - 1,
                        y = (6 * TILE_SIZE) - TILE_SIZE,
                        width = 16,
                        height = 16,
                        frame = 1,
                        collidable = false
                    }
                )
            end
        end
    end

    -- Spawn random floating coin trails in the air
    for x = 1, width do
        -- Only spawn over ground and far from start/end areas
        if hasGround[x] and x > 10 and x < width - 25 and math.random(10) == 1 then
            local coinY = math.random(2, 4)
            local coinCount = math.random(2, 5)
            
            for i = 0, coinCount - 1 do
                local currentX = x + i
                -- Ensure we stay within safe bounds and over ground
                if currentX < width - 20 and hasGround[currentX] then
                    table.insert(objects, GameObject {
                        texture = 'gems',
                        x = (currentX - 1) * TILE_SIZE + 4,
                        y = (coinY - 1) * TILE_SIZE,
                        width = 9,
                        height = 16,
                        frame = 1,
                        collidable = true,
                        consumable = true,
                        onConsume = function(player, gemObject)
                            gSounds['pickup']:play()
                            player:addScore(100)
                        end
                    })
                end
            end
        end
    end

    -- Append decorative pipes after bushes so they render above grass
    for _, pipe in ipairs(decorativePipes) do
        table.insert(objects, pipe)
    end

    -- Place Start Side Pipe
    table.insert(objects, GameObject {
        texture = 'side-pipe-start',
        x = 0,
        y = (7 - 3) * TILE_SIZE,
        width = 34,
        height = 32,
        frame = 1,
        collidable = true,
        solid = true
    })

    -- Place Castle (Now encounter this first)
    table.insert(objects, GameObject {
        texture = 'castle',
        x = (width - 16) * TILE_SIZE,
        y = (7 - 1) * TILE_SIZE - 48, -- Adjusted Y to sit on the ground for 48px height
        width = 48, height = 48, frame = 1,
        collidable = true, isCastle = true
    })

    -- Place Flagpole Base (Pyramid Block)
    table.insert(objects, GameObject {
        texture = 'pyramid',
        x = (width - 13) * TILE_SIZE, -- Moved closer to castle
        y = (7 - 1) * TILE_SIZE - 16,
        width = 16, height = 16, frame = 1,
        collidable = true, solid = true
    })

    -- Place Flagpole (Stack of 4 segments)
    for i = 0, 3 do
        table.insert(objects, GameObject {
            texture = 'flagpole',
            x = (width - 13) * TILE_SIZE + 7, -- Centered (16 - 2) / 2 = 7
            y = (7 - 2 - i) * TILE_SIZE - 16,
            width = 2, height = 16, frame = 1,
            collidable = true, 
            isFlagPole = true,
            -- Tag the bottom segment as the base for the sliding animation
            isFlagPoleBase = (i == 0),
            isFlagPoleTop = (i == 3)
        })
    end

    -- Place Flag
    table.insert(objects, GameObject {
        texture = 'flag',
        x = (width - 13) * TILE_SIZE + 7 - 16, -- On the left side of the 2px pole
        y = (7 - 5) * TILE_SIZE - 16,      -- Start at the top of the 4-segment stack
        width = 16, height = 16, frame = 1,
        collidable = false, isFlag = true
    })

    local map = TileMap(width, height)
    map.tiles = tiles

    return GameLevel(entities, objects, map, levelNum)
end