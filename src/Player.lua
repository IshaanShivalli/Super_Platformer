Player = Class{__includes = Entity}

function Player:init(def)
    Entity.init(self, def)
    self.score = def.score or 0
    self.lives = def.lives or 3
    self.powerupState = def.powerupState or PLAYER_STATE_SMALL -- Initial state
    self.fireballTimer = 0
    self.fireballCooldown = 0.5
    self.jumpCooldown = 0
    self.jumpCooldownTime = 0.2
    self.jumpKeyPressed = false -- Track if jump key is currently held
    self.invincibleTimer = 0 -- For temporary invincibility after taking a hit
    self.inFlagpoleSequence = false

    -- Player-specific animations
    -- Assuming Mariosheet.png has these frames for the base texture ('green-alien')
    self.idleAnimation = Animation {
        frames = {1}, -- Frame 1 for idle
        interval = 1
    }
    self.walkingAnimation = Animation {
        frames = {3, 4}, -- Proper walk cycle (excluding idle frame 1)
        interval = 0.1
    }
    self.jumpAnimation = Animation {
        frames = {7}, -- Frame 7 for jumping
        interval = 1
    }
    self.fallingAnimation = Animation {
        frames = {1}, -- Frame 2 for falling
        interval = 1
    }
    self.flagAnimation = Animation {
        frames = {6}, -- Frame 6 for grabbing the flag
        interval = 1
    }
    self.swimmingAnimation = Animation {
        frames = {8, 9, 10, 11}, -- Swimming frames 8 to 11
        interval = 0.1
    }
    -- Initialize currentAnimation to idle
    self.currentAnimation = self.idleAnimation

    -- Store the base texture name and the current texture name for rendering
    self.baseTextureName = def.texture -- e.g., 'green-alien'
    self.currentTextureName = self.baseTextureName

    -- Set initial texture based on powerup state if provided
    if self.powerupState == PLAYER_STATE_BIG then
        self.currentTextureName = 'mario-powerup'
        self.height = 32
    elseif self.powerupState == PLAYER_STATE_FIRE then
        self.currentTextureName = 'fire-powerup-big'
        self.height = 32
    end

    -- Initialize particle system for brick breaking
    self.psystem = love.graphics.newParticleSystem(gTextures['particle'], 64)
    self.psystem:setParticleLifetime(0.5, 1.0)
    self.psystem:setLinearAcceleration(-100, 100, 100, 400) -- Gravity-like effect
    self.psystem:setEmissionArea('normal', 4, 4)
    -- Use the first frame of the particle quads
    self.psystem:setQuads(gFrames['particle'][1])
end

function Player:update(dt)
    -- Reset jump key flag FIRST when key is released (before state machine updates)
    if not (love.keyboard.isDown('space') or love.keyboard.isDown('up')) then
        self.jumpKeyPressed = false
    end

    -- Update the state machine first
    self.stateMachine:update(dt)

    -- Select animation based on level and state
    if self.level.levelNum >= 21 and self.level.levelNum < 26 then
        if self.currentAnimation ~= self.swimmingAnimation then
            self.currentAnimation = self.swimmingAnimation
        end
    elseif self.inFlagpoleSequence then
        if self.currentAnimation ~= self.flagAnimation then
            self.currentAnimation = self.flagAnimation
        end
    else
        if self.stateMachine.current.name == 'idle' then
            self.currentAnimation = self.idleAnimation
        elseif self.stateMachine.current.name == 'walking' then
            self.currentAnimation = self.walkingAnimation
        elseif self.stateMachine.current.name == 'jump' then
            self.currentAnimation = self.jumpAnimation
        elseif self.stateMachine.current.name == 'falling' then
            self.currentAnimation = self.fallingAnimation
        end
    end
    
    self.currentAnimation:update(dt) -- Update the chosen animation

    self.psystem:update(dt)

    if self.fireballTimer > 0 then
        self.fireballTimer = self.fireballTimer - dt
    end

    if self.invincibleTimer > 0 then
        self.invincibleTimer = self.invincibleTimer - dt
        -- Flicker effect for invincibility
        self.opacity = (math.floor(self.invincibleTimer * 10) % 2 == 0) and 0.5 or 1
    else
        self.opacity = 1
    end

    if self.jumpCooldown > 0 then
        self.jumpCooldown = math.max(0, self.jumpCooldown - dt)
    end

    for i = #self.level.objects, 1, -1 do
        local object = self.level.objects[i]
        if object.consumable and self:collides(object) then
            object.onConsume(self, object)
            table.remove(self.level.objects, i)
        end
    end
end

function Player:takeHit()
    if self.invincibleTimer > 0 then return end -- Already invincible

    gSounds['death']:play() -- Generic hit sound for now

    if self.powerupState == PLAYER_STATE_FIRE then
        self.powerupState = PLAYER_STATE_BIG
        self.currentTextureName = 'mario-powerup'
        self.height = 32
        self.invincibleTimer = 2 -- 2 seconds invincibility
    elseif self.powerupState == PLAYER_STATE_BIG then
        self.y = self.y + (32 - 14.8) -- Shift down to stay on ground
        self.powerupState = PLAYER_STATE_SMALL
        self.currentTextureName = self.baseTextureName
        self.height = 14.8
        self.invincibleTimer = 2 -- 2 seconds invincibility
    else -- PLAYER_STATE_SMALL
        self.lives = self.lives - 1
        if self.lives <= 0 then
            -- Reset save file on actual Game Over
            love.filesystem.write('lvls', "1")
            gStateMachine:change('start')
        else
            -- Respawn: Restart current level with current stats
            gStateMachine:change('play', {
                levelNum = self.level.levelNum,
                score = self.score,
                lives = self.lives,
                powerupState = PLAYER_STATE_SMALL
            })
        end
    end
end

function Player:isOnGround()
    -- Check for tiles beneath the player
    local tileBottomLeft = self.map:pointToTile(self.x + 1, self.y + self.height)
    local tileBottomRight = self.map:pointToTile(self.x + self.width - 1, self.y + self.height)
    
    -- Check for objects beneath the player
    self.y = self.y + 1
    local collidedObjects = self:checkObjectCollisions(true)
    self.y = self.y - 1
    
    -- Player is on ground if there are collidable tiles or objects beneath
    local hasGroundTiles = (tileBottomLeft and tileBottomRight) and 
                           (tileBottomLeft:collidable() or tileBottomRight:collidable())
    local hasGroundObjects = #collidedObjects > 0
    
    return hasGroundTiles or hasGroundObjects
end

function Player:canPerformOverworldJump()
    if not self.level or not self.level.levelNum then
        return true
    end
    
    local levelNum = self.level.levelNum
    
    -- Only allow unlimited jumping in underwater levels (21-25)
    if levelNum >= 21 and levelNum <= 25 then
        return true
    end
    
    -- For all other levels (1-9, 10, 11-20, 26): Must be on ground to jump
    return self:isOnGround()
end

function Player:startOverworldJumpCooldown()
    if self.level and self.level.levelNum and self.level.levelNum < UNDERGROUND_LEVEL_START and self.level.levelNum ~= 10 then
        self.jumpCooldown = self.jumpCooldownTime
    end
end

function Player:gainPowerup(powerupType)
    gSounds['powerup-reveal']:play()

    if powerupType == POWERUP_SIZE_ID then
        if self.powerupState == PLAYER_STATE_SMALL then
            self.y = self.y - (32 - 14.8) -- Shift up to accommodate larger height
            self.powerupState = PLAYER_STATE_BIG
            self.currentTextureName = 'mario-powerup'
            self.height = 32
        end
    elseif powerupType == POWERUP_FIRE_ID then
        if self.powerupState == PLAYER_STATE_SMALL then
            self.y = self.y - (32 - 14.8)
        end
        self.powerupState = PLAYER_STATE_FIRE
        self.currentTextureName = 'fire-powerup-big'
        self.height = 32
    end
end

function Player:addScore(amount)
    self.score = self.score + amount
    -- Refill system: Exchange every 2000 points for an extra life
    while self.score >= 2000 do
        self.score = self.score - 2000
        self.lives = self.lives + 1
        gSounds['powerup-reveal']:play()
    end
end

function Player:throwFireball()
    if self.powerupState == PLAYER_STATE_FIRE and self.fireballTimer <= 0 then
        gSounds['fireball']:play()
        self.fireballTimer = self.fireballCooldown

        local fireballX = self.x + (self.direction == 'right' and self.width or -FIREBALL_WIDTH)
        local fireballY = self.y + self.height / 2 - FIREBALL_HEIGHT / 2

        table.insert(self.level.fireballs, Fireball {
            x = fireballX,
            y = fireballY,
            dx = self.direction == 'right' and FIREBALL_SPEED or -FIREBALL_SPEED,
            dy = 0,
            level = self.level,
            player = self -- Pass player reference for fireball direction
        })
    end
end

function Player:render()
    love.graphics.setColor(1, 1, 1, self.opacity or 1)
    if self.currentAnimation then
        local quad = gFrames[self.currentTextureName][self.currentAnimation:getCurrentFrame()]
        if quad then
            love.graphics.draw(gTextures[self.currentTextureName], quad,
                math.floor(self.x) + self.width / 2,
                math.floor(self.y) + self.height / 2,
                0, self.direction == 'right' and 1 or -1, 1,
                self.width / 2, self.height / 2)
        end
    end

    -- Draw particles in world space (camera translation already applied in PlayState)
    love.graphics.draw(self.psystem, 0, 0)

    love.graphics.setColor(1, 1, 1, 1)
    self:renderHitbox(0, 1, 0, 1)
end

function Player:checkLeftCollisions(dt)
    local tileTopLeft = self.map:pointToTile(self.x, self.y + 1)
    local tileBottomLeft = self.map:pointToTile(self.x, self.y + self.height - 1)

    if (tileTopLeft and tileBottomLeft) and (tileTopLeft:collidable() or tileBottomLeft:collidable()) then
    if tileTopLeft then
        self.x = (tileTopLeft.x) * TILE_SIZE
    end
    else
        -- Temporarily shrink hitbox vertically to avoid floor/ceiling snags
        -- For Big Mario (32px), we need a larger buffer to prevent "pinning"
        local oldY, oldHeight = self.y, self.height
        local buffer = 4
        self.y, self.height = self.y + buffer, self.height - (buffer * 2)
        
        local collidedObjects = self:checkObjectCollisions(false)
        
        self.y, self.height = oldY, oldHeight

        if #collidedObjects > 0 then
            local snapX = collidedObjects[1].x + collidedObjects[1].width
            for i = 2, #collidedObjects do
                snapX = math.max(snapX, collidedObjects[i].x + collidedObjects[i].width)
            end
            self.x = snapX
        end
    end
end

function Player:checkRightCollisions(dt)
    local tileTopRight = self.map:pointToTile(self.x + self.width, self.y + 1)
    local tileBottomRight = self.map:pointToTile(self.x + self.width, self.y + self.height - 1)

    if (tileTopRight and tileBottomRight) and (tileTopRight:collidable() or tileBottomRight:collidable()) then
        self.x = (tileTopRight.x - 1) * TILE_SIZE - self.width
    else
        -- Temporarily shrink hitbox vertically to avoid floor/ceiling snags
        local oldY, oldHeight = self.y, self.height
        local buffer = 4
        self.y, self.height = self.y + buffer, self.height - (buffer * 2)

        local collidedObjects = self:checkObjectCollisions(false)

        self.y, self.height = oldY, oldHeight

        if #collidedObjects > 0 then
            local snapX = collidedObjects[1].x
            for i = 2, #collidedObjects do
                snapX = math.min(snapX, collidedObjects[i].x)
            end
            self.x = snapX - self.width
        end
    end
end

function Player:checkPipeCollisions(dt)
    for k, object in pairs(self.level.objects) do
        local isSidePipeStart = object.texture == 'side-pipe-start'
        local isSidePipeEnd   = object.texture == 'side-pipe-end'
        local isSidePipe      = isSidePipeStart or isSidePipeEnd
        local isPipe          = object.texture == 'pipes' or isSidePipe

        if isPipe and object.collidable and object:collides(self) then
            if object.checkPlantCollision and object:checkPlantCollision(self) then
                self:takeHit() -- Use the life system instead of hard reset
                return true 
            end

            local pRight  = (self.x + self.width) - object.x
            local pLeft   = (object.x + object.width) - self.x
            local pBottom = (self.y + self.height) - object.y
            local pTop    = (object.y + object.height) - self.y

            local minP
            -- Only resolve vertical collision in the direction Mario is moving
            -- This prevents "teleporting" to the top while jumping from below
            if pBottom >= 0 and pBottom < 8 and self.dy >= 0 then
                minP = pBottom
            elseif pTop >= 0 and pTop < 8 and self.dy < 0 then
                minP = pTop
            else
                minP = math.min(pRight, pLeft)
            end

            -- Check if Mario is vertically inside the pipe opening
            local playerVerticallyAligned = self.y >= object.y and
                                            self.y + self.height <= object.y + object.height + 4

            if isSidePipe and playerVerticallyAligned then
                if isSidePipeStart then
                    -- Opening is on the RIGHT side of start pipe
                    -- Mario enters from the right → pLeft is entry (allow)
                    -- pRight is the back wall (block)
                    if minP == pRight then
                        -- Back wall: block at the left edge of the pipe/screen
                        self.x = object.x
                        return true
                    end
                    -- Entry from right side: allow
                    return false

                elseif isSidePipeEnd then
                    -- Opening is on the LEFT side of end pipe
                    -- Mario enters from the left → pRight is entry (allow)
                    -- pLeft is the back wall (block)
                    if minP == pLeft then
                        -- Back wall: block
                        self.x = object.x + object.width - self.width
                        return true
                    end
                    -- Entry from left side: allow
                    return false
                end
            end

            -- Standard pipe collision resolution
            if minP == pBottom then
                self.y = object.y - self.height

                if self.dy > 0 then
                    self.dy = 0
                    local isMoving = love.keyboard.isDown('left') or love.keyboard.isDown('right')
                    if isMoving then
                        if self.stateMachine.current.name ~= 'walking' then self:changeState('walking') end
                    else
                        if self.stateMachine.current.name ~= 'idle' then self:changeState('idle') end
                    end
                    return true
                elseif self.dy == 0 then
                    self.dy = 0
                end
                return false

            elseif minP == pTop then
                self.y = object.y + object.height + 1 -- Snap with 1px buffer to prevent pinning
                self.dy = 0
                return true

            elseif minP == pRight then
                local isVerticalOpening = object.texture == 'pipes' and
                    (self.y + self.height >= object.y - 1 and self.y < object.y + TILE_SIZE)

                if not isSidePipe and not isVerticalOpening then
                    self.x = object.x - self.width
                    return true
                end

            elseif minP == pLeft then
                local isVerticalOpening = object.texture == 'pipes' and
                    (self.y + self.height >= object.y - 1 and self.y < object.y + TILE_SIZE)

                if not isSidePipe and not isVerticalOpening then
                    self.x = object.x + object.width
                    return true
                end
            end
        end
    end
    return false
end

-- New helper function for breaking blocks from below
function Player:hitBlockFromBelow(block)
    if (block.texture == 'bricks' or block.texture == 'underground-bricks') and (self.powerupState == PLAYER_STATE_BIG or self.powerupState == PLAYER_STATE_FIRE) then
        -- Emit debris particles from the center of the block
        self.psystem:setPosition(block.x + block.width / 2, block.y + (block.height or 15) / 2)
        self.psystem:emit(20)

        -- Remove the brick
        for i = #self.level.objects, 1, -1 do
            if self.level.objects[i] == block then
                table.remove(self.level.objects, i)
                gSounds['break-block']:play()
                self:addScore(50) -- Award points for breaking a block
                break
            end
        end
        return true -- Brick was broken
    end
    return false -- Brick was not broken
end

function Player:checkObjectCollisions(isFloorCheck)
    local collidedObjects = {}

    for k, object in pairs(self.level.objects) do

        -- LAVA DAMAGE
        if object.isLava and self:collides(object) then
            self:takeHit()
            return {}
        end

        -- NORMAL OBJECT COLLISION
        if object:collides(self) then

            if object.solid then

                -- Skip victory objects
                if not (object.isFlagPole or object.isCastle) then
                    table.insert(collidedObjects, object)
                end
            end
        end
    end

    return collidedObjects
end