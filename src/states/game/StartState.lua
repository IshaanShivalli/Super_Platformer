StartState = Class{__includes = BaseState}

function StartState:init()
    if love.filesystem.getInfo('lvls') then
        local content, size = love.filesystem.read('lvls')
        self.savedLevel = tonumber(string.match(content, '^(%d+)')) or 1
    else
        self.savedLevel = 1
    end

    self.map = LevelMaker.generate(100, 10, self.savedLevel)
    self.background = math.random(3)
end

function StartState:update(dt)
    if love.keyboard.wasPressed('enter') or love.keyboard.wasPressed('return') then
        gStateMachine:change('play', {
            levelNum = self.savedLevel,
            score = 0,
            lives = 3,
            powerupState = PLAYER_STATE_SMALL
        })
    end
end

function StartState:render()
    if self.savedLevel < 10 then
        love.graphics.draw(gTextures['backgrounds'], gFrames['backgrounds'][self.background], 0, 0)
        love.graphics.draw(gTextures['backgrounds'], gFrames['backgrounds'][self.background], 0,
            VIRTUAL_HEIGHT, 0, 1, -1)
    elseif self.savedLevel >= 21 then
        for bgX = 0, VIRTUAL_WIDTH, 16 do
            love.graphics.draw(gTextures['underwater-topper'], gFrames['underwater-topper'][1], bgX, 0)
            for bgY = 16, VIRTUAL_HEIGHT, 16 do
                love.graphics.draw(gTextures['underwater-bg'], gFrames['underwater-bg'][1], bgX, bgY)
            end
        end
    end
    self.map:render()

    love.graphics.setFont(gFonts['title'])
    love.graphics.setColor(0, 0, 0, 255)
    love.graphics.printf('Super Mario Bros.', 1, VIRTUAL_HEIGHT / 2 - 40 + 1, VIRTUAL_WIDTH, 'center')
    love.graphics.setColor(255, 255, 255, 255)
    love.graphics.printf('Super Mario Bros.', 0, VIRTUAL_HEIGHT / 2 - 40, VIRTUAL_WIDTH, 'center')

    love.graphics.setFont(gFonts['medium'])
    love.graphics.setColor(0, 0, 0, 255)
    love.graphics.printf('Press Enter', 1, VIRTUAL_HEIGHT / 2 + 17, VIRTUAL_WIDTH, 'center')
    love.graphics.setColor(255, 255, 255, 255)
    love.graphics.printf('Press Enter', 0, VIRTUAL_HEIGHT / 2 + 16, VIRTUAL_WIDTH, 'center')
end