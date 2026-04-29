Enemy = {}
Enemy.__index = Enemy

function Enemy.create(x, y, type)
    local self = setmetatable({}, Enemy)
    self.type = type or 'worm'
    self.width = 16
    self.height = 28
    self.x = x
    self.y = y
    self.health = 3
    self.fireTimer = 0
    self.fireRate = 2
    self.speed = 40
    self.startX = x
    self.patrolLeft = x - 28
    self.patrolRight = x + 28
    self.moveDir = -1
    self.facing = -1
    self.dead = false
    self.corpse = false
    self.deathDuration = 0
    self.animationTimer = 0
    self.attackTimer = 0
    self.attackWindupTimer = 0
    self.pendingShotDir = nil
    self.hitTimer = 0
    self.spriteScaleMultiplier = 2.0
    self.spriteYOffset = 21
    return self
end

function Enemy:update(dt, player, bullets)
    if self.dead then
        self.animationTimer = self.animationTimer + dt
        if self.deathDuration > 0 and self.animationTimer >= self.deathDuration then
            self.corpse = true
        end
        return
    end

    self.fireTimer = self.fireTimer + dt
    self.attackTimer = math.max(0, self.attackTimer - dt)
    self.attackWindupTimer = math.max(0, self.attackWindupTimer - dt)
    self.hitTimer = math.max(0, self.hitTimer - dt)
    self.animationTimer = self.animationTimer + dt

    if self.attackTimer == 0 and self.pendingShotDir == nil then
        self:patrol(dt)
    end

    if self.attackWindupTimer == 0 and self.pendingShotDir then
        local fireX = self.x + self.width / 2 + self.pendingShotDir * 18
        local fireY = self.y + self.height / 2 - 2
        local projType = self.type == 'huntress' and 'arrow' or 'fireball'
        table.insert(bullets, Bullet.create(fireX, fireY, self.pendingShotDir, 'enemy', 0, 1, false, projType))
        playSound(self.type == 'huntress' and 'huntressProjectile' or 'wormFireball')
        self.pendingShotDir = nil
    end

    if self:canSeePlayer(player) and self.fireTimer >= self.fireRate and self.attackTimer == 0 then
        self:startAttack(player)
    end
end

function Enemy:patrol(dt)
    self.x = self.x + self.moveDir * self.speed * dt

    if self.x >= self.patrolRight then
        self.x = self.patrolRight
        self.moveDir = -1
    elseif self.x <= self.patrolLeft then
        self.x = self.patrolLeft
        self.moveDir = 1
    end

    self.facing = self.moveDir
end

function Enemy:startAttack(player)
    self.fireTimer = 0
    local attackAnim = gSprites and gSprites.enemies and gSprites.enemies[self.type] and gSprites.enemies[self.type].attack
    if attackAnim then
        self.attackTimer = #attackAnim.quads * attackAnim.frameDuration
        self.attackWindupTimer = self.attackTimer * 0.6
    else
        self.attackTimer = 1.05
        self.attackWindupTimer = 0.62
    end

    self.animationTimer = 0
    local dir = player.x < self.x and -1 or 1
    self.facing = dir
    self.pendingShotDir = dir
end

function Enemy:takeDamage(amount)
    amount = amount or 1
    self.health = self.health - amount
    self.hitTimer = 0.38
    self.animationTimer = 0
    if self.health <= 0 then
        self.dead = true
        self.corpse = false
        self.hitTimer = 0
        self.attackTimer = 0
        self.attackWindupTimer = 0
        self.pendingShotDir = nil
        self.animationTimer = 0
        local death = gSprites and gSprites.enemies and gSprites.enemies[self.type] and gSprites.enemies[self.type].death
        self.deathDuration = death and (#death.quads - 1) * death.frameDuration or 0
        return true
    end
    return false
end

function Enemy:canSeePlayer(player)
    return math.abs(player.x - self.x) < 300
end

function Enemy:isFacingPlayer(player)
    if player.x < self.x then
        return self.facing < 0
    end
    return self.facing > 0
end

function Enemy:draw()
    local animation = self:getAnimation()
    if animation then
        self:drawAnimation(animation)
        return
    end

    love.graphics.setColor(1, 0.4, 0.4)
    love.graphics.rectangle('fill', self.x, self.y, self.width, self.height)
    love.graphics.setColor(1, 1, 1)
end

function Enemy:getAnimation()
    if not (gSprites and gSprites.enemies and gSprites.enemies[self.type]) then
        return nil
    end

    local sprites = gSprites.enemies[self.type]

    if self.dead then
        return sprites.death
    end

    if self.hitTimer > 0 then
        return sprites.hit
    end

    if self.attackTimer > 0 then
        return sprites.attack
    end

    return sprites.walk or sprites.run
end

function Enemy:drawAnimation(animation)
    local frame
    if self.dead then
        if self.corpse then
            frame = #animation.quads
        else
            frame = math.min(#animation.quads, math.floor(self.animationTimer / animation.frameDuration) + 1)
        end
    else
        frame = math.floor(self.animationTimer / animation.frameDuration) % #animation.quads + 1
    end
    local scale = self.height / animation.frameHeight * self.spriteScaleMultiplier
    local facing = self.facing < 0 and -1 or 1

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(
        animation.image,
        animation.quads[frame],
        self.x + self.width / 2,
        self.y + self.height + self.spriteYOffset,
        0,
        scale * facing,
        scale,
        animation.frameWidth / 2,
        animation.frameHeight
    )
    love.graphics.setColor(1, 1, 1)
end

return Enemy
