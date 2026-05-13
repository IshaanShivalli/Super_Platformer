Player = Class{__includes = Entity}

function Player:init(def)
    Entity.init(self, def)
    self.score = def.score or 0
end

function Player:update(dt)
    Entity.update(self, dt)

    for i = #self.level.objects, 1, -1 do
        local object = self.level.objects[i]
        if object.consumable and self:collides(object) then
            object.onConsume(self, object)
            table.remove(self.level.objects, i)
        end
    end
end

function Player:render()
    Entity.render(self)
end

function Player:checkLeftCollisions(dt)
    local tileTopLeft = self.map:pointToTile(self.x + 1, self.y + 1)
    local tileBottomLeft = self.map:pointToTile(self.x + 1, self.y + self.height - 1)

    if (tileTopLeft and tileBottomLeft) and (tileTopLeft:collidable() or tileBottomLeft:collidable()) then
        self.x = (tileTopLeft.x - 1) * TILE_SIZE + tileTopLeft.width - 1
    else
        self.y = self.y - 1
        local collidedObjects = self:checkObjectCollisions(false)
        self.y = self.y + 1

        if #collidedObjects > 0 then
            self.x = self.x + PLAYER_WALK_SPEED * dt
        end
    end
end

function Player:checkRightCollisions(dt)
    local tileTopRight = self.map:pointToTile(self.x + self.width - 1, self.y + 1)
    local tileBottomRight = self.map:pointToTile(self.x + self.width - 1, self.y + self.height - 1)

    if (tileTopRight and tileBottomRight) and (tileTopRight:collidable() or tileBottomRight:collidable()) then
        self.x = (tileTopRight.x - 1) * TILE_SIZE - self.width
    else
        self.y = self.y - 1
        local collidedObjects = self:checkObjectCollisions(false)
        self.y = self.y + 1

        if #collidedObjects > 0 then
            self.x = self.x - PLAYER_WALK_SPEED * dt
        end
    end
end

function Player:checkPipeCollisions(dt)
    for k, object in pairs(self.level.objects) do
        local isSidePipeStart = object.texture == 'side-pipe-start'
        local isSidePipeEnd   = object.texture == 'side-pipe-end'
        local isSidePipe      = isSidePipeStart or isSidePipeEnd
        local isPipe          = object.texture == 'pipes' or isSidePipe

        if isPipe and object.collidable and object:collides(self) then
            if object.checkPlantCollision and object:checkPlantCollision(self) then
                gSounds['death']:play()
                gStateMachine:change('start')
                return true
            end

            local pRight  = (self.x + self.width) - object.x
            local pLeft   = (object.x + object.width) - self.x
            local pBottom = (self.y + self.height) - object.y
            local pTop    = (object.y + object.height) - self.y

            local minP
            if pBottom >= 0 and pBottom < 8 and self.dy >= 0 then
                minP = pBottom
            else
                minP = math.min(pRight, pLeft, pBottom, pTop)
            end

            -- Check if Mario is vertically inside the pipe opening
            local playerVerticallyAligned = self.y >= object.y and
                                            self.y + self.height <= object.y + object.height + 4

            if isSidePipe and playerVerticallyAligned then
                if isSidePipeStart then
                    -- Opening is on the RIGHT side of start pipe
                    -- Mario enters from the right → pLeft is entry (allow)
                    -- pRight is the back wall (block)
                    if minP == pRight then
                        -- Back wall: block
                        self.x = object.x - self.width
                        return true
                    end
                    -- Entry from right side: allow
                    return false

                elseif isSidePipeEnd then
                    -- Opening is on the LEFT side of end pipe
                    -- Mario enters from the left → pRight is entry (allow)
                    -- pLeft is the back wall (block)
                    if minP == pLeft then
                        -- Back wall: block
                        self.x = object.x + object.width - self.width
                        return true
                    end
                    -- Entry from left side: allow
                    return false
                end
            end

            -- Standard pipe collision resolution
            if minP == pBottom then
                self.y = object.y - self.height

                if self.dy > 0 then
                    self.dy = 0
                    local isMoving = love.keyboard.isDown('left') or love.keyboard.isDown('right')
                    if isMoving then
                        if self.stateMachine.current.name ~= 'walking' then self:changeState('walking') end
                    else
                        if self.stateMachine.current.name ~= 'idle' then self:changeState('idle') end
                    end
                    return true
                elseif self.dy == 0 then
                    self.dy = 0
                end
                return false

            elseif minP == pTop then
                if not isSidePipe then
                    self.y = object.y + object.height
                    self.dy = 0
                    return true
                end

            elseif minP == pRight then
                local isVerticalOpening = object.texture == 'pipes' and
                    (self.y + self.height >= object.y - 1 and self.y < object.y + TILE_SIZE)

                if not isSidePipe and not isVerticalOpening then
                    self.x = object.x - self.width
                    return true
                end

            elseif minP == pLeft then
                local isVerticalOpening = object.texture == 'pipes' and
                    (self.y + self.height >= object.y - 1 and self.y < object.y + TILE_SIZE)

                if not isSidePipe and not isVerticalOpening then
                    self.x = object.x + object.width - self.width
                    return true
                end
            end
        end
    end
    return false
end

function Player:checkObjectCollisions(isFloorCheck)
    local collidedObjects = {}

    for k, object in pairs(self.level.objects) do
        if object:collides(self) then
            if object.solid then
                -- Skip physics blocking for victory objects so we don't break the loop
                if not (object.isFlagPole or object.isCastle) then
                    local isSidePipe = object.isExit or object.texture == 'side-pipe-start'

                    if isSidePipe then
                        if isFloorCheck then
                            table.insert(collidedObjects, object)
                        end
                    elseif object.texture == 'pipes' then
                        local onTop = (self.y + self.height) >= object.y - 1 and
                                      (self.y + self.height) <= object.y + 2

                        if isFloorCheck then
                            if onTop then table.insert(collidedObjects, object) end
                        elseif onTop then
                            -- on top during wall check: don't block
                        else
                            local pipeOpeningTop    = object.y
                            local pipeOpeningBottom = object.y + TILE_SIZE
                            if not (self.y + self.height >= pipeOpeningTop - 1 and self.y < pipeOpeningBottom) then
                                table.insert(collidedObjects, object)
                            end
                        end
                    else
                        table.insert(collidedObjects, object)
                    end
                end
            end
        end
    end

    return collidedObjects
end