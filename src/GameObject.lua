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
    if self.texture == 'gems' then
        -- Draw gem
        if gFrames['gems'] and gFrames['gems'][self.frame] then
            love.graphics.draw(gTextures['gems'], gFrames['gems'][self.frame], self.x, self.y)
        else
            love.graphics.setColor(1, 0.84, 0, 1)
            love.graphics.circle('fill', self.x + self.width/2, self.y + self.height/2, 5)
            love.graphics.setColor(1, 1, 1, 1)
        end
    else
        local quad = gFrames[self.texture] and gFrames[self.texture][self.frame]
        if quad then
            if self.isBarrel then
                -- Scale the 14x14 sprite by 0.5 to match the 7x7 hitbox
                love.graphics.draw(gTextures[self.texture], quad, self.x, self.y, 0, 0.5, 0.5)
            else
                love.graphics.draw(gTextures[self.texture], quad, self.x, self.y)
            end
        end
    end
end