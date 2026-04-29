Win = {}

function Win:enter(score)
    self.score = score or 0
    self.selection = 1
    self.options = {'Retry', 'Main Menu'}

    if gSounds and gSounds.bgMusic then
        gSounds.bgMusic:stop()
    end
end

function Win:keypressed(key)
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

function Win:draw()
    love.graphics.clear(0.05, 0.15, 0.1)

    love.graphics.push()
    love.graphics.origin()
    local sx = push._scaleX
    local sy = push._scaleY

    love.graphics.setFont(gHudFonts.large)
    love.graphics.printf('You Win!', 0, 32 * sy, VIRTUAL_WIDTH * sx, 'center')
    love.graphics.setFont(gHudFonts.medium)
    love.graphics.printf('Score: ' .. self.score, 0, 80 * sy, VIRTUAL_WIDTH * sx, 'center')

    for i, option in ipairs(self.options) do
        local y = 120 + i * 22
        if i == self.selection then
            love.graphics.setColor(0.6, 1, 0.6)
        else
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.printf(option, 0, y * sy, VIRTUAL_WIDTH * sx, 'center')
    end
    love.graphics.setColor(1, 1, 1)

    love.graphics.pop()
end
