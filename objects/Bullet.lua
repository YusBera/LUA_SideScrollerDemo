Bullet = {}
Bullet.__index = Bullet

function Bullet.create(x, y, dir, owner, dy, damage, isCat, visualType)
    local self = setmetatable({}, Bullet)
    self.x = x
    self.y = y
    self.dx = 240 * dir
    self.dy = dy or 0
    self.owner = owner or 'player'
    self.damage = damage or 1
    self.isCat = isCat or false
    self.visualType = visualType or 'fireball'

    if self.owner == 'enemy' then
        self.width = self.visualType == 'darkball' and 24 or 12
        self.height = self.visualType == 'darkball' and 24 or 12
    elseif self.owner == 'player' then
        self.width = self.isCat and 9 or 12
        self.height = self.isCat and 9 or 12
    else
        self.width = 4
        self.height = 4
    end
    self.dead = false
    self.animationTimer = 0
    return self
end

function Bullet:update(dt)
    self.x = self.x + self.dx * dt
    self.y = self.y + self.dy * dt
    self.animationTimer = self.animationTimer + dt
    if self.x < -self.width or self.x > WORLD_WIDTH or self.y < -self.height or self.y > VIRTUAL_HEIGHT then
        self.dead = true
    end
end

function Bullet:draw()
    local animation = nil
    if self.owner == 'player' and gSprites and gSprites.projectile then
        animation = gSprites.projectile.moving
    elseif self.owner == 'enemy' and gSprites and gSprites.enemies then
        if self.visualType == 'darkball' and gSprites.enemies.darkball then
            animation = gSprites.enemies.darkball.move
        elseif self.visualType == 'arrow' and gSprites.enemies.arrow then
            animation = gSprites.enemies.arrow.move
        elseif self.visualType == 'spear' and gSprites.enemies.spear then
            animation = gSprites.enemies.spear.move or gSprites.enemies.spear.idle
        elseif gSprites.enemies.fireball then
            animation = gSprites.enemies.fireball.move
        end
    end

    if animation then
        local frame = math.floor(self.animationTimer / animation.frameDuration) % #animation.quads + 1
        local scale = self.owner == 'enemy' and 0.48 or (self.isCat and 0.525 or 0.54)
        if self.visualType == 'darkball' then
            scale = 0.96
        end
        if self.visualType == 'spear' then
            scale = 1
        end
        local facing = self.dx < 0 and -1 or 1
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(
            animation.image,
            animation.quads[frame],
            self.x + self.width / 2,
            self.y + self.height / 2,
            0,
            scale * facing,
            scale,
            animation.frameWidth / 2,
            animation.frameHeight / 2
        )
        return
    end

    if self.owner == 'player' then
        love.graphics.setColor(0.25, 0.75, 1)
    else
        love.graphics.setColor(1, 0.2, 0.2)
    end
    love.graphics.rectangle('fill', self.x, self.y, self.width, self.height)
    love.graphics.setColor(1, 1, 1)
end

return Bullet
