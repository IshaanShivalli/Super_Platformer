PlayerJumpState = Class{__includes = BaseState}

function PlayerJumpState:init(player, gravity)
    self.player = player
    self.name = 'jump'
    self.gravity = gravity
    self.animation = Animation {
        frames = {4},
        interval = 1
    }
end

function PlayerJumpState:enter(params)
    params = params or {}

    if params.playSound ~= false then
        gSounds['jump']:play()
    end

    self.player.dy = params.velocity or PLAYER_JUMP_VELOCITY
end

function PlayerJumpState:update(dt)
    local previousY = self.player.y
    self.player.dy = self.player.dy + self.gravity * dt
    self.player.y = self.player.y + (self.player.dy * dt)

    -- Check pipe/plant collisions while jumping
    if self.player:checkPipeCollisions(dt) then
        return
    end

    -- go into the falling state when y velocity is positive
    if self.player.dy >= 0 then
        self.player:changeState('falling')
        return
    end

    local tileLeft = self.player.map:pointToTile(self.player.x + 3, self.player.y)
    local tileRight = self.player.map:pointToTile(self.player.x + self.player.width - 3, self.player.y)

    -- Fix: Use 'or' for tile existence to avoid teleporting/phasing at map edges
    if (tileLeft and tileLeft:collidable()) or (tileRight and tileRight:collidable()) then
        local collisionTile = tileLeft or tileRight
        self.player.y = collisionTile.y * TILE_SIZE -- Snap to bottom of the tile
        self.player.dy = 0
        self.player:changeState('falling')
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

    for k, object in pairs(self.player.level.objects) do
        if object.solid then
            local blockBottom = object.y + object.height
            local blockLeft = object.x
            local blockRight = object.x + object.width
            local playerLeft = self.player.x
            local playerRight = self.player.x + self.player.width

            if self.player.dy < 0 and self.player.y <= blockBottom and self.player.y + 4 >= blockBottom and
               playerRight > blockLeft and
               playerLeft < blockRight then

                if object.onCollide then 
                    object.onCollide(object) 
                else 
                    if self.player:hitBlockFromBelow(object) then
                        -- Protect Mario from enemies sitting on top of the block he just hit
                        self.player.invincibleTimer = math.max(self.player.invincibleTimer, 0.1)
                    end
                end

                self.player.y = object.y + object.height + 1 -- Snap below to prevent sticking
                self.player.dy = 0
                self.player:changeState('falling')
                return
            end
        end
    end
end