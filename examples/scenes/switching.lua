-- title: Switching scenes
-- description: Registers a second scene at runtime and switches between the two with the action button.
-- order: 3
-- tags: sceneManager, setCurrentScene, addScene
local Scene = require "engine.Scene"
local sceneManager = require "engine.sceneManager"
local cacheManager = require "engine.cacheManager"

local A = "scenes/switching"
local B = "scenes/switching:b" -- extra scenes are named "<id>:<suffix>"

local function switchTo(name)
  -- setCurrentScene throws if the scene is already current, so guard it.
  if sceneManager.getCurrentScene() ~= name then
    sceneManager.setCurrentScene(name)
  end
end

local function banner(title, hint, colour)
  love.graphics.setFont(cacheManager.getFont("header"))
  love.graphics.setColor(colour)
  love.graphics.print(title, 48, 48)
  love.graphics.setFont(cacheManager.getFont("body"))
  love.graphics.setColor(0.78, 0.72, 0.75, 1)
  love.graphics.print(hint, 48, 96)
  love.graphics.setColor(1, 1, 1, 1)
end

---@class SwitchingB : Scene
local SceneB = Scene.extend(Scene)

function SceneB:new()
  SceneB.super.new(self, B)
  self.backgroundColor = { 0.25, 0.08, 0.10, 1 }
  self.visits = 0
end

function SceneB:start()
  SceneB.super.start(self)
  self.visits = self.visits + 1
end

function SceneB:onActionPressed(name)
  if name == "action" or name == "ui_cancel" then switchTo(A) end
end

function SceneB:draw()
  banner("Scene B", "Space / A returns to scene A. Visits: " .. self.visits, { 1, 0.5, 0.5, 1 })
end

---@class ScenesSwitching : Scene
local Example = Scene.extend(Scene)

function Example:new()
  Example.super.new(self, A)
  self.backgroundColor = { 0.08, 0.10, 0.25, 1 }
  self.switches = 0
end

function Example:load()
  -- Scenes can be registered from anywhere; addScene runs the new scene's load() at once.
  sceneManager.addScene(SceneB)
end

function Example:onActionPressed(name)
  if name == "action" then
    self.switches = self.switches + 1
    switchTo(B)
  end
end

function Example:draw()
  banner("Scene A", "Press Space / A to switch to scene B", { 0.5, 0.7, 1, 1 })
end

Example.script = {
  { at = 30, tap = "action" },
}

function Example.check(scene, ctx)
  if ctx.done then
    assert(scene.switches == 1, "expected one switch, got " .. scene.switches)
    assert(sceneManager.getCurrentScene() == B, "scene B should be current")
    assert(sceneManager.getScene(B).visits == 1, "scene B should have started once")
  end
end

return Example
