PlayerFallingState = Class{__includes = BaseState}

function PlayerFallingState:init(player, gravity)
    self.player = player
    self.gravity = gravity
    self.animation = Animation {
        frames = {1},
        interval = 1
    }
    self.player.currentAnimation = self.animation
end

function PlayerFallingState:update(dt)
    self.player.currentAnimation:update(dt)

    if self.player.controlLock then return end

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

            if previousBottom <= entityTop + 2 and currentBottom >= entityTop then
                gSounds['kill']:play()
                gSounds['kill2']:play()
                self.player.score = self.player.score + 100
                
                if entity.class == 'Goomba' then
                    entity:squish()
                    -- Remove after squish animation plays (assuming squishAnimation.interval * frames is total duration)
                    Timer.after(entity.squishAnimation.interval * #entity.squishAnimation.frames, function()
                        table.remove(self.player.level.entities, k)
                    end)
                else
                    table.remove(self.player.level.entities, k)
                end

                -- Bounce off the enemy and transition to jump state
                self.player:changeState('jump', {
                    velocity = -200,
                    playSound = false
                })
            else
                gSounds['death']:play()
                gStateMachine:change('start')
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
        return  -- Important: return after handling tile collision
    elseif self.player.y > self.player.map.height * TILE_SIZE then
        gSounds['death']:play()
        gStateMachine:change('start')
        return
    elseif love.keyboard.isDown('left') then
        self.player.direction = 'left'
        self.player.x = self.player.x - PLAYER_WALK_SPEED * dt
        self.player:checkLeftCollisions(dt)
    elseif love.keyboard.isDown('right') then
        self.player.direction = 'right'
        self.player.x = self.player.x + PLAYER_WALK_SPEED * dt
        self.player:checkRightCollisions(dt)
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
            end
        end
    end
end