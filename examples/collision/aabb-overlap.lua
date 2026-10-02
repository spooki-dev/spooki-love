-- title: Rectangle overlap
-- description: Axis-aligned overlap tests with rectangleIntersection and GameObject.rectsIntersect, highlighting the shared area.
-- order: 1
-- tags: intersection, rectsIntersect, getRect
local Scene = require "engine.Scene"
local GameObject = require "engine.GameObject"
local Vector2 = require "engine.Vector2"
local Vector4 = require "engine.Vector4"
local cacheManager = require "engine.cacheManager"
local intersection = require "engine.utils.intersection"

---@class CollisionAabb : Scene
local Example = Scene.extend(Scene)

function Example:new()
  Example.super.new(self, "collision/aabb-overlap")
  self.backgroundColor = { 0.09, 0.09, 0.13, 1 }
  self.elapsed = 0
  self.overlapping = false
end

function Example:load()
  self.anchor = self:addGameObject(GameObject("anchor", Vector2(440, 260), 200, 200))
  self.anchor.fillColor = Vector4(0.25, 0.25, 0.32, 1)
  self.mover = self:addGameObject(GameObject("mover", Vector2(400, 300), 120, 120))
  self.mover.fillColor = Vector4(1, 1, 0, 1)
end

function Example:update(dt)
  self.elapsed = self.elapsed + dt
  -- Swing left and right across the anchor.
  local pos = self.mover:getPos()
  pos.x = 400 + 320 * math.sin(self.elapsed * math.pi / 2)
  self.mover:setPos(pos)
  self.overlapping = intersection.rectangleIntersection(self.mover:getRect(), self.anchor:getRect())
  self.anchor.fillColor = self.overlapping and Vector4(0.9, 0.3, 0.3, 1) or Vector4(0.25, 0.25, 0.32, 1)
end

function Example:draw()
  love.graphics.setFont(cacheManager.getFont("body"))
  love.graphics.setColor(0.78, 0.72, 0.75, 1)
  love.graphics.print("rectangleIntersection(mover, anchor) = " .. tostring(self.overlapping), 48, 48)
  if self.overlapping then
    -- The shared area is the intersection of the two rects.
    local a, b = self.mover:getRect(), self.anchor:getRect()
    local x1, y1 = math.max(a.x, b.x), math.max(a.y, b.y)
    local x2, y2 = math.min(a.x + a.width, b.x + b.width), math.min(a.y + a.height, b.y + b.height)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.rectangle("fill", x1, y1, x2 - x1, y2 - y1)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

function Example.check(scene, ctx)
  local truth = GameObject.rectsIntersect(scene.mover:getRect(), scene.anchor:getRect())
  assert(scene.overlapping == truth, "both helpers agree")
  if ctx.frame == 60 then
    assert(not scene.overlapping, "at the far right after 1 s") -- x = 720, anchor ends at 640
  elseif ctx.done then
    assert(scene.overlapping, "back over the anchor after 2 s")
  end
end

return Example
