HighScore = {}

local HIGH_SCORE_FILE = 'highscores.txt'

function HighScore:enter()
    self.scores = self.loadScores()
end

function HighScore:keypressed(key)
    if key == 'escape' or key == 'return' or key == 'enter' then
        Gamestate.switch(Menu)
    end
end

function HighScore:draw()
    love.graphics.clear(0.05, 0.05, 0.1)

    love.graphics.push()
    love.graphics.origin()
    local sx = push._scaleX
    local sy = push._scaleY

    love.graphics.setFont(gHudFonts.large)
    love.graphics.printf('High Scores', 0, 20 * sy, VIRTUAL_WIDTH * sx, 'center')

    love.graphics.setFont(gHudFonts.medium)
    for i = 1, 3 do
        local score = self.scores[i] or 0
        love.graphics.printf(i .. '. ' .. score, 0, (70 + i * 22) * sy, VIRTUAL_WIDTH * sx, 'center')
    end

    love.graphics.setFont(gHudFonts.small)
    love.graphics.printf('Press Enter or Escape to return', 0, (VIRTUAL_HEIGHT - 24) * sy, VIRTUAL_WIDTH * sx, 'center')

    love.graphics.pop()
end

function HighScore.loadScores()
    local scores = {}
    if love.filesystem.getInfo(HIGH_SCORE_FILE) then
        for line in love.filesystem.lines(HIGH_SCORE_FILE) do
            local score = tonumber(line)
            if score then
                table.insert(scores, score)
            end
        end
    end
    table.sort(scores, function(a, b) return a > b end)
    while #scores < 3 do
        table.insert(scores, 0)
    end
    while #scores > 3 do
        table.remove(scores)
    end
    return scores
end

function HighScore.saveScores(scores)
    table.sort(scores, function(a, b) return a > b end)
    local data = ''
    for i = 1, math.min(3, #scores) do
        local score = scores[i] or 0
        data = data .. tostring(score) .. '\n'
    end
    love.filesystem.write(HIGH_SCORE_FILE, data)
end

return HighScore
