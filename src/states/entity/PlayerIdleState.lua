

PlayerIdleState = Class{__includes = BaseState}

function PlayerIdleState:init(player)
    self.player = player
    self.name = 'idle'
    self.animation = Animation {
        frames = {1},
        interval = 1
    }
end

function PlayerIdleState:enter(params)
end

function PlayerIdleState:update(dt)
    if self.player.controlLock then return end

    if love.keyboard.isDown('left') or love.keyboard.isDown('right') then
        self.player:changeState('walking')
    end

    -- Handle jump input with key press tracking
    local jumpKeyDown = love.keyboard.isDown('space') or love.keyboard.isDown('up')
    
    if jumpKeyDown and not self.player.jumpKeyPressed then
        -- Jump key just pressed
        if self.player:canPerformOverworldJump() then
            self.player.jumpKeyPressed = true
            self.player:changeState('jump')
        end
    elseif not jumpKeyDown then
        -- Jump key released
        self.player.jumpKeyPressed = false
    end
end

function PlayerIdleState:render()
end