GameLevel = Class{}

function GameLevel:init(entities, objects, tilemap, levelNum)
    self.entities = entities or {}
    self.objects = objects or {}
    self.tileMap = tilemap
    self.levelNum = levelNum
end

function GameLevel:clear()
    if self.objects then
        for i = #self.objects, 1, -1 do
            if not self.objects[i] then
                table.remove(self.objects, i)
            end
        end
    end

    if self.entities then
        for i = #self.entities, 1, -1 do
            if not self.entities[i] then
                table.remove(self.entities, i)
            end
        end
    end
end

function GameLevel:update(dt)
    if self.tileMap then
        self.tileMap:update(dt)
    end

    if self.objects then
        for k, object in pairs(self.objects) do
            if object and object.update then
                object:update(dt, self.player)
            end
        end
    end

    if self.entities then
        for k, entity in pairs(self.entities) do
            if entity and entity.update then
                entity:update(dt, self.player)
            end
        end
    end
end

function GameLevel:render()
    if self.tileMap then
        self.tileMap:render()
    end

    if self.objects then
        for k, object in pairs(self.objects) do
            if object and object.render then
                object:render()
            end
        end
    end

    if self.entities then
        for k, entity in pairs(self.entities) do
            if entity and entity.render then
                entity:render()
            end
        end
    end
end