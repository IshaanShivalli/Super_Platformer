DonkeyKong = Class{__includes = Entity}

function DonkeyKong:init(def)
    Entity.init(self, def)
    self.hp = 15 -- Donkey Kong's current HP
    self.maxHP = self.hp
    self.throwTimer = 0
    self.hitTimer = 0

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
    self.currentAnimation:update(dt)

    if self.defeated then
        self.dx = 0
        return
    end

    -- Horizontal movement logic
    if self.currentAnimation ~= self.animations['throwing'] then
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
    -- Face the player when throwing
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
        dx = rollSpeed -- Speed at which it rolls toward Mario
    }

    -- Add the barrel to the level's object list
    table.insert(self.level.objects, barrel)
end