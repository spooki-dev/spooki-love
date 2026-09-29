-- engine/utils/table_serialize.lua
-- Provides functions to serialize a Lua table to a string and deserialize it back.
-- WARNING: Deserialization uses load(), so only use with trusted data.

local M = {}

-- Serialize a table to a string (Lua code)
function M.serialize(tbl)
  local function serialize_value(v)
    if type(v) == "number" then
      return tostring(v)
    elseif type(v) == "boolean" then
      return tostring(v)
    elseif type(v) == "string" then
      return string.format("%q", v)
    elseif type(v) == "table" then
      return M.serialize(v)
    else
      error("Unsupported value type: " .. type(v))
    end
  end

  local result = "{"
  local first = true
  for k, v in pairs(tbl) do
    if not first then
      result = result .. ", "
    end
    first = false
    local key
    if type(k) == "string" and k:match("^[_%a][_%w]*$") then
      key = k
    else
      key = "[" .. serialize_value(k) .. "]"
    end
    result = result .. key .. " = " .. serialize_value(v)
  end
  result = result .. "}"
  return result
end

-- Deserialize a string (Lua table code) back to a table
function M.deserialize(str)
  local f, err = load("return " .. str)
  if not f then error("Failed to deserialize: " .. tostring(err)) end
  return f()
end

return M
