-- title: Moving with dt
-- description: A rectangle moves at a constant speed and bounces off the edges of the window.
-- order: 2
-- tags: GameObject, setPos, update
local Scene = require "engine.Scene"
local GameObject = require "engine.GameObject"
local Vector2 = require "engine.Vector2"
local Vector4 = require "engine.Vector4"

local SPEED = 600
local SIZE = 48

---@class Ball : GameObject
local Ball = GameObject.extend(GameObject)

function Ball:new()
  Ball.super.new(self, "ball", Vector2(100, 300), SIZE, SIZE)
  self.fillColor = Vector4(1, 1, 0, 1)
  self.borderRadius = Vector4(8, 8, 8, 8)
  self.velocity = Vector2(SPEED, SPEED * 0.25)
  self.bounces = 0
end

function Ball:update(dt)
  local pos = self:getPos():add(self.velocity:scale(dt))
  local w, h = love.graphics.getDimensions()
  if pos.x < 0 or pos.x + SIZE > w then
    self.velocity.x = -self.velocity.x
    pos.x = math.max(0, math.min(pos.x, w - SIZE))
    self.bounces = self.bounces + 1
  end
  if pos.y < 0 or pos.y + SIZE > h then
    self.velocity.y = -self.velocity.y
    pos.y = math.max(0, math.min(pos.y, h - SIZE))
    self.bounces = self.bounces + 1
  end
  self:setPos(pos)
end

---@class GameObjectsMovement : Scene
local Example = Scene.extend(Scene)

function Example:new()
  Example.super.new(self, "game-objects/movement")
  self.backgroundColor = { 0.09, 0.09, 0.13, 1 }
end

function Example:load()
  self.ball = self:addGameObject(Ball())
end

function Example.check(scene, ctx)
  if ctx.done then
    -- 10 px per frame from x=100: the right wall (x=1232) is hit on frame 114,
    -- then six frames back: 1232 - 60 = 1172. 2.5 px per frame in y never reaches an edge.
    local pos = scene.ball:getPos()
    assert(scene.ball.bounces == 1, "expected one bounce, got " .. scene.ball.bounces)
    assert(math.abs(pos.x - 1172) < 1e-6, "unexpected x after bounce: " .. pos.x)
    assert(math.abs(pos.y - 600) < 1e-6, "unexpected y: " .. pos.y)
  end
end

return Example
