-- title: Chaining shaders
-- description: Several shaders run in order over the frame; each definition can be toggled with its enabled flag.
-- order: 3
-- tags: shaders, chain, enabled
local Scene = require "engine.Scene"
local GameObject = require "engine.GameObject"
local Vector2 = require "engine.Vector2"
local Vector4 = require "engine.Vector4"
local cacheManager = require "engine.cacheManager"

-- The live definitions, so the scene can flip `enabled` at runtime.
local chain = {}

---@class PostChain : Scene
local Example = Scene.extend(Scene)

function Example:new()
  Example.super.new(self, "post-processing/shader-chain")
  self.backgroundColor = { 0.16, 0.16, 0.22, 1 }
end

function Example:load()
  for i = 0, 11 do
    local block = self:addGameObject(GameObject("block" .. i, Vector2(64 + i * 96, 200 + (i % 3) * 110), 80, 300))
    block.fillColor = Vector4(0.9 - i * 0.05, 0.3 + i * 0.05, 0.4 + (i % 2) * 0.3, 1)
  end
  local hud = GameObject("hud", Vector2(48, 48), 1100, 24)
  hud.layer = "ui"
  hud.textColor = Vector4(1, 1, 1, 1)
  hud.font = cacheManager.getFont("body")
  hud.text = ""
  function hud:update()
    self.text = string.format("Space / A: vignette %s.  Shift / X: scanlines %s.  Shaders run in order: vignette, scanlines.",
      chain.vignette and chain.vignette.enabled and "on" or "off",
      chain.scanlines and chain.scanlines.enabled and "on" or "off")
  end

  self:addGameObject(hud)
end

function Example:onActionPressed(name)
  if name == "action" and chain.vignette then
    chain.vignette.enabled = not chain.vignette.enabled
  elseif name == "secondary" and chain.scanlines then
    chain.scanlines.enabled = not chain.scanlines.enabled
  end
end

function Example:updateShaderUniforms(uniforms, dt)
  uniforms.strength = 1
end

Example.shaders = function()
  chain.vignette = {
    name = "vignette",
    shader = love.graphics.newShader("examples/shaders/vignette.glsl"),
    enabled = true,
    sendUniforms = function(shader, time, w, h, uniforms) shader:send("strength", uniforms.strength or 0) end,
  }
  chain.scanlines = {
    name = "scanlines",
    shader = love.graphics.newShader("examples/shaders/scanlines.glsl"),
    enabled = true,
    sendUniforms = function(shader, time) shader:send("time", time) end,
  }
  return { chain.vignette, chain.scanlines }
end

Example.snapshotTolerance = { channel = 24, ratio = 0.03 }

Example.script = {
  { at = 30, tap = "action" },
  { at = 60, tap = "secondary" },
  { at = 90, tap = "secondary" },
}

function Example.check(scene, ctx)
  if ctx.frame == 45 then
    assert(chain.vignette.enabled == false and chain.scanlines.enabled == true, "vignette off after the first press")
  elseif ctx.frame == 75 then
    assert(chain.scanlines.enabled == false, "scanlines off")
  elseif ctx.done then
    assert(chain.vignette.enabled == false and chain.scanlines.enabled == true, "final state")
  end
end

return Example
