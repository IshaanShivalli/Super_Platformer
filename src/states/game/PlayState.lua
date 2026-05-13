PlayState = Class{__includes = BaseState}

function PlayState:init(params)
    self.camX = 0
    self.camY = 0
    self.lockedCamX = nil
    self.background = math.random(3)
    self.backgroundX = 0
    self.gravityOn = true
    self.gravityAmount = 900
    self.transitioning = false
    self.showHUD = true
    self.fadeOpacity = 1
    self.shakeAmount = 0
end

function PlayState:enter(params)
    self.levelNum = params and params.levelNum or 1
    
    -- Persist the current level number to the 'lvls' file
    love.filesystem.write('lvls', tostring(self.levelNum))

    self.showHUD = true
    self.transitioning = false
    self.lockedCamX = nil
    local levelHeight = self.levelNum >= UNDERGROUND_LEVEL_START and 16 or 20
    self.level = LevelMaker.generate(self.levelNum >= UNDERGROUND_LEVEL_START and 30 or (100 + (self.levelNum - 1) * 20), levelHeight, self.levelNum)
    self.tileMap = self.level.tileMap

    self.camera = Camera(self.tileMap.width, levelHeight, self.levelNum)

    local startPipeX = 8
    -- Align feet perfectly with the pipe floor (Pipe bottom is 96, Mario height is 15)
    local startPipeY = (7 - 3) * TILE_SIZE + 17
    
    -- Fade in from black
    Timer.tween(1, {
        [self] = {fadeOpacity = 0}
    })

    self.player = Player({
        -- If it's the underground level, start Mario at the beginning of the map
        x = self.levelNum >= UNDERGROUND_LEVEL_START and TILE_SIZE * 2 or startPipeX, -- Start at the top-left of the underground
        y = self.levelNum >= UNDERGROUND_LEVEL_START and (7 - 1) * TILE_SIZE - 15 or startPipeY,
        -- For underground, we don't want the pipe spawn animation
        controlLock = self.levelNum >= UNDERGROUND_LEVEL_START and false or true,
        width = 14.86, height = 15,
        score = params and params.score or 0,
        texture = 'green-alien',
        stateMachine = StateMachine {
            ['idle'] = function() return PlayerIdleState(self.player) end,
            ['walking'] = function() return PlayerWalkingState(self.player) end,
            ['jump'] = function() return PlayerJumpState(self.player, self.gravityAmount) end,
            ['falling'] = function() return PlayerFallingState(self.player, self.gravityAmount) end
        },
        map = self.tileMap,
        level = self.level
    })
    self.player:changeState('idle') -- Initialize player's animation state immediately (Fix for nil currentAnimation)
    
    -- Give the level a reference to the player so objects can check proximity
    self.level.player = self.player

    self:spawnEnemies()
    
    -- Spawn animation: start inside the pipe and walk out (only for non-underground levels)
    if self.levelNum < 11 then
        self.player.controlLock = true
        self.player.direction = 'right'
        self.player.dy = 0
        self.player:changeState('walking')
        Timer.tween(1.5, {
            [self.player] = {x = 45}
        }):finish(function()
            self.player.controlLock = false
            self.player:changeState('idle')
        end)
    end

    -- Level 10 Conversation Trigger
    if self.levelNum == 10 then
        -- Stop music for the boss fight
        gSounds['music']:stop()

        self.player.controlLock = true
        Chain(
            function(go) Timer.after(1, go) end,
            function(go) 
                gSounds['dk-roar']:play()
                self.shakeAmount = 10 -- Add a roar shake
                self.dialogueText = "Donkey Kong: RAWR! You dare enter my arena?" Timer.after(2, go) 
            end,
            function(go) self.dialogueText = "Mario: It's-a me! Let's settle this!" Timer.after(2, go) end,
            function(go) self.dialogueText = nil self.player.controlLock = false go() end
        )()
    end
end

function PlayState:update(dt)
    Timer.update(dt)

    if self.shakeAmount > 0 then
        self.shakeAmount = math.max(0, self.shakeAmount - 60 * dt)
    end

    self.level:clear()
    self.player:update(dt)
    self.level:update(dt)

    -- Level 10 Combat and Barrel Logic
    if self.levelNum == 10 then
        for _, entity in pairs(self.level.entities) do
            -- Only damage if it's DK and he isn't currently in hit-stun
            if entity.texture == 'donkey-kong' and self.player:collides(entity) and not entity.defeated then
                -- Mario damages DK by jumping on his head (top 15px of the 28px sprite)
                -- We check hitTimer here so he can still kill Mario if not in hit-stun
                if self.player.dy > 0 and self.player.y + self.player.height <= entity.y + 15 and (entity.hitTimer or 0) <= 0 then
                    gSounds['kill']:play()
                    gSounds['dk-hit']:play()
                    self.shakeAmount = 5

                    entity.hp = entity.hp - 1
                    -- Apply 0.8s of invulnerability to prevent multi-hits
                    entity.hitTimer = 0.8 

                    -- Determine knockback direction based on player's position relative to boss center
                    local playerMid = self.player.x + self.player.width / 2
                    local bossMid = entity.x + entity.width / 2
                    local knockDir = playerMid < bossMid and -1 or 1

                    self.player:changeState('jump', {
                        velocity = -280,
                        playSound = false
                    })

                    -- Apply slight horizontal and upward knockback impulse
                    Timer.tween(0.2, {
                        [self.player] = {x = self.player.x + (knockDir * 48)}
                    })

                    if entity.hp <= 0 then
                        entity.defeated = true
                        self.player.controlLock = true
                        
                        local floorY = (7 - 1) * TILE_SIZE
                        local pipeX = entity.x + 64
                        
                        -- Create the pipe initially hidden below ground
                        local victoryPipe = GameObject {
                            texture = 'pipes',
                            x = pipeX,
                            y = VIRTUAL_HEIGHT, -- Start off-screen at the bottom
                            width = 32,
                            height = VIRTUAL_HEIGHT, -- Make it extend to the full map height
                            frame = 1,
                            collidable = false, -- Fix: This pipe should not block Mario's movement
                            solid = false, -- Fix: No longer blocks Mario horizontally
                            isVictoryPipe = true,
                            render = function(svc)
                                -- Draw the pipe head
                                love.graphics.draw(gTextures['pipes'], gFrames['pipes'][svc.frame], svc.x, svc.y) -- Use svc.frame for the head
                                local pipeBodyQuad = gFrames['pipes'][2] or gFrames['pipes'][1] -- Use frame 1 as fallback if frame 2 doesn't exist
                                for bodyY = svc.y + 48, VIRTUAL_HEIGHT + 200, 48 do -- Extend beyond screen for seamless look
                                    love.graphics.draw(gTextures['pipes'], pipeBodyQuad, svc.x, bodyY)
                                end
                            end
                        }
                        table.insert(self.level.objects, victoryPipe)

                        Chain(
                            function(go)
                                self.dialogueText = "Donkey Kong: NOOO! My bananas! I'll get you for this with more barrels! Hooo Hooo Haaa Haaa!"
                                Timer.after(2.5, go)
                            end,
                            function(go)
                                self.dialogueText = nil
                                Timer.tween(1.5, {[victoryPipe] = {y = 90}}):finish(go) 
                            end,
                            function(go) 
                                entity.direction = 'right'
                                Timer.tween(1.5, {[entity] = {x = pipeX + 8}}):finish(go) 
                            end,
                            function(go) 
                                -- Donkey Kong walks "down" inside the pipe and off-screen
                                Timer.tween(0.8, {[entity] = {y = VIRTUAL_HEIGHT}}):finish(go) 
                            end,
                            function(go)
                                -- Spawn gems around the pipe, not inside it
                                for i = 1, 8 do
                                    local side = math.random(0, 1) == 0 and -1 or 1
                                    local spawnX = pipeX + (side == -1 and math.random(-48, -10) or math.random(42, 80))
                                    table.insert(self.level.objects, GameObject {
                                        texture = 'gems',
                                        x = spawnX,
                                        y = floorY - 16 - math.random(0, 32),
                                        width = 9, height = 16, frame = 1,
                                        collidable = true, consumable = true,
                                        onConsume = function(p, gem) gSounds['pickup']:play() p.score = p.score + 100 end
                                    })
                                end
                                self.player.controlLock = false
                                go()
                            end
                        )()
                    end
                elseif not self.player.controlLock and (entity.hitTimer or 0) <= 0 then
                    gSounds['death']:play()
                    gStateMachine:change('start')
                end
            end
        end

        -- Barrel Collision and Movement
        for i = #self.level.objects, 1, -1 do
            local object = self.level.objects[i]
            if object.isBarrel then
                -- Apply gravity and bouncing
                object.dy = (object.dy or 0) + self.gravityAmount * dt
                object.x = object.x + (object.dx or 0) * dt
                object.y = object.y + object.dy * dt

                -- Update barrel animation
                if object.animation then
                    object.animation:update(dt)
                    object.frame = object.animation:getCurrentFrame()
                end

                -- Floor check (Row 7)
                local groundY = (7 - 1) * TILE_SIZE
                if object.y + object.height >= groundY then
                    object.y = groundY - object.height
                    object.dy = -120 -- Bounce velocity
                end

                -- Collision with player
                if self.player:collides(object) and not self.player.controlLock then
                    gSounds['death']:play()
                    gStateMachine:change('start')
                end

                if object.x < -object.width or object.x > self.tileMap.width * TILE_SIZE then
                    table.remove(self.level.objects, i)
                end
            end
        end

        -- Proximity check for Mario entering the victory pipe
        for _, object in pairs(self.level.objects) do
            if object.isVictoryPipe and math.abs((self.player.x + self.player.width/2) - (object.x + object.width/2)) < 12 
               and math.abs((self.player.y + self.player.height) - object.y) <= 8
               and not self.transitioning and not self.player.controlLock then
                
                self.transitioning = true
                self.player.controlLock = true
                self.player.x = object.x + object.width/2 - self.player.width/2
                
                Timer.tween(1.0, {
                    [self.player] = {y = object.y + object.height}
                }):finish(function()
                    gStateMachine:change('play', {
                        levelNum = self.levelNum + 1,
                        score = self.player.score + 1000
                    })
                end)
            end
        end
    end

    local snailNear = false
    local goombaNear = false
    local anyEntities = false

    for i = #self.level.entities, 1, -1 do
        local entity = self.level.entities[i]

        -- Fix: Check against the actual map height, not just the virtual screen height
        if entity.y > self.tileMap.height * TILE_SIZE then
            table.remove(self.level.entities, i)
        else
            anyEntities = true
            local dist = math.abs(entity.x - self.player.x)
            -- Trigger sound if within 6 tiles
            if dist < TILE_SIZE * 6 then
                if entity.texture == 'snail' then snailNear = true end
                if entity.texture == 'creatures' then goombaNear = true end
            end
        end
    end

    -- Logic for Snail (Turtle) sounds
    if snailNear then
        gSounds['turtleSounds']:setLooping(true)
        if not gSounds['turtleSounds']:isPlaying() then
            gSounds['turtleSounds']:play()
        end
    else
        gSounds['turtleSounds']:stop()
    end

    -- Logic for Goomba sounds
    if goombaNear then
        gSounds['goomba']:setLooping(true)
        if not gSounds['goomba']:isPlaying() then
            gSounds['goomba']:play()
        end
    else
        gSounds['goomba']:stop()
    end

    -- Handle Springs vs Creatures
    for _, entity in pairs(self.level.entities) do
        for _, object in pairs(self.level.objects) do
            if object.isSpring and entity:collides(object) then
                entity.dy = -400 -- Bounce the creature
                object.hit = true
                Timer.after(0.25, function() object.hit = false end)
            end
        end
    end

    local touchedPole = nil
    local flagpoleBase = nil
    local flagpoleTop = nil
    local flag = nil
    local castle = nil
    for _, object in pairs(self.level.objects) do
        -- Check if player is colliding with any part of the pole
        if object.isFlagPole and self.player:collides(object) then 
            touchedPole = object 
        end
        if object.isFlagPoleBase then flagpoleBase = object end
        if object.isFlagPoleTop then flagpoleTop = object end
        if object.isFlag then flag = object end
        if object.isCastle then castle = object end
    end

    -- Trigger victory sequence only when Mario enters the castle
    if castle and not self.transitioning and self.player:collides(castle) then
       
        self.transitioning = true
        self.lockedCamX = self.camX
        self.showHUD = false
        self.player.controlLock = true
        self.player.dx = 0
        self.player.dy = 0

        gSounds['pickup']:play()

        Chain(
            -- 1. Walk into the castle door
            function(go)
                self.player:changeState('walking')
                self.player.direction = 'right'
                Timer.tween(1.0, {
                    [self.player] = {x = castle.x + castle.width / 2 - self.player.width / 2}
                }):finish(go)
            end,
            -- 2. Snap to the top floor of the castle
            function(go)
                -- Make him invisible while "inside" the castle
                Timer.tween(0.1, { [self.player] = { opacity = 0 } }):finish(function()
                    Timer.after(0.5, function()
                        self.player.y = castle.y - self.player.height
                        self.player.opacity = 1
                        go()
                    end)
                end)
            end,
            -- 3. Jump from the top floor to the flagpole
            function(go)
                self.player:changeState('jump', { velocity = -200, playSound = true })
                Timer.tween(0.7, {
                    [self.player] = {x = flagpoleTop.x - 6, y = flagpoleTop.y}
                }):finish(go)
            end,
            -- 4. Grab pole and slide flag down
            function(go)
                self.player.dy = 0
                self.player.currentAnimation = Animation { frames = {6}, interval = 1 }
                Timer.tween(1.2, {
                    [flag] = {y = flagpoleBase.y},
                    [self.player] = {y = flagpoleBase.y}
                }):finish(go)
            end,
            -- 5. Fade out
            function(go)
                Timer.tween(1.0, {
                    [self] = {fadeOpacity = 1}
                }):finish(go)
            end
        )(function()
            gStateMachine:change('play', {
                levelNum = self.levelNum + 1,
                score = self.player.score
            })
        end)()
    end

    if not self.transitioning and not self.player.controlLock then
        if self.player.x < 0 then
            self.player.x = 0
        elseif self.player.x > TILE_SIZE * self.tileMap.width - self.player.width then
            -- Check if we are currently touching the exit pipe
            local touchingExit = false
            for _, object in pairs(self.level.objects) do
                if object.isExit and self.player:collides(object) then
                    touchingExit = true
                    break
                end
            end
            
            -- Only block movement if we aren't trying to enter the exit pipe
            if not touchingExit then
                self.player.x = TILE_SIZE * self.tileMap.width - self.player.width
            end
        end
    end

    self:updateCamera(dt)

end

function PlayState:render()
    love.graphics.push()

    if self.shakeAmount > 0 then
        love.graphics.translate(math.random(-self.shakeAmount, self.shakeAmount), math.random(-self.shakeAmount, self.shakeAmount))
    end
    
    -- Draw Overworld/Boss Background in Screen Space (Static Backdrop, No Rolling)
    if self.levelNum <= 10 then
        love.graphics.draw(gTextures['backgrounds'], gFrames['backgrounds'][self.background], 0, 0)
        love.graphics.draw(gTextures['backgrounds'], gFrames['backgrounds'][self.background], 0, 128)
    end

    love.graphics.translate(-math.floor(self.camera.x), -math.floor(self.camera.y))

    -- Custom rendering for Boss Fight (Level 10) and Underground World (Level 11+)
    if self.levelNum >= 10 then
        -- For underground levels (11+), draw nothing (black)
        if self.levelNum >= UNDERGROUND_LEVEL_START then
            -- No background for underground levels, default clear color is black
        else -- Boss fight level (10) still uses background
            local bgStartX = math.floor(self.camX / 256) * 256 - 256
            local bgEndX = self.camX + VIRTUAL_WIDTH + 256
            local bgStartY = math.floor(self.camY / 128) * 128 - 128
            local bgEndY = self.camY + VIRTUAL_HEIGHT + 128

            for bgX = bgStartX, bgEndX, 256 do
                for bgY = bgStartY, bgEndY, 128 do -- Step by 128px (actual texture height)
                    love.graphics.draw(gTextures['backgrounds'], gFrames['backgrounds'][self.background], bgX, bgY)
                end
            end
        end
        if self.level.tileMap then self.level.tileMap:render() end
        if self.level.entities then for _, e in pairs(self.level.entities) do e:render() end end
        self.player:render()
        if self.level.objects then for _, o in pairs(self.level.objects) do o:render() end end
        
    -- Standard level rendering
    else
        self.level:render()
        self.player:render()
    end

    -- Draw the black screen for transitions
    love.graphics.setColor(0, 0, 0, self.fadeOpacity)
    love.graphics.rectangle('fill', 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    love.graphics.setColor(1, 1, 1, 1)

    love.graphics.pop()

    if self.showHUD then
        love.graphics.setFont(gFonts['medium'])
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.print(tostring(self.player.score), 5, 5)
        love.graphics.print("Level: " .. tostring(self.levelNum), 5, 20)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(tostring(self.player.score), 4, 4)
        love.graphics.print("Level: " .. tostring(self.levelNum), 4, 19)
    end

    -- Boss UI Elements (HP Bar and Dialogue)
    if self.levelNum == 10 then
        local dk = nil
        for _, e in pairs(self.level.entities) do
            if e.texture == 'donkey-kong' then dk = e break end
        end

        if dk then
            -- Golden border for the Boss HP bar
            love.graphics.setColor(1, 0.84, 0, 1) -- Golden color
            love.graphics.rectangle('line', VIRTUAL_WIDTH / 2 - 41, 4, 82, 8)

            -- HP Bar background
            love.graphics.setColor(0, 0, 0, 0.5)
            love.graphics.rectangle('fill', VIRTUAL_WIDTH / 2 - 40, 5, 80, 6)
            -- HP Bar fill
            love.graphics.setColor(1, 0, 0, 1)
            love.graphics.rectangle('fill', VIRTUAL_WIDTH / 2 - 40, 5, (dk.hp / dk.maxHP) * 80, 6)
            love.graphics.setColor(1, 1, 1, 1)
        end

        if self.dialogueText then
            love.graphics.setColor(0, 0, 0, 0.8)
            love.graphics.rectangle('fill', 10, VIRTUAL_HEIGHT - 40, VIRTUAL_WIDTH - 20, 30)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.rectangle('line', 10, VIRTUAL_HEIGHT - 40, VIRTUAL_WIDTH - 20, 30)
            love.graphics.setFont(gFonts['small'])
            love.graphics.printf(self.dialogueText, 15, VIRTUAL_HEIGHT - 35, VIRTUAL_WIDTH - 30, 'left')
        end
    end
end

function PlayState:updateCamera(dt)
    if self.transitioning and self.lockedCamX then
        self.camera.x = self.lockedCamX
        return
    end

    self.camera:update(dt, self.player, self.levelNum)
    
    -- Sync internal variables for any external logic still using camX/Y
    self.camX = self.camera.x
    self.camY = self.camera.y
end

function PlayState:spawnEnemies()
    if self.levelNum >= UNDERGROUND_LEVEL_START then -- Underground specific enemy spawning
        local lowerFloorRow = self.tileMap.height - 1

        -- Scan the entire vertical shaft for ground tiles to spawn enemies on platforms
        for x = 8, self.tileMap.width - 8 do
            for y = 4, lowerFloorRow do
                local tile = self.tileMap.tiles[y] and self.tileMap.tiles[y][x]
                local aboveTile = self.tileMap.tiles[y - 1] and self.tileMap.tiles[y - 1][x]
                
                -- If we find a ground tile with empty space above it, potentially spawn an enemy
                if tile and tile.id == TILE_ID_UNDERGROUND_GROUND and aboveTile and aboveTile.id == TILE_ID_EMPTY and math.random(12) == 1 then
                    local enemy
                    if math.random(2) == 1 then
                        enemy = Snail {
                            texture = 'snail',
                            x = (x - 1) * TILE_SIZE,
                        y = (y - 1) * TILE_SIZE - 16, -- Spawn on top of the tile
                            width = 16,
                            height = 16,
                            level = self.level
                        }
                    else
                        enemy = Goomba {
                            texture = 'creatures',
                            x = (x - 1) * TILE_SIZE,
                        y = (y - 1) * TILE_SIZE - 16, -- Spawn on top of the tile
                            width = 16,
                            height = 16,
                            level = self.level
                        }
                    end

                    enemy.stateMachine = StateMachine {
                        ['idle'] = function() return SnailIdleState(self.tileMap, self.player, enemy) end,
                        ['moving'] = function() return SnailMovingState(self.tileMap, self.player, enemy) end,
                        ['chasing'] = function() return SnailChasingState(self.tileMap, self.player, enemy) end
                    }

                    enemy:changeState('moving')
                    table.insert(self.level.entities, enemy)
                end
            end
        end

        return
    end

    if self.levelNum >= 10 then return end -- No enemies in boss levels
    
    for x = 1, self.tileMap.width do
        -- Skip the start area and the last 20 columns (Castle/Flag area)
        if x > 6 and x < self.tileMap.width - 20 then
            -- First, check if there's a solid object (like a pipe) at this column
            local hasPipeAtLocation = false
            for _, object in pairs(self.level.objects) do
                if object.solid then
                    local objStartTile = math.floor(object.x / TILE_SIZE) + 1
                    local objEndTile = math.floor((object.x + object.width - 1) / TILE_SIZE) + 1
                    if x >= objStartTile and x <= objEndTile then
                        hasPipeAtLocation = true
                        break
                    end
                end
            end

            local hasGroundSurface =
                self.tileMap.tiles[7] and
                self.tileMap.tiles[7][x] and
                self.tileMap.tiles[7][x].id == TILE_ID_GROUND and
                self.tileMap.tiles[6] and
                self.tileMap.tiles[6][x] and
                self.tileMap.tiles[6][x].id == TILE_ID_EMPTY

            -- Only spawn enemies on normal ground so they don't appear to walk in the air.
            if not hasPipeAtLocation and hasGroundSurface and math.random(10) == 1 then
                local enemy
                if math.random(2) == 1 then
                    enemy = Snail {
                        texture = 'snail',
                        x = (x - 1) * TILE_SIZE,
                        y = (7 - 2) * TILE_SIZE,
                        width = 16,
                        height = 16,
                        level = self.level
                    }
                else
                    enemy = Goomba {
                        texture = 'creatures',
                        x = (x - 1) * TILE_SIZE,
                        y = (7 - 2) * TILE_SIZE,
                        width = 16,
                        height = 16,
                        level = self.level
                    }
                end

                enemy.stateMachine = StateMachine {
                    ['idle'] = function() return SnailIdleState(self.tileMap, self.player, enemy) end,
                    ['moving'] = function() return SnailMovingState(self.tileMap, self.player, enemy) end,
                    ['chasing'] = function() return SnailChasingState(self.tileMap, self.player, enemy) end
                }

                enemy:changeState('moving')

                table.insert(self.level.entities, enemy)
            end
        end
    end
end