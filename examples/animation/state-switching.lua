-- title: Switching animations by state
-- description: A ghost floats when idle and waves while moving, flipping to face the direction of travel.
-- order: 3
-- tags: AnimationManager, set, flipX, inputMap.vector
local Scene = require "engine.Scene"
local GameObject = require "engine.GameObject"
local Vector2 = require "engine.Vector2"
local cacheManager = require "engine.cacheManager"
local inputMap = require "engine.input.inputMap"

local SPEED = 240

---@class Walker : GameObject
local Walker = GameObject.extend(GameObject)

function Walker:new()
  Walker.super.new(self, "walker", Vector2(600, 300), 16, 16)
  self.scaleX, self.scaleY = 8, 8
  self.animation:add("float", "examples-ghost", { "float1", "float2", "float3", "float4" }, nil, 6)
  self.animation:add("wave", "examples-ghost", { "wave1", "wave2", "wave3", "wave4" }, nil, 12)
  self.animation:set("float")
end

function Walker:update(dt)
  local dx, dy = inputMap.vector("move_left", "move_right", "move_up", "move_down")
  if dx ~= 0 or dy ~= 0 then
    self.animation:set("wave") -- set() keeps the frame when the animation is unchanged
    if dx ~= 0 then self.flipX = dx < 0 end
    self:setPos(self:getPos():add(Vector2(dx * SPEED * dt, dy * SPEED * dt)))
  else
    self.animation:set("float")
  end
  self.animation:update(dt)
end

function Walker:draw()
  self.animation:draw(self)
end

---@class AnimationStateSwitching : Scene
local Example = Scene.extend(Scene)

function Example:new()
  Example.super.new(self, "animation/state-switching")
  self.backgroundColor = { 0.09, 0.09, 0.13, 1 }
end

function Example:load()
  self.walker = self:addGameObject(Walker())
end

function Example:draw()
  love.graphics.setFont(cacheManager.getFont("body"))
  love.graphics.setColor(0.78, 0.72, 0.75, 1)
  love.graphics.print("WASD / arrows / stick to move. Animation: " .. self.walker.animation:getCurrentAnimation().name ..
    (self.walker.flipX and " (facing left)" or " (facing right)"), 48, 48)
  love.graphics.setColor(1, 1, 1, 1)
end

Example.script = {
  { at = 2,  press = "move_left" },
  { at = 50, release = "move_left" },
  { at = 70, press = "move_right" },
}

function Example.check(scene, ctx)
  local anim = scene.walker.animation:getCurrentAnimation().name
  if ctx.frame == 40 then
    assert(anim == "wave" and scene.walker.flipX, "moving left: wave, flipped")
  elseif ctx.frame == 60 then
    assert(anim == "float", "idle: float")
  elseif ctx.done then
    assert(anim == "wave" and not scene.walker.flipX, "moving right: wave, not flipped")
    -- 48 frames left then 51 frames right at 4 px per frame.
    assert(math.abs(scene.walker:getPos().x - (600 - 48 * 4 + 51 * 4)) < 1e-6, "position")
  end
end

return Example
