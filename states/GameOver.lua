GameOver = {}

function GameOver:enter(previousScore)
    self.previousScore = previousScore or 0
    self.selection = 1
    self.options = {'Retry', 'Main Menu'}

    if gSounds and gSounds.bgMusic then
        gSounds.bgMusic:stop()
    end
end

function GameOver:update(dt)
end

function GameOver:keypressed(key)
    if key == 'up' or key == 'w' or key == 'down' or key == 's' then
        self.selection = 3 - self.selection
    elseif key == 'return' or key == 'enter' then
        if self.selection == 1 then
            Gamestate.switch(Play)
        else
            Gamestate.switch(Menu)
        end
    end
end

function GameOver:draw()
    love.graphics.clear(0.1, 0, 0)

    love.graphics.push()
    love.graphics.origin()
    local sx = push._scaleX
    local sy = push._scaleY

    love.graphics.setFont(gHudFonts.large)
    love.graphics.printf('Game Over', 0, 40 * sy, VIRTUAL_WIDTH * sx, 'center')
    love.graphics.setFont(gHudFonts.small)
    love.graphics.printf('Score: ' .. self.previousScore, 0, 90 * sy, VIRTUAL_WIDTH * sx, 'center')

    local text = self.selection == 1 and 'Retry' or 'Main Menu'
    love.graphics.printf(text, 0, 130 * sy, VIRTUAL_WIDTH * sx, 'center')

    love.graphics.pop()
end