Entity = Class{}

function Entity:init(def)
    self.x = def.x
    self.y = def.y

    self.dx = def.dx or 0
    self.dy = def.dy or 0

    self.width = def.width
    self.height = def.height

    self.texture = def.texture
    self.stateMachine = def.stateMachine

    self.direction = 'left'
    self.opacity = 1
    
    self.animations = def.animations

    self.map = def.map
    self.level = def.level
end

function Entity:changeState(state, params)
    self.stateMachine:change(state, params)
end

function Entity:update(dt)
    if self.stateMachine then
        self.stateMachine:update(dt)
    end
end

function Entity:collides(entity)
    return not (self.x > entity.x + entity.width or entity.x > self.x + self.width or
                self.y > entity.y + entity.height or entity.y > self.y + self.height)
end

function Entity:render()
    love.graphics.setColor(1, 1, 1, self.opacity or 1)
    -- Safety check for currentAnimation to prevent invisibility if not set
    local quad = gFrames[self.texture][self.currentAnimation and self.currentAnimation:getCurrentFrame() or 1]
    if quad then
        love.graphics.draw(gTextures[self.texture], quad,
            math.floor(self.x) + self.width / 2,
            math.floor(self.y) + self.height / 2,
            0, self.direction == 'right' and 1 or -1, 1,
            self.width / 2, self.height / 2)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Entity:renderHitbox(r, g, b, a)
    if not gShowHitboxes then
        return
    end

    love.graphics.setColor(r or 1, g or 0, b or 0, a or 1)
    love.graphics.rectangle('line', math.floor(self.x), math.floor(self.y), self.width, self.height)
    love.graphics.setColor(1, 1, 1, 1)
end
