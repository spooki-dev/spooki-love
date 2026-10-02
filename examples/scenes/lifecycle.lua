-- title: Lifecycle hooks
-- description: The order in which load, start and update run on a scene and its game objects, logged on screen.
-- order: 2
-- tags: scene, load, start, update
local Scene = require "engine.Scene"
local GameObject = require "engine.GameObject"
local Vector2 = require "engine.Vector2"
local Vector4 = require "engine.Vector4"
local cacheManager = require "engine.cacheManager"

---@class LoggingObject : GameObject
local LoggingObject = GameObject.extend(GameObject)

function LoggingObject:new(log)
  LoggingObject.super.new(self, "logger", Vector2(48, 200), 64, 64)
  self.fillColor = Vector4(1, 1, 0, 1)
  self.log = log
end

-- Called once by the scene when the object is added (Scene:addGameObject runs handleLoad).
function LoggingObject:load()
  table.insert(self.log, "object load")
end

-- Called when the scene becomes current (Scene:start calls every object's start).
function LoggingObject:start()
  table.insert(self.log, "object start")
end

---@class ScenesLifecycle : Scene
local Example = Scene.extend(Scene)

function Example:new()
  Example.super.new(self, "scenes/lifecycle")
  self.backgroundColor = { 0.09, 0.09, 0.13, 1 }
  self.log = {}
  self.updates = 0
end

-- Runs once, when the scene is registered (sceneManager.addScene).
function Example:load()
  table.insert(self.log, "load")
  self:addGameObject(LoggingObject(self.log))
end

-- Runs each time the scene becomes current. Call the parent so objects get their start().
function Example:start()
  Example.super.start(self)
  table.insert(self.log, "start")
end

function Example:update(dt)
  self.updates = self.updates + 1
  if self.updates == 1 then
    table.insert(self.log, "update")
  end
end

function Example:draw()
  love.graphics.setFont(cacheManager.getFont("header"))
  love.graphics.setColor(1, 1, 0, 1)
  love.graphics.print("Lifecycle order", 48, 48)
  love.graphics.setFont(cacheManager.getFont("body"))
  for i, entry in ipairs(self.log) do
    love.graphics.setColor(0.78, 0.72, 0.75, 1)
    love.graphics.print(i .. ". " .. entry, 160, 184 + (i - 1) * 24)
  end
  love.graphics.setColor(0.6, 0.6, 0.65, 1)
  love.graphics.print("updates: " .. self.updates, 160, 184 + (#self.log) * 24 + 12)
  love.graphics.setColor(1, 1, 1, 1)
end

function Example.check(scene, ctx)
  if ctx.frame == 1 then
    assert(table.concat(scene.log, ",") == "load,object load,object start,start,update",
      "unexpected order: " .. table.concat(scene.log, ","))
  end
  if ctx.done then
    assert(scene.updates == ctx.frame, "update should run once per frame")
  end
end

return Example
