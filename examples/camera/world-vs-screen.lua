-- title: World versus screen space
-- description: The camera scrolls; entities move with it while objects on the ui layer stay fixed on screen.
-- order: 3
-- tags: camera, layers, ui
local Scene = require "engine.Scene"
local GameObject = require "engine.GameObject"
local Vector2 = require "engine.Vector2"
local Vector4 = require "engine.Vector4"
local cacheManager = require "engine.cacheManager"

local SCROLL = 60 -- px per second

---@class CameraWorldVsScreen : Scene
local Example = Scene.extend(Scene)

function Example:new()
  Example.super.new(self, "camera/world-vs-screen")
  self.backgroundColor = { 0.09, 0.09, 0.13, 1 }
end

function Example:load()
  -- World: posts every 160 px so the scroll is visible.
  for i = 0, 15 do
    local post = self:addGameObject(GameObject("post" .. i, Vector2(i * 160, 300), 24, 200))
    post.fillColor = Vector4(0.2, 0.55, 0.25, 1)
    local sign = self:addGameObject(GameObject("sign" .. i, Vector2(i * 160 - 20, 260), 64, 24))
    sign.text = tostring(i * 160)
    sign.textColor = Vector4(0.6, 0.6, 0.65, 1)
    sign.font = cacheManager.getFont("body")
    sign.textAlign = "center"
  end
  -- Screen: a HUD panel that never moves.
  self.panel = GameObject("panel", Vector2(48, 48), 520, 80)
  self.panel.layer = "ui"
  self.panel.fillColor = Vector4(0.05, 0.05, 0.07, 0.85)
  self.panel.border = Vector4(2, 2, 2, 2)
  self.panel.borderColor = Vector4(1, 1, 0, 1)
  self:addGameObject(self.panel)
  self.readout = GameObject("readout", Vector2(64, 60), 500, 60)
  self.readout.layer = "ui"
  self.readout.textColor = Vector4(0.78, 0.72, 0.75, 1)
  self.readout.font = cacheManager.getFont("body")
  self.readout.text = ""
  self:addGameObject(self.readout)
end

function Example:update(dt)
  self.camera:move(SCROLL * dt, 0)
  self.readout.text = string.format("ui layer (fixed)\ncamera x = %.0f, posts scroll left", self.camera.x)
end

function Example.check(scene, ctx)
  if ctx.done then
    assert(math.abs(scene.camera.x - SCROLL * ctx.t) < 1e-6, "camera scrolled")
    local pos = scene.panel:getPos()
    assert(pos.x == 48 and pos.y == 48, "ui object position unchanged")
  end
end

return Example
