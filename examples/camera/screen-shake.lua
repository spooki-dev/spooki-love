-- title: Screen shake
-- description: Trauma-based shake: offsets the camera by seeded random amounts that decay back to rest.
-- order: 4
-- tags: camera, love.math.random
local Scene = require "engine.Scene"
local GameObject = require "engine.GameObject"
local Vector2 = require "engine.Vector2"
local Vector4 = require "engine.Vector4"
local cacheManager = require "engine.cacheManager"

local MAX_OFFSET = 24
local DECAY = 1.2 -- trauma per second

---@class CameraShake : Scene
local Example = Scene.extend(Scene)

function Example:new()
  Example.super.new(self, "camera/screen-shake")
  self.backgroundColor = { 0.09, 0.09, 0.13, 1 }
  self.trauma = 0
  self.peak = 0
end

function Example:load()
  for i = 0, 7 do
    local pillar = self:addGameObject(GameObject("pillar" .. i, Vector2(120 + i * 150, 240), 60, 260))
    pillar.fillColor = Vector4(0.25, 0.25, 0.32, 1)
  end
  local core = self:addGameObject(GameObject("core", Vector2(608, 328), 64, 64))
  core.fillColor = Vector4(1, 1, 0, 1)
  local hud = GameObject("hud", Vector2(48, 48), 1100, 24)
  hud.layer = "ui"
  hud.text = "Space / A shakes the camera. Shake = trauma^2 x " .. MAX_OFFSET .. " px, decaying " .. DECAY .. "/s"
  hud.textColor = Vector4(0.78, 0.72, 0.75, 1)
  hud.font = cacheManager.getFont("body")
  self:addGameObject(hud)
end

function Example:onActionPressed(name)
  if name == "action" then
    self.trauma = 1
  end
end

function Example:update(dt)
  self.trauma = math.max(0, self.trauma - DECAY * dt)
  local shake = self.trauma * self.trauma * MAX_OFFSET
  -- love.math.random is seeded by the runner, so tests see the same shake every run.
  local ox = (love.math.random() * 2 - 1) * shake
  local oy = (love.math.random() * 2 - 1) * shake
  self.peak = math.max(self.peak, math.abs(ox), math.abs(oy))
  self.camera:setPosition(ox, oy)
end

Example.script = {
  { at = 30, tap = "action" },
}

function Example.check(scene, ctx)
  if ctx.frame == 35 then
    assert(scene.trauma > 0.8, "trauma right after the press")
  elseif ctx.done then
    -- 90 frames of decay at 1.2/s removes 1.8 trauma: fully settled.
    assert(scene.trauma == 0, "trauma decayed")
    assert(scene.camera.x == 0 and scene.camera.y == 0, "camera back at rest")
    assert(scene.peak > 4, "the shake was visible")
  end
end

return Example
