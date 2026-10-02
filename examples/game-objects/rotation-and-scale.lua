-- title: Rotation, scale and flip
-- description: Sprites from a spritesheet quad drawn with rotation, rotationOrigin, scaleX/scaleY and flipX.
-- order: 5
-- tags: rotation, scaleX, flipX, spritesheet
local Scene = require "engine.Scene"
local GameObject = require "engine.GameObject"
local Vector2 = require "engine.Vector2"
local Vector4 = require "engine.Vector4"
local cacheManager = require "engine.cacheManager"

local SPIN = math.pi / 2 -- radians per second

local function ghost(name, x, y)
  local sheet = cacheManager.getSpritesheet("examples-ghost")
  local object = GameObject(name, Vector2(x, y), 16, 16)
  object.spritesheet = sheet.image
  object.quad = sheet.quads.float1
  object.scaleX, object.scaleY = 6, 6
  return object
end

local function caption(scene, name, x, y, text)
  local label = GameObject(name, Vector2(x - 100, y), 300, 24)
  label.text = text
  label.textColor = Vector4(0.6, 0.6, 0.65, 1)
  label.font = cacheManager.getFont("body")
  label.textAlign = "center"
  scene:addGameObject(label)
end

---@class GameObjectsRotation : Scene
local Example = Scene.extend(Scene)

function Example:new()
  Example.super.new(self, "game-objects/rotation-and-scale")
  self.backgroundColor = { 0.09, 0.09, 0.13, 1 }
end

function Example:load()
  self.plain = self:addGameObject(ghost("plain", 150, 280))
  caption(self, "c1", 150, 420, "scale 6")

  self.spinner = self:addGameObject(ghost("spinner", 400, 280))
  caption(self, "c2", 400, 420, "rotation (centre)")

  self.corner = self:addGameObject(ghost("corner", 650, 280))
  self.corner.rotationOrigin = Vector2(0, 0) -- rotate around the top-left of the sprite
  caption(self, "c3", 650, 420, "rotationOrigin (0, 0)")

  self.flipped = self:addGameObject(ghost("flipped", 900, 280))
  self.flipped.flipX = true
  caption(self, "c4", 900, 420, "flipX")

  self.stretched = self:addGameObject(ghost("stretched", 1100, 280))
  self.stretched.scaleX, self.stretched.scaleY = 9, 4
  caption(self, "c5", 1100, 420, "scaleX 9, scaleY 4")
end

function Example:update(dt)
  self.spinner.rotation = (self.spinner.rotation or 0) + SPIN * dt
  self.corner.rotation = (self.corner.rotation or 0) + SPIN * dt
end

function Example.check(scene, ctx)
  if ctx.done then
    assert(math.abs(scene.spinner.rotation - SPIN * ctx.t) < 1e-6, "rotation should be angular speed x time")
    assert(scene.flipped.flipX and scene.plain.flipX == false, "flip flags")
    assert(scene.stretched.scaleX == 9 and scene.stretched.scaleY == 4, "scale kept")
  end
end

return Example
