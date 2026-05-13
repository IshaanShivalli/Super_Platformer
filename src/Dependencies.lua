Class = require 'lib.class'
push = require 'lib.push'
Timer = require 'lib.knife.knife.timer'
Chain = require 'lib.knife.knife.chain'
require 'src.constants'
require 'src.StateMachine'
require 'src.Util'
require 'src.states.BaseState'
require 'src.states.game.PlayState'
require 'src.states.game.StartState'
require 'src.states.entity.PlayerFallingState'
require 'src.states.entity.PlayerIdleState'
require 'src.states.entity.PlayerJumpState'
require 'src.states.entity.PlayerWalkingState'
require 'src.states.entity.snail.SnailChasingState'
require 'src.states.entity.snail.SnailIdleState'
require 'src.states.entity.snail.SnailMovingState'
require 'src.Animation'
require 'src.Entity'
require 'src.GameObject'
require 'src.GameLevel'
require 'src.LevelMaker'
require 'src.Player'
require 'src.Snail'
require 'src.DonkeyKong'
require 'src.Spring'
require 'src.Goomba'
require 'src.Tile'
require 'src.TileMap'
require 'src.Camera'
require 'src.pipes'


gSounds = {
    ['jump'] = love.audio.newSource('sounds/jump.wav', 'static'),
    ['death'] = love.audio.newSource('sounds/death.wav', 'static'),
    ['music'] = love.audio.newSource('sounds/music.wav', 'static'),
    ['powerup-reveal'] = love.audio.newSource('sounds/powerup-reveal.wav', 'static'),
    ['pickup'] = love.audio.newSource('sounds/pickup.wav', 'static'),
    ['empty-block'] = love.audio.newSource('sounds/empty-block.wav', 'static'),
    ['kill'] = love.audio.newSource('sounds/kill.wav', 'static'),
    ['kill2'] = love.audio.newSource('sounds/kill2.wav', 'static'),
    ['plant'] = love.audio.newSource('sounds/plant.wav', 'static'),
    ['turtleSounds'] = love.audio.newSource('sounds/turtleSounds.mp3', 'static'),
    ['goomba'] = love.audio.newSource('sounds/goomba.mp3', 'static'),
    ['dk-roar'] = love.audio.newSource('sounds/dk-yell.mp3', 'static'),
    ['dk-hit'] = love.audio.newSource('sounds/dk-defeat.m4a', 'static'),
    ['dk-throw'] = love.audio.newSource('sounds/dk-throw.mp3', 'static')
}

gTextures = {
    ['tiles'] = love.graphics.newImage('graphics/tiles.png'),
    ['toppers'] = love.graphics.newImage('graphics/topper.png'),
    ['bushes'] = love.graphics.newImage('graphics/grass.png'),
    ['small-bushes'] = love.graphics.newImage('graphics/bush.png'),
    ['jump-blocks'] = love.graphics.newImage('graphics/Jumpblocks.png'),
    ['gems'] = love.graphics.newImage('graphics/coin.png'),
    ['pipes'] = love.graphics.newImage('graphics/pipes.png'),
    ['backgrounds'] = love.graphics.newImage('graphics/backgrounds.png'),
    ['plants'] = love.graphics.newImage('graphics/plants.png'),
    ['green-alien'] = love.graphics.newImage('graphics/Mariosheet.png'),
    ['creatures'] = love.graphics.newImage('graphics/creatures.png'),
    ['snail'] = love.graphics.newImage('graphics/snail.png'),
    ['pyramid'] = love.graphics.newImage('graphics/pyramid_block.png'),
    ['side-pipe-start'] = love.graphics.newImage('graphics/SidePipeStart.png'),
    ['side-pipe-end'] = love.graphics.newImage('graphics/SidePipe.png'),
    ['spring'] = love.graphics.newImage('graphics/jumpers.png'),
    ['castle'] = love.graphics.newImage('graphics/Castle.png'),
    ['barrels'] = love.graphics.newImage('graphics/DonkeyKong.png'),
    ['donkey-kong'] = love.graphics.newImage('graphics/DonkeyKong.png'),
    ['flagpole'] = love.graphics.newImage('graphics/FlagPole.png'),
    ['flag'] = love.graphics.newImage('graphics/Flag.png'),
    ['Underground'] = love.graphics.newImage('graphics/Underground.png'),
    ['UndergroundTop'] = love.graphics.newImage('graphics/Underground Topper.png'),
    ['Cannon'] = love.graphics.newImage('graphics/Cannon.png'),
    ['Rocket'] = love.graphics.newImage('graphics/Rocket.png'),
    ['underground-tiles'] = love.graphics.newImage('graphics/Underground.png'), -- Assuming Underground.png is 32x16 and contains 2 16x16 frames
    ['underground-pillar'] = love.graphics.newImage('graphics/Underground topper.png') -- Assuming Underground pillar.png is 16x16
}

gFrames = {
    ['tiles'] = GenerateQuads(gTextures['tiles'], TILE_SIZE, TILE_SIZE),
    ['toppers'] = GenerateQuads(gTextures['toppers'], TILE_SIZE, TILE_SIZE),
    ['bushes'] = GenerateQuads(gTextures['bushes'], 34, 16),
    ['small-bushes'] = GenerateQuads(gTextures['small-bushes'], 16, 16),
    ['jump-blocks'] = GenerateQuads(gTextures['jump-blocks'], 16, 16),
    ['gems'] = GenerateGemQuads(gTextures['gems'], 8, 8),
    ['pipes'] = GeneratePipeQuads(gTextures['pipes'], 32, 48),
    ['plants'] = GenerateQuads(gTextures['plants'], 16, 16),
    ['backgrounds'] = GenerateQuads(gTextures['backgrounds'], 256, 128),
    ['green-alien'] = GenerateQuads(gTextures['green-alien'], 16, 16),
    ['creatures'] = GenerateQuads(gTextures['creatures'], 16, 16),
    ['snail'] = GenerateQuads(gTextures['snail'], 16, 16),
    ['pyramid'] = GenerateQuads(gTextures['pyramid'], 16, 16),
    ['side-pipe-start'] = GenerateQuads(gTextures['side-pipe-start'], 34, 32),
    ['side-pipe-end'] = GenerateQuads(gTextures['side-pipe-end'], 34, 32),
    ['spring'] = GenerateSpringQuads(gTextures['spring']),
    ['castle'] = GenerateQuads(gTextures['castle'], 48, 48),
    ['donkey-kong'] = GenerateQuads(gTextures['donkey-kong'], 28, 28),
    ['barrels'] = GenerateQuads(gTextures['donkey-kong'], 14, 14),
    ['flagpole'] = GenerateQuads(gTextures['flagpole'], 2, 16),
    ['flag'] = GenerateQuads(gTextures['flag'], 16, 16),
    ['underground-tiles'] = GenerateQuads(gTextures['underground-tiles'], 16, 16),
    ['underground-pillar'] = GenerateQuads(gTextures['underground-pillar'], 16, 32)
}

gFrames['tilesets'] = GenerateTileSets(gFrames['tiles'],
    TILE_SETS_WIDE, TILE_SETS_TALL, TILE_SET_WIDTH, TILE_SET_HEIGHT)

gFrames['toppersets'] = GenerateTileSets(gFrames['toppers'],
    TOPPER_SETS_WIDE, TOPPER_SETS_TALL, TILE_SET_WIDTH, TILE_SET_HEIGHT)

gFonts = {
    ['small'] = love.graphics.newFont('fonts/font.ttf', 8),
    ['medium'] = love.graphics.newFont('fonts/font.ttf', 16),
    ['large'] = love.graphics.newFont('fonts/font.ttf', 32),
    ['title'] = love.graphics.newFont('fonts/ArcadeAlternate.ttf', 32)
}
