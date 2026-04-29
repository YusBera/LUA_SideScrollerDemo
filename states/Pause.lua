Pause = {}

function Pause:enter(playState)
    self.playState = playState
end

function Pause:keypressed(key)
    if key == 'p' or key == 'escape' then
        Gamestate.currentState = self.playState
    end
end

function Pause:update(dt)
    -- keep the gameplay state frozen while paused
end

function Pause:draw()
    if self.playState and self.playState.draw then
        self.playState:draw()
    end

    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle('fill', 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(gFonts.large)
    love.graphics.printf('PAUSED', 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
end
