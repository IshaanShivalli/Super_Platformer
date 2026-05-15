SnailMovingState = Class{__includes = BaseState}

function SnailMovingState:init(tilemap, player, snail)
    self.tilemap = tilemap
    self.player = player
    self.snail = snail
    self.name = 'moving'

    self.movingDirection = math.random(2) == 1 and 'left' or 'right'
    self.snail.direction = self.movingDirection

    self.movingDuration = math.random(5, 10) -- Walk for longer periods
    self.movingTimer = 0
    self.level = snail.level -- Store level reference from the snail entity
end

function SnailMovingState:update(dt)
    self.movingTimer = self.movingTimer + dt

    -- Apply gravity to allow creatures to fall onto platforms
    self.snail.dy = self.snail.dy + 900 * dt
    self.snail.y = self.snail.y + self.snail.dy * dt

    -- Floor tile collision
    local tileBottomLeft = self.tilemap:pointToTile(self.snail.x + 1, self.snail.y + self.snail.height)
    local tileBottomRight = self.tilemap:pointToTile(self.snail.x + self.snail.width - 1, self.snail.y + self.snail.height)

    if (tileBottomLeft and tileBottomLeft:collidable()) or (tileBottomRight and tileBottomRight:collidable()) then
        self.snail.dy = 0
        -- Improved snapping to prevent sinking into ground
        local floorY = (tileBottomLeft and tileBottomLeft.y or tileBottomRight.y)
        self.snail.y = (floorY - 1) * TILE_SIZE - self.snail.height
    end

    -- Vertical collision with solid GameObjects (Platforms)
    if self.level and self.level.objects then
        for _, object in pairs(self.level.objects) do
            if object.solid and self.snail:collides(object) then
                if self.snail.dy >= 0 and (self.snail.y + self.snail.height) <= (object.y + 12) then
                    self.snail.dy = 0
                    self.snail.y = object.y - self.snail.height
                end
            end
        end
    end

    local pipeCollision = false
    local entityCollision = false

    -- reset movement direction and timer if timer is above duration
    local dx = 0
    if self.snail.direction == 'left' then
        dx = -SNAIL_MOVE_SPEED * dt
    else
        dx = SNAIL_MOVE_SPEED * dt
    end

    if self.movingTimer > self.movingDuration then

        -- chance to go into idle state randomly
        if math.random(4) == 1 then
            self.snail:changeState('idle', {

                -- random amount of time for snail to be idle
                wait = math.random(5)
            })
        else
            self.movingDirection = math.random(2) == 1 and 'left' or 'right'
            self.snail.direction = self.movingDirection
            self.movingDuration = math.random(5)
            self.movingTimer = 0
        end
    else
        -- Predict new position
        local nextX = self.snail.x + dx

        -- Check for pipe collisions at the predicted position
        if self.level and self.level.objects then
            for _, object in pairs(self.level.objects) do
                if object.solid and 
                   object:collides({
                       x = nextX, 
                       y = self.snail.y + 4, -- Shrink collision box vertically
                       width = self.snail.width, 
                       height = self.snail.height - 8
                   }) then
                    pipeCollision = true
                    break
                end
            end
        end

        if self.level and self.level.entities then
            for _, entity in pairs(self.level.entities) do
                if entity ~= self.snail and entity:collides({
                    x = nextX,
                    y = self.snail.y,
                    width = self.snail.width,
                    height = self.snail.height
                }) then
                    entityCollision = true
                    break
                end
            end
        end

        if pipeCollision or entityCollision then
            -- Reverse direction if hit a solid obstacle or another creature
            self.movingDirection = (self.snail.direction == 'left') and 'right' or 'left'
            self.snail.direction = self.movingDirection
            self.movingDuration = math.random(5)
            self.movingTimer = 0
        else
            -- Apply movement if no pipe collision
            self.snail.x = nextX

            -- Now check for tile collisions at the new position
            if self.snail.direction == 'left' then
                local tileLeft = self.tilemap:pointToTile(self.snail.x, self.snail.y)
                local tileBottomLeft = self.tilemap:pointToTile(self.snail.x, self.snail.y + self.snail.height)

                -- Check for solid GameObjects (bricks/platforms) under the left edge
                local groundObjectBelow = false
                for _, object in pairs(self.level.objects) do
                    if object.solid and self.snail.x >= object.x and self.snail.x < object.x + object.width and
                       math.abs((self.snail.y + self.snail.height) - object.y) < 5 then
                        groundObjectBelow = true
                        break
                    end
                end

                -- For underground levels, allow falling. Only reverse if hitting a solid wall.
                local shouldReverse = (tileLeft and tileLeft:collidable()) or entityCollision
                shouldReverse = shouldReverse or (not groundObjectBelow and (tileBottomLeft and not tileBottomLeft:collidable()))
                if shouldReverse then
                    self.snail.x = self.snail.x - dx -- Revert x movement

                    -- reset direction if we hit a wall
                    self.movingDirection = 'right'
                    self.snail.direction = self.movingDirection
                    self.movingDuration = math.random(5)
                    self.movingTimer = 0
                end
            else -- self.snail.direction == 'right'
                local tileRight = self.tilemap:pointToTile(self.snail.x + self.snail.width, self.snail.y)
                local tileBottomRight = self.tilemap:pointToTile(self.snail.x + self.snail.width, self.snail.y + self.snail.height)

                -- Check for solid GameObjects (bricks/platforms) under the right edge
                local groundObjectBelow = false
                for _, object in pairs(self.level.objects) do
                    if object.solid and (self.snail.x + self.snail.width) > object.x and (self.snail.x + self.snail.width) <= object.x + object.width and
                       math.abs((self.snail.y + self.snail.height) - object.y) < 5 then
                        groundObjectBelow = true
                        break
                    end
                end

                -- For underground levels, allow falling. Only reverse if hitting a solid wall.
                local shouldReverse = (tileRight and tileRight:collidable()) or entityCollision
                shouldReverse = shouldReverse or (not groundObjectBelow and (tileBottomRight and not tileBottomRight:collidable()))
                if shouldReverse then
                    self.snail.x = self.snail.x - dx -- Revert x movement

                    -- reset direction if we hit a wall
                    self.movingDirection = 'left'
                    self.snail.direction = self.movingDirection
                    self.movingDuration = math.random(5)
                    self.movingTimer = 0
                end
            end
        end
    end

    -- calculate difference between snail and player on X axis
    -- and only chase if <= 5 tiles
    local diffX = math.abs(self.player.x - self.snail.x)

    -- Only chase if player is near AND we aren't about to walk into a pipe
    if diffX < 5 * TILE_SIZE then
        if not pipeCollision then
            self.snail:changeState('chasing')
        end
    end
end
