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
require 'src.Bowser' 
require 'src.Player'
require 'src.Snail'
require 'src.DonkeyKong'
require 'src.Spring'
require 'src.Goomba'
require 'src.Tile'
require 'src.TileMap'
require 'src.Fireball'
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
    ['dk-throw'] = love.audio.newSource('sounds/dk-throw.mp3', 'static'),
    ['break-block'] = love.audio.newSource('sounds/break-block.wav', 'static'),
    ['fireball'] = love.audio.newSource('sounds/fireball.wav', 'static'),
    ['fireball-bounce'] = love.audio.newSource('sounds/fireball-bounce.wav', 'static')
}

gTextures = {
    ['tiles'] = love.graphics.newImage('graphics/tiles.png'),
    ['toppers'] = love.graphics.newImage('graphics/topper.png'),
    ['bushes'] = love.graphics.newImage('graphics/grass.png'),
    ['small-bushes'] = love.graphics.newImage('graphics/bush.png'),
    ['jump-blocks'] = love.graphics.newImage('graphics/Jumpblocks.png'),
    ['bricks'] = love.graphics.newImage('graphics/Brick.png'),
    ['underground-bricks'] = love.graphics.newImage('graphics/Underground Bricks.png'),
    ['gems'] = love.graphics.newImage('graphics/coin.png'),
    ['pipes'] = love.graphics.newImage('graphics/pipes.png'),
    ['powerup'] = love.graphics.newImage('graphics/Powerup.png'),
    ['fire-powerup'] = love.graphics.newImage('graphics/FirePowerup.png'),
    ['mario-powerup'] = love.graphics.newImage('graphics/MarioPowerup.png'),
    ['fire-powerup-big'] = love.graphics.newImage('graphics/FirePowerupBig.png'),
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
    ['fireball'] = love.graphics.newImage('graphics/Fireball.png'),
    ['Underground'] = love.graphics.newImage('graphics/Underground.png'),
    ['UndergroundTop'] = love.graphics.newImage('graphics/Underground Topper.png'),
    ['Cannon'] = love.graphics.newImage('graphics/Cannon.png'),
    ['Rocket'] = love.graphics.newImage('graphics/Rocket.png'),
    ['underwater-bg'] = love.graphics.newImage('graphics/Underwater.png'),
    ['underwater-topper'] = love.graphics.newImage('graphics/Underwater topper.png'),
    ['squid'] = love.graphics.newImage('graphics/Squids.png'),
    ['fish'] = love.graphics.newImage('graphics/Fish.png'),
    ['underwater-ground'] = love.graphics.newImage('graphics/Underwater block.png'),
    ['underwater-brick'] = love.graphics.newImage('graphics/Underwater brick.png'),
    ['coral'] = love.graphics.newImage('graphics/Coral plant.png'),
    ['castle-ground'] = love.graphics.newImage('graphics/Castle Ground.png'),
    ['castle-brick'] = love.graphics.newImage('graphics/Castle Brick.png'),
    ['bowser'] = love.graphics.newImage('graphics/Bowser.png'), 
    ['gate'] = love.graphics.newImage('graphics/Gate.png'),     
    ['princess'] = love.graphics.newImage('graphics/Princess.png'),
    ['mushroom-friend'] = love.graphics.newImage('graphics/Mushroom Friend.png'),
    ['luigi'] = love.graphics.newImage('graphics/Luigi.png'),   
    ['underground-tiles'] = love.graphics.newImage('graphics/Underground.png'), 
    ['underground-pillar'] = love.graphics.newImage('graphics/Underground topper.png'),
    ['particle'] = love.graphics.newImage('graphics/particle.png'),
    ['lava'] = love.graphics.newImage('graphics/lava.png'),
    ['lava-topper'] = love.graphics.newImage('graphics/lava topper.png'),
    ['fire-projectile'] = love.graphics.newImage('graphics/Fire Projectile.png'),

}

gFrames = {
    ['tiles'] = GenerateQuads(gTextures['tiles'], TILE_SIZE, TILE_SIZE),
    ['toppers'] = GenerateQuads(gTextures['toppers'], TILE_SIZE, TILE_SIZE),
    ['bushes'] = GenerateQuads(gTextures['bushes'], 34, 16),
    ['small-bushes'] = GenerateQuads(gTextures['small-bushes'], 16, 16),
    ['jump-blocks'] = GenerateQuads(gTextures['jump-blocks'], 16, 16),
    ['bricks'] = GenerateQuads(gTextures['bricks'], 32, 15), 
    ['underground-bricks'] = GenerateQuads(gTextures['underground-bricks'], 16, 15),
    ['powerup'] = GenerateQuads(gTextures['powerup'], 16, 16),
    ['fire-powerup'] = GenerateQuads(gTextures['fire-powerup'], 16, 16),
    ['mario-powerup'] = GenerateQuads(gTextures['mario-powerup'], 16, 32),
    ['fire-powerup-big'] = GenerateQuads(gTextures['fire-powerup-big'], 16, 32),
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
    ['fireball'] = GenerateQuads(gTextures['fireball'], 16, 16),
    ['underground-tiles'] = GenerateQuads(gTextures['underground-tiles'], 16, 16),
    ['underground-pillar'] = GenerateQuads(gTextures['underground-pillar'], 16, 32),
    ['particle'] = GenerateQuads(gTextures['particle'], 10, 10),
    ['Cannon'] = GenerateQuads(gTextures['Cannon'], 16, 48),
    ['Rocket'] = GenerateQuads(gTextures['Rocket'], 16, 14),
    ['underwater-ground'] = GenerateQuads(gTextures['underwater-ground'], 16, 16),
    ['underwater-brick'] = GenerateQuads(gTextures['underwater-brick'], 16, 16),
    ['coral'] = GenerateQuads(gTextures['coral'], 16, 16),
    ['squid'] = GenerateQuads(gTextures['squid'], 16, 24), 
    ['fish'] = GenerateQuads(gTextures['fish'], 16, 16),
    ['underwater-bg'] = GenerateQuads(gTextures['underwater-bg'], 16, 16),
    ['underwater-topper'] = GenerateQuads(gTextures['underwater-topper'], 16, 16),
    ['castle-ground'] = GenerateQuads(gTextures['castle-ground'], 16, 16),
    ['castle-brick'] = GenerateQuads(gTextures['castle-brick'], 16, 16),
    ['lava'] = GenerateQuads(gTextures['lava'], 16, 16),
    ['lava-topper'] = GenerateQuads(gTextures['lava-topper'], 16, 16),
    ['bowser'] = GenerateQuads(gTextures['bowser'], 32, 32), 
    ['gate'] = GenerateQuads(gTextures['gate'], 16, 16),     
    ['princess'] = GenerateQuads(gTextures['princess'], 16, 24), 
    ['mushroom-friend'] = GenerateQuads(gTextures['mushroom-friend'], 16, 24), 
    ['luigi'] = GenerateQuads(gTextures['luigi'], 16, 16),
    ['fire-projectile'] = GenerateQuads(gTextures['fire-projectile'], 12, 12)
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
