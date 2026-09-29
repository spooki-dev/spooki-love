-- engine/utils/hexcolor.lua
local Vector4 = require "engine.Vector4"

local function hexToIntegerColor(hex)
  hex = hex:gsub("#", "")
  if #hex == 3 then
    -- Short form: "abc" -> "aabbcc"
    hex = hex:sub(1, 1):rep(2) .. hex:sub(2, 2):rep(2) .. hex:sub(3, 3):rep(2)
  end
  if #hex ~= 6 then
    error("Invalid hex color: " .. tostring(hex))
  end
  local r = tonumber(hex:sub(1, 2), 16) or 0
  local g = tonumber(hex:sub(3, 4), 16) or 0
  local b = tonumber(hex:sub(5, 6), 16) or 0
  return { r, g, b }
end

-- Converts a hex color string (e.g. "#efb571" or "efb571") to a table of normalized RGB values (0-1)
local function hexToDecimalColor(hex)
  local rgb = hexToIntegerColor(hex)
  return { rgb[1] / 255, rgb[2] / 255, rgb[3] / 255 }
end

--- Converts a hex color string (e.g. "#efb571" or "efb571") to a Vector4 color (r, g, b, a) with normalized values (0-1)
--- @param hex string The hex color string
--- @return Vector4 The resulting Vector4 color
local function hexToVec4Color(hex)
  local rgb = hexToIntegerColor(hex)
  return Vector4(rgb[1] / 255, rgb[2] / 255, rgb[3] / 255, 1)
end

return {
  hexToDecimalColor = hexToDecimalColor,
  hexToIntegerColor = hexToIntegerColor,
  hexToVec4Color = hexToVec4Color
}
