Spring = Class{__includes = GameObject}

function Spring:init(def)
    GameObject.init(self, def)
    self.height = 32
    self.y = self.y - 16 -- Offset up so it sits on the ground at 32px height
    self.animation = Animation {
        frames = {3, 2, 1, 2, 3},
        interval = 0.05
    }
    self.isSpring = true
end

function Spring:update(dt)
    if self.hit then
        self.animation:update(dt)
    end
end

function Spring:collides(target)
    local colliderX = self.x + 1
    local colliderY = self.y + 16
    local colliderWidth = self.width - 2
    local colliderHeight = 12

    return not (
        target.x > colliderX + colliderWidth or
        colliderX > target.x + target.width or
        target.y > colliderY + colliderHeight or
        colliderY > target.y + target.height
    )
end

function Spring:render()
    local frame = self.hit and self.animation:getCurrentFrame() or 3
    local quad = gFrames[self.texture][frame]
    if quad then
        love.graphics.draw(gTextures[self.texture], quad, self.x, self.y)
    end
end
