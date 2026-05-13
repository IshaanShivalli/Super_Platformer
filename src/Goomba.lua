Goomba = Class{__includes = Entity}

function Goomba:init(def)
    Entity.init(self, def)
    self.score = 50

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
    Entity.update(self, dt)
end

function Goomba:render()
    Entity.render(self)
    self:renderHitbox(1, 0.2, 0.2, 1)
end
