local Object = require "engine.lib.classic"

---@class Vector4 : Object
---@field x number
---@field y number
---@field z number
---@field w number
local Vector4 = Object:extend()

function Vector4:new(x, y, z, w)
  self.x = x or 0
  self.y = y or 0
  self.z = z or 0
  self.w = w or 0
end

function Vector4:unpack()
  return self.x, self.y, self.z, self.w
end

function Vector4:clone()
  return Vector4(self.x, self.y, self.z, self.w)
end

function Vector4:__tostring()
  return string.format("Vector4(%f, %f, %f, %f)", self.x, self.y, self.z, self.w)
end

return Vector4
