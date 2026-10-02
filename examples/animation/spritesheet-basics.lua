-- title: Spritesheet quads
-- description: A spritesheet preloaded with named frames; each frame is drawn by setting spritesheet and quad on an object.
-- order: 1
-- tags: cacheManager, preloadSpritesheet, quad
local Scene = require "engine.Scene"
local GameObject = require "engine.GameObject"
local Vector2 = require "engine.Vector2"
local Vector4 = require "engine.Vector4"
local cacheManager = require "engine.cacheManager"

-- The sheet was preloaded by the examples runner as:
--   cacheManager.preloadSpritesheet("examples-ghost", "examples/assets/ghost.png", 16, 16,
--     { "float1", "float2", "float3", "float4", "wave1", "wave2", "wave3", "wave4" })
-- Frames are numbered left to right, top to bottom, and keyed by the names given.
local FRAMES = { "float1", "float2", "float3", "float4", "wave1", "wave2", "wave3", "wave4" }

---@class AnimationSpritesheet : Scene
local Example = Scene.extend(Scene)

function Example:new()
  Example.super.new(self, "animation/spritesheet-basics")
  self.backgroundColor = { 0.09, 0.09, 0.13, 1 }
end

function Example:load()
  local sheet = cacheManager.getSpritesheet("examples-ghost")
  for i, key in ipairs(FRAMES) do
    local x = 80 + (i - 1) * 144
    local frame = GameObject("frame-" .. key, Vector2(x, 240), 16, 16)
    frame.spritesheet = sheet.image
    frame.quad = sheet.quads[key]
    frame.scaleX, frame.scaleY = 6, 6
    self:addGameObject(frame)

    local label = GameObject("label-" .. key, Vector2(x - 40, 340), 96, 24)
    label.text = key
    label.textColor = Vector4(0.6, 0.6, 0.65, 1)
    label.font = cacheManager.getFont("body")
    label.textAlign = "center"
    self:addGameObject(label)
  end

  -- The whole sheet, unscaled, for reference.
  local whole = GameObject("sheet", Vector2(80, 480), 128, 16)
  whole.image = "examples-ghost-image"
  whole.scaleX, whole.scaleY = 4, 4
  whole.positionOrigin = Vector2(-1.5, -1.5) -- scaling is about the centre; shift so the top-left lands at pos
  self:addGameObject(whole)
end

function Example:draw()
  love.graphics.setFont(cacheManager.getFont("body"))
  love.graphics.setColor(0.78, 0.72, 0.75, 1)
  love.graphics.print("Eight 16x16 frames from one 128x16 sheet, drawn at 6x", 48, 48)
  love.graphics.print("The source image at 4x:", 80, 440)
  love.graphics.setColor(1, 1, 1, 1)
end

function Example.check(scene, ctx)
  if ctx.done then
    local sheet = cacheManager.getSpritesheet("examples-ghost")
    assert(scene:getGameObject("frame-wave2").quad == sheet.quads.wave2, "quad lookup by key")
    local x, y = sheet.quads.wave2:getViewport()
    assert(x == 16 * 5 and y == 0, "wave2 is the sixth frame")
    local pos = cacheManager.getSpritePosition(128, 16, 16, 5)
    assert(pos[1] == 80 and pos[2] == 0, "getSpritePosition")
  end
end

return Example
