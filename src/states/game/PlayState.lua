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
    self.fireballs = {}
    self.rockets = {}
    self.rocketTimer = 0
    self.bowserIntro = false
end

function PlayState:enter(params)
    local initialLevelNum = params and params.levelNum or 1
    local initialPowerupState = PLAYER_STATE_SMALL
    
    if params == nil then
        if love.filesystem.getInfo('lvls') then
            local content, size = love.filesystem.read('lvls')
            local levelStr = string.match(content, "^(%d+)") 
            initialLevelNum = tonumber(levelStr) or 1
        end
    else
        initialLevelNum = params.levelNum or 1
        initialPowerupState = params.powerupState or PLAYER_STATE_SMALL
    end

    self.levelNum = initialLevelNum
    self.showHUD = true
    self.transitioning = false
    self.lockedCamX = nil
    
    local mapWidth = 80 + (self.levelNum - 1) * 20
    if self.levelNum >= UNDERGROUND_LEVEL_START and self.levelNum < 21 then
        mapWidth = 250 + (self.levelNum - UNDERGROUND_LEVEL_START) * 50
    elseif self.levelNum >= 21 and self.levelNum <= 25 then
        mapWidth = 150 
    elseif self.levelNum == 26 then 
        mapWidth = 120 
    end

    if self.levelNum >= 21 and self.levelNum <= 25 then
        self.gravityAmount = 300
    end

    local mapHeight = 12
    self.level = LevelMaker.generate(mapWidth, mapHeight, self.levelNum)

    if not self.level then
        self.level = LevelMaker.generate(mapWidth, mapHeight, 1)
    end

    self.level.fireballs = self.fireballs 
    self.tileMap = self.level.tileMap
    self.camera = Camera(self.tileMap.width, self.tileMap.height, self.levelNum)

    local startPipeX = 0
    local startPipeY = (7 - 3) * TILE_SIZE + 16

    Timer.tween(1, {
        [self] = {fadeOpacity = 0}
    })

    self.player = Player({
        x = self.levelNum >= UNDERGROUND_LEVEL_START and TILE_SIZE * 5 or startPipeX, 
        y = self.levelNum >= UNDERGROUND_LEVEL_START and (7 - 1) * TILE_SIZE - 15 or startPipeY,
        controlLock = self.levelNum >= UNDERGROUND_LEVEL_START and false or true, 
        lives = params and params.lives or 3, 
        powerupState = params and params.powerupState or PLAYER_STATE_SMALL, 
        width = 14.8, height = 14.8,
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
    self.player:changeState('idle') 

    self.level.player = self.player

    if self.levelNum == 26 then
        for _, entity in pairs(self.level.entities) do
            if entity.texture == 'bowser' then
                entity.level = self.level
                entity.level.fireballs = self.fireballs
                entity.player = self.player
            end
        end
    end

    self:spawnEnemies()

    if self.levelNum < 11 then
        self.player.opacity = 0 
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

        Timer.after(1.0, function()
            Timer.tween(0.3, { [self.player] = { opacity = 1 } })
        end)
    end

    if self.levelNum == 10 or self.levelNum == 20 then
        gSounds['music']:stop()

        self.player.controlLock = true
        Chain(
            function(go) Timer.after(1, go) end,
            function(go) 
                gSounds['dk-roar']:play()
                self.dialogueText = "Donkey Kong: RAWR! You dare enter my arena?" Timer.after(2, go) 
            end,
            function(go) self.dialogueText = "Mario: It's-a me! Let's settle this!" Timer.after(2, go) end,
            function(go) self.dialogueText = nil self.player.controlLock = false go() end
        )()
    elseif self.levelNum >= UNDERGROUND_LEVEL_START then
        if not gSounds['music']:isPlaying() then
            gSounds['music']:play()
            gSounds['music']:setLooping(true)
        end
    end
end

function PlayState:update(dt)
    dt = math.min(dt, 0.033) 
    Timer.update(dt)

    self.level:clear()

    if self.level.objects then
        for i = #self.level.objects, 1, -1 do
            if self.level.objects[i].dead then
                table.remove(self.level.objects, i)
            end
        end
    end

    self.player:update(dt)
    self.level:update(dt)

    if self.levelNum == 26 then
        local lockThreshold = 85 * TILE_SIZE
        local bowser = nil
        for _, e in pairs(self.level.entities) do
            if e.texture == 'bowser' then bowser = e break end
        end

        if self.player.x > lockThreshold and bowser and not bowser.defeated and not self.transitioning then
            self.lockedCamX = lockThreshold
            
            if not self.bowserIntro then
                self.bowserIntro = true
                self.player.controlLock = true
                Chain(
                    function(go)
                        gSounds['dk-roar']:play() -- Bowser's roar triggers immediately
                        self.dialogueText = "Bowser: Gwa ha ha! You've reached the end of the line, Mario!"
                        Timer.after(2.5, go)
                    end,
                    function(go) self.dialogueText = "Mario: Where are my friends?!" Timer.after(2, go) end,
                    function(go) self.dialogueText = "Bowser: They're my guests of honor... forever!" Timer.after(2, go) end,
                    function(go) self.dialogueText = nil self.player.controlLock = false bowser.active = true go() end -- Bowser becomes active after dialogue
                )()
            end
        end

        if self.lockedCamX then
            self.player.x = math.max(self.player.x, self.lockedCamX)
            
            if bowser and not bowser.defeated and not self.transitioning then
                self.player.x = math.min(self.player.x, self.lockedCamX + VIRTUAL_WIDTH - self.player.width)
            end
        end

        for _, entity in pairs(self.level.entities) do
            local isFriend = entity.texture == 'princess' or entity.texture == 'mushroom-friend'
            if isFriend and bowser and bowser.defeated and self.player:collides(entity) and not self.transitioning then
                self:triggerBowserVictory()
                break
            end
        end

        for _, object in pairs(self.level.objects) do
            if object.texture == 'luigi' and bowser and bowser.defeated and self.player:collides(object) and not self.transitioning then
                self:triggerBowserVictory()
                break
            end
        end
    end

    if not self.player.controlLock and (self.player.invincibleTimer or 0) <= 0 then
        local corners = {
            {self.player.x + 2,                     self.player.y + self.player.height - 1},
            {self.player.x + self.player.width - 2, self.player.y + self.player.height - 1},
        }
        for _, pt in ipairs(corners) do
            local tile = self.tileMap:pointToTile(pt[1], pt[2])
            if tile and (tile.id == TILE_ID_LAVA or tile.id == TILE_ID_LAVA_TOP) then
                self.player:takeHit()
                break
            end
        end
        for _, obj in pairs(self.level.objects) do
            if obj.isLava and obj:collides(self.player) then
                self.player:takeHit()
                break
            end
        end
    end

    if self.levelNum >= 21 and self.levelNum <= 25 then
        if love.keyboard.wasPressed('space') or love.keyboard.wasPressed('up') then
            self.player.dy = -150
            gSounds['jump']:play()
        end

        if self.player.y < 0 then
            self.player.y = 0
            self.player.dy = 0
        end
    else
        self.gravityAmount = 900 
    end

    if self.levelNum == 10 or self.levelNum == 20 then
        for _, entity in pairs(self.level.entities) do
            if entity.texture == 'donkey-kong' and self.player:collides(entity) and not entity.defeated then
                
                if self.player.dy > 0 and self.player.y + self.player.height <= entity.y + 15 and (entity.hitTimer or 0) <= 0 then
                    gSounds['kill']:play()
                    gSounds['dk-hit']:play()

                    entity.hp = entity.hp - 1
                    
                    entity.hitTimer = 0.8 

                    
                    local playerMid = self.player.x + self.player.width / 2
                    local bossMid = entity.x + entity.width / 2
                    local knockDir = playerMid < bossMid and -1 or 1

                    self.player:changeState('jump', {
                        velocity = -280,
                        playSound = false
                    })
                    self.player.invincibleTimer = 0.1 

                    
                    Timer.tween(0.2, {
                        [self.player] = {x = self.player.x + (knockDir * 48)}
                    })

                    if entity.hp <= 0 then
                        entity.defeated = true
                        self.player.controlLock = true
                        
                        local floorY = (7 - 1) * TILE_SIZE
                        local pipeX = entity.x + 64
                        
                        local victoryPipe = GameObject {
                            texture = 'pipes',
                            x = pipeX,
                            y = VIRTUAL_HEIGHT, 
                            width = 32,
                            height = 48, 
                            frame = 1,
                            collidable = false, 
                            solid = false, 
                            isVictoryPipe = true,
                            render = function(svc)
                                love.graphics.draw(gTextures['pipes'], gFrames['pipes'][svc.frame], svc.x, svc.y)
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
                                Timer.tween(1.5, {[entity] = {x = pipeX + 2}}):finish(go) 
                            end,
                            function(go) 
                                Timer.tween(0.8, {[entity] = {y = VIRTUAL_HEIGHT}}):finish(go) 
                            end,
                            function(go)
                                for i = 1, 8 do
                                    local side = math.random(0, 1) == 0 and -1 or 1
                                    local spawnX = pipeX + (side == -1 and math.random(-48, -10) or math.random(42, 80))
                                    table.insert(self.level.objects, GameObject {
                                        texture = 'gems',
                                        x = spawnX,
                                        y = floorY - 16 - math.random(0, 32),
                                        width = 9, height = 16, frame = 1,
                                        collidable = true, consumable = true,
                                        onConsume = function(p, gem) gSounds['pickup']:play() p:addScore(100) end
                                    })
                                end
                                self.player.controlLock = false
                                go()
                            end
                        )()
                    end
                elseif not self.player.controlLock and (entity.hitTimer or 0) <= 0 then
                    self.player:takeHit()
                    return 
                end
            end
        end

        if self.levelNum == 20 then
            local dk = nil
            for _, e in pairs(self.level.entities) do
                if e.texture == 'donkey-kong' then dk = e break end
            end

            self.rocketTimer = self.rocketTimer + dt
            if dk and not dk.defeated and dk.hp < 5 then
                if self.rocketTimer > 6 then
                    self.rocketTimer = 0
                    for _, obj in pairs(self.level.objects) do
                        if obj.texture == 'Cannon' then
                            local direction = obj.x < self.tileMap.width * TILE_SIZE / 2 and 1 or -1
                            table.insert(self.rockets, {
                                texture = 'Rocket',
                                x = direction == 1 and obj.x + 16 or obj.x - 16,
                                y = obj.y + 4, 
                                width = 16, height = 14,
                                dx = direction * 80,
                                frame = 1
                            })
                            gSounds['dk-throw']:play()
                        end
                    end
                end
            end
        end

        for i = #self.rockets, 1, -1 do
            local r = self.rockets[i]
            r.x = r.x + r.dx * dt
            if self.player:collides(r) and not self.player.controlLock then
                local previousBottom = (self.player.y + self.player.height) - (self.player.dy * dt)
                local currentBottom = self.player.y + self.player.height
                local rTop = r.y

                local isStomp = (self.player.dy > 0 and previousBottom <= rTop + 8 and currentBottom >= rTop) or
                                (self.player.dy <= 0 and currentBottom <= rTop + 4)

                if isStomp then
                    gSounds['kill']:play()
                    self.player:addScore(100)
                    table.remove(self.rockets, i)
                    self.player:changeState('jump', {
                        velocity = -200,
                        playSound = false
                    })
                else
                    self.player:takeHit()
                    table.remove(self.rockets, i)
                end
            elseif r.x < -16 or r.x > self.tileMap.width * TILE_SIZE then
                table.remove(self.rockets, i)
            end
        end

        for i = #self.level.objects, 1, -1 do
            local object = self.level.objects[i]
            if object.isBarrel then
                object.dy = (object.dy or 0) + self.gravityAmount * dt
                object.x = object.x + (object.dx or 0) * dt
                object.y = object.y + object.dy * dt

                if object.animation then
                    object.animation:update(dt)
                    object.frame = object.animation:getCurrentFrame()
                end

                
                local groundY = (7 - 1) * TILE_SIZE
                if object.y + object.height >= groundY then
                    object.y = groundY - object.height
                    object.dy = -120 
                end


                if self.player:collides(object) and not self.player.controlLock then
                    self.player:takeHit()
                    return
                end

                if object.x < -object.width or object.x > self.tileMap.width * TILE_SIZE then
                    table.remove(self.level.objects, i)
                end
            end
        end
    end
    
    if self.levelNum == 26 then
        local bowser = nil
        for _, e in pairs(self.level.entities) do
            if e.texture == 'bowser' then bowser = e break end
        end

        if bowser then
            if self.player:collides(bowser) and not self.player.controlLock and not bowser.defeated and (bowser.hitTimer or 0) <= 0 then
                if self.player.dy > 0 and self.player.y + self.player.height <= bowser.y + 15 then
                    gSounds['kill']:play()
                    bowser:takeDamage()

                    local playerMid = self.player.x + self.player.width / 2
                    local bossMid = bowser.x + bowser.width / 2
                    local knockDir = playerMid < bossMid and -1 or 1

                    self.player:changeState('jump', {
                        velocity = -280,
                        playSound = false
                    })
                    self.player.invincibleTimer = 0.1

                    Timer.tween(0.2, {
                        [self.player] = {x = self.player.x + (knockDir * 48)}
                    })
                else
                    self.player:takeHit()
                end
            end

            for i = #self.fireballs, 1, -1 do
                local fireball = self.fireballs[i]
                if fireball.player == self.player and fireball:collides(bowser) and not bowser.defeated then
                    if (bowser.hitTimer or 0) <= 0 then
                        gSounds['kill']:play()
                        bowser:takeDamage()
                    end
                    fireball.dead = true -- Fireball always breaks on hit
                end
            end

            if bowser.defeated then
                gSounds['music']:stop()
                for _, obj in pairs(self.level.objects) do
                    if obj.isGate then obj.dead = true end
                end
                self.lockedCamX = nil
            end
        end
    end
    
    for _, object in pairs(self.level.objects) do
        if object.isVictoryPipe and math.abs((self.player.x + self.player.width/2) - (object.x + object.width/2)) < 12 
           and math.abs((self.player.y + self.player.height) - object.y) <= 8
           and not self.transitioning and not self.player.controlLock then
            
            self.transitioning = true
            self.player.controlLock = true
            self.player.x = object.x + object.width/2 - self.player.width/2
            
            Timer.tween(1.0, {
                [self.player] = {y = object.y + 32, opacity = 0}
            }):finish(function()
                self.player:addScore(1000)
                love.filesystem.write('lvls', tostring(self.levelNum + 1))
                gStateMachine:change('play', {
                    levelNum = self.levelNum + 1,
                    lives = self.player.lives,
                    powerupState = PLAYER_STATE_SMALL,
                    score = self.player.score
                })
            end)
        end
    end

    for i = #self.level.entities, 1, -1 do
        local entity = self.level.entities[i]
        local isFriend = entity.texture == 'princess' or entity.texture == 'mushroom-friend' or entity.texture == 'luigi'
        local isBoss = entity.class == 'DonkeyKong' or entity.class == 'Bowser' or 
                       entity.texture == 'donkey-kong' or entity.texture == 'bowser' or
                       entity.texture == 'barrels'

        if isBoss or isFriend then
            goto continue
        elseif self.player:collides(entity) and not self.player.controlLock then
            local previousBottom = (self.player.y + self.player.height) - (self.player.dy * dt)
            local currentBottom = self.player.y + self.player.height
            local entityTop = entity.y

            local isStomp = (self.player.dy > 0 and previousBottom <= entityTop + 8 and currentBottom >= entityTop) or
                            (self.player.dy <= 0 and currentBottom <= entityTop + 4)

            if isStomp then
                gSounds['kill']:play()
                gSounds['kill2']:play()
                self.player:addScore(100)
                table.remove(self.level.entities, i)
                self.player.invincibleTimer = 0.1 
                self.player:changeState('jump', {
                    velocity = -200,
                    playSound = false
                })
            else
                self.player:takeHit()
            end
        end
        ::continue::
    end

    for i = #self.fireballs, 1, -1 do
        local fireball = self.fireballs[i]
        fireball:update(dt)

        local hitEnemy = false
        for j = #self.level.entities, 1, -1 do
            local enemy = self.level.entities[j]
            local isFriend = enemy.texture == 'princess' or enemy.texture == 'mushroom-friend' or enemy.texture == 'luigi'
            if enemy.class ~= 'DonkeyKong' and enemy.texture ~= 'bowser' and not isFriend and fireball:collides(enemy) then
                if enemy.takeDamage then
                    enemy:takeDamage()
                end
                fireball.dead = true 
                hitEnemy = true
                break
            end
        end
        if hitEnemy then goto next_fireball end

        for j = #self.rockets, 1, -1 do
            if fireball:collides(self.rockets[j]) then
                gSounds['kill']:play()
                table.remove(self.rockets, j)
                fireball.dead = true
                goto next_fireball
            end
        end

        if fireball.player ~= self.player and fireball:collides(self.player) and not self.player.invincible then
            self.player:takeHit()
            fireball.dead = true
            goto next_fireball
        end

        if fireball.x < self.camX - fireball.width or fireball.x > self.camX + VIRTUAL_WIDTH or
           fireball.y < self.camY - fireball.height or fireball.y > self.camY + VIRTUAL_HEIGHT then
            fireball.dead = true
        elseif fireball.lifetime <= 0 then 
            fireball.dead = true
        end
        ::next_fireball::
    end

    local snailNear = false

    for i = #self.fireballs, 1, -1 do
        if self.fireballs[i].dead then
            table.remove(self.fireballs, i)
        end
    end
    local goombaNear = false
    local anyEntities = false

    for i = #self.level.entities, 1, -1 do
        local entity = self.level.entities[i]

        if entity.hitTimer and entity.hitTimer > 0 then
            entity.hitTimer = entity.hitTimer - dt
        end

        if entity.y > self.tileMap.height * TILE_SIZE or entity.dead then
            table.remove(self.level.entities, i)
        else
            anyEntities = true
            local dist = math.abs(entity.x - self.player.x)
            if dist < TILE_SIZE * 6 then
                if entity.texture == 'snail' then snailNear = true end
                if entity.texture == 'creatures' then goombaNear = true end
            end
        end
    end

    if snailNear then
        gSounds['turtleSounds']:setLooping(true)
        if not gSounds['turtleSounds']:isPlaying() then
            gSounds['turtleSounds']:play()
        end
    else
        gSounds['turtleSounds']:stop()
    end

    if goombaNear then
        gSounds['goomba']:setLooping(true)
        if not gSounds['goomba']:isPlaying() then
            gSounds['goomba']:play()
        end
    else
        gSounds['goomba']:stop()
    end

    for _, entity in pairs(self.level.entities) do
        for _, object in pairs(self.level.objects) do
            if object.isSpring and entity:collides(object) then
                local springTop = object.y + 16
                if entity.dy >= 0 and (entity.y + entity.height) <= springTop + 5 then
                    entity.dy = -400 
                    object.hit = true
                    Timer.after(0.25, function() object.hit = false end)
                end
            end
        end
    end

    local touchedPole = nil
    local flagpoleBase = nil
    local flagpoleTop = nil
    local flag = nil
    local castle = nil
    for _, object in pairs(self.level.objects) do
        if object.isFlagPole and self.player:collides(object) then 
            touchedPole = object 
        end
        if object.isFlagPoleBase then flagpoleBase = object end
        if object.isFlagPoleTop then flagpoleTop = object end
        if object.isFlag then flag = object end
        if object.isCastle then castle = object end
    end

    if castle and not self.transitioning and self.player:collides(castle) then
       
        self.transitioning = true
        self.lockedCamX = self.camX
        self.showHUD = false
        self.player.controlLock = true
        self.player.dx = 0
        self.player.dy = 0

        gSounds['pickup']:play()

        Chain(
            function(go)
                self.player:changeState('walking')
                self.player.direction = 'right'
                Timer.tween(1.0, {
                    [self.player] = {x = castle.x + castle.width / 2 - self.player.width / 2}
                }):finish(go)
            end,
            function(go)
                Timer.tween(0.1, { [self.player] = { opacity = 0 } }):finish(function()
                    Timer.after(0.5, function()
                        self.player.y = castle.y - self.player.height
                        self.player.opacity = 1
                        go()
                    end)
                end)
            end,
            function(go)
                self.player:changeState('jump', { velocity = -200, playSound = true })
                Timer.tween(0.7, {
                    [self.player] = {x = flagpoleTop.x - 6, y = flagpoleTop.y}
                }):finish(go)
            end,
            function(go)
                self.player.dy = 0
                self.player.inFlagpoleSequence = true
                Timer.tween(1.2, {
                    [flag] = {y = flagpoleBase.y},
                    [self.player] = {y = flagpoleBase.y}
                }):finish(go)
            end,
            function(go)
                Timer.tween(1.0, {
                    [self] = {fadeOpacity = 1}
                }):finish(go)
            end
        )(function()
            love.filesystem.write('lvls', tostring(self.levelNum + 1)) 
            self.player:addScore(1000)
            gStateMachine:change('play', {
                levelNum = self.levelNum + 1, 
                lives = self.player.lives,
                powerupState = PLAYER_STATE_SMALL, 
                score = self.player.score
            })
        end)()
    end

    if not self.transitioning and not self.player.controlLock then
        if self.player.x < 0 then
            self.player.x = 0
        elseif self.player.x > TILE_SIZE * self.tileMap.width - self.player.width then
            local touchingExit = false
            for _, object in pairs(self.level.objects) do
                if object.isExit and self.player:collides(object) then
                    touchingExit = true
                    break
                end
            end
            
            if not touchingExit then
                self.player.x = TILE_SIZE * self.tileMap.width - self.player.width
            end
        end
    end

    self:updateCamera(dt)

    if love.keyboard.wasPressed('z') then 
        self.player:throwFireball()
    end

end

function PlayState:render()
    love.graphics.push()

    if self.levelNum < 10 then
        love.graphics.draw(gTextures['backgrounds'], gFrames['backgrounds'][self.background], 0, 0)
        love.graphics.draw(gTextures['backgrounds'], gFrames['backgrounds'][self.background], 0, 128)
    elseif self.levelNum == 26 then
        love.graphics.setColor(0.1, 0.1, 0.1, 1) 
        love.graphics.rectangle('fill', 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
        love.graphics.setColor(1, 1, 1, 1)
    elseif self.levelNum >= 21 then
        for bgX = 0, VIRTUAL_WIDTH, 16 do
            love.graphics.draw(gTextures['underwater-topper'], gFrames['underwater-topper'][1], bgX, 0)
            for bgY = 16, VIRTUAL_HEIGHT, 16 do
                love.graphics.draw(gTextures['underwater-bg'], gFrames['underwater-bg'][1], bgX, bgY)
            end
        end
    end

    if self.levelNum >= 10 then
        if self.levelNum >= UNDERGROUND_LEVEL_START or self.levelNum == 10 or self.levelNum == 20 then
        else 
            local bgStartX = math.floor(self.camX / 256) * 256 - 256
            local bgEndX = self.camX + VIRTUAL_WIDTH + 256
            local bgStartY = math.floor(self.camY / 128) * 128 - 128
            local bgEndY = self.camY + VIRTUAL_HEIGHT + 128

            for bgX = bgStartX, bgEndX, 256 do
                for bgY = bgStartY, bgEndY, 128 do 
                    love.graphics.draw(gTextures['backgrounds'], gFrames['backgrounds'][self.background], bgX, bgY)
                end
            end
        end

        love.graphics.translate(-math.floor(self.camera.x), -math.floor(self.camera.y))

        if self.level.tileMap then self.level.tileMap:render() end
        if self.level.objects then for _, o in pairs(self.level.objects) do o:render() end end
        if self.level.entities then for _, e in pairs(self.level.entities) do e:render() end end
        for _, r in pairs(self.rockets) do
            local quad = gFrames[r.texture] and gFrames[r.texture][r.frame or 1]
            if quad then
                love.graphics.draw(gTextures[r.texture], quad, 
                    math.floor(r.x) + r.width / 2, math.floor(r.y) + r.height / 2,
                    0, r.dx > 0 and -1 or 1, 1,
                    r.width / 2, r.height / 2)
            end
        end
        self.player:render()
        
    else
        love.graphics.translate(-math.floor(self.camera.x), -math.floor(self.camera.y))
        self.level:render()
        self.player:render()
    end

    for _, fireball in pairs(self.fireballs) do
        fireball:render()
    end

    love.graphics.pop() -- End of World Space

    if self.showHUD then
        love.graphics.setFont(gFonts['medium'])
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.print(tostring(self.player.score), 5, 5)
        love.graphics.print("Level: " .. tostring(self.levelNum), 5, 20)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Lives: " .. tostring(self.player.lives), 4, 34)
        love.graphics.print("Lives: " .. tostring(self.player.lives), 5, 35)
        love.graphics.print(tostring(self.player.score), 4, 4)
        love.graphics.print("Level: " .. tostring(self.levelNum), 4, 19)
    end

    if self.levelNum == 10 or self.levelNum == 20 or self.levelNum == 26 then
        local dk = nil
        for _, e in pairs(self.level.entities) do
            if e.texture == 'donkey-kong' then dk = e break end
        end

        if dk and dk.hp and dk.maxHP then
            love.graphics.setColor(1, 0.84, 0, 1) 
            love.graphics.rectangle('line', VIRTUAL_WIDTH / 2 - 41, 4, 82, 8)
            love.graphics.setColor(0, 0, 0, 0.5)
            love.graphics.rectangle('fill', VIRTUAL_WIDTH / 2 - 40, 5, 80, 6)

            love.graphics.setColor(1, 0, 0, 1)
            love.graphics.rectangle('fill', VIRTUAL_WIDTH / 2 - 40, 5, (dk.hp / dk.maxHP) * 80, 6)
            love.graphics.setColor(1, 1, 1, 1)
        end

    end

    if self.levelNum == 26 then
        local bowser = nil
        for _, e in pairs(self.level.entities) do
            if e.texture == 'bowser' then bowser = e break end
        end
        if bowser and bowser.hp and bowser.maxHP then
            love.graphics.setColor(1, 0.84, 0, 1) 
            love.graphics.rectangle('line', VIRTUAL_WIDTH / 2 - 41, 4, 82, 8)
            love.graphics.setColor(0, 0, 0, 0.5)
            love.graphics.rectangle('fill', VIRTUAL_WIDTH / 2 - 40, 5, 80, 6)

            love.graphics.setColor(1, 0, 0, 1)
            love.graphics.rectangle('fill', VIRTUAL_WIDTH / 2 - 40, 5, (bowser.hp / bowser.maxHP) * 80, 6)
            love.graphics.setColor(1, 1, 1, 1)
        end
    end

    love.graphics.setColor(0, 0, 0, self.fadeOpacity)
    love.graphics.rectangle('fill', 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    love.graphics.setColor(1, 1, 1, 1)

    if self.dialogueText then
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle('fill', 10, VIRTUAL_HEIGHT - 40, VIRTUAL_WIDTH - 20, 30)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle('line', 10, VIRTUAL_HEIGHT - 40, VIRTUAL_WIDTH - 20, 30)
        love.graphics.setFont(gFonts['small'])
        love.graphics.printf(self.dialogueText, 15, VIRTUAL_HEIGHT - 35, VIRTUAL_WIDTH - 30, 'left')
    end
end


function PlayState:updateCamera(dt)
    if self.lockedCamX then
        self.camera.x = self.lockedCamX
    else
        self.camera:update(dt, self.player, self.levelNum)
    end

    self.camX = self.camera.x
    self.camY = self.camera.y
end

function PlayState:triggerBowserVictory()
    if self.transitioning then return end
    self.transitioning = true
    self.player.controlLock = true
    self.player.dx = 0
    self.player.dy = 0
    self.showHUD = false

    for _, e in pairs(self.level.entities) do
        if e.texture == 'bowser' then
            Timer.tween(0.5, { [e] = { opacity = 0 } }):finish(function()
                e.dead = true
            end)
            break
        end
    end

    gSounds['powerup-reveal']:play() 

    Chain(
        function(go)
            self.dialogueText = "Princess Peach: Mario! You saved us!"
            Timer.after(1.5, go)
        end,
        function(go)
            self.dialogueText = "Luigi: Wowie! You actually did it, bro!"
            Timer.after(1.5, go)
        end,
        function(go)
            self.dialogueText = "Mushroom Friend: The castle is safe again! Let's go home!"
            Timer.after(1.5, go)
        end,
        function(go)
            self.dialogueText = nil
            Timer.tween(0.5, { [self] = { fadeOpacity = 1 } }):finish(go)
        end
    )(function()
        love.filesystem.write('lvls', '1')
        gStateMachine:change('start')
    end)
end

function PlayState:spawnEnemies()
    if self.levelNum >= 21 and self.levelNum <= 25 then
        for x = 10, self.tileMap.width - 25 do
            if math.random(8) == 1 then 
                local isSquid = math.random(2) == 1
                local enemy = Entity {
                    texture = isSquid and 'squid' or 'fish',
                    x = (x - 1) * TILE_SIZE,
                    y = math.random(2, 6) * TILE_SIZE,
                    width = 16, -- Match the 16x24 frame width for squids
                    height = isSquid and 24 or 16,
                    dx = isSquid and 0 or 40, 
                    level = self.level,
                    animations = {
                        ['idle'] = Animation {
                            frames = {1, 2}, 
                            interval = 0.2
                        }
                    }
                }
                enemy.direction = 'right' 

                enemy.currentAnimation = enemy.animations['idle']
                
                enemy.class = 'Enemy'
                enemy.takeDamage = function(this) this.dead = true end

                enemy.update = function(this, dt)
                    if this.currentAnimation then
                        this.currentAnimation:update(dt)
                    end

                    if isSquid then
                        local diffX = this.x - self.player.x
                        local diffY = this.y - self.player.y
                        local dist = math.sqrt(diffX * diffX + diffY * diffY)

                        if dist < 220 then
                            local speed = 30
                            local dirX = this.x < self.player.x and 1 or -1
                            local dirY = this.y < self.player.y and 1 or -1
                            
                            this.x = this.x + dirX * speed * dt
                            this.y = this.y + dirY * speed * dt
                            
                            this.direction = dirX == 1 and 'left' or 'right'
                        end
                    else
                        this.x = this.x + this.dx * dt
                        
                        if this.x < 0 then
                            this.x = 0
                            this.dx = -this.dx
                        elseif this.x > self.tileMap.width * TILE_SIZE - this.width then
                            this.x = self.tileMap.width * TILE_SIZE - this.width
                            this.dx = -this.dx
                        end

                        this.direction = this.dx > 0 and 'left' or 'right'
                    end
                end
                table.insert(self.level.entities, enemy)
            end
        end
        return
    end

    if self.levelNum == 10 or self.levelNum == 20 then
        return
    end

    if self.levelNum >= UNDERGROUND_LEVEL_START or self.levelNum == 26 then 
        local lowerFloorRow = self.tileMap.height - 1
        
        -- Limit enemy spawning for Level 26 to avoid the boss arena
        local spawnLimit = self.tileMap.width - 4
        if self.levelNum == 26 then
            spawnLimit = self.tileMap.width - 35
        end

        for x = 8, spawnLimit do
            for y = 3, lowerFloorRow do
                local isFloorTile = self.tileMap.tiles[y][x].id == TILE_ID_UNDERGROUND_GROUND
                                 or self.tileMap.tiles[y][x].id == TILE_ID_CASTLE_GROUND
                local isFloorObject = false

                for _, obj in pairs(self.level.objects) do
                    if obj.solid and obj.texture == 'underground-bricks' and math.floor(obj.x / TILE_SIZE) + 1 == x and math.floor(obj.y / TILE_SIZE) + 1 == y then
                        isFloorObject = true
                        break
                    end
                end

                if isFloorTile or isFloorObject then
                    local isSpaceAboveEmpty = self.tileMap.tiles[y - 1][x].id == TILE_ID_EMPTY
                    
                    if isSpaceAboveEmpty then
                        for _, obj in pairs(self.level.objects) do
                            if obj.solid and math.floor(obj.x / TILE_SIZE) + 1 == x and math.floor(obj.y / TILE_SIZE) + 1 == y - 1 then
                                isSpaceAboveEmpty = false
                                break
                            end
                        end
                    end

                    local hasPipe = false
                    for _, obj in pairs(self.level.objects) do
                        if obj.texture == 'pipes' then
                            local pipeX = math.floor(obj.x / TILE_SIZE) + 1
                            if x == pipeX or x == pipeX + 1 then
                                hasPipe = true
                                break
                            end
                        end
                    end

                    if isSpaceAboveEmpty and not hasPipe and math.random(10) == 1 then
                        local enemy
                        local spawnX = (x - 1) * TILE_SIZE
                        local spawnY = (y - 2) * TILE_SIZE

                        if math.random(2) == 1 then
                            enemy = Snail {
                                texture = 'snail',
                                x = spawnX,
                                y = spawnY,
                                width = 16, height = 16,
                                level = self.level
                            }
                        else
                            enemy = Goomba {
                                texture = 'creatures',
                                x = spawnX,
                                y = spawnY,
                                width = 16, height = 16,
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

        return
    end

    for x = 1, self.tileMap.width do
        if x > 6 and x < self.tileMap.width - 20 then
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