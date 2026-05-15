SnailChasingState = Class{__includes = BaseState}

function SnailChasingState:init(tilemap, player, snail)
    self.tilemap = tilemap
    self.player = player
    self.snail = snail
    -- Animation is now handled by the Entity:update method based on state name
    self.name = 'chasing'
end

function SnailChasingState:update(dt)
    -- Animation update is handled in Snail:update or Goomba:update

    -- Apply gravity to allow creatures to fall onto platforms
    self.snail.dy = self.snail.dy + 900 * dt
    self.snail.y = self.snail.y + self.snail.dy * dt

    -- Floor tile collision
    local tileBottomLeft = self.tilemap:pointToTile(self.snail.x + 1, self.snail.y + self.snail.height)
    local tileBottomRight = self.tilemap:pointToTile(self.snail.x + self.snail.width - 1, self.snail.y + self.snail.height)

    if (tileBottomLeft and tileBottomLeft:collidable()) or (tileBottomRight and tileBottomRight:collidable()) then
        self.snail.dy = 0
        self.snail.y = (tileBottomLeft and tileBottomLeft.y or tileBottomRight.y) * TILE_SIZE - self.snail.height - TILE_SIZE
    end

    -- Vertical collision with solid GameObjects (Platforms)
    if self.snail.level and self.snail.level.objects then
        for _, object in pairs(self.snail.level.objects) do
            if object.solid and self.snail:collides(object) then
                if self.snail.dy >= 0 and (self.snail.y + self.snail.height) <= (object.y + 10) then
                    self.snail.dy = 0
                    self.snail.y = object.y - self.snail.height
                end
            end
        end
    end

    local diffX = math.abs(self.player.x - self.snail.x)
    local function collidesWithOtherEntity()
        if self.snail.level and self.snail.level.entities then
            for _, entity in pairs(self.snail.level.entities) do
                if entity ~= self.snail and entity:collides(self.snail) then
                    return true
                end
            end
        end

        return false
    end

    if diffX > 5 * TILE_SIZE then
        self.snail:changeState('moving')
    elseif self.player.x < self.snail.x then
        self.snail.direction = 'left'
        self.snail.x = self.snail.x - SNAIL_MOVE_SPEED * dt

        -- check for object collisions (pipes, pyramids, pillars)
        local objectCollision = false
        if self.snail.level and self.snail.level.objects then
            for _, object in pairs(self.snail.level.objects) do
                if object.solid and object:collides({
                    x = self.snail.x,
                    y = self.snail.y + 4,
                    width = self.snail.width,
                    height = self.snail.height - 8
                }) then
                    objectCollision = true
                    break
                end
            end
        end
        local entityCollision = collidesWithOtherEntity()

        -- stop the snail if there's a missing tile on the floor to the left or a solid tile directly left
        local tileLeft = self.tilemap:pointToTile(self.snail.x, self.snail.y)
        local tileBottomLeft = self.tilemap:pointToTile(self.snail.x, self.snail.y + self.snail.height)

        -- Check for solid GameObjects (bricks/platforms) under the left edge
        local groundObjectBelow = false
        for _, object in pairs(self.snail.level.objects) do
            if object.solid and self.snail.x >= object.x and self.snail.x < object.x + object.width and
               math.abs((self.snail.y + self.snail.height) - object.y) < 5 then
                groundObjectBelow = true
                break
            end
        end

        -- For underground levels, allow falling. Only reverse if hitting a solid wall or another entity/object.
        local shouldReverse = (tileLeft and tileLeft:collidable()) or objectCollision or entityCollision
        shouldReverse = shouldReverse or (not groundObjectBelow and (tileBottomLeft and not tileBottomLeft:collidable()))
        if shouldReverse then
            self.snail.x = self.snail.x + SNAIL_MOVE_SPEED * dt
        end
    else
        self.snail.direction = 'right'
        self.snail.x = self.snail.x + SNAIL_MOVE_SPEED * dt

        -- check for object collisions (pipes, pyramids, pillars)
        local objectCollision = false
        if self.snail.level and self.snail.level.objects then
            for _, object in pairs(self.snail.level.objects) do
                if object.solid and object:collides({
                    x = self.snail.x,
                    y = self.snail.y + 4,
                    width = self.snail.width,
                    height = self.snail.height - 8
                }) then
                    objectCollision = true
                    break
                end
            end
        end
        local entityCollision = collidesWithOtherEntity()

        -- stop the snail if there's a missing tile on the floor to the right or a solid tile directly right
        local tileRight = self.tilemap:pointToTile(self.snail.x + self.snail.width, self.snail.y)
        local tileBottomRight = self.tilemap:pointToTile(self.snail.x + self.snail.width, self.snail.y + self.snail.height)

        -- Check for solid GameObjects (bricks/platforms) under the right edge
        local groundObjectBelow = false
        for _, object in pairs(self.snail.level.objects) do
            if object.solid and (self.snail.x + self.snail.width) > object.x and (self.snail.x + self.snail.width) <= object.x + object.width and
               math.abs((self.snail.y + self.snail.height) - object.y) < 5 then
                groundObjectBelow = true
                break
            end
        end

        -- For underground levels, allow falling. Only reverse if hitting a solid wall or another entity/object.
        local shouldReverse = (tileRight and tileRight:collidable()) or objectCollision or entityCollision
        shouldReverse = shouldReverse or (not groundObjectBelow and (tileBottomRight and not tileBottomRight:collidable()))
        if shouldReverse then
            self.snail.x = self.snail.x - SNAIL_MOVE_SPEED * dt
        end
    end
end
