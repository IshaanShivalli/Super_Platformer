Fireball = Class{__includes = GameObject}

function Fireball:init(def)
    GameObject.init(self, def)
    self.texture = def.texture or 'fireball'

    if self.texture == 'fire-projectile' then
        self.width = 12
        self.height = 12
    else
        self.width = FIREBALL_WIDTH
        self.height = FIREBALL_HEIGHT
    end

    self.frame = 1
    self.collidable = true
    self.solid = false -- Fireballs don't block Mario
    self.dx = def.dx
    self.dy = def.dy
    self.gravity = 500 -- Fireballs have gravity
    self.bounceVelocity = -100 -- How high it bounces
    self.level = def.level
    self.player = def.player -- Reference to player for direction (for rendering flip)
    self.dead = false -- Mark for removal
    self.lifetime = 3 -- Fireball lasts for 3 seconds

    local frames = {1, 2, 3, 4}
    if self.texture == 'fire-projectile' then
        -- Row 1 is right (index 1), Row 2 is left (index 2 assuming 1 col)
        frames = self.dx > 0 and {1} or {2}
    end

    self.animation = Animation {
        frames = frames,
        interval = 0.1
    }
end

function Fireball:update(dt)
    self.animation:update(dt)
    self.lifetime = self.lifetime - dt

    local prevY = self.y
    self.dy = self.dy + self.gravity * dt
    self.x = self.x + self.dx * dt
    self.y = self.y + self.dy * dt

    -- Collision with floor tiles
    local tileBottomLeft = self.level.tileMap:pointToTile(self.x + 1, self.y + self.height)
    local tileBottomRight = self.level.tileMap:pointToTile(self.x + self.width - 1, self.y + self.height)

    if (tileBottomLeft and tileBottomLeft:collidable()) or (tileBottomRight and tileBottomRight:collidable()) then
        self.dy = self.bounceVelocity
        self.y = (tileBottomLeft and tileBottomLeft.y or tileBottomRight.y) * TILE_SIZE - self.height - TILE_SIZE
        gSounds['fireball-bounce']:play()
    end

    -- Collision with solid GameObjects (platforms, pipes)
    for _, object in pairs(self.level.objects) do
        if object.solid and object:collides(self) then
            -- Vertical bounce: Check if falling and if we were above the object top in the last frame
            if self.dy > 0 and (prevY + self.height) <= (object.y + 5) then
                self.dy = self.bounceVelocity
                self.y = object.y - self.height
                gSounds['fireball-bounce']:play()
            -- Horizontal bounce: Specifically for bricks/underground bricks
            elseif object.texture == 'bricks' or object.texture == 'underground-bricks' then
                local wasMovingRight = self.dx > 0
                self.dx = -self.dx
                
                -- Snap X position out of the brick to prevent getting stuck
                if wasMovingRight then
                    self.x = object.x - self.width
                else
                    self.x = object.x + object.width
                end
                gSounds['fireball-bounce']:play()
            -- If hitting from side or bottom, mark for removal
            else
                self.dead = true
                return
            end
        end
    end
end

function Fireball:render()
    local quad = gFrames[self.texture][self.animation:getCurrentFrame()]

    local scaleX = self.player.direction == 'right' and 1 or -1
    if self.texture == 'fire-projectile' then
        scaleX = 1 -- Sprite sheet handles direction via frames
    end

    if quad then
        love.graphics.draw(gTextures[self.texture], quad,
            math.floor(self.x) + self.width / 2,
            math.floor(self.y) + self.height / 2,
            0, scaleX, 1,
            self.width / 2, self.height / 2)
    end
end