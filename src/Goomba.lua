Goomba = Class{__includes = Entity}

function Goomba:init(def)
    -- Goomba sprites live in the 'creatures' sheet
    def.texture = 'creatures'
    Entity.init(self, def)
    self.class = 'Goomba'
    self.score = 50
    self.dead = false

    self.walkAnimation = Animation {
        frames = {1, 2},
        interval = 0.2
    }

    self.squishAnimation = Animation {
        frames = {3},
        interval = 1
    }

    self.currentAnimation = self.walkAnimation
end

function Goomba:update(dt, player)
    -- stateMachine is assigned by PlayState after construction; guard until it exists
    if self.stateMachine then
        Entity.update(self, dt)
    end

    if self.dead then return end

    -- Always play the walk animation while alive
    self.currentAnimation = self.walkAnimation
    self.currentAnimation:update(dt)
end

function Goomba:takeDamage()
    gSounds['kill']:play()
    self.dead = true
end

function Goomba:render()
    Entity.render(self)
    self:renderHitbox(1, 0.2, 0.2, 1)
end