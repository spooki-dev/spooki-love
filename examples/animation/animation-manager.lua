-- title: Playing an animation
-- description: Every GameObject owns an AnimationManager: add frames, set one, update it each frame and draw it.
-- order: 2
-- tags: AnimationManager, play, pause
local Scene = require "engine.Scene"
local GameObject = require "engine.GameObject"
local Vector2 = require "engine.Vector2"
local cacheManager = require "engine.cacheManager"

local FRAME_RATE = 8

---@class Ghost : GameObject
local Ghost = GameObject.extend(GameObject)

function Ghost:new(name, x, paused)
  Ghost.super.new(self, name, Vector2(x, 260), 16, 16)
  self.scaleX, self.scaleY = 8, 8
  -- add(name, sheetKey, frameKeys, onFrame, frameRate)
  self.animation:add("float", "examples-ghost", { "float1", "float2", "float3", "float4" }, nil, FRAME_RATE)
  self.animation:set("float")
  if paused then self.animation:pause() end
end

-- The manager is not updated or drawn for you; do both from the object.
function Ghost:update(dt)
  self.animation:update(dt)
end

function Ghost:draw()
  self.animation:draw(self)
end

---@class AnimationManagerExample : Scene
local Example = Scene.extend(Scene)

function Example:new()
  Example.super.new(self, "animation/animation-manager")
  self.backgroundColor = { 0.09, 0.09, 0.13, 1 }
end

function Example:load()
  self.playing = self:addGameObject(Ghost("playing", 360, false))
  self.paused = self:addGameObject(Ghost("paused", 760, true))
end

function Example:onActionPressed(name)
  if name == "action" then
    -- Toggle the paused ghost.
    if self.paused.animation.state == "playing" then
      self.paused.animation:pause()
    else
      self.paused.animation:play()
    end
  end
end

function Example:draw()
  love.graphics.setFont(cacheManager.getFont("body"))
  love.graphics.setColor(0.78, 0.72, 0.75, 1)
  love.graphics.print("Left: playing at " .. FRAME_RATE .. " fps.  Right: paused on frame 1 (Space / A toggles).", 48, 48)
  love.graphics.setColor(0.6, 0.6, 0.65, 1)
  love.graphics.print("frame " .. self.playing.animation:getCurrentFrame(), 380, 420)
  love.graphics.print(self.paused.animation.state .. ", frame " .. self.paused.animation:getCurrentFrame(), 780, 420)
  love.graphics.setColor(1, 1, 1, 1)
end

function Example.check(scene, ctx)
  if ctx.done then
    -- 8 fps at dt 1/60 advances every 8 frames: 15 advances in 120 frames, 15 % 4 = 3 -> frame 4.
    assert(scene.playing.animation:getCurrentFrame() == 4,
      "expected frame 4, got " .. scene.playing.animation:getCurrentFrame())
    assert(scene.paused.animation:getCurrentFrame() == 1 and scene.paused.animation.state == "paused", "paused ghost")
  end
end

return Example
