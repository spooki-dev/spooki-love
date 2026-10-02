-- title: Easing a value
-- description: The easing curves in engine/utils/easing move four boxes from left to right and back.
-- order: 5
-- tags: easing, inCubic, outCubic, inOutCubic
local Scene = require "engine.Scene"
local GameObject = require "engine.GameObject"
local Vector2 = require "engine.Vector2"
local Vector4 = require "engine.Vector4"
local cacheManager = require "engine.cacheManager"
local easing = require "engine.utils.easing"

local FROM, TO = 300, 1000
local DURATION = 1.5
local CURVES = { "linear", "inCubic", "outCubic", "inOutCubic" }

---@class AnimationTweening : Scene
local Example = Scene.extend(Scene)

function Example:new()
  Example.super.new(self, "animation/tweening")
  self.backgroundColor = { 0.09, 0.09, 0.13, 1 }
  self.elapsed = 0
  self.forward = true
end

function Example:load()
  self.boxes = {}
  for i, name in ipairs(CURVES) do
    local box = self:addGameObject(GameObject("box-" .. name, Vector2(FROM, 160 + (i - 1) * 110), 64, 64))
    box.fillColor = Vector4(1, 1, 0, 1)
    box.curve = easing[name]
    self.boxes[i] = box

    local label = self:addGameObject(GameObject("label-" .. name, Vector2(80, 180 + (i - 1) * 110), 200, 24))
    label.text = name
    label.textColor = Vector4(0.78, 0.72, 0.75, 1)
    label.font = cacheManager.getFont("body")
  end
end

-- Progress 0..1 along the current leg; the easing function reshapes it.
function Example:progress()
  return math.min(1, self.elapsed / DURATION)
end

function Example:update(dt)
  self.elapsed = self.elapsed + dt
  if self.elapsed >= DURATION then
    self.elapsed = self.elapsed - DURATION
    self.forward = not self.forward
  end
  local p = self:progress()
  for _, box in ipairs(self.boxes) do
    local eased = box.curve(self.forward and p or 1 - p)
    local pos = box:getPos()
    pos.x = FROM + (TO - FROM) * eased
    box:setPos(pos)
  end
end

function Example:draw()
  love.graphics.setColor(0.25, 0.25, 0.32, 1)
  love.graphics.setLineWidth(1)
  love.graphics.line(FROM, 140, FROM, 600)
  love.graphics.line(TO + 64, 140, TO + 64, 600)
  love.graphics.setColor(1, 1, 1, 1)
end

function Example.check(scene, ctx)
  local x = function(i) return scene.boxes[i]:getPos().x end
  if ctx.frame == 30 then
    -- A third of the way: ease-in lags, ease-out leads.
    assert(x(2) < x(1) and x(1) < x(3), "inCubic < linear < outCubic at t = 1/3")
  elseif ctx.frame == 89 then
    -- Last frame of the first leg: every box sits exactly where its curve says.
    local p = scene:progress()
    assert(p > 0.98 and scene.forward, "still on the first leg")
    for i = 1, 4 do
      local expected = FROM + (TO - FROM) * easing[CURVES[i]](p)
      assert(math.abs(x(i) - expected) < 1e-6, CURVES[i] .. " position")
    end
    assert(x(3) > x(1) and x(1) > x(2), "ordering holds near the end")
  elseif ctx.done then
    assert(not scene.forward, "second leg is the return")
  end
end

return Example
