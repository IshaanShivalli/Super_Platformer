Pipe = Class{__includes = GameObject}

function Pipe:init(def)
    GameObject.init(self, def)
    self.hasPlant = def.hasPlant or false
    -- Start the plant hidden inside the pipe
    self.plantY = self.y 
    self.isCycling = false

    -- Create animation for the plant using frames 1 and 2 from plants.png
    self.animation = Animation {
        frames = {1, 2},
        interval = 0.15
    }
end

function Pipe:cyclePlant()
    self.isCycling = true
    
    -- Play the sound immediately when starting to emerge
    gSounds['plant']:play()
    
    -- Tween up over 1 second
    Timer.tween(1, {
        [self] = {plantY = self.y - 16}
    }):finish(function()
        -- Stay up for 2 seconds, then tween down over 1 second
        Timer.after(2, function()
            Timer.tween(1, {
                [self] = {plantY = self.y}
            }):finish(function()
                -- Delay before allowing the next cycle to trigger (cooldown)
                Timer.after(2, function()
                    self.isCycling = false
                end)
            end)
        end)
    end)
end

function Pipe:update(dt, player)
    if self.hasPlant then
        self.animation:update(dt)

        -- Only trigger if we aren't already moving and the player is within 6 tiles
        if not self.isCycling and player then
            local distance = math.abs(player.x - self.x)
            if distance < TILE_SIZE * 6 then
                self:cyclePlant()
            end
        end
    end
end

function Pipe:render()
    -- Draw plant first (behind/inside the pipe)
    if self.hasPlant then
        local currentFrame = self.animation:getCurrentFrame()
        if gFrames['plants'] and gFrames['plants'][currentFrame] then
            love.graphics.draw(gTextures['plants'], gFrames['plants'][currentFrame], 
                self.x + 8, -- Center the 16px plant in the 32px pipe
                self.plantY)
        end
    end

    -- Draw pipe base on top of the plant
    if gFrames['pipes'] and gFrames['pipes'][self.frame] then
        love.graphics.draw(gTextures['pipes'], gFrames['pipes'][self.frame], self.x, self.y)
    end
end

function Pipe:collides(target)
    return not (target.x > self.x + self.width or self.x > target.x + target.width or
            target.y > self.y + self.height or self.y > target.y + target.height)
end

function Pipe:checkPlantCollision(player)
    -- Only collide if the plant has emerged from the pipe
    if self.hasPlant and self.plantY < self.y - 2 then
        -- Plant hitbox is roughly 12px wide, centered
        if player.x + player.width > self.x + 10 and 
           player.x < self.x + 22 and
           player.y + player.height > self.plantY and 
           player.y < self.plantY + 16 then
            return true
        end
    end
    return false
end