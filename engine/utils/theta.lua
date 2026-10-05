--[[
    theta.lua

    Theta* any-angle pathfinding over a tile grid. The grid is grid[y][x]
    with 1 meaning blocked and anything else free; coordinates are whatever
    the grid is indexed by (1-based tiles here) and anything off the grid
    counts as blocked. Paths are lists of {x, y} corner points: Theta* lets a
    node be reached straight from its parent's parent whenever that parent
    can see it, so a path is a few straight runs rather than a staircase.

    Usage:
      local theta = require "engine.utils.theta"
      local path = theta.findPath(grid, { x = 1, y = 1 }, { x = 9, y = 4 })
      -- path[1] is the start, path[#path] the goal, or nil when unreachable

    Line of sight is a supercover Bresenham: a diagonal step also checks the
    two tiles it squeezes between, so a sightline never slips through the
    corner where two blocked tiles touch (a mover with any width would snag).

    The open list is a binary heap and `maxExpansions` (default 4000) caps
    the search, so an unreachable goal on a big map fails fast instead of
    sweeping every tile.
--]]

local theta = {}

local DEFAULT_MAX_EXPANSIONS = 4000

---@param grid table<number, number[]>
---@param x number
---@param y number
---@return boolean
local function blocked(grid, x, y)
  local row = grid[y]
  return row == nil or row[x] == nil or row[x] == 1
end

--- Whether every tile a straight line from (x0, y0) to (x1, y1) touches is free.
---@param grid table<number, number[]>
---@param x0 number
---@param y0 number
---@param x1 number
---@param y1 number
---@return boolean
function theta.lineOfSight(grid, x0, y0, x1, y1)
  local dx = math.abs(x1 - x0)
  local dy = math.abs(y1 - y0)
  local sx = x0 < x1 and 1 or -1
  local sy = y0 < y1 and 1 or -1
  local err = dx - dy
  while true do
    if blocked(grid, x0, y0) then
      return false
    end
    if x0 == x1 and y0 == y1 then
      return true
    end
    local e2 = 2 * err
    local stepX = e2 > -dy
    local stepY = e2 < dx
    if stepX and stepY and (blocked(grid, x0 + sx, y0) or blocked(grid, x0, y0 + sy)) then
      return false
    end
    if stepX then
      err = err - dy
      x0 = x0 + sx
    end
    if stepY then
      err = err + dx
      y0 = y0 + sy
    end
  end
end

---@param ax number
---@param ay number
---@param bx number
---@param by number
---@return number
local function dist(ax, ay, bx, by)
  local dx, dy = ax - bx, ay - by
  return math.sqrt(dx * dx + dy * dy)
end

-- Binary min-heap on `f`. Entries are {f, x, y}; stale entries are skipped on pop.
local function heapPush(heap, entry)
  local n = #heap + 1
  heap[n] = entry
  while n > 1 do
    local parent = math.floor(n / 2)
    if heap[parent][1] <= heap[n][1] then
      break
    end
    heap[parent], heap[n] = heap[n], heap[parent]
    n = parent
  end
end

local function heapPop(heap)
  local n = #heap
  if n == 0 then
    return nil
  end
  local top = heap[1]
  heap[1] = heap[n]
  heap[n] = nil
  n = n - 1
  local i = 1
  while true do
    local l, r = 2 * i, 2 * i + 1
    local smallest = i
    if l <= n and heap[l][1] < heap[smallest][1] then smallest = l end
    if r <= n and heap[r][1] < heap[smallest][1] then smallest = r end
    if smallest == i then
      break
    end
    heap[i], heap[smallest] = heap[smallest], heap[i]
    i = smallest
  end
  return top
end

--- Finds a path from `start` to `goal`, both {x, y} on the grid.
---@param grid table<number, number[]> grid[y][x] == 1 is blocked
---@param start table {x, y}
---@param goal table {x, y}
---@param maxExpansions number|nil Give up after this many nodes, default 4000
---@return table[]|nil path Points {x, y} from start to goal inclusive, or nil
function theta.findPath(grid, start, goal, maxExpansions)
  if blocked(grid, start.x, start.y) or blocked(grid, goal.x, goal.y) then
    return nil
  end
  maxExpansions = maxExpansions or DEFAULT_MAX_EXPANSIONS
  -- Keys pack (x, y) into one number; the stride only has to exceed any x.
  local stride = 1
  for _, row in pairs(grid) do
    if #row + 1 > stride then
      stride = #row + 1
    end
  end
  local function key(x, y)
    return y * stride + x
  end

  local startKey, goalKey = key(start.x, start.y), key(goal.x, goal.y)
  local gScore = { [startKey] = 0 }
  local parentX, parentY = {}, {} -- key -> parent tile
  local closed = {}
  local open = {}
  heapPush(open, { dist(start.x, start.y, goal.x, goal.y), start.x, start.y })

  local expansions = 0
  while true do
    local current = heapPop(open)
    if not current then
      return nil
    end
    local cx, cy = current[2], current[3]
    local ck = key(cx, cy)
    if not closed[ck] then
      closed[ck] = true
      if ck == goalKey then
        local path = {}
        local x, y = cx, cy
        while true do
          table.insert(path, 1, { x = x, y = y })
          local k = key(x, y)
          if k == startKey then
            break
          end
          x, y = parentX[k], parentY[k]
        end
        return path
      end
      expansions = expansions + 1
      if expansions > maxExpansions then
        return nil
      end

      -- Theta*: try to reach each neighbour straight from the current node's
      -- parent when it can see it, otherwise step from the current node.
      local px, py = parentX[ck], parentY[ck]
      local hasParent = px ~= nil
      for i = 1, 4 do
        local nx, ny = cx, cy
        if i == 1 then nx = cx + 1 elseif i == 2 then nx = cx - 1 elseif i == 3 then ny = cy + 1 else ny = cy - 1 end
        if not blocked(grid, nx, ny) then
          local nk = key(nx, ny)
          if not closed[nk] then
            local viaX, viaY, tentative
            if hasParent and theta.lineOfSight(grid, px, py, nx, ny) then
              viaX, viaY = px, py
              tentative = gScore[key(px, py)] + dist(px, py, nx, ny)
            else
              viaX, viaY = cx, cy
              tentative = gScore[ck] + 1
            end
            local known = gScore[nk]
            if not known or tentative < known then
              gScore[nk] = tentative
              parentX[nk], parentY[nk] = viaX, viaY
              heapPush(open, { tentative + dist(nx, ny, goal.x, goal.y), nx, ny })
            end
          end
        end
      end
    end
  end
end

return theta
