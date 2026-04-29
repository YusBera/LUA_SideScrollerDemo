Menu = {}

function Menu:enter()
    self.selection = 1
    self.options = {'Start', 'High Scores', 'Quit'}
    self.scores = HighScore.loadScores()
    self.pulseTimer = 0
end

function Menu:update(dt)
    self.pulseTimer = self.pulseTimer + dt
end

function Menu:keypressed(key)
    if key == 'up' or key == 'w' then
        self.selection = math.max(1, self.selection - 1)
    elseif key == 'down' or key == 's' then
        self.selection = math.min(#self.options, self.selection + 1)
    elseif key == 'return' or key == 'enter' then
        if self.selection == 1 then
            Gamestate.switch(Play)
        elseif self.selection == 2 then
            Gamestate.switch(HighScore)
        elseif self.selection == 3 then
            love.event.quit()
        end
    end
end

function Menu:draw()
    love.graphics.clear(0.05, 0.05, 0.1)

    love.graphics.push()
    love.graphics.origin()
    local sx = push._scaleX
    local sy = push._scaleY

    love.graphics.setFont(gHudFonts.large)
    love.graphics.printf('The Dimensional Traveler', 0, 20 * sy, VIRTUAL_WIDTH * sx, 'center')

    love.graphics.setFont(gHudFonts.medium)
    for i, option in ipairs(self.options) do
        local y = 90 + (i - 1) * 20
        if i == self.selection then
            local pulse = 0.75 + math.sin(self.pulseTimer * 8) * 0.2
            love.graphics.setColor(pulse, 0.9, 0.35)
        else
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.printf(option, 0, y * sy, VIRTUAL_WIDTH * sx, 'center')
    end

    love.graphics.setFont(gHudFonts.small)
    love.graphics.setColor(0.8, 0.85, 1)
    love.graphics.printf('Top Scores', 0, 146 * sy, VIRTUAL_WIDTH * sx, 'center')
    for i = 1, 3 do
        love.graphics.printf(i .. '. ' .. tostring(self.scores[i] or 0), 0, (156 + (i - 1) * 8) * sy, VIRTUAL_WIDTH * sx, 'center')
    end
    love.graphics.setColor(1, 1, 1)

    love.graphics.pop()
end
