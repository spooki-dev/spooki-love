-- Theta* pathfinding implementation for grid-based navigation
-- Usage: local theta = require "engine.utils.theta"
--        local path = theta.findPath(grid, start, goal)

local theta = {}

-- Bresenham's line of sight for grid
function theta.lineOfSight(grid, x0, y0, x1, y1)
  local dx = math.abs(x1 - x0)
  local dy = math.abs(y1 - y0)
  local sx = x0 < x1 and 1 or -1
  local sy = y0 < y1 and 1 or -1
  local err = dx - dy
  while true do
    if grid[y0] and grid[y0][x0] == 1 then
      return false
    end
    if x0 == x1 and y0 == y1 then break end
    local e2 = 2 * err
    if e2 > -dy then
      err = err - dy; x0 = x0 + sx
    end
    if e2 < dx then
      err = err + dx; y0 = y0 + sy
    end
  end
  return true
end

local function heuristic(a, b)
  return math.abs(a.x - b.x) + math.abs(a.y - b.y)
end

local function key(pos)
  return pos.x .. "," .. pos.y
end

function theta.findPath(grid, start, goal)
  local open = {}
  local closed = {}
  local cameFrom = {}
  local gScore = {}
  local fScore = {}

  gScore[key(start)] = 0
  fScore[key(start)] = heuristic(start, goal)
  table.insert(open, { pos = start, f = fScore[key(start)] })

  while #open > 0 do
    table.sort(open, function(a, b) return a.f < b.f end)
    local current = table.remove(open, 1).pos
    if current.x == goal.x and current.y == goal.y then
      local path = { goal }
      local k = key(goal)
      while cameFrom[k] do
        table.insert(path, 1, cameFrom[k])
        k = key(cameFrom[k])
      end
      return path
    end
    closed[key(current)] = true
    local neighbors = {
      { x = current.x + 1, y = current.y },
      { x = current.x - 1, y = current.y },
      { x = current.x,     y = current.y + 1 },
      { x = current.x,     y = current.y - 1 },
    }
    for _, neighbor in ipairs(neighbors) do
      if grid[neighbor.y] and grid[neighbor.y][neighbor.x] ~= 1 and not closed[key(neighbor)] then
        local parent = cameFrom[key(current)] or current
        local tentative_gScore
        if theta.lineOfSight(grid, parent.x, parent.y, neighbor.x, neighbor.y) then
          tentative_gScore = gScore[key(parent)] + heuristic(parent, neighbor)
        else
          tentative_gScore = gScore[key(current)] + heuristic(current, neighbor)
        end
        if not gScore[key(neighbor)] or tentative_gScore < gScore[key(neighbor)] then
          cameFrom[key(neighbor)] = parent
          gScore[key(neighbor)] = tentative_gScore
          fScore[key(neighbor)] = tentative_gScore + heuristic(neighbor, goal)
          table.insert(open, { pos = neighbor, f = fScore[key(neighbor)] })
        end
      end
    end
  end
  return nil
end

return theta
