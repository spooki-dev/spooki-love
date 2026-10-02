-- title: Vignette shader
-- description: A full-screen shader declared on the example; the scene feeds it a uniform each frame through updateShaderUniforms.
-- order: 1
-- tags: shaders, PostProcessing, updateShaderUniforms
local Scene = require "engine.Scene"
local GameObject = require "engine.GameObject"
local Vector2 = require "engine.Vector2"
local Vector4 = require "engine.Vector4"
local cacheManager = require "engine.cacheManager"

---@class PostVignette : Scene
local Example = Scene.extend(Scene)

function Example:new()
  Example.super.new(self, "post-processing/vignette")
  self.backgroundColor = { 0.16, 0.16, 0.22, 1 }
  self.elapsed = 0
  self.strength = 0.9
  self.enabled = true
end

function Example:load()
  for row = 0, 5 do
    for col = 0, 9 do
      local tile = GameObject(string.format("tile-%d-%d", col, row), Vector2(col * 128 + 8, row * 128 + 8), 112, 112)
      tile.fillColor = Vector4(0.3 + col * 0.06, 0.4 + row * 0.08, 0.6, 1)
      self:addGameObject(tile)
    end
  end
  local hud = GameObject("hud", Vector2(48, 48), 1100, 24)
  hud.layer = "ui"
  hud.textColor = Vector4(1, 1, 1, 1)
  hud.font = cacheManager.getFont("body")
  hud.text = ""
  local scene = self
  function hud:update()
    self.text = string.format("Space / A toggles the vignette (%s). Strength %.2f", scene.enabled and "on" or "off",
      scene.strength)
  end

  self:addGameObject(hud)
end

function Example:onActionPressed(name)
  if name == "action" then self.enabled = not self.enabled end
end

function Example:update(dt)
  self.elapsed = self.elapsed + dt
  self.strength = 0.6 + 0.3 * math.sin(self.elapsed)
end

-- The engine clears postProcessing.uniforms every frame and calls this hook on the current scene.
function Example:updateShaderUniforms(uniforms, dt)
  uniforms.strength = self.enabled and self.strength or 0
end

-- Shader definitions for the engine's post-processing chain. A function, so the
-- shader is only compiled when this example runs.
Example.shaders = function()
  return {
    {
      name = "vignette",
      shader = love.graphics.newShader("examples/shaders/vignette.glsl"),
      enabled = true,
      sendUniforms = function(shader, time, w, h, uniforms)
        shader:send("strength", uniforms.strength or 0)
      end,
    },
  }
end

-- Shader output differs slightly between GPUs; allow more pixel drift than usual.
Example.snapshotTolerance = { channel = 24, ratio = 0.03 }

function Example.check(scene, ctx)
  if ctx.done then
    local uniforms = {}
    scene:updateShaderUniforms(uniforms, 0)
    assert(math.abs(uniforms.strength - (0.6 + 0.3 * math.sin(ctx.t))) < 1e-6, "uniform follows time")
  end
end

return Example
