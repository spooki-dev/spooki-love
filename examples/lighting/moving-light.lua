-- title: A moving light
-- description: updateLightPosition moves a light each frame so a torch follows the player through the dark.
-- order: 2
-- tags: LightManager, updateLightPosition
local Scene = require "engine.Scene"
local GameObject = require "engine.GameObject"
local Vector2 = require "engine.Vector2"
local Vector4 = require "engine.Vector4"
local cacheManager = require "engine.cacheManager"
local inputMap = require "engine.input.inputMap"
local LightManager = require "engine.components.LightManager"

local SPEED = 240

---@class LightingMovingLight : Scene
local Example = Scene.extend(Scene)

function Example:new()
  Example.super.new(self, "lighting/moving-light")
  self.backgroundColor = { 0.3, 0.3, 0.36, 1 }
end

function Example:load()
  for row = 0, 5 do
    for col = 0, 9 do
      local tile = GameObject(string.format("tile-%d-%d", col, row), Vector2(col * 128, row * 128), 128, 128)
      tile.layer = "ground"
      local shade = (col + row) % 2 == 0 and 0.5 or 0.44
      tile.fillColor = Vector4(shade + 0.05, shade, shade, 1)
      self:addGameObject(tile)
    end
  end
  for i = 0, 4 do
    local crate = self:addGameObject(GameObject("crate" .. i, Vector2(200 + i * 220, 460 - (i % 2) * 200), 72, 72))
    crate.fillColor = Vector4(0.7, 0.55, 0.35, 1)
  end
  self.player = self:addGameObject(GameObject("player", Vector2(160, 344), 32, 32))
  self.player.fillColor = Vector4(1, 1, 0, 1)

  self.lightManager = LightManager:new(self)
  self.lightManager.world:SetColor(25, 25, 40, 255)
  self.lightManager:addLight(176, 360, 220, { 255, 190, 110 }, 1, "torch")
  self.lightManager:addLight(1100, 150, 160, { 140, 180, 255 }, 1, "window")

  local hud = GameObject("hud", Vector2(48, 48), 1100, 24)
  hud.layer = "ui"
  hud.text = "WASD / arrows / stick: carry the torch. The light's position is updated every frame."
  hud.textColor = Vector4(1, 1, 1, 1)
  hud.font = cacheManager.getFont("body")
  self:addGameObject(hud)
end

function Example:update(dt)
  local dx, dy = inputMap.vector("move_left", "move_right", "move_up", "move_down")
  local pos = self.player:getPos()
  pos.x = math.max(0, math.min(1248, pos.x + dx * SPEED * dt))
  pos.y = math.max(0, math.min(688, pos.y + dy * SPEED * dt))
  self.player:setPos(pos)
  -- World coordinates; the manager converts through the scene camera.
  self.lightManager:updateLightPosition("torch", pos.x + 16, pos.y + 16)
end

Example.snapshotTolerance = { channel = 32, ratio = 0.05 }

Example.script = {
  { at = 2, press = "move_right" },
}

function Example.check(scene, ctx)
  if ctx.done then
    local pos = scene.player:getPos()
    assert(math.abs(pos.x - (160 + 119 * 4)) < 1e-6, "player moved")
    local lx, ly = scene.lightManager.lights.torch:GetPosition()
    local sx, sy = scene.camera:worldToScreen(pos.x + 16, pos.y + 16)
    assert(math.abs(lx - sx) < 1e-6 and math.abs(ly - sy) < 1e-6, string.format("light at %.1f,%.1f expected %.1f,%.1f", lx, ly, sx, sy))
  end
end

return Example
