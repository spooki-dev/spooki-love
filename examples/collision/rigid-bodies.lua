-- title: Rigid bodies
-- description: setRigidBody makes setPos refuse moves that would overlap another rigid body; debugShape shows the collision shapes.
-- order: 2
-- tags: setRigidBody, setPos, canMoveTo, debugShape
local Scene = require "engine.Scene"
local GameObject = require "engine.GameObject"
local Vector2 = require "engine.Vector2"
local Vector4 = require "engine.Vector4"
local cacheManager = require "engine.cacheManager"
local inputMap = require "engine.input.inputMap"

local SPEED = 240

---@class CollisionRigid : Scene
local Example = Scene.extend(Scene)

function Example:new()
  Example.super.new(self, "collision/rigid-bodies")
  self.backgroundColor = { 0.09, 0.09, 0.13, 1 }
  self.blocked = 0
end

function Example:load()
  self.player = self:addGameObject(GameObject("player", Vector2(200, 334), 32, 32))
  self.player.fillColor = Vector4(1, 1, 0, 1)
  self.player.debugShape = true
  self.player:setRigidBody(true) -- after adding to the scene so it is tracked in scene.rigidBodies

  self.wall = self:addGameObject(GameObject("wall", Vector2(600, 200), 40, 300))
  self.wall.fillColor = Vector4(0.25, 0.25, 0.32, 1)
  self.wall:setRigidBody(true)

  -- A shape smaller than the drawn box: collisions use the shape, not the sprite.
  self.pillar = self:addGameObject(GameObject("pillar", Vector2(900, 300), 96, 96))
  self.pillar.fillColor = Vector4(0.25, 0.25, 0.32, 1)
  self.pillar:setShape({ x = 24, y = 24, width = 48, height = 48 })
  self.pillar.debugShape = true
  self.pillar:setRigidBody(true)

  self.ghost = self:addGameObject(GameObject("ghost", Vector2(600, 540), 40, 40))
  self.ghost.fillColor = Vector4(0.5, 0.7, 1, 0.6) -- not rigid: can be walked through
end

function Example:update(dt)
  local dx, dy = inputMap.vector("move_left", "move_right", "move_up", "move_down")
  if dx ~= 0 or dy ~= 0 then
    local target = self.player:getPos():add(Vector2(dx * SPEED * dt, dy * SPEED * dt))
    -- setPos returns false (and does nothing) when the move would overlap a rigid body.
    if not self.player:setPos(target) then
      self.blocked = self.blocked + 1
    end
  end
end

function Example:draw()
  love.graphics.setFont(cacheManager.getFont("body"))
  love.graphics.setColor(0.78, 0.72, 0.75, 1)
  love.graphics.print("Move into the wall: blocked moves = " .. self.blocked ..
    ". Green overlays are collision shapes; the blue box is not rigid.", 48, 48)
  love.graphics.setColor(1, 1, 1, 1)
end

Example.script = {
  { at = 2, press = "move_right" },
}

function Example.check(scene, ctx)
  if ctx.done then
    local x = scene.player:getPos().x
    assert(x == 568, "stopped flush against the wall, got " .. x) -- 200 + 92 * 4; the 93rd step is refused
    assert(scene.blocked > 0, "moves were refused")
    assert(scene.player:canMoveTo(100, 334, { scene.wall }) and not scene.player:canMoveTo(580, 334, { scene.wall }),
      "canMoveTo agrees")
  end
end

return Example
