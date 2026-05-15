GameObject = Class{}

function GameObject:init(def)
    for k, v in pairs(def) do
        self[k] = v
    end
end

function GameObject:collides(target)
    return not (target.x > self.x + self.width or self.x > target.x + target.width or
            target.y > self.y + self.height or self.y > target.y + target.height)
end

function GameObject:update(dt)
end

function GameObject:render()
    local quad = gFrames[self.texture] and gFrames[self.texture][self.frame]
    if quad then
        if self.isBarrel then
            -- Scale the 14x14 sprite by 0.5 to match the 7x7 hitbox
            love.graphics.draw(gTextures[self.texture], quad, math.floor(self.x), math.floor(self.y), 0, 0.5, 0.5)
        else
            love.graphics.draw(gTextures[self.texture], quad, math.floor(self.x), math.floor(self.y))
        end
    end
end