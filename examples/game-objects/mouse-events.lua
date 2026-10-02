-- title: Hover and click
-- description: Objects that define onMouseEntered, onMouseExit and onClick receive mouse events automatically.
-- order: 4
-- tags: onClick, onMouseEntered, onMouseExit
local Scene = require "engine.Scene"
local GameObject = require "engine.GameObject"
local Vector2 = require "engine.Vector2"
local Vector4 = require "engine.Vector4"
local cacheManager = require "engine.cacheManager"

---@class Pad : GameObject
local Pad = GameObject.extend(GameObject)

function Pad:new(name, x)
  Pad.super.new(self, name, Vector2(x, 260), 200, 200)
  self.idle = Vector4(0.25, 0.25, 0.32, 1)
  self.hot = Vector4(1, 1, 0, 1)
  self.fillColor = self.idle
  self.clicks, self.entered, self.exited = 0, 0, 0
end

-- Defining these methods is what registers the object for mouse dispatch.
function Pad:onMouseEntered()
  self.entered = self.entered + 1
  self.fillColor = self.hot
end

function Pad:onMouseExit()
  self.exited = self.exited + 1
  self.fillColor = self.idle
end

function Pad:onClick()
  self.clicks = self.clicks + 1
end

---@class GameObjectsMouse : Scene
local Example = Scene.extend(Scene)

function Example:new()
  Example.super.new(self, "game-objects/mouse-events")
  self.backgroundColor = { 0.09, 0.09, 0.13, 1 }
end

function Example:load()
  self.pads = {}
  for i = 1, 3 do
    self.pads[i] = self:addGameObject(Pad("pad" .. i, 140 + (i - 1) * 300))
  end
end

function Example:draw()
  love.graphics.setFont(cacheManager.getFont("body"))
  love.graphics.setColor(0.78, 0.72, 0.75, 1)
  love.graphics.print("Hover and click the pads", 48, 48)
  for i, pad in ipairs(self.pads) do
    local pos = pad:getPos()
    love.graphics.setColor(0.6, 0.6, 0.65, 1)
    love.graphics.print(string.format("clicks %d  in %d  out %d", pad.clicks, pad.entered, pad.exited), pos.x, pos.y + 216)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

Example.script = {
  { at = 20, mouse = { 540, 360 } },  -- over pad 2
  { at = 40, click = { 540, 360, 1 } },
  { at = 60, mouse = { 640, 100 } },  -- away
  { at = 80, mouse = { 840, 360 } },  -- over pad 3 and stay
}

function Example.check(scene, ctx)
  if ctx.done then
    local p2, p3 = scene.pads[2], scene.pads[3]
    assert(p2.clicks == 1 and p2.entered == 1 and p2.exited == 1,
      string.format("pad 2: clicks %d in %d out %d", p2.clicks, p2.entered, p2.exited))
    assert(p3.entered == 1 and p3.exited == 0 and p3.isMouseOver, "pad 3 should be hovered")
    assert(scene.pads[1].entered == 0, "pad 1 untouched")
  end
end

return Example
