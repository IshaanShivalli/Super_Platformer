PlayerFallingState = Class{__includes = BaseState}

function PlayerFallingState:init(player, gravity)
    self.player = player
    self.name = 'falling'
    self.gravity = gravity
    self.animation = Animation {
        frames = {5},
        interval = 1
    }
end

function PlayerFallingState:update(dt)
    local previousY = self.player.y
    self.player.dy = self.player.dy + self.gravity * dt
    self.player.y = self.player.y + (self.player.dy * dt)
    local previousBottom = previousY + self.player.height
    local currentBottom = self.player.y + self.player.height

    -- check if we've collided with any entities and kill them if so
    for k, entity in pairs(self.player.level.entities) do
        if entity:collides(self.player) then
            -- If it's the boss, skip the generic instant-kill logic.
            -- Boss HP and damage are handled in PlayState:update.
            if entity.texture == 'donkey-kong' then
                break
            end

            local entityTop = entity.y

            -- Forgiving stomp: allow a larger vertical buffer for corner hits
            if previousBottom <= entityTop + 8 and currentBottom >= entityTop then
                gSounds['kill']:play()
                gSounds['kill2']:play()
                self.player:addScore(100)
                
                -- Remove the entity immediately on hit
                table.remove(self.player.level.entities, k)
                self.player.invincibleTimer = 0.1 -- Tiny window to avoid double-hit death

                -- Bounce off the enemy and transition to jump state
                self.player:changeState('jump', {
                    velocity = -200,
                    playSound = false
                })
            else
                self.player:takeHit()
            end
            return
        end
    end

    -- look at two tiles below our feet and check for collisions
    local tileBottomLeft = self.player.map:pointToTile(self.player.x + 1, self.player.y + self.player.height)
    local tileBottomRight = self.player.map:pointToTile(self.player.x + self.player.width - 1, self.player.y + self.player.height)

    -- if we get a collision beneath us, go into either walking or idle
    if (tileBottomLeft and tileBottomRight) and (tileBottomLeft:collidable() or tileBottomRight:collidable()) then
        self.player.dy = 0
        
        -- set the player to be walking or idle on landing depending on input
        if love.keyboard.isDown('left') or love.keyboard.isDown('right') then
            self.player:changeState('walking')
        else
            self.player:changeState('idle')
        end

        self.player.y = (tileBottomLeft.y - 1) * TILE_SIZE - self.player.height
        return
    -- Head collision check for underwater levels where Mario can swim upward (dy < 0)
    elseif self.player.dy < 0 then
        local tileTopLeft = self.player.map:pointToTile(self.player.x + 3, self.player.y)
        local tileTopRight = self.player.map:pointToTile(self.player.x + self.player.width - 3, self.player.y)

        if (tileTopLeft and tileTopLeft:collidable()) or (tileTopRight and tileTopRight:collidable()) then
            local collisionTile = tileTopLeft or tileTopRight
            -- Snap to the bottom of the tile we hit
            self.player.y = collisionTile.y * TILE_SIZE
            self.player.dy = 0
        end
    elseif self.player.y > self.player.map.height * TILE_SIZE then
        self.player.lives = self.player.lives - 1
        gSounds['death']:play()
        if self.player.controlLock then self.player.controlLock = false end
        if self.player.lives <= 0 then
            love.filesystem.write('lvls', "1")
            gStateMachine:change('start')
        else
            gStateMachine:change('play', {
                levelNum = self.player.level.levelNum,
                score = self.player.score,
                lives = self.player.lives,
                powerupState = self.player.powerupState
            })
        end
        return
    end

    if not self.player.controlLock then
        if love.keyboard.isDown('left') then
            self.player.direction = 'left'
            self.player.x = self.player.x - PLAYER_WALK_SPEED * dt
            self.player:checkLeftCollisions(dt)
        elseif love.keyboard.isDown('right') then
            self.player.direction = 'right'
            self.player.x = self.player.x + PLAYER_WALK_SPEED * dt
            self.player:checkRightCollisions(dt)
        end
    end

    if self.player:canPerformOverworldJump() and (love.keyboard.wasPressed('space') or love.keyboard.wasPressed('up')) then
        self.player:changeState('jump')
    end

    -- Check pipe collisions FIRST before other objects
    if self.player:checkPipeCollisions(dt) then
        return  -- Stop processing if pipe collision occurred
    end

    -- check if we've collided with any collidable game objects (skip pipes since we already handled them)
    for k, object in pairs(self.player.level.objects) do
        -- Skip vertical pipes AND side pipes (side pipes are handled via overlap/triggers)
        local isSidePipe = object.texture == 'side-pipe-start' or object.texture == 'side-pipe-end'
        
        if object.texture ~= 'pipes' and not isSidePipe and object:collides(self.player) then
            -- Handle Spring interaction
            if object.isSpring then
                local springTop = object.y + 16

                if self.player.dy >= 0 and
                   previousBottom <= springTop + 2 and
                   currentBottom >= springTop then
                    gSounds['jump']:play()
                    object.hit = true
                    self.player.y = springTop - self.player.height
                    self.player:changeState('jump', {
                        velocity = -480, -- Launch roughly 8 blocks high
                        playSound = false
                    })
                    Timer.after(0.25, function() object.hit = false end)
                    return
                end
            end

            -- Only land on top of solid objects if we are falling downwards
            -- and our feet were above the object's top in the previous frame
            local isSidePipe = object.texture == 'side-pipe-start' or object.texture == 'side-pipe-end'
            if object.solid and self.player.dy >= 0 and (self.player.y + self.player.height - self.player.dy * dt) <= object.y + 2 then
                self.player.dy = 0
                self.player.y = object.y - self.player.height

                if love.keyboard.isDown('left') or love.keyboard.isDown('right') then
                    self.player:changeState('walking')
                else
                    self.player:changeState('idle')
                end
                return
            -- Hitting from below (Ceiling) - essential for underwater platforms
            elseif self.player.dy < 0 and (self.player.y + 4 >= object.y + object.height) then
                self.player.y = object.y + object.height
                self.player.dy = 0
                if object.onCollide then object.onCollide(object) end
            end
        end
    end
end