-- title: Theta* pathfinding
-- description: theta.findPath returns any-angle waypoints across a grid of walls; an agent walks the path.
-- order: 2
-- tags: theta, findPath, lineOfSight
local Scene = require "engine.Scene"
local GameObject = require "engine.GameObject"
local Vector2 = require "engine.Vector2"
local Vector4 = require "engine.Vector4"
local cacheManager = require "engine.cacheManager"
local theta = require "engine.utils.theta"

local CELL = 64
local MAP = {
  "....................",
  ".S.......#..........",
  ".........#....####..",
  "...####..#.......#..",
  "......#..#.......#..",
  "......#..#..###..#..",
  "......#.....#....#..",
  "...####.....#....#..",
  "............#...G...",
  "....##########......",
  "....................",
}
local TRAVEL_TIME = 1.5

---@class UtilsTheta : Scene
local Example = Scene.extend(Scene)

function Example:new()
  Example.super.new(self, "utils/theta-pathfinding")
  self.backgroundColor = { 0.09, 0.09, 0.13, 1 }
  -- grid[y][x] == 1 is a wall; anything else is free.
  self.grid = {}
  for y, row in ipairs(MAP) do
    self.grid[y] = {}
    for x = 1, #row do
      local c = row:sub(x, x)
      self.grid[y][x] = c == "#" and 1 or 0
      if c == "S" then self.startCell = { x = x, y = y } end
      if c == "G" then self.goalCell = { x = x, y = y } end
    end
  end
  self.path = theta.findPath(self.grid, self.startCell, self.goalCell)
  self.progress = 0
  self.length = 0
  for i = 2, #(self.path or {}) do
    local a, b = self.path[i - 1], self.path[i]
    self.length = self.length + math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
  end
end

local function centre(cell)
  return (cell.x - 0.5) * CELL, (cell.y - 0.5) * CELL
end

function Example:load()
  for y, row in ipairs(self.grid) do
    for x, v in ipairs(row) do
      if v == 1 then
        local wall = self:addGameObject(GameObject(string.format("wall-%d-%d", x, y), Vector2((x - 1) * CELL, (y - 1) * CELL),
          CELL, CELL))
        wall.fillColor = Vector4(0.25, 0.25, 0.32, 1)
      end
    end
  end
  self.agent = self:addGameObject(GameObject("agent", Vector2(0, 0), 24, 24))
  self.agent.fillColor = Vector4(1, 1, 0, 1)
  self.agent.ysortOffset = 1000
  self:place()
end

-- Position along the path at `progress` (0..1 of total length).
function Example:place()
  local remaining = self.progress * self.length
  for i = 2, #self.path do
    local ax, ay = centre(self.path[i - 1])
    local bx, by = centre(self.path[i])
    local seg = math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2) / CELL
    if remaining <= seg or i == #self.path then
      local t = seg > 0 and math.min(1, remaining / seg) or 1
      self.agent:setPos(Vector2(ax + (bx - ax) * t - 12, ay + (by - ay) * t - 12))
      return
    end
    remaining = remaining - seg
  end
end

function Example:update(dt)
  self.progress = math.min(1, self.progress + dt / TRAVEL_TIME)
  self:place()
end

function Example:draw()
  love.graphics.setLineWidth(3)
  love.graphics.setColor(0.5, 0.7, 1, 0.9)
  for i = 2, #self.path do
    local ax, ay = centre(self.path[i - 1])
    local bx, by = centre(self.path[i])
    love.graphics.line(ax, ay, bx, by)
  end
  for _, cell in ipairs(self.path) do
    local cx, cy = centre(cell)
    love.graphics.circle("fill", cx, cy, 6, 12)
  end
  local sx, sy = centre(self.startCell)
  local gx, gy = centre(self.goalCell)
  love.graphics.setColor(0.3, 0.9, 0.5, 1)
  love.graphics.rectangle("line", sx - 28, sy - 28, 56, 56)
  love.graphics.setColor(0.9, 0.3, 0.3, 1)
  love.graphics.rectangle("line", gx - 28, gy - 28, 56, 56)
  love.graphics.setFont(cacheManager.getFont("body"))
  love.graphics.setColor(0.78, 0.72, 0.75, 1)
  love.graphics.print(string.format("%d waypoints, %.1f cells long. Theta* cuts corners wherever there is line of sight.",
    #self.path, self.length), 48, 8)
  love.graphics.setColor(1, 1, 1, 1)
end

function Example.check(scene, ctx)
  if ctx.frame == 1 then
    local path = scene.path
    assert(path and #path >= 2, "a path was found")
    assert(path[1].x == scene.startCell.x and path[1].y == scene.startCell.y, "starts at S")
    assert(path[#path].x == scene.goalCell.x and path[#path].y == scene.goalCell.y, "ends at G")
    for i = 2, #path do
      assert(theta.lineOfSight(scene.grid, path[i - 1].x, path[i - 1].y, path[i].x, path[i].y), "waypoints see each other")
    end
  elseif ctx.done then
    local gx, gy = centre(scene.goalCell)
    local pos = scene.agent:getPos()
    assert(math.abs(pos.x + 12 - gx) < 1e-6 and math.abs(pos.y + 12 - gy) < 1e-6, "agent arrived at the goal")
  end
end

return Example
