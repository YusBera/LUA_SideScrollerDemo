Player = {}
Player.__index = Player

local HUMAN_VISIBLE_BOTTOM = 96
local CAT_VISIBLE_BOTTOM = 31

function Player.create(x, y)
    local self = setmetatable({}, Player)
    self.width = 16
    self.height = 32
    self.x = x
    self.y = y
    self.groundY = y
    self.visualGroundY = y + self.height
    self.spriteScaleMultiplier = 2.175
    self.catScaleMultiplier = 1.5
    self.spriteYOffset = 15
    self.vy = 0
    self.jumpHoldTimer = 0
    self.maxJumpHoldTime = 0.18
    self.facing = 1
    self.healthLevel = 5
    self.lives = 3
    self.score = 0
    self.startX = x
    self.startY = y
    self.worldWidth = VIRTUAL_WIDTH
    self.isCrouching = false
    self.currentHitboxHeight = self.height
    self.invulnerableTimer = 0
    self.animationTimer = 0
    self.currentAnimation = 'idle'
    self.attackTimer = 0
    self.attackReleaseTimer = 0
    self.pendingAttackDir = nil
    self.isCatCasting = false
    self.isCatHit = false
    self.lastVerticalInput = nil
    self.hitTimer = 0
    return self
end

function Player:update(dt)
    local speed = self.isCrouching and 90 * 1.5 or 90
    local moving = false
    if love.keyboard.isDown('left') or love.keyboard.isDown('a') then
        self.x = self.x - speed * dt
        self.facing = -1
        moving = true
    elseif love.keyboard.isDown('right') or love.keyboard.isDown('d') then
        self.x = self.x + speed * dt
        self.facing = 1
        moving = true
    end

    local pressingCrouch = (love.keyboard.isDown('down') or love.keyboard.isDown('s')) and self.lastVerticalInput ~= 'jump'
    self.isCrouching = (self.y >= self.groundY and pressingCrouch) or self.isCatCasting
    self.currentHitboxHeight = self.isCrouching and self.height / 2 or self.height

    self.vy = self.vy + 540 * dt
    if self.jumpHoldTimer > 0 and self.vy < 0 and (love.keyboard.isDown('up') or love.keyboard.isDown('w')) then
        self.vy = self.vy - 760 * dt
        self.jumpHoldTimer = math.max(0, self.jumpHoldTimer - dt)
    else
        self.jumpHoldTimer = 0
    end
    self.y = self.y + self.vy * dt
    if self.y >= self.groundY then
        self.y = self.groundY
        self.vy = 0
    end

    self.invulnerableTimer = math.max(0, self.invulnerableTimer - dt)
    self.attackTimer = math.max(0, self.attackTimer - dt)
    self.attackReleaseTimer = math.max(0, self.attackReleaseTimer - dt)
    if self.pendingAttackDir then
        self.pendingAttackDir = self.facing
    elseif self.attackTimer == 0 then
        self.isCatCasting = false
    end
    self.hitTimer = math.max(0, self.hitTimer - dt)
    if self.hitTimer == 0 then
        self.isCatHit = false
    end
    self.currentAnimation = self:getAnimationName(moving)
    self.animationTimer = self.animationTimer + dt

    self.x = math.max(0, math.min(self.worldWidth - self.width, self.x))
end

function Player:jump()
    self.lastVerticalInput = 'jump'
    if self.y >= self.groundY then
        self.isCrouching = false
        self.currentHitboxHeight = self.height
        self.vy = -145
        self.jumpHoldTimer = self.maxJumpHoldTime
    end
end

function Player:crouch()
    self.lastVerticalInput = 'crouch'
end

function Player:takeDamage()
    if self.invulnerableTimer > 0 then
        return false
    end

    self.healthLevel = self.healthLevel - 1
    self.invulnerableTimer = 1
    self.hitTimer = 0.25
    self.isCatHit = self.isCrouching

    if self.healthLevel <= 0 then
        self.lives = self.lives - 1
        if self.lives > 0 then
            self.x, self.y = self.startX, self.startY
            self.vy = 0
            self.healthLevel = 5
        else
            return true
        end
    end

    return false
end

function Player:startAttack()
    if self.attackTimer > 0 then
        return false
    end

    self.isCatCasting = self.isCrouching
    local animation = gSprites and gSprites.player and (self.isCatCasting and gSprites.player.catMeow or gSprites.player.attack)
    if animation then
        self.attackTimer = #animation.quads * animation.frameDuration
    else
        self.attackTimer = 0.55
    end
    self.attackReleaseTimer = math.max(0, self.attackTimer - 0.06)
    self.pendingAttackDir = self.facing
    self.animationTimer = 0
    if self.isCatCasting then
        playSound('catProjectile')
    end
    return true
end

function Player:consumeReleasedAttack()
    if self.pendingAttackDir and self.attackReleaseTimer == 0 then
        local dir = self.pendingAttackDir
        self.pendingAttackDir = nil
        return dir
    end
    return nil
end

function Player:getCastOrigin(dir)
    local visualGroundY = self:getVisualGroundY()

    if self.isCatCasting then
        return {
            x = self.x + self.width / 2 + dir * 12,
            y = visualGroundY - 8
        }
    end

    local animation = gSprites and gSprites.player and gSprites.player.attack
    if not animation then
        return {
            x = self.x + self.width / 2 + dir * 18,
            y = self.y + 10
        }
    end

    local scale = self.height / animation.frameHeight * self.spriteScaleMultiplier
    local drawX = self.x + self.width / 2
    local drawY = visualGroundY + (animation.frameHeight - HUMAN_VISIBLE_BOTTOM) * scale

    return {
        x = drawX + dir * 46 * scale,
        y = drawY - 88 * scale
    }
end

function Player:getVisualGroundY()
    return self.visualGroundY + (self.y - self.groundY)
end

function Player:getAnimationName(moving)
    if self.hitTimer > 0 then
        if self.isCatHit or self.isCatCasting or self.isCrouching then
            return 'catIdle'
        end
        return 'hit'
    end

    if self.attackTimer > 0 then
        if self.isCatCasting then
            return 'catMeow'
        end
        return 'attack'
    end

    if self.vy < -10 then
        return 'jump'
    end

    if self.vy > 10 then
        return 'fall'
    end

    if moving and not self.isCrouching then
        return 'run'
    end

    if self.isCrouching then
        return moving and 'catWalk' or 'catIdle'
    end

    return 'idle'
end

function Player:getHitbox()
    local height = self.currentHitboxHeight
    return {
        x = self.x,
        y = self.y + self.height - height,
        width = self.width,
        height = height
    }
end

function Player:draw()
    local animation = gSprites and gSprites.player and gSprites.player[self.currentAnimation]
    if animation then
        self:drawAnimation(animation)
        if self.currentAnimation == 'catMeow' then
            self:drawCatMeowVfx()
        end
        return
    end

    if self.invulnerableTimer > 0 and math.floor(self.invulnerableTimer * 12) % 2 == 0 then
        love.graphics.setColor(1, 1, 1, 0.45)
    else
        love.graphics.setColor(0.5, 0.8, 1)
    end

    local hitbox = self:getHitbox()
    love.graphics.rectangle('fill', hitbox.x, hitbox.y, hitbox.width, hitbox.height)
    love.graphics.setColor(1, 1, 1)
end

function Player:drawAnimation(animation)
    local frameCount = #animation.quads
    local frame = math.floor(self.animationTimer / animation.frameDuration) % frameCount + 1
    local isCat = self.currentAnimation == 'catIdle' or self.currentAnimation == 'catWalk' or self.currentAnimation == 'catMeow'
    local scale = self.height / animation.frameHeight * (isCat and self.catScaleMultiplier or self.spriteScaleMultiplier)
    local drawX = self.x + self.width / 2
    local visualGroundY = self:getVisualGroundY()
    local drawY
    if isCat then
        drawY = visualGroundY + (animation.frameHeight - CAT_VISIBLE_BOTTOM) * scale
    else
        drawY = visualGroundY + (animation.frameHeight - HUMAN_VISIBLE_BOTTOM) * scale
    end
    local scaleX = scale * self.facing
    local alpha = 1

    if self.invulnerableTimer > 0 and math.floor(self.invulnerableTimer * 12) % 2 == 0 then
        alpha = 0.45
    end

    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(
        animation.image,
        animation.quads[frame],
        drawX,
        drawY,
        0,
        scaleX,
        scale,
        animation.frameWidth / 2,
        animation.frameHeight
    )
    love.graphics.setColor(1, 1, 1)
end

function Player:drawCatMeowVfx()
    local animation = gSprites and gSprites.player and gSprites.player.catMeowVfx
    if not animation then
        return
    end

    local rawFrame = math.floor(self.animationTimer / animation.frameDuration) + 1
    if rawFrame > #animation.quads then
        return
    end

    local origin = self:getCastOrigin(self.facing)
    local scale = 0.75

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(
        animation.image,
        animation.quads[rawFrame],
        origin.x,
        origin.y,
        0,
        scale * self.facing,
        scale,
        animation.frameWidth / 2,
        animation.frameHeight / 2
    )
    love.graphics.setColor(1, 1, 1)
end

return Player
