-- title: Trigger zones
-- description: A non-rigid zone detects when the player enters and leaves it using rect overlap tests each frame.
-- order: 4
-- tags: rectsIntersect, trigger, enter, exit
local Scene = require "engine.Scene"
local GameObject = require "engine.GameObject"
local Vector2 = require "engine.Vector2"
local Vector4 = require "engine.Vector4"
local cacheManager = require "engine.cacheManager"
local inputMap = require "engine.input.inputMap"

local SPEED = 240

---@class Zone : GameObject
local Zone = GameObject.extend(GameObject)

function Zone:new(name, x, width)
  Zone.super.new(self, name, Vector2(x, 240), width, 240)
  self.idle = Vector4(0.2, 0.55, 0.25, 0.35)
  self.active = true
  self.fillColor = self.idle
  self.inside = false
  self.entered, self.exited = 0, 0
end

-- Edge detection: compare this frame's overlap with the last.
function Zone:track(other)
  local now = GameObject.rectsIntersect(self:getRect(), other:getRect())
  if now and not self.inside then
    self.entered = self.entered + 1
    self.fillColor = Vector4(1, 1, 0, 0.5)
    if self.onEnter then self:onEnter(other) end
  elseif not now and self.inside then
    self.exited = self.exited + 1
    self.fillColor = self.idle
  end
  self.inside = now
end

---@class CollisionTriggers : Scene
local Example = Scene.extend(Scene)

function Example:new()
  Example.super.new(self, "collision/triggers")
  self.backgroundColor = { 0.09, 0.09, 0.13, 1 }
  self.messages = {}
end

function Example:load()
  self.player = self:addGameObject(GameObject("player", Vector2(100, 344), 32, 32))
  self.player.fillColor = Vector4(1, 1, 0, 1)
  self.player.ysortOffset = 400 -- draw over the zones
  self.zones = { self:addGameObject(Zone("zoneA", 400, 160)), self:addGameObject(Zone("zoneB", 800, 240)) }
  local scene = self
  for _, zone in ipairs(self.zones) do
    function zone:onEnter()
      table.insert(scene.messages, 1, "entered " .. self.name)
    end
  end
end

function Example:update(dt)
  local dx, dy = inputMap.vector("move_left", "move_right", "move_up", "move_down")
  self.player:setPos(self.player:getPos():add(Vector2(dx * SPEED * dt, dy * SPEED * dt)))
  for _, zone in ipairs(self.zones) do zone:track(self.player) end
end

function Example:draw()
  love.graphics.setFont(cacheManager.getFont("body"))
  love.graphics.setColor(0.78, 0.72, 0.75, 1)
  love.graphics.print("Walk through the zones (not rigid: nothing blocks you).", 48, 48)
  for i, zone in ipairs(self.zones) do
    love.graphics.print(string.format("%s: inside %s, entered %d, exited %d", zone.name, tostring(zone.inside),
      zone.entered, zone.exited), 48, 80 + (i - 1) * 24)
  end
  for i, message in ipairs(self.messages) do
    love.graphics.setColor(0.6, 0.6, 0.65, 1 - (i - 1) * 0.3)
    love.graphics.print(message, 48, 560 + (i - 1) * 24)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

Example.script = {
  { at = 2, press = "move_right" },
}

function Example.check(scene, ctx)
  if ctx.done then
    local a, b = scene.zones[1], scene.zones[2]
    -- 119 moves of 4 px: x = 576, past zone A (400..560) and short of zone B (800..).
    assert(scene.player:getPos().x == 576, "player x " .. scene.player:getPos().x)
    assert(a.entered == 1 and a.exited == 1 and not a.inside, string.format("zone A %d/%d", a.entered, a.exited))
    assert(b.entered == 0 and not b.inside, "zone B untouched")
    assert(scene.messages[1] == "entered zoneA", "onEnter callback")
  end
end

return Example
