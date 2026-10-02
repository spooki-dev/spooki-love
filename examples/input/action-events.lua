-- title: Action events
-- description: Scenes and game objects receive onActionPressed and onActionReleased callbacks for named actions.
-- order: 2
-- tags: onActionPressed, onActionReleased
local Scene = require "engine.Scene"
local GameObject = require "engine.GameObject"
local Vector2 = require "engine.Vector2"
local Vector4 = require "engine.Vector4"
local cacheManager = require "engine.cacheManager"

---@class Lamp : GameObject
local Lamp = GameObject.extend(GameObject)

function Lamp:new()
  Lamp.super.new(self, "lamp", Vector2(900, 240), 160, 160)
  self.off = Vector4(0.25, 0.25, 0.32, 1)
  self.on = Vector4(1, 1, 0, 1)
  self.fillColor = self.off
  self.borderRadius = Vector4(80, 80, 80, 80)
  self.toggles = 0
end

-- Defining onActionPressed on an object registers it for action dispatch.
function Lamp:onActionPressed(name)
  if name == "action" then
    self.fillColor = self.on
    self.toggles = self.toggles + 1
  end
end

function Lamp:onActionReleased(name)
  if name == "action" then self.fillColor = self.off end
end

---@class InputEvents : Scene
local Example = Scene.extend(Scene)

function Example:new()
  Example.super.new(self, "input/action-events")
  self.backgroundColor = { 0.09, 0.09, 0.13, 1 }
  self.log = {}
  self.pressed, self.released = 0, 0
end

function Example:load()
  self.lamp = self:addGameObject(Lamp())
end

function Example:record(text)
  table.insert(self.log, 1, text)
  if #self.log > 10 then table.remove(self.log) end
end

-- Scene hooks fire for every action, including the engine's locked ui_* ones.
function Example:onActionPressed(name)
  self.pressed = self.pressed + 1
  self:record("pressed  " .. name)
end

function Example:onActionReleased(name)
  self.released = self.released + 1
  self:record("released " .. name)
end

function Example:draw()
  love.graphics.setFont(cacheManager.getFont("body"))
  love.graphics.setColor(0.78, 0.72, 0.75, 1)
  love.graphics.print("Press anything bound to an action. The lamp listens for `action` (Space / A / LMB).", 48, 48)
  love.graphics.print(string.format("pressed %d   released %d", self.pressed, self.released), 48, 96)
  for i, line in ipairs(self.log) do
    love.graphics.setColor(0.6, 0.6, 0.65, 1 - (i - 1) * 0.08)
    love.graphics.print(line, 48, 160 + (i - 1) * 24)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

Example.script = {
  { at = 20, tap = "action" },
  { at = 40, tap = "action" },
  { at = 60, tap = "move_left" },
  { at = 80, tap = "action" },
}

function Example.check(scene, ctx)
  if ctx.frame == 20 then
    assert(scene.lamp.fillColor == scene.lamp.on, "lamp lit on the press frame")
  elseif ctx.frame == 21 then
    assert(scene.lamp.fillColor == scene.lamp.off, "lamp off on the release frame")
  elseif ctx.done then
    assert(scene.pressed == 4 and scene.released == 4, string.format("pressed %d released %d", scene.pressed, scene.released))
    assert(scene.lamp.toggles == 3, "lamp saw three action presses")
  end
end

return Example
