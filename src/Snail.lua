Snail = Class{__includes = Entity}

function Snail:init(def)
    Entity.init(self, def)
    self.class = 'Snail'

    self.walkAnimation = Animation {
        frames = {1, 2},
        interval = 0.2
    }
    self.chaseAnimation = Animation {
        frames = {3},
        interval = 0.5
    }
    self.idleAnimation = Animation {
        frames = {1},
        interval = 1
    }
    self.currentAnimation = self.walkAnimation -- Default
    self.dead = false -- New property to mark for removal
end

function Snail:update(dt)
    -- Update the state machine first
    if self.stateMachine then
        Entity.update(self, dt)
    end

    -- Then set animation based on current state
    if self.dead then
        return -- Don't update if dead, PlayState will remove it
    end

    if self.stateMachine and self.stateMachine.current then
        if self.stateMachine.current.name == 'moving' then
            self.currentAnimation = self.walkAnimation
        elseif self.stateMachine.current.name == 'chasing' then
            self.currentAnimation = self.chaseAnimation
        elseif self.stateMachine.current.name == 'idle' then
            self.currentAnimation = self.idleAnimation
        end
    else
        self.currentAnimation = self.idleAnimation
    end
    self.currentAnimation:update(dt) -- Update the chosen animation
end

function Snail:render()
    local currentFrame = self.currentAnimation:getCurrentFrame()
    local quad = gFrames[self.texture][currentFrame]
    if quad then
        love.graphics.draw(gTextures[self.texture], quad,
            math.floor(self.x) + self.width / 2,
            math.floor(self.y) + self.height / 2,
            0, self.direction == 'left' and 1 or -1, 1,
            self.width / 2, self.height / 2)
    end

    self:renderHitbox(0, 1, 0, 1)
end

function Snail:takeDamage()
    gSounds['kill']:play() -- Or a specific enemy hit sound
    self.dead = true -- Mark for removal
end
