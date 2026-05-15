Bowser = Class{__includes = Entity}

function Bowser:init(def)
    def.texture = 'bowser'
    Entity.init(self, def)
    self.class = 'Bowser'
    self.hp = 20
    self.maxHP = self.hp
    self.attackTimer = 0
    self.attackCooldown = 2
    self.hitTimer = 0
    self.defeated = false

    self.dy = 0
    self.groundY = self.y

    self.dx = def.dx or 20
    self.minX = def.minX or (self.x - TILE_SIZE * 3)
    self.maxX = def.maxX or (self.x + TILE_SIZE * 3)

    self.animations = {
        ['idle'] = Animation {
            frames = {1, 2},
            interval = 0.3
        },
        ['attack'] = Animation {
            frames = {3, 4, 5},
            interval = 0.1,
            looping = false
        },
        ['hit'] = Animation {
            frames = {6},
            interval = 1
        }
    }
    self.currentAnimation = self.animations['idle']
end

function Bowser:update(dt)
    self.currentAnimation:update(dt)

    if self.defeated then
        return
    end

    if self.player then
        self.direction = (self.player.x < self.x) and 'left' or 'right'
    end

    self.x = self.x + self.dx * dt

    if self.dx < 0 and self.x <= self.minX then
        self.x = self.minX
        self.dx = -self.dx
    elseif self.dx > 0 and self.x >= self.maxX then
        self.x = self.maxX
        self.dx = -self.dx
    end

    self.dy = self.dy + 900 * dt
    self.y = self.y + self.dy * dt

    if self.y >= self.groundY then
        self.y = self.groundY
        self.dy = 0
    end

    if self.hitTimer > 0 then
        self.hitTimer = self.hitTimer - dt
        self.opacity = (math.floor(self.hitTimer * 20) % 2 == 0) and 0.5 or 1
    else
        self.opacity = 1
    end

    self.attackTimer = self.attackTimer + dt
    if self.attackTimer >= self.attackCooldown then
        self.attackTimer = 0
        self:attack(self.player)
    end
end

function Bowser:attack(player)
    if not player then return end
    gSounds['dk-throw']:play()
    self.currentAnimation = self.animations['attack']
    self.currentAnimation:refresh()

    Timer.after(self.currentAnimation.interval * #self.currentAnimation.frames, function()
        self.currentAnimation = self.animations['idle']
    end)

    local fireballX = self.x + (self.direction == 'right' and self.width or -FIREBALL_WIDTH)
    local fireballY = self.y + self.height / 2 - FIREBALL_HEIGHT / 2

    table.insert(self.level.fireballs, Fireball {
        texture = 'fire-projectile',
        x = fireballX,
        y = fireballY,
        dx = self.direction == 'right' and FIREBALL_SPEED or -FIREBALL_SPEED,
        dy = 0,
        gravity = 0,
        level = self.level,
        player = self
    })
end

function Bowser:takeDamage()
    if self.hitTimer > 0 then return end

    self.hp = self.hp - 1
    gSounds['dk-hit']:play()
    self.hitTimer = 0.8

    if self.hp <= 0 then
        self.defeated = true
        gSounds['dk-roar']:play()
    end
end