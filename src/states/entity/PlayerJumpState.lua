PlayerJumpState = Class{__includes = BaseState}

function PlayerJumpState:init(player, gravity)
    self.player = player
    self.gravity = gravity
    self.animation = Animation {
        frames = {7},
        interval = 1
    }
    self.player.currentAnimation = self.animation
end

function PlayerJumpState:enter(params)
    params = params or {}

    if params.playSound ~= false then
        gSounds['jump']:play()
    end

    self.player.dy = params.velocity or PLAYER_JUMP_VELOCITY
end

function PlayerJumpState:update(dt)
    self.player.currentAnimation:update(dt)

    if self.player.controlLock then return end

    local previousY = self.player.y
    self.player.dy = self.player.dy + self.gravity * dt
    self.player.y = self.player.y + (self.player.dy * dt)

    -- go into the falling state when y velocity is positive
    if self.player.dy >= 0 then
        self.player:changeState('falling')
        return
    end

    local tileLeft = self.player.map:pointToTile(self.player.x + 3, self.player.y)
    local tileRight = self.player.map:pointToTile(self.player.x + self.player.width - 3, self.player.y)

    if (tileLeft and tileRight) and (tileLeft:collidable() or tileRight:collidable()) then
        self.player.y = tileLeft.y * TILE_SIZE -- Snap to bottom of the tile
        self.player.dy = 0
        self.player:changeState('falling')
        return
    end

    if love.keyboard.isDown('left') then
        self.player.direction = 'left'
        self.player.x = self.player.x - PLAYER_WALK_SPEED * dt
        self.player:checkLeftCollisions(dt)
    elseif love.keyboard.isDown('right') then
        self.player.direction = 'right'
        self.player.x = self.player.x + PLAYER_WALK_SPEED * dt
        self.player:checkRightCollisions(dt)
    end

    -- Check pipe collisions BEFORE other objects
    if self.player:checkPipeCollisions(dt) then
        return
    end

    for k, object in pairs(self.player.level.objects) do
        if object.texture ~= 'pipes' and object.solid then
            local prevHead = previousY
            local currHead = self.player.y
            local blockBottom = object.y + object.height
            local blockLeft = object.x
            local blockRight = object.x + object.width
            local playerLeft = self.player.x
            local playerRight = self.player.x + self.player.width

            if self.player.dy < 0 and
               prevHead >= blockBottom and
               currHead <= blockBottom and
               playerRight > blockLeft and
               playerLeft < blockRight then

                if object.onCollide then
                    object.onCollide(object)
                end
                self.player.y = object.y + object.height + 1 -- Snap below to prevent sticking
                self.player.dy = 0
                self.player:changeState('falling')
                return
            end
        end
    end

    for k, entity in pairs(self.player.level.entities) do
        if entity:collides(self.player) then
            gSounds['death']:play()
            gStateMachine:change('start')
        end
    end
end
