-- title: Custom draw()
-- description: Override draw() on a GameObject to render anything with love.graphics, in world space, in sort order.
-- order: 7
-- tags: draw, love.graphics
local Scene = require "engine.Scene"
local GameObject = require "engine.GameObject"
local Vector2 = require "engine.Vector2"
local cacheManager = require "engine.cacheManager"

---@class Radar : GameObject
local Radar = GameObject.extend(GameObject)

function Radar:new()
  Radar.super.new(self, "radar", Vector2(440, 160), 400, 400)
  self.sweep = 0
end

function Radar:update(dt)
  self.sweep = self.sweep + dt * math.pi / 2
end

function Radar:draw()
  local pos = self:getPos()
  local cx, cy = pos.x + self.width / 2, pos.y + self.height / 2
  local radius = self.width / 2
  love.graphics.setLineWidth(2)
  love.graphics.setColor(0.2, 0.55, 0.25, 1)
  for i = 1, 4 do
    love.graphics.circle("line", cx, cy, radius * i / 4, 48)
  end
  love.graphics.line(cx - radius, cy, cx + radius, cy)
  love.graphics.line(cx, cy - radius, cx, cy + radius)
  -- Sweep: a filled wedge made of a triangle fan.
  local points = { cx, cy }
  for i = 0, 12 do
    local a = self.sweep - i * 0.06
    points[#points + 1] = cx + math.cos(a) * radius
    points[#points + 1] = cy + math.sin(a) * radius
  end
  love.graphics.setColor(1, 1, 0, 0.35)
  love.graphics.polygon("fill", points)
  love.graphics.setColor(1, 1, 0, 1)
  love.graphics.line(cx, cy, cx + math.cos(self.sweep) * radius, cy + math.sin(self.sweep) * radius)
  -- Blips at fixed positions.
  for _, blip in ipairs({ { 0.6, 0.3 }, { -0.4, 0.5 }, { 0.2, -0.7 } }) do
    love.graphics.circle("fill", cx + blip[1] * radius, cy + blip[2] * radius, 5, 12)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

---@class GameObjectsCustomDraw : Scene
local Example = Scene.extend(Scene)

function Example:new()
  Example.super.new(self, "game-objects/custom-draw")
  self.backgroundColor = { 0.09, 0.09, 0.13, 1 }
end

function Example:load()
  self.radar = self:addGameObject(Radar())
end

function Example:draw()
  love.graphics.setFont(cacheManager.getFont("body"))
  love.graphics.setColor(0.78, 0.72, 0.75, 1)
  love.graphics.print("Radar:draw() uses love.graphics directly; the scene still culls and sorts it", 48, 48)
  love.graphics.setColor(1, 1, 1, 1)
end

function Example.check(scene, ctx)
  if ctx.done then
    assert(math.abs(scene.radar.sweep - ctx.t * math.pi / 2) < 1e-6, "sweep angle")
  end
end

return Example
