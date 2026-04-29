Play = {}

local LEVELS = {
    {
        name = 'Forest Gate',
        theme = 'forest',
        playerStart = {x = 28, y = VIRTUAL_HEIGHT - 44},
        playerVisualGroundY = 164,
        enemies = {{x = 205, y = VIRTUAL_HEIGHT - 42}},
        boss = {x = 530, y = VIRTUAL_HEIGHT - 14}
    },
    {
        name = 'Night Cave',
        theme = 'cave',
        playerStart = {x = 28, y = 134},
        playerVisualGroundY = 169,
        enemies = {{x = 155, y = 138}, {x = 315, y = 138}},
        boss = {x = 530, y = 166}
    }
}

local function overlaps(a, b)
    return a.x < b.x + b.width and
        b.x < a.x + a.width and
        a.y < b.y + b.height and
        b.y < a.y + a.height
end

local function rectFor(object)
    return {x = object.x, y = object.y, width = object.width, height = object.height}
end

function Play:enter(levelIndex, score)
    self.currentLevel = levelIndex or 1
    self:initLevel()
    self.player.score = score or 0

    if gSounds and gSounds.bgMusic and not gSounds.bgMusic:isPlaying() then
        gSounds.bgMusic:setLooping(true)
        gSounds.bgMusic:play()
    end
end

function Play:initLevel()
    self.level = LEVELS[self.currentLevel]
    self.bullets = {}
    self.enemyBullets = {}
    self.impacts = {}
    self.levelClearTimer = 0
    self.levelExitStarted = false
    self.levelExitDelay = 0
    self.levelIntroStarted = self.currentLevel > 1
    self.levelIntroTargetX = self.level.playerStart.x
    self.cameraX = 0

    self.player = Player.create(self.level.playerStart.x, self.level.playerStart.y)
    if self.levelIntroStarted then
        self.player.x = -self.player.width - 4
    end
    self.player.worldWidth = WORLD_WIDTH
    self.player.visualGroundY = self.level.playerVisualGroundY
    self.player.score = self.player.score or 0

    self.enemies = {}
    for _, enemyData in ipairs(self.level.enemies) do
        local enemyType = self.currentLevel == 2 and 'huntress' or 'worm'
        table.insert(self.enemies, Enemy.create(enemyData.x, enemyData.y, enemyType))
    end

    self.boss = Boss.create(self.level.boss.x, self.level.boss.y, self.currentLevel)
    if self.currentLevel == 2 then
        self.boss.maxHealth = 16
        self.boss.health = 16
        self.boss.fireRate = 2.2
    end
end

function Play:keypressed(key)
    if self.levelExitStarted or self.levelIntroStarted then
        return
    end

    if key == 'p' then
        Gamestate.switch(Pause, self)
    elseif key == 'escape' then
        Gamestate.switch(Menu)
    elseif key == 'space' then
        self:firePlayerBullet()
    elseif key == 'up' or key == 'w' then
        self.player:jump()
    elseif key == 'down' or key == 's' then
        self.player:crouch()
    end
end

function Play:firePlayerBullet()
    self.player:startAttack()
end

function Play:update(dt)
    if self.levelIntroStarted then
        self:updateLevelIntro(dt)
        return
    end

    if self.levelExitStarted then
        self:updateLevelExit(dt)
        return
    end

    self.player:update(dt)
    self:releasePlayerAttack()
    self.cameraX = math.max(0, math.min(WORLD_WIDTH - VIRTUAL_WIDTH, self.player.x - 90))

    self:updateBullets(dt)
    self:updateImpacts(dt)
    self:updateEnemies(dt)
    if self.boss.health > 0 or self.boss.dead then
        self.boss:update(dt, self.player, self.enemyBullets, self.cameraX)
    end
    self:handleCombatCollisions()

    if self.boss.health <= 0 and self.boss.corpse then
        self.levelClearTimer = self.levelClearTimer + dt
        if self.levelClearTimer > 0.35 then
            self:startLevelExit()
        end
    end
end

function Play:updateLevelIntro(dt)
    local introSpeed = 72
    self.player.facing = 1
    self.player.x = math.min(self.levelIntroTargetX, self.player.x + introSpeed * dt)
    self.player.vy = self.player.vy + 540 * dt
    self.player.y = self.player.y + self.player.vy * dt
    if self.player.y >= self.player.groundY then
        self.player.y = self.player.groundY
        self.player.vy = 0
    end
    self.player.isCrouching = false
    self.player.isCatCasting = false
    self.player.currentHitboxHeight = self.player.height
    self.player.currentAnimation = 'run'
    self.player.animationTimer = self.player.animationTimer + dt
    self.cameraX = 0

    if self.player.x >= self.levelIntroTargetX then
        self.player.x = self.levelIntroTargetX
        self.player.currentAnimation = 'idle'
        self.player.animationTimer = 0
        self.levelIntroStarted = false
    end
end

function Play:startLevelExit()
    self.levelExitStarted = true
    self.levelExitDelay = 0
    self.bullets = {}
    self.enemyBullets = {}
    self.player.isCrouching = false
    self.player.isCatCasting = false
    self.player.currentHitboxHeight = self.player.height
    self.player.facing = 1
    self.player.currentAnimation = 'run'
    self.player.animationTimer = 0
end

function Play:updateLevelExit(dt)
    local exitSpeed = 92
    self.player.facing = 1
    self.player.x = self.player.x + exitSpeed * dt
    self.player.vy = self.player.vy + 540 * dt
    self.player.y = self.player.y + self.player.vy * dt
    if self.player.y >= self.player.groundY then
        self.player.y = self.player.groundY
        self.player.vy = 0
    end
    self.player.currentAnimation = 'run'
    self.player.animationTimer = self.player.animationTimer + dt
    self.cameraX = math.max(0, math.min(WORLD_WIDTH - VIRTUAL_WIDTH, self.player.x - 90))

    if self.player.x > self.cameraX + VIRTUAL_WIDTH + self.player.width then
        self.levelExitDelay = self.levelExitDelay + dt
        if self.levelExitDelay >= 1 then
            self:finishLevel()
        end
    end
end

function Play:releasePlayerAttack()
    local dir = self.player:consumeReleasedAttack()
    if not dir then
        return
    end

    local origin = self.player:getCastOrigin(dir)
    local isCat = self.player.isCatCasting
    local damage = isCat and 1 or 2
    local offset = isCat and 3 or 6
    table.insert(self.bullets, Bullet.create(origin.x - offset, origin.y - offset, dir, 'player', 0, damage, isCat))
    playSound('playerFireball')
end

function Play:updateBullets(dt)
    for i = #self.bullets, 1, -1 do
        local bullet = self.bullets[i]
        bullet:update(dt)
        if bullet.dead then
            table.remove(self.bullets, i)
        end
    end

    for i = #self.enemyBullets, 1, -1 do
        local bullet = self.enemyBullets[i]
        bullet:update(dt)
        if bullet.dead then
            table.remove(self.enemyBullets, i)
        end
    end
end

function Play:updateImpacts(dt)
    for i = #self.impacts, 1, -1 do
        local impact = self.impacts[i]
        impact.timer = impact.timer + dt
        if impact.timer >= impact.duration then
            table.remove(self.impacts, i)
        end
    end
end

function Play:addImpact(x, y, visualType, owner, isCat)
    local animation = self:getImpactAnimation(visualType, owner)
    if not animation then
        return
    end

    local scale = owner == 'enemy' and 0.48 or (isCat and 0.525 or 0.54)
    table.insert(self.impacts, {
        x = x,
        y = y,
        animation = animation,
        scale = scale,
        timer = 0,
        duration = #animation.quads * animation.frameDuration
    })
end

function Play:getImpactAnimation(visualType, owner)
    if owner == 'player' and gSprites and gSprites.projectile then
        return gSprites.projectile.explode
    end

    if not (gSprites and gSprites.enemies) then
        return nil
    end

    if visualType == 'fireball' and gSprites.enemies.fireball then
        return gSprites.enemies.fireball.explode
    elseif visualType == 'darkball' and gSprites.enemies.darkball then
        return gSprites.enemies.darkball.explode
    end

    return nil
end

function Play:updateEnemies(dt)
    for i = #self.enemies, 1, -1 do
        local enemy = self.enemies[i]
        enemy:update(dt, self.player, self.enemyBullets)
        if enemy.remove then
            table.remove(self.enemies, i)
        end
    end
end

function Play:handleCombatCollisions()
    local playerHitbox = self.player:getHitbox()

    for i = #self.bullets, 1, -1 do
        local bullet = self.bullets[i]
        local bulletRect = rectFor(bullet)

        for _, enemy in ipairs(self.enemies) do
            local enemyRect = rectFor(enemy)
            if not enemy.dead and overlaps(bulletRect, enemyRect) then
                bullet.dead = true
                self:addImpact(enemyRect.x + enemyRect.width / 2, enemyRect.y + enemyRect.height / 2, bullet.visualType, bullet.owner, bullet.isCat)
                if enemy:takeDamage(bullet.damage) then
                    self.player.score = self.player.score + 100
                end
                break
            end
        end

        local bossRect = rectFor(self.boss)
        if not bullet.dead and self.boss.health > 0 and self.boss:isDamageable() and overlaps(bulletRect, bossRect) then
            bullet.dead = true
            self:addImpact(bossRect.x + bossRect.width / 2, bossRect.y + bossRect.height / 2, bullet.visualType, bullet.owner, bullet.isCat)
            if self.boss:takeDamage(bullet.damage) then
                self.player.score = self.player.score + 500
            else
                self.player.score = self.player.score + 25
            end
        end
    end

    for i = #self.enemyBullets, 1, -1 do
        local bullet = self.enemyBullets[i]
        if overlaps(rectFor(bullet), playerHitbox) then
            bullet.dead = true
            self:addImpact(playerHitbox.x + playerHitbox.width / 2, playerHitbox.y + playerHitbox.height / 2, bullet.visualType, bullet.owner, bullet.isCat)
            self:damagePlayer()
        end
    end

    for _, enemy in ipairs(self.enemies) do
        if not enemy.dead and overlaps(rectFor(enemy), playerHitbox) then
            self:damagePlayer()
        end
    end

    if self.boss.health > 0 then
        local bossMeleeHitbox = self.boss:getMeleeHitbox()
        if bossMeleeHitbox and overlaps(bossMeleeHitbox, playerHitbox) then
            self.boss:markMeleeHit()
            self:damagePlayer()
        elseif self.currentLevel ~= 2 and not self.boss:isEscaping() and overlaps(rectFor(self.boss), playerHitbox) then
            self:damagePlayer()
        end
    end
end

function Play:damagePlayer()
    if self.player:takeDamage() then
        self:saveFinalScore()
        Gamestate.switch(GameOver, self.player.score)
    end
end

function Play:finishLevel()
    if self.currentLevel < #LEVELS then
        Gamestate.switch(Play, self.currentLevel + 1, self.player.score + 250)
    else
        self:saveFinalScore()
        Gamestate.switch(Win, self.player.score)
    end
end

function Play:saveFinalScore()
    local scores = HighScore.loadScores()
    table.insert(scores, self.player.score)
    table.sort(scores, function(a, b) return a > b end)
    while #scores > 3 do
        table.remove(scores)
    end
    HighScore.saveScores(scores)
end

function Play:draw()
    self:drawBackground()

    love.graphics.push()
    love.graphics.translate(-self.cameraX, 0)

    for _, enemy in ipairs(self.enemies) do
        enemy:draw()
    end

    if self.boss.health > 0 or self.boss.dead then
        self.boss:draw()
    end

    self.player:draw()

    for _, bullet in ipairs(self.bullets) do
        bullet:draw()
    end

    for _, bullet in ipairs(self.enemyBullets) do
        bullet:draw()
    end

    for _, impact in ipairs(self.impacts) do
        self:drawImpact(impact)
    end

    love.graphics.pop()

    self:drawForeground()

    self:drawHUD()
end

function Play:drawImpact(impact)
    local animation = impact.animation
    local frame = math.min(#animation.quads, math.floor(impact.timer / animation.frameDuration) + 1)

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(
        animation.image,
        animation.quads[frame],
        impact.x,
        impact.y,
        0,
        impact.scale,
        impact.scale,
        animation.frameWidth / 2,
        animation.frameHeight / 2
    )
    love.graphics.setColor(1, 1, 1)
end

function Play:drawBackground()
    if self.level.theme == 'forest' and gBackgrounds and gBackgrounds.level1 and #gBackgrounds.level1 > 0 then
        self:drawImageBackground(gBackgrounds.level1, {0.33, 0.41, 0.50}, 1, #gBackgrounds.level1 - 1)
        return
    end

    if self.level.theme == 'cave' and gBackgrounds and gBackgrounds.level2 and #gBackgrounds.level2 > 0 then
        self:drawImageBackground(gBackgrounds.level2, {0.95, 0.95, 0.84}, 1, #gBackgrounds.level2 - 1)
        return
    end

    local layer1 = -(self.cameraX * 0.08) % VIRTUAL_WIDTH
    local layer2 = -(self.cameraX * 0.18) % VIRTUAL_WIDTH
    local layer3 = -(self.cameraX * 0.35) % VIRTUAL_WIDTH

    if self.level.theme == 'forest' then
        love.graphics.clear(0.45, 0.72, 0.95)
        love.graphics.setColor(0.35, 0.55, 0.45)
        for i = -1, 1 do
            love.graphics.rectangle('fill', layer1 + i * VIRTUAL_WIDTH, 80, VIRTUAL_WIDTH, 36)
        end
        love.graphics.setColor(0.12, 0.42, 0.2)
        for i = -1, 1 do
            love.graphics.rectangle('fill', layer2 + i * VIRTUAL_WIDTH, 112, VIRTUAL_WIDTH, 30)
        end
        love.graphics.setColor(0.18, 0.3, 0.16)
        for i = -1, 1 do
            love.graphics.rectangle('fill', layer3 + i * VIRTUAL_WIDTH, 142, VIRTUAL_WIDTH, 38)
        end
    else
        love.graphics.clear(0.04, 0.04, 0.08)
        love.graphics.setColor(0.12, 0.12, 0.2)
        for i = -1, 1 do
            love.graphics.rectangle('fill', layer1 + i * VIRTUAL_WIDTH, 68, VIRTUAL_WIDTH, 48)
        end
        love.graphics.setColor(0.22, 0.16, 0.2)
        for i = -1, 1 do
            love.graphics.rectangle('fill', layer2 + i * VIRTUAL_WIDTH, 116, VIRTUAL_WIDTH, 28)
        end
        love.graphics.setColor(0.38, 0.08, 0.03)
        for i = -1, 1 do
            love.graphics.rectangle('fill', layer3 + i * VIRTUAL_WIDTH, 144, VIRTUAL_WIDTH, 36)
        end
    end
end

function Play:drawForeground()
    if self.level.theme == 'forest' and gBackgrounds and gBackgrounds.level1 and #gBackgrounds.level1 > 0 then
        self:drawImageBackground(gBackgrounds.level1, nil, #gBackgrounds.level1, #gBackgrounds.level1)
        return
    end

    if self.level.theme == 'cave' and gBackgrounds and gBackgrounds.level2 and #gBackgrounds.level2 > 0 then
        self:drawImageBackground(gBackgrounds.level2, nil, #gBackgrounds.level2, #gBackgrounds.level2)
        return
    end
end

function Play:drawImageBackground(layers, bgColor, startIndex, endIndex)
    if bgColor then
        love.graphics.clear(bgColor[1], bgColor[2], bgColor[3])
    end
    love.graphics.setColor(1, 1, 1)

    startIndex = startIndex or 1
    endIndex = endIndex or #layers

    for index = startIndex, endIndex do
        local image = layers[index]
        local scale = VIRTUAL_HEIGHT / image:getHeight()
        local width = image:getWidth() * scale

        local speed = 0.02 + (index - 1) * 0.025
        if index >= #layers - 1 then
            speed = 1
        end
        local offset = -(self.cameraX * speed) % width

        for x = offset - width, VIRTUAL_WIDTH + width, width do
            love.graphics.draw(image, x, 0, 0, scale, scale)
        end
    end
end

function Play:drawHUD()
    local sx = push._scaleX
    local sy = push._scaleY

    love.graphics.push()
    love.graphics.origin()

    love.graphics.setFont(gHudFonts.small)

    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle('fill', 0, 0, VIRTUAL_WIDTH * sx, 22 * sy)

    love.graphics.setColor(0.8, 0.1, 0.1)
    love.graphics.rectangle('fill', 8 * sx, 7 * sy, 50 * sx, 6 * sy)
    love.graphics.setColor(0.1, 0.9, 0.25)
    love.graphics.rectangle('fill', 8 * sx, 7 * sy, 10 * self.player.healthLevel * sx, 6 * sy)

    love.graphics.setColor(1, 1, 1)
    love.graphics.print('Lives: ' .. self.player.lives, 66 * sx, 5 * sy)
    love.graphics.print('Score: ' .. self.player.score, 120 * sx, 5 * sy)
    love.graphics.print('Level ' .. self.currentLevel .. ': ' .. self.level.name, 210 * sx, 5 * sy)

    if self.boss.health > 0 then
        love.graphics.setColor(0.25, 0.25, 0.25)
        love.graphics.rectangle('fill', 204 * sx, 20 * sy, 108 * sx, 5 * sy)
        love.graphics.setColor(1, 0.2, 0.25)
        love.graphics.rectangle('fill', 204 * sx, 20 * sy, 108 * (self.boss.health / self.boss.maxHealth) * sx, 5 * sy)
    end
    love.graphics.setColor(1, 1, 1)

    love.graphics.pop()
end
