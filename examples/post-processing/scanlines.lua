-- title: Scanlines
-- description: A time-driven shader: PostProcessing keeps a running clock and hands it to sendUniforms every frame.
-- order: 2
-- tags: shaders, time, sendUniforms
local Scene = require "engine.Scene"
local GameObject = require "engine.GameObject"
local Vector2 = require "engine.Vector2"
local Vector4 = require "engine.Vector4"
local cacheManager = require "engine.cacheManager"

---@class PostScanlines : Scene
local Example = Scene.extend(Scene)

function Example:new()
  Example.super.new(self, "post-processing/scanlines")
  self.backgroundColor = { 0.05, 0.08, 0.05, 1 }
  self.elapsed = 0
end

function Example:load()
  self.ghost = self:addGameObject(GameObject("ghost", Vector2(560, 240), 16, 16))
  local sheet = cacheManager.getSpritesheet("examples-ghost")
  self.ghost.spritesheet = sheet.image
  self.ghost.quad = sheet.quads.float1
  self.ghost.scaleX, self.ghost.scaleY = 10, 10
  for i = 0, 7 do
    local bar = self:addGameObject(GameObject("bar" .. i, Vector2(160 + i * 120, 500), 100, 120))
    bar.fillColor = Vector4(i / 7, 1 - i / 7, 0.5, 1)
  end
  local hud = GameObject("hud", Vector2(48, 48), 1100, 24)
  hud.layer = "ui"
  hud.text = "Every other pixel row is darkened and a brightness band rolls down the screen."
  hud.textColor = Vector4(0.3, 1, 0.4, 1)
  hud.font = cacheManager.getFont("body")
  self:addGameObject(hud)
end

function Example:update(dt)
  self.elapsed = self.elapsed + dt
  local pos = self.ghost:getPos()
  pos.y = 240 + math.sin(self.elapsed * 2) * 20
  self.ghost:setPos(pos)
end

Example.shaders = function()
  return {
    {
      name = "scanlines",
      shader = love.graphics.newShader("examples/shaders/scanlines.glsl"),
      enabled = true,
      -- `time` is PostProcessing.time, accumulated from dt by the engine.
      sendUniforms = function(shader, time, w, h, uniforms)
        shader:send("time", time)
      end,
    },
  }
end

Example.snapshotTolerance = { channel = 24, ratio = 0.03 }

function Example.check(scene, ctx)
  if ctx.done then
    assert(math.abs(scene.elapsed - ctx.t) < 1e-6, "scene clock")
  end
end

return Example
