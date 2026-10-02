-- title: Layers and Y-sorting
-- description: Ground, entities and ui layers; entities sort by their feet so a ghost passes behind, then in front of, a tree.
-- order: 4
-- tags: layers, ysortOffset, drawPriority
local Scene = require "engine.Scene"
local GameObject = require "engine.GameObject"
local Vector2 = require "engine.Vector2"
local Vector4 = require "engine.Vector4"
local cacheManager = require "engine.cacheManager"

local TILE = 64

---@class ScenesLayers : Scene
local Example = Scene.extend(Scene)

function Example:new()
  Example.super.new(self, "scenes/layers-and-ysort")
  self.backgroundColor = { 0.09, 0.09, 0.13, 1 }
end

function Example:load()
  -- Ground: a checkerboard. Objects default to the "entities" layer; set `layer` before adding.
  for row = 0, 10 do
    for col = 0, 19 do
      local tile = GameObject(string.format("tile-%d-%d", col, row), Vector2(col * TILE, row * TILE), TILE, TILE)
      tile.layer = "ground"
      local shade = (col + row) % 2 == 0 and 0.16 or 0.13
      tile.fillColor = Vector4(shade, shade + 0.04, shade, 1)
      self:addGameObject(tile)
    end
  end

  -- A tall tree: trunk at the bottom, so sort by its feet (ysortOffset = height).
  self.tree = self:addGameObject(GameObject("tree", Vector2(608, 232), 64, 160))
  self.tree.fillColor = Vector4(0.2, 0.55, 0.25, 1)
  self.tree.ysortOffset = self.tree.height

  -- A ghost drifting down the screen across the tree.
  self.ghost = self:addGameObject(GameObject("ghost", Vector2(624, 120), 32, 32))
  self.ghost.fillColor = Vector4(1, 1, 0, 1)
  self.ghost.ysortOffset = self.ghost.height

  -- UI layer: screen space, drawn after the camera is unset, ordered by drawPriority.
  local label = GameObject("label", Vector2(48, 48), 1100, 24)
  label.layer = "ui"
  label.text = "ui layer: Y-sorted entities below, ground beneath"
  label.textColor = Vector4(1, 1, 0, 1)
  label.font = cacheManager.getFont("body")
  label.drawPriority = 10
  self:addGameObject(label)
end

function Example:update(dt)
  local pos = self.ghost:getPos()
  pos.y = pos.y + 150 * dt
  if pos.y > 460 then pos.y = 120 end
  self.ghost:setPos(pos)
end

local function count(objects)
  local n = 0
  for _ in pairs(objects) do n = n + 1 end
  return n
end

function Example.check(scene, ctx)
  if ctx.frame == 1 then
    assert(count(scene.layers.ground.objects) == 11 * 20, "ground tiles")
    assert(count(scene.layers.entities.objects) == 2, "entities")
    assert(count(scene.layers.ui.objects) == 1, "ui")
  end
  if ctx.done then
    -- After 2 s the ghost's feet (y + 32) are below the tree's feet, so it draws in front.
    local ghostFeet = scene.ghost:getPos().y + scene.ghost.ysortOffset
    local treeFeet = scene.tree:getPos().y + scene.tree.ysortOffset
    assert(ghostFeet > treeFeet, string.format("ghost feet %.1f should be below tree feet %.1f", ghostFeet, treeFeet))
  end
end

return Example
