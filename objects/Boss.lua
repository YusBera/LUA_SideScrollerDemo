Boss = {}
Boss.__index = Boss

local BOSS_GROUND_Y = VIRTUAL_HEIGHT - 14
local BOSS_FRAME_W = 250
local BOSS_FRAME_H = 250
local BOSS_VISIBLE_BOTTOM = 166
local BOSS_SCALE = 0.68

function Boss.create(x, y, levelIndex)
    local self = setmetatable({}, Boss)
    self.levelIndex = levelIndex or 1
    self.spriteKey = self.levelIndex == 2 and 'level2Boss' or 'level1Boss'
    self.x = x
    self.groundY = y
    self.projectileType = self.levelIndex == 2 and 'spear' or 'darkball'
    self.width = 28
    self.height = 46
    self.spriteScale = self.levelIndex == 2 and 1.35 or BOSS_SCALE
    self.visibleBottom = self.levelIndex == 2 and 95 or BOSS_VISIBLE_BOTTOM
    self.jumpOffsetY = 0
    self.y = self.groundY - self.height - self.jumpOffsetY

    self.maxHealth = 12
    self.health = self.maxHealth
    self.phase = 1

    self.baseSpeed = self.levelIndex == 2 and 135 or 90
    self.speed = self.baseSpeed
    self.moveDir = -1
    self.isMoving = false
    self.minX = 8
    self.maxX = WORLD_WIDTH - self.width - 8
    self.facing = -1

    self.fireTimer = 0
    self.fireRate = 3
    self.preferredMinRange = 145
    self.preferredMaxRange = 190
    self.emergencyRange = 30
    self.attackTimer = 0
    self.attackWindupTimer = 0
    self.currentAttackDuration = 0
    self.currentAttackKind = nil
    self.attackCueTimer = 0
    self.pendingAttackSound = nil
    self.meleeHitTimer = 0
    self.meleeHasHit = false
    self.meleeDecisionRange = self.levelIndex == 2 and 64 or 48
    self.meleeReach = self.levelIndex == 2 and 60 or 36
    self.pendingAttack = nil
    self.canCastWhileCornered = false
    self.jumpTimer = 0
    self.jumpDuration = 0
    self.jumpStartX = x
    self.jumpTargetX = x
    self.jumpHeight = 24
    self.jumpCooldown = 0
    self.hitTimer = 0
    self.animationTimer = 0

    self.isActive = false
    self.introTimer = 2
    self.dead = false
    self.corpse = false
    self.deathDuration = 0

    return self
end

function Boss:update(dt, player, bullets, cameraX)
    self.y = self.groundY - self.height

    if self.dead then
        self.animationTimer = self.animationTimer + dt
        if self.deathDuration > 0 and self.animationTimer >= self.deathDuration then
            self.corpse = true
        end
        return
    end

    self.animationTimer = self.animationTimer + dt
    self.hitTimer = math.max(0, self.hitTimer - dt)
    self.attackTimer = math.max(0, self.attackTimer - dt)
    self.attackWindupTimer = math.max(0, self.attackWindupTimer - dt)
    self.attackCueTimer = math.max(0, self.attackCueTimer - dt)
    self.jumpTimer = math.max(0, self.jumpTimer - dt)
    self.jumpCooldown = math.max(0, self.jumpCooldown - dt)
    self.meleeHitTimer = math.max(0, self.meleeHitTimer - dt)

    if not self.isActive then
        local viewX = cameraX or 0
        if self.x + self.width > viewX and self.x < viewX + VIRTUAL_WIDTH then
            self.isActive = true
            self.introTimer = 2
            self.animationTimer = 0
        end
        return
    end

    if self.introTimer > 0 then
        self.introTimer = math.max(0, self.introTimer - dt)
        return
    end

    self:checkPhase()
    self:updateAttackCue()
    self:updateMeleeDamageWindow()
    self:updateAttackRelease(bullets)
    self.isMoving = false
    self.canCastWhileCornered = false

    if self.levelIndex == 2 and self.phase == 2 then
        self:updateDuelistAI(dt, player)
    else
        self:updateMageAI(dt, player)
    end
end

function Boss:updateMageAI(dt, player)
    if self.jumpTimer > 0 then
        self:updateJump()
    elseif self:shouldJumpAway(player) then
        self:startJumpAway(player)
    elseif self.attackWindupTimer == 0 and self.attackTimer == 0 then
        self:updateRangeControl(dt, player)
    end

    self.fireTimer = self.fireTimer + dt
    if (self:isInPreferredRange(player) or self.canCastWhileCornered) and self.fireTimer >= self.fireRate and self.attackTimer == 0 and self.jumpTimer == 0 then
        self:startAttack(player, 'ranged')
    end
end

function Boss:updateDuelistAI(dt, player)
    if self.jumpTimer > 0 then
        self:updateJump()
        return
    end

    if self.currentAttackKind == 'melee1' and self.attackTimer == 0 then
        self:startAttack(player, 'melee2')
        return
    end

    if self.attackTimer > 0 or self.attackWindupTimer > 0 then
        return
    end

    self.currentAttackKind = nil

    local bossCenter = self.x + self.width / 2
    local playerCenter = player.x + player.width / 2
    local distance = math.abs(playerCenter - bossCenter)
    self.facing = playerCenter < bossCenter and -1 or 1

    if self:shouldJumpWhenCornered(player) then
        self:startJumpAway(player)
        return
    end

    if distance <= self.meleeDecisionRange then
        self:startAttack(player, 'melee1')
        return
    end

    self.fireTimer = self.fireTimer + dt
    if distance > self.meleeDecisionRange then
        local step = math.min(self.speed * dt, distance - self.meleeDecisionRange)
        self.isMoving = true
        self.moveDir = self.facing
        self.x = self.x + self.facing * step
        self.x = math.max(self.minX, math.min(self.maxX, self.x))
    elseif self.fireTimer >= self.fireRate then
        self:startAttack(player, 'ranged')
    end
end

function Boss:checkPhase()
    if self.phase == 1 and self.health <= self.maxHealth / 2 then
        self.phase = 2
        self.fireRate = self.levelIndex == 2 and 1.8 or 2
        self.speed = self.levelIndex == 2 and 67.5 or self.baseSpeed * 1.5
    end
end

function Boss:move(dt)
    self.isMoving = true
    self.x = self.x + self.moveDir * self.speed * dt

    if self.x < self.minX then
        self.x = self.minX
        self.moveDir = 1
    elseif self.x > self.maxX then
        self.x = self.maxX
        self.moveDir = -1
    end

    if not self.pendingAttack then
        self.facing = self.moveDir
    end
end

function Boss:updateRangeControl(dt, player)
    local bossCenter = self.x + self.width / 2
    local playerCenter = player.x + player.width / 2
    local distance = math.abs(playerCenter - bossCenter)

    if distance < self.preferredMinRange then
        local dir = bossCenter < playerCenter and -1 or 1
        if self:isBlockedInDirection(dir) then
            self.facing = playerCenter < bossCenter and -1 or 1
            self.canCastWhileCornered = true
            return
        end
        local step = math.min(self.speed * dt, self.preferredMinRange - distance)
        self.isMoving = true
        self.moveDir = dir
        self.facing = dir
        self.x = self.x + dir * step
        self.x = math.max(self.minX, math.min(self.maxX, self.x))
    elseif distance > self.preferredMaxRange then
        local dir = bossCenter < playerCenter and 1 or -1
        local step = math.min(self.speed * dt, distance - self.preferredMaxRange)
        self.isMoving = true
        self.moveDir = dir
        self.facing = dir
        self.x = self.x + dir * step
        self.x = math.max(self.minX, math.min(self.maxX, self.x))
    else
        self.facing = playerCenter < bossCenter and -1 or 1
    end
end

function Boss:isInPreferredRange(player)
    local bossCenter = self.x + self.width / 2
    local playerCenter = player.x + player.width / 2
    local distance = math.abs(playerCenter - bossCenter)
    return distance >= self.preferredMinRange and distance <= self.preferredMaxRange
end

function Boss:isBlockedInDirection(dir)
    return (dir < 0 and self.x <= self.minX + 1) or
        (dir > 0 and self.x >= self.maxX - 1)
end

function Boss:shouldJumpAway(player)
    local bossCenter = self.x + self.width / 2
    local playerCenter = player.x + player.width / 2
    local distance = math.abs(playerCenter - bossCenter)
    local awayDir = bossCenter < playerCenter and -1 or 1

    return self.jumpCooldown == 0 and
        self.jumpTimer == 0 and
        self.attackTimer == 0 and
        self.attackWindupTimer == 0 and
        (distance < self.emergencyRange or
            (distance < 58 and self:isBlockedInDirection(awayDir)))
end

function Boss:shouldJumpWhenCornered(player)
    local bossCenter = self.x + self.width / 2
    local playerCenter = player.x + player.width / 2
    local distance = math.abs(playerCenter - bossCenter)
    local pushedDir = bossCenter < playerCenter and -1 or 1

    return self.jumpCooldown == 0 and
        distance < 52 and
        self:isBlockedInDirection(pushedDir)
end

function Boss:startJumpAway(player)
    local bossCenter = self.x + self.width / 2
    local playerCenter = player.x + player.width / 2
    local dir = bossCenter < playerCenter and 1 or -1
    local preferredTarget = playerCenter + dir * 180
    local clampedTarget = math.max(self.minX, math.min(self.maxX, preferredTarget))

    if math.abs(clampedTarget - self.x) < 34 then
        dir = -dir
        preferredTarget = playerCenter + dir * 180
        clampedTarget = math.max(self.minX, math.min(self.maxX, preferredTarget))
    end

    self.facing = dir
    self.jumpDuration = 0.95
    self.jumpTimer = self.jumpDuration
    self.jumpCooldown = 1.4
    self.jumpStartX = self.x
    self.jumpTargetX = clampedTarget
    self.jumpHeight = 82
    self.jumpOffsetY = 0
    self.animationTimer = 0
end

function Boss:updateJump()
    local progress = 1 - (self.jumpTimer / self.jumpDuration)
    progress = math.max(0, math.min(1, progress))
    local eased = progress * progress * (3 - 2 * progress)
    self.x = self.jumpStartX + (self.jumpTargetX - self.jumpStartX) * eased
    self.jumpOffsetY = math.sin(progress * math.pi) * self.jumpHeight

    if self.jumpTimer == 0 then
        self.x = self.jumpTargetX
        self.jumpOffsetY = 0
        self.moveDir = self.facing
    end
end

function Boss:isEscaping()
    return self.jumpTimer > 0
end

function Boss:isDamageable()
    return self.isActive and self.introTimer == 0 and not self.dead
end

function Boss:startAttack(player, attackKind)
    local dir = player.x < self.x and -1 or 1
    attackKind = attackKind or 'ranged'
    local animation = self:getAttackAnimation(attackKind)
    local duration = animation and (#animation.quads * animation.frameDuration) or (self.phase == 1 and 0.72 or 0.9)
    local holdDuration = animation and animation.frameDuration or 0.06

    self.facing = dir
    self.fireTimer = 0
    self.attackTimer = duration + holdDuration
    self.attackWindupTimer = duration
    self.currentAttackDuration = duration
    self.currentAttackKind = attackKind
    self.meleeHasHit = false
    self.pendingAttack = {dir = dir, phase = self.phase, kind = attackKind}
    self.pendingAttackSound = self:getAttackSoundName(attackKind)
    self.attackCueTimer = 0
    if self.pendingAttackSound then
        self.attackCueTimer = math.max(0, duration - 1)
    end
    self.animationTimer = 0

    if attackKind == 'melee1' or attackKind == 'melee2' then
        playSound('spearMelee')
    end
end

function Boss:updateAttackRelease(bullets)
    if self.attackWindupTimer == 0 and self.pendingAttack then
        local dir = self.pendingAttack.dir
        self.facing = dir
        if self.pendingAttack.kind == 'melee1' or self.pendingAttack.kind == 'melee2' then
            -- Melee damage is driven by the visible strike frame, not by animation end.
        elseif self.pendingAttack.kind == 'ranged' and self.levelIndex == 2 then
            table.insert(bullets, Bullet.create(self.x + self.width / 2 + dir * 28, self.groundY - 34, dir, 'enemy', 0, 1, false, self.projectileType))
        elseif self.pendingAttack.phase == 1 then
            table.insert(bullets, Bullet.create(self.x + self.width / 2 + dir * 26, self.groundY - 28, dir, 'enemy', 0, 1, false, self.projectileType))
        else
            table.insert(bullets, Bullet.create(self.x + self.width / 2 + dir * 26, self.groundY - 40, dir, 'enemy', -70, 1, false, self.projectileType))
            table.insert(bullets, Bullet.create(self.x + self.width / 2 + dir * 26, self.groundY - 28, dir, 'enemy', 0, 1, false, self.projectileType))
            table.insert(bullets, Bullet.create(self.x + self.width / 2 + dir * 26, self.groundY - 16, dir, 'enemy', 70, 1, false, self.projectileType))
        end
        self.pendingAttack = nil
    end
end

function Boss:updateAttackCue()
    if self.pendingAttackSound and self.attackCueTimer == 0 then
        playSound(self.pendingAttackSound)
        self.pendingAttackSound = nil
    end
end

function Boss:getAttackSoundName(attackKind)
    if attackKind ~= 'ranged' then
        return nil
    end

    if self.levelIndex == 2 and self.phase == 1 then
        return 'spearProjectile'
    elseif self.levelIndex == 1 then
        return 'boss1Projectile'
    end

    return nil
end

function Boss:takeDamage(amount)
    if self.dead then
        return false
    end

    amount = amount or 1
    self.health = self.health - amount
    self.hitTimer = 0.28
    self.animationTimer = 0

    if self.health <= 0 then
        self.dead = true
        self.hitTimer = 0
        self.attackTimer = 0
        self.attackWindupTimer = 0
        self.currentAttackDuration = 0
        self.currentAttackKind = nil
        self.attackCueTimer = 0
        self.pendingAttackSound = nil
        self.meleeHitTimer = 0
        self.pendingAttack = nil
        self.animationTimer = 0
        local sprites = self:getSpriteSet()
        local death = sprites and sprites.death
        self.deathDuration = death and (#death.quads - 1) * death.frameDuration or 0
        return true
    end

    return false
end

function Boss:draw()
    local animation = self:getAnimation()
    if not animation then
        love.graphics.setColor(self.phase == 1 and 0.7 or 1, 0.2, self.phase == 1 and 0.9 or 0.25)
        love.graphics.rectangle('fill', self.x, self.y, self.width, self.height)
        love.graphics.setColor(1, 1, 1)
        return
    end

    self:drawAnimation(animation)
end

function Boss:getAnimation()
    local boss = self:getSpriteSet()
    if not boss then
        return nil
    end
    if self.dead then
        return boss.death
    end

    if not self.isActive or self.introTimer > 0 then
        return boss.idle
    end

    if self.hitTimer > 0 then
        return boss.hit
    end

    if self.jumpTimer > 0 then
        return boss.jump or boss.run or boss.idle
    end

    if self.attackTimer > 0 then
        return self:getAttackAnimation(self.currentAttackKind)
    end

    if self.isMoving then
        return boss.run or boss.idle
    end

    return boss.idle or boss.run
end

function Boss:getSpriteSet()
    if not (gSprites and gSprites.enemies) then
        return nil
    end

    return gSprites.enemies[self.spriteKey]
end

function Boss:getAttackAnimation(attackKind)
    local boss = self:getSpriteSet()
    if not boss then
        return nil
    end

    if self.levelIndex == 2 then
        if attackKind == 'melee1' then
            return boss.attack1 or boss.attack3
        elseif attackKind == 'melee2' then
            return boss.attack2 or boss.attack1 or boss.attack3
        end
        return boss.attack3 or boss.attack1
    end

    return self.phase == 1 and boss.attack1 or boss.attack2
end

function Boss:updateMeleeDamageWindow()
    if self.levelIndex ~= 2 or
        (self.currentAttackKind ~= 'melee1' and self.currentAttackKind ~= 'melee2') or
        self.attackTimer == 0 or
        self.meleeHasHit then
        return
    end

    local animation = self:getAttackAnimation(self.currentAttackKind)
    if not animation then
        return
    end

    local frame = math.min(#animation.quads, math.floor(self.animationTimer / animation.frameDuration) + 1)
    if frame == 4 then
        self.meleeHitTimer = animation.frameDuration
    end
end

function Boss:getMeleeHitbox()
    if self.levelIndex ~= 2 or self.meleeHitTimer == 0 or self.meleeHasHit then
        return nil
    end

    local reach = self.meleeReach
    local hitboxWidth = reach
    local hitboxHeight = 42
    local x = self.facing < 0 and (self.x - reach) or (self.x + self.width)

    return {
        x = x,
        y = self.groundY - hitboxHeight,
        width = hitboxWidth,
        height = hitboxHeight
    }
end

function Boss:markMeleeHit()
    self.meleeHasHit = true
end

function Boss:drawAnimation(animation)
    local frame
    if self.dead then
        if self.corpse then
            frame = #animation.quads
        else
            frame = math.min(#animation.quads, math.floor(self.animationTimer / animation.frameDuration) + 1)
        end
    elseif self.attackTimer > 0 then
        if self.pendingAttack then
            frame = math.min(#animation.quads, math.floor(self.animationTimer / animation.frameDuration) + 1)
        else
            frame = #animation.quads
        end
    else
        frame = math.floor(self.animationTimer / animation.frameDuration) % #animation.quads + 1
    end

    local facing = self.facing < 0 and -1 or 1
    local drawX = self.x + self.width / 2
    local drawY = self.groundY - self.jumpOffsetY + (animation.frameHeight - self.visibleBottom) * self.spriteScale

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(
        animation.image,
        animation.quads[frame],
        drawX,
        drawY,
        0,
        self.spriteScale * facing,
        self.spriteScale,
        animation.frameWidth / 2,
        animation.frameHeight
    )
    love.graphics.setColor(1, 1, 1)
end

return Boss
