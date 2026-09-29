local Object = require "engine.lib.classic"

---@class Vector2
---@field x number The x coordinate
---@field y number The y coordinate
local Vector2 = Object.extend(Object)

---@param x number
---@param y number
function Vector2:new(x, y)
  self.x = x
  self.y = y
end

---@param other Vector2
---@return Vector2
function Vector2:add(other)
  return Vector2(self.x + other.x, self.y + other.y)
end

---@param other Vector2
---@return Vector2
function Vector2:subtract(other)
  return Vector2(self.x - other.x, self.y - other.y)
end

---@param other Vector2
---@return Vector2
function Vector2:multiply(other)
  return Vector2(self.x * other.x, self.y * other.y)
end

---@param other Vector2
---@return Vector2
function Vector2:divide(other)
  return Vector2(self.x / other.x, self.y / other.y)
end

---@return number
function Vector2:magnitude()
  return math.sqrt(self.x * self.x + self.y * self.y)
end

---@return Vector2
function Vector2:normalize()
  local mag = self:magnitude()
  if mag == 0 then
    return Vector2(0, 0)
  else
    return Vector2(self.x / mag, self.y / mag)
  end
end

---@param scalar number
---@return Vector2
function Vector2:scale(scalar)
  return Vector2(self.x * scalar, self.y * scalar)
end

---@param other Vector2
---@return number
function Vector2:dot(other)
  return self.x * other.x + self.y * other.y
end

---@param other Vector2
---@return number
function Vector2:distance(other)
  return math.sqrt((self.x - other.x) ^ 2 + (self.y - other.y) ^ 2)
end

function Vector2:__tostring()
  return string.format("Vector2(%f, %f)", self.x, self.y)
end

return Vector2
