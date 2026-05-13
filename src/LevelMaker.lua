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

    -- track which columns have ground at row 7
    local hasGround = {}
    local busyColumns = {}
    local consecutiveChasms = 0
    
    -- Track state for multi-column structures
    local pyramidWidth = 0
    local pyramidHeight = 0
    local pyramidStep = 0
    local skyPlatformWidth = 0
    local skyPlatformY = 0

    -- Special logic for Level 10 Boss Arena
    if levelNum == 10 then
        local arenaWidth = 30 -- Force a compact arena
        
        for y = 1, height do table.insert(tiles, {}) end
        for x = 1, arenaWidth do
            for y = 1, height do
                local id = y >= 7 and TILE_ID_GROUND or TILE_ID_EMPTY
                table.insert(tiles[y], Tile(x, y, id, y == 7, 1, 1))
            end
        end

        -- Spawn Donkey Kong at the end of the arena
        table.insert(entities, DonkeyKong {
            texture = 'donkey-kong',
            x = (arenaWidth - 8) * TILE_SIZE,
            y = (7 - 1) * TILE_SIZE - 28, -- Adjusted for 28px height
            minX = 10 * TILE_SIZE,        -- Left boundary of patrol
            maxX = (arenaWidth - 4) * TILE_SIZE, -- Right boundary
            width = 28, height = 28,
            level = {objects = objects}, -- Temporary reference for spawning during generation
            stateMachine = StateMachine {
                ['idle'] = function() return BaseState() end
            }
        })

        local map = TileMap(arenaWidth, height)
        map.tiles = tiles
        return GameLevel(entities, objects, map, levelNum)
    end
    
    -- Special logic for Underground World
    if levelNum >= UNDERGROUND_LEVEL_START then
        local arenaWidth = math.random(30, 50) -- More varied width for horizontal continuation
        height = math.random(16, 24) -- More varied height for vertical continuation

        for y = 1, height do table.insert(tiles, {}) end
        
        local ceilingBottom = 2 -- Thinner ceiling for visibility
        local upperFloorRow = 7
        local lowerFloorRow = height - 1
        local openingStart = math.random(8, 12) -- Start opening earlier
        local openingWidth = math.min(math.random(8, 12), arenaWidth - openingStart - 4) -- Smaller opening width

        -- Fill the underground chamber with ceiling, a top floor, a deep shaft, and a bottom floor.
        for x = 1, arenaWidth do
            for y = 1, height do
                local id = TILE_ID_EMPTY
                local topper = nil
                local tileset = 1
                local topperset = 1

                if y <= ceilingBottom then
                    id = TILE_ID_UNDERGROUND_CEILING
                    topper = true
                elseif y == upperFloorRow then
                    if x < openingStart or x > openingStart + openingWidth - 1 then
                        id = TILE_ID_UNDERGROUND_GROUND
                        topper = true
                    end
                elseif y >= lowerFloorRow then -- Ensure continuous ground at the very bottom
                    id = TILE_ID_UNDERGROUND_GROUND
                    topper = y == lowerFloorRow
                end

                table.insert(tiles[y], Tile(x, y, id, topper, tileset, topperset))
            end
        end

        local platforms = {} -- Initialize platforms table for dynamic generation
        local numPlatforms = math.random(4, 7) -- Generate between 4 and 7 platforms
        local platformMinX = openingStart + 1
        local platformMaxX = openingStart + openingWidth - 2
        local platformMinY = upperFloorRow + 2
        local platformMaxY = lowerFloorRow - 3 -- Ensure platforms are above the very bottom floor

        for i = 1, numPlatforms do
            local platformRow = math.random(platformMinY, platformMaxY)
            local platformWidth = math.random(2, 5) -- Random width for platforms
            local platformX = math.random(platformMinX, platformMaxX - platformWidth + 1) -- Ensure enough space for width

            -- Add the platform objects
            for px = platformX, platformX + platformWidth - 1 do
                -- Ensure we don't place platforms outside the arenaWidth
                if px >= 1 and px <= arenaWidth and tiles[platformRow] and tiles[platformRow][px] then
                    tiles[platformRow][px].id = TILE_ID_UNDERGROUND_GROUND
                    tiles[platformRow][px].topper = true
                end
            end
            -- Store platform info for coin generation
            table.insert(platforms, {row = platformRow, x = platformX, width = platformWidth})
        end

        -- Add jump blocks to the underground floors
        for x = 2, arenaWidth - 2 do
            if math.random(8) == 1 then
                local targetY = nil
                -- Check if we are on the upper floor or lower floor and if it's ground
                if tiles[upperFloorRow] and tiles[upperFloorRow][x].id == TILE_ID_UNDERGROUND_GROUND then
                    targetY = upperFloorRow - 3
                elseif tiles[lowerFloorRow] and tiles[lowerFloorRow][x].id == TILE_ID_UNDERGROUND_GROUND then
                    targetY = lowerFloorRow - 3
                end

                -- Ensure jump blocks don't spawn inside or above the ceiling
                if targetY and targetY > ceilingBottom then
                    table.insert(objects, GameObject {
                        texture = 'jump-blocks',
                        x = (x - 1) * TILE_SIZE,
                        y = (targetY - 1) * TILE_SIZE,
                        width = 16, height = 16, frame = 1,
                        collidable = true, solid = true, hit = false,
                        onCollide = function(obj)
                            if not obj.hit then
                                if math.random(3) == 1 then
                                    local gem = GameObject {
                                        texture = 'gems',
                                        x = obj.x + 4,
                                        y = obj.y - 1,
                                        width = 9, height = 16, frame = 1,
                                        collidable = true, consumable = true,
                                        onConsume = function(player, g)
                                            gSounds['pickup']:play()
                                            player.score = player.score + 100
                                        end
                                    }
                                    Timer.tween(0.3, {[gem] = {y = gem.y - 18}})
                                    gSounds['powerup-reveal']:play()
                                    table.insert(objects, gem)
                                end
                                obj.hit = true
                                gSounds['empty-block']:play()
                            end
                        end
                    })
                end
            end
        end

        -- Add treasure coins along the shaft and on the mini ledges.
        for x = openingStart + 2, openingStart + openingWidth - 3, 2 do -- Coins in the main shaft
            table.insert(objects, GameObject {
                texture = 'gems',
                x = (x - 1) * TILE_SIZE + 4,
                y = (ceilingBottom + 1) * TILE_SIZE,
                width = 9,
                height = 16,
                frame = 1,
                collidable = true,
                consumable = true,
                onConsume = function(player, gem)
                    gSounds['pickup']:play()
                    player.score = player.score + 100
                end
            })
        end

        for _, platform in ipairs(platforms) do -- Coins on platforms
            local gemX = math.floor(platform.x + (platform.width - 1) / 2)
            table.insert(objects, GameObject {
                texture = 'gems',
                x = (gemX - 1) * TILE_SIZE + 4,
                y = (platform.row - 1) * TILE_SIZE - 16,
                width = 9,
                height = 16,
                frame = 1,
                collidable = true,
                consumable = true,
                onConsume = function(player, gem)
                    gSounds['pickup']:play()
                    player.score = player.score + 100
                end
            })
        end

        for step = 1, 5 do -- Coins leading down from the top floor
            table.insert(objects, GameObject {
                texture = 'gems',
                x = (openingStart + step * 2 - 1) * TILE_SIZE + 4,
                y = (upperFloorRow + step) * TILE_SIZE,
                width = 9,
                height = 16,
                frame = 1,
                collidable = true,
                consumable = true,
                onConsume = function(player, gem)
                    gSounds['pickup']:play()
                    player.score = player.score + 100
                end
            })
        end

        -- Place the static exit pipe at the end of the level on the lower floor.
        local exitPipeX = (arenaWidth - 4) * TILE_SIZE -- Place closer to the right edge
        local exitPipeY = (lowerFloorRow - 1) * TILE_SIZE - 48
        table.insert(objects, GameObject {
            texture = 'pipes',
            x = exitPipeX,
            y = exitPipeY,
            width = 32,
            height = VIRTUAL_HEIGHT,
            frame = 1,
            collidable = false,
            solid = false,
            isVictoryPipe = true,
            render = function(svc) love.graphics.draw(gTextures['pipes'], gFrames['pipes'][svc.frame], svc.x, svc.y) local pipeBodyQuad = gFrames['pipes'][2] or gFrames['pipes'][1] for bodyY = svc.y + 48, VIRTUAL_HEIGHT + 200, 48 do love.graphics.draw(gTextures['pipes'], pipeBodyQuad, svc.x, bodyY) end end
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
        local headroomBottomRow = groundTop - 4

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
        local areaBottom = (groundTop - 3) * TILE_SIZE

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
        
        local isChasm = math.random(6) == 1

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

        -- Mark column as busy for pipes if it's a pyramid column
        if pyramidWidth > 0 then
            busyColumns[x] = true
            for i = -2, 2 do
                if x + i > 0 and x + i <= width then busyColumns[x + i] = true end
            end
        end

        if isChasm then
            hasGround[x] = false
            consecutiveChasms = consecutiveChasms + 1
            for y = 1, height do
                -- Sky platforms can still spawn over chasms
                local isSky = skyPlatformWidth > 0 and y == skyPlatformY
                
                if isSky then
                    table.insert(tiles[y], Tile(x, y, TILE_ID_GROUND, true, tileset, topperset))

                    -- Add gems on top of sky platforms over chasms
                    if math.random(3) == 1 then
                        table.insert(objects, GameObject {
                            texture = 'gems',
                            x = (x - 1) * TILE_SIZE + 4,
                            y = (y - 2) * TILE_SIZE,
                            width = 9,
                            height = 16,
                            frame = 1,
                            collidable = true,
                            consumable = true,
                            onConsume = function(player, gemObject)
                                gSounds['pickup']:play()
                                player.score = player.score + 100
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
            if pyramidWidth == 0 and math.random(50) == 1 and x > 5 and x < width - 20 then
                pyramidHeight = math.random(4, 5)
                pyramidWidth = pyramidHeight * 2 - 1
                pyramidStep = 1

                -- Spawn a spring in front of tall pyramids so player can get over
                if pyramidHeight > 4 and hasGround[x - 1] and hasVerticalClearance(x - 1, 6) and not busyColumns[x - 1] then
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
                    -- Sky platform check for the empty space above ground
                    local isSky = skyPlatformWidth > 0 and y == skyPlatformY
                    if isSky then
                        table.insert(tiles[y], Tile(x, y, TILE_ID_GROUND, true, tileset, topperset))

                        -- Add gems on top of sky platforms over ground
                        if math.random(3) == 1 then
                            table.insert(objects, GameObject {
                                texture = 'gems',
                                x = (x - 1) * TILE_SIZE + 4,
                                y = (y - 2) * TILE_SIZE,
                                width = 9,
                                height = 16,
                                frame = 1,
                                collidable = true,
                                consumable = true,
                                onConsume = function(player, gemObject)
                                    gSounds['pickup']:play()
                                    player.score = player.score + 100
                                end
                            })
                        end
                    else
                        table.insert(tiles[y], Tile(x, y, TILE_ID_EMPTY, nil, tileset, topperset))
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
            if pyramidWidth == 0 and currentHeight == 0 and math.random(8) == 1 and x > 4 and x < width - 20 then
                blockHeight = 2
                busyColumns[x] = true
                if x > 1 then busyColumns[x-1] = true end
                if x < width then busyColumns[x+1] = true end

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
            if pyramidWidth == 0 and currentHeight == 0 and x > 5 and x < width - 22 and
               not busyColumns[x] and not busyColumns[x + 1] and hasGround[x] and hasGround[x + 1] and math.random(10) == 1 then
                busyColumns[x] = true
                busyColumns[x + 1] = true
                if x > 1 then busyColumns[x - 1] = true end

                table.insert(decorativePipes, Pipe {
                    texture = 'pipes',
                    x = (x - 1) * TILE_SIZE,
                    y = (7 - 3) * TILE_SIZE,
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
            if pyramidWidth == 0 and currentHeight == 0 and nearHighBlock and not busyColumns[x] and
               math.random(5) == 1 and x > 4 and x < width - 20 and 
               not busyColumns[x - 1] and not busyColumns[x + 1] then
                blockHeight = 3 -- Spawning at row 3 instead of 4 for more "breathing room"
                
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
                            if math.random(5) == 1 then
                                local gem = GameObject {
                                texture = 'gems',
                                x = (x - 1) * TILE_SIZE + 4, -- Centered for 9px width
                                y = (blockHeight - 1) * TILE_SIZE - 1,
                                width = 9,
                                height = 16,
                                frame = 1,  -- Try frames 1-8 based on your GEMS array
                                collidable = true,
                                consumable = true,
                                solid = false,
                                
                                -- Add a custom render function to ensure visibility
                                render = function(self)
                                    love.graphics.draw(gTextures['gems'], gFrames['gems'][self.frame], self.x, self.y)
                                end,
                                
                                onConsume = function(player, gemObject)
                                    gSounds['pickup']:play()
                                    player.score = player.score + 100
                                end
                            }
                                
                                -- Animate the gem floating up
                                Timer.tween(0.3, {
                                    [gem] = {y = (blockHeight - 1) * TILE_SIZE - 18} -- Shorter jump offset
                                })
                                gSounds['powerup-reveal']:play()
                                
                                table.insert(objects, gem)
                            end
                            
                            obj.hit = true
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
        -- Stop sky platforms even earlier to ensure the area above the castle is empty
        elseif math.random(12) == 1 and x > 4 and x < width - 25 then
            local newSkyPlatformWidth = math.random(2, 6)
            local newSkyPlatformY = math.random(2, 4)
            
            -- If near a pyramid, spawn 2 blocks higher
            if pyramidWidth > 0 or (x > 5 and x < width - 12 and math.random(3) == 1) then
                newSkyPlatformY = math.max(1, newSkyPlatformY - 2)
            end

            skyPlatformWidth = newSkyPlatformWidth
            skyPlatformY = newSkyPlatformY

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
                            player.score = player.score + 100
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
