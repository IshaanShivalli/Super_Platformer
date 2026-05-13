Animation = Class{}

function Animation:init(def)
    self.frames = def.frames
    self.interval = def.interval
    self.timer = 0
    self.currentFrame = 1
end

function Animation:update(dt)
    self.timer = self.timer + dt

    if self.timer > self.interval then
        self.timer = self.timer % self.interval
        self.currentFrame = math.max(1, (self.currentFrame + 1) % (#self.frames + 1))
        if not self.looping and self.currentFrame == 1 then self.currentFrame = #self.frames end -- Stop at last frame if not looping
    end
end

function Animation:getCurrentFrame()
    return self.frames[self.currentFrame]
end

function Animation:refresh()
    self.timer = 0
    self.currentFrame = 1
end