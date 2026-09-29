--- Easing functions for smooth interpolation
--- All functions take t (0-1) and return an eased value (0-1)

local easing = {}

--- Linear (no easing)
---@param t number 0-1
---@return number
function easing.linear(t)
  return t
end

--- Ease in cubic (slow start)
---@param t number 0-1
---@return number
function easing.inCubic(t)
  return t * t * t
end

--- Ease out cubic (slow end)
---@param t number 0-1
---@return number
function easing.outCubic(t)
  return 1 - (1 - t) ^ 3
end

--- Ease in-out cubic (slow start and end)
---@param t number 0-1
---@return number
function easing.inOutCubic(t)
  if t < 0.5 then return 4 * t * t * t end
  return 1 - ((-2 * t + 2) ^ 3) / 2
end

return easing
