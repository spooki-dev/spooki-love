-- title: Per-frame callbacks
-- description: onFrame callbacks fire when an animation reaches a frame; here each loop leaves a footprint.
-- order: 4
-- tags: AnimationManager, onFrame
local Scene = require "engine.Scene"
local GameObject = require "engine.GameObject"
local Vector2 = require "engine.Vector2"
local cacheManager = require "engine.cacheManager"

---@class Stepper : GameObject
local Stepper = GameObject.extend(GameObject)

function Stepper:new(scene)
  Stepper.super.new(self, "stepper", Vector2(200, 300), 16, 16)
  self.scaleX, self.scaleY = 8, 8
  self.steps = 0
  local stepper = self
  -- The callback table is keyed by frame index within the animation.
  self.animation:add("wave", "examples-ghost", { "wave1", "wave2", "wave3", "wave4" }, {
    [1] = function()
      stepper.steps = stepper.steps + 1
      scene.footprints[#scene.footprints + 1] = stepper:getPos().x + 64
    end,
  }, 8)
  self.animation:set("wave")
end

function Stepper:update(dt)
  self.animation:update(dt)
  self:setPos(self:getPos():add(Vector2(60 * dt, 0)))
end

function Stepper:draw()
  self.animation:draw(self)
end

---@class AnimationFrameCallbacks : Scene
local Example = Scene.extend(Scene)

function Example:new()
  Example.super.new(self, "animation/frame-callbacks")
  self.backgroundColor = { 0.09, 0.09, 0.13, 1 }
  self.footprints = {}
end

function Example:load()
  self.stepper = self:addGameObject(Stepper(self))
end

function Example:draw()
  love.graphics.setFont(cacheManager.getFont("body"))
  love.graphics.setColor(0.78, 0.72, 0.75, 1)
  love.graphics.print("onFrame[1] fires each time the wave loops: steps = " .. self.stepper.steps, 48, 48)
  love.graphics.setColor(1, 1, 0, 0.8)
  for _, x in ipairs(self.footprints) do
    love.graphics.rectangle("fill", x - 6, 440, 12, 6)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

function Example.check(scene, ctx)
  if ctx.done then
    -- 15 frame advances in 2 s at 8 fps; the loop wraps to frame 1 on advances 4, 8 and 12.
    assert(scene.stepper.steps == 3, "expected 3 steps, got " .. scene.stepper.steps)
    assert(#scene.footprints == 3, "one footprint per step")
  end
end

return Example
