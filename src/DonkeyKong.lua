DonkeyKong = Class{__includes = Entity}

function DonkeyKong:init(def)
    def.texture = 'donkey-kong'
    Entity.init(self, def)
    self.class = 'DonkeyKong'
    self.hp = 15 -- Donkey Kong's current HP
    self.maxHP = self.hp
    self.throwTimer = 0
    self.hitTimer = 0
    self.frozen = def.frozen or false

    self.dy = 0
    self.groundY = self.y
    self.targetJumpBlock = nil

    -- Movement properties
    self.dx = def.dx or -20 -- Patrol speed
    self.minX = def.minX or (self.x - 64)
    self.maxX = def.maxX or self.x

    self.animations = {
        ['idle'] = Animation {
        frames = {1, 2, 3, 2, 4, 5, 6},
        interval = 0.15
        },
        ['throwing'] = Animation {
            frames = {11, 12, 13},
            interval = 0.2,
            looping = false
        }
    }
    self.currentAnimation = self.animations['idle']
end

function DonkeyKong:update(dt, player)
    -- If frozen, do not update animations, movement, or throwing logic
    if self.frozen then
        return
    end

    self.currentAnimation:update(dt)

    if self.defeated then
        self.dx = 0
        self.dy = self.dy + 900 * dt
        self.y = self.y + self.dy * dt
        if self.y > self.groundY then
            self.y = self.groundY
            self.dy = 0
        end
        return
    end

    -- Apply gravity
    self.dy = self.dy + 900 * dt
    self.y = self.y + self.dy * dt

    -- Floor collision
    if self.y >= self.groundY then
        self.y = self.groundY
        self.dy = 0

        -- Check if player is on a jump block to trigger jump behavior
        if not self.targetJumpBlock and self.currentAnimation ~= self.animations['throwing'] then
            local playerOnJumpBlock = false
            for _, object in pairs(self.level.objects) do
                if object.texture == 'jump-blocks' then
                    -- More forgiving detection for Mario standing on a block
                    if player.x + player.width > object.x and player.x < object.x + object.width and
                       math.abs((player.y + player.height) - object.y) < 5 then
                        playerOnJumpBlock = true
                        break
                    end
                end
            end

            if playerOnJumpBlock then
                -- Find a jump block to jump to (one that Mario isn't currently occupying)
                local candidates = {}
                for _, object in pairs(self.level.objects) do
                    if object.texture == 'jump-blocks' then
                        local playerOnThis = player.x + player.width > object.x and player.x < object.x + object.width and
                                             math.abs((player.y + player.height) - object.y) < 5
                        if not playerOnThis then
                            table.insert(candidates, object)
                        end
                    end
                end

                if #candidates > 0 then
                    self.targetJumpBlock = candidates[math.random(#candidates)]
                    self.dy = -350 -- Slightly stronger jump to guarantee clearing height
                end
            end
        end
    end

    -- Target block behavior
    if self.targetJumpBlock then
        -- Move horizontally toward target block
        local targetX = self.targetJumpBlock.x + self.targetJumpBlock.width / 2 - self.width / 2
        if math.abs(self.x - targetX) > 4 then
            self.x = self.x + (self.x < targetX and 1 or -1) * 150 * dt
            self.direction = self.x < targetX and 'right' or 'left'
        end

        -- Check for landing on target block
        if self.dy >= 0 and self.y + self.height <= self.targetJumpBlock.y + 12 and
           self.x + self.width > self.targetJumpBlock.x and self.x < self.targetJumpBlock.x + self.targetJumpBlock.width then

            self.y = self.targetJumpBlock.y - self.height
            self.dy = 0

            -- Throw barrel directly at player
            self:throwBarrel(player)
            self.targetJumpBlock = nil -- Fall back down after throwing
        end
    elseif self.currentAnimation ~= self.animations['throwing'] then
        -- Horizontal movement logic (Patrol)
        self.x = self.x + self.dx * dt
        if self.x <= self.minX then
            self.x = self.minX
            self.dx = -self.dx
            self.direction = 'right'
        elseif self.x >= self.maxX then
            self.x = self.maxX
            self.dx = -self.dx
            self.direction = 'left'
        end
    end

    -- Handle hit stun and flickering (Invulnerability frames)
    if self.hitTimer > 0 then
        self.hitTimer = self.hitTimer - dt
        -- Rapidly toggle opacity for a flicker effect
        self.opacity = (math.floor(self.hitTimer * 20) % 2 == 0) and 0.5 or 1
    else
        self.opacity = 1
    end

    -- Barrel throwing logic
    -- Frequency increases as health decreases (from ~6.0s down to 2.0s)
    local throwDelay = math.max(2.0, 6.0 * (self.hp / self.maxHP))
    self.throwTimer = self.throwTimer + dt
    if self.throwTimer > throwDelay then
        self.throwTimer = 0
        self:throwBarrel(player)
    end
end

function DonkeyKong:throwBarrel(player)
    if player and player.x < self.x then
        self.direction = 'left'
    else
        self.direction = 'right'
    end

    gSounds['dk-throw']:play()

    self.currentAnimation = self.animations['throwing']
    self.currentAnimation:refresh()

    Timer.after(0.6, function()
        self.currentAnimation = self.animations['idle']
    end)

    -- Create a rolling barrel GameObject
    local spawnX = self.direction == 'left' and (self.x - 16) or (self.x + self.width)
    local rollSpeed = self.direction == 'left' and -60 or 60

    local barrel = GameObject {
        texture = 'barrels',
        x = spawnX,
        y = self.y + 14,
        width = 7,
        height = 7,
        frame = 83,
        collidable = true,
        solid = false,
        isBarrel = true,
        animation = Animation {
            frames = {83, 84, 85, 86}, -- Columns 3 to 6
            interval = 0.1
        },
        dy = 0,
        dx = rollSpeed,
        direction = self.direction
    }

    -- Add the barrel to the level's object list
    table.insert(self.level.objects, barrel)
end