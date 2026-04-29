push = require 'lib.push'
Gamestate = require 'lib.hump.gamestate'

VIRTUAL_WIDTH = 320
VIRTUAL_HEIGHT = 180
WINDOW_WIDTH = 1280
WINDOW_HEIGHT = 720
WORLD_WIDTH = 640

require 'states.Menu'
require 'states.Play'
require 'states.Pause'
require 'states.Win'
require 'states.GameOver'
require 'states.HighScore'
require 'objects.Player'
require 'objects.Bullet'
require 'objects.Enemy'
require 'objects.Boss'

local function loadImages(paths)
    local images = {}
    for _, path in ipairs(paths) do
        if love.filesystem.getInfo(path) then
            table.insert(images, love.graphics.newImage(path))
        end
    end
    return images
end

local function loadAnimation(path, frameWidth, frameHeight, frameDuration)
    if not love.filesystem.getInfo(path) then
        return nil
    end

    local image = love.graphics.newImage(path)
    local frames = math.floor(image:getWidth() / frameWidth)
    local quads = {}

    for i = 0, frames - 1 do
        table.insert(quads, love.graphics.newQuad(i * frameWidth, 0, frameWidth, frameHeight, image:getDimensions()))
    end

    return {
        image = image,
        quads = quads,
        frameDuration = frameDuration or 0.08,
        frameWidth = frameWidth,
        frameHeight = frameHeight
    }
end

local function loadSound(path)
    if not love.filesystem.getInfo(path) then
        return nil
    end

    return love.audio.newSource(path, 'static')
end

function playSound(name)
    if not (gSounds and gSounds[name]) then
        return
    end

    local sound = gSounds[name]:clone()
    sound:play()
end

function love.load()
    love.graphics.setDefaultFilter('nearest', 'nearest')
    love.window.setTitle('The Dimensional Traveler')

    gFonts = {
        small  = love.graphics.newFont(8),
        medium = love.graphics.newFont(16),
        large  = love.graphics.newFont(32)
    }
    for _, font in pairs(gFonts) do
        font:setFilter('nearest', 'nearest')
    end

    local hudScale = WINDOW_WIDTH / VIRTUAL_WIDTH
    gHudFonts = {
        small  = love.graphics.newFont(math.floor(8 * hudScale)),
        medium = love.graphics.newFont(math.floor(16 * hudScale)),
        large  = love.graphics.newFont(math.floor(32 * hudScale))
    }

    gBackgrounds = {
        level1 = loadImages({
            'assets/sprites/level1/background_layers/layer_0011_0.png',
            'assets/sprites/level1/background_layers/layer_0010_1.png',
            'assets/sprites/level1/background_layers/layer_0009_2.png',
            'assets/sprites/level1/background_layers/layer_0008_3.png',
            'assets/sprites/level1/background_layers/layer_0007_lights.png',
            'assets/sprites/level1/background_layers/layer_0006_4.png',
            'assets/sprites/level1/background_layers/layer_0005_5.png',
            'assets/sprites/level1/background_layers/layer_0004_lights.png',
            'assets/sprites/level1/background_layers/layer_0003_6.png',
            'assets/sprites/level1/background_layers/layer_0002_7.png',
            'assets/sprites/level1/background_layers/layer_0001_8.png',
            'assets/sprites/level1/background_layers/layer_0000_9.png'
        }),
        level2 = loadImages({
            'assets/sprites/level2/background_layers/hills_layer_01.png',
            'assets/sprites/level2/background_layers/hills_layer_02.png',
            'assets/sprites/level2/background_layers/hills_layer_03.png',
            'assets/sprites/level2/background_layers/hills_layer_04.png',
            'assets/sprites/level2/background_layers/hills_layer_05.png',
            'assets/sprites/level2/background_layers/hills_layer_06.png'
        })
    }

    gSounds = {
        bgMusic = love.filesystem.getInfo('assets/sounds/bg.mp3') and love.audio.newSource('assets/sounds/bg.mp3', 'stream') or nil,
        playerFireball = loadSound('assets/sounds/player_fireball.mp3'),
        catProjectile = loadSound('assets/sounds/cat_projectile.mp3'),
        wormFireball = loadSound('assets/sounds/worm_fireball.mp3'),
        boss1Projectile = loadSound('assets/sounds/boss_1_projectile.mp3'),
        huntressProjectile = loadSound('assets/sounds/huntress_projectile.mp3'),
        spearProjectile = loadSound('assets/sounds/spear_projectile.mp3'),
        spearMelee = loadSound('assets/sounds/spear_melee.mp3')
    }

    gSprites = {
        player = {
            idle = loadAnimation('assets/sprites/player/idle.png', 140, 140, 0.12),
            run = loadAnimation('assets/sprites/player/run.png', 140, 140, 0.07),
            walk = loadAnimation('assets/sprites/player/walk.png', 140, 140, 0.08),
            jump = loadAnimation('assets/sprites/player/jump.png', 140, 140, 0.1),
            fall = loadAnimation('assets/sprites/player/fall.png', 140, 140, 0.1),
            attack = loadAnimation('assets/sprites/player/attack.png', 140, 140, 0.0275),
            hit = loadAnimation('assets/sprites/player/get_hit.png', 140, 140, 0.08),
            death = loadAnimation('assets/sprites/player/death.png', 140, 140, 0.08),
            catIdle = loadAnimation('assets/sprites/player/cat_form/cat_idle.png', 50, 50, 0.1),
            catWalk = loadAnimation('assets/sprites/player/cat_form/cat_walk.png', 50, 50, 0.08),
            catMeow = loadAnimation('assets/sprites/player/cat_form/cat_meow.png', 50, 50, 0.08),
            catMeowVfx = loadAnimation('assets/sprites/player/cat_form/meow_vfx.png', 16, 16, 0.06)
        },
        projectile = {
            moving = loadAnimation('assets/sprites/player/projectile/moving.png', 50, 50, 0.07),
            explode = loadAnimation('assets/sprites/player/projectile/explode.png', 50, 50, 0.06)
        },
        enemies = {
            worm = {
                walk = loadAnimation('assets/sprites/level1/worm/walk.png', 90, 90, 0.08),
                attack = loadAnimation('assets/sprites/level1/worm/attack.png', 90, 90, 0.05),
                hit = loadAnimation('assets/sprites/level1/worm/get_hit.png', 90, 90, 0.08),
                death = loadAnimation('assets/sprites/level1/worm/death.png', 90, 90, 0.08)
            },
            fireball = {
                move = loadAnimation('assets/sprites/level1/fire_ball/move.png', 46, 46, 0.07),
                explode = loadAnimation('assets/sprites/level1/fire_ball/explosion.png', 46, 46, 0.06)
            },
            darkball = {
                move = loadAnimation('assets/sprites/level1/dark_ball/move.png', 46, 46, 0.07),
                explode = loadAnimation('assets/sprites/level1/dark_ball/explosion.png', 46, 46, 0.06)
            },
            huntress = {
                idle = loadAnimation('assets/sprites/level2/huntress/character/idle.png', 100, 100, 0.08),
                run = loadAnimation('assets/sprites/level2/huntress/character/run.png', 100, 100, 0.08),
                attack = loadAnimation('assets/sprites/level2/huntress/character/attack.png', 100, 100, 0.05),
                hit = loadAnimation('assets/sprites/level2/huntress/character/get_hit.png', 100, 100, 0.08),
                death = loadAnimation('assets/sprites/level2/huntress/character/death.png', 100, 100, 0.08)
            },
            arrow = {
                move = loadAnimation('assets/sprites/level2/huntress/arrow/move.png', 24, 5, 0.07)
            },
            spear = {
                move = loadAnimation('assets/sprites/level2/boss/spear_move.png', 60, 20, 0.07),
                idle = loadAnimation('assets/sprites/level2/boss/spear.png', 60, 20, 0.07)
            },
            level1Boss = {
                idle = loadAnimation('assets/sprites/level1/boss/idle.png', 250, 250, 0.08),
                run = loadAnimation('assets/sprites/level1/boss/run.png', 250, 250, 0.07),
                attack1 = loadAnimation('assets/sprites/level1/boss/attack_1.png', 250, 250, 0.06),
                attack2 = loadAnimation('assets/sprites/level1/boss/attack_2.png', 250, 250, 0.06),
                hit = loadAnimation('assets/sprites/level1/boss/take_hit.png', 250, 250, 0.08),
                death = loadAnimation('assets/sprites/level1/boss/death.png', 250, 250, 0.08),
                jump = loadAnimation('assets/sprites/level1/boss/jump.png', 250, 250, 0.08),
                fall = loadAnimation('assets/sprites/level1/boss/fall.png', 250, 250, 0.08)
            },
            level2Boss = {
                idle = loadAnimation('assets/sprites/level2/boss/idle.png', 150, 150, 0.08),
                run = loadAnimation('assets/sprites/level2/boss/run.png', 150, 150, 0.07),
                attack1 = loadAnimation('assets/sprites/level2/boss/attack_1.png', 150, 150, 0.06),
                attack2 = loadAnimation('assets/sprites/level2/boss/attack_2.png', 150, 150, 0.06),
                attack3 = loadAnimation('assets/sprites/level2/boss/attack_3.png', 150, 150, 0.06),
                hit = loadAnimation('assets/sprites/level2/boss/take_hit.png', 150, 150, 0.08),
                death = loadAnimation('assets/sprites/level2/boss/death.png', 150, 150, 0.08),
                jump = loadAnimation('assets/sprites/level2/boss/jump.png', 150, 150, 0.08),
                fall = loadAnimation('assets/sprites/level2/boss/fall.png', 150, 150, 0.08)
            }
        }
    }

    push:setupScreen(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, WINDOW_WIDTH, WINDOW_HEIGHT, {
        fullscreen = false,
        resizable = true,
        vsync = true
    })

    Gamestate.switch(Menu)
end

function love.resize(w, h)
    push:resize(w, h)
end

function love.update(dt)
    Gamestate.update(dt)
end

function love.keypressed(key)
    Gamestate.keypressed(key)
end

function love.draw()
    push:start()
        Gamestate.draw()
    push:finish()
end
