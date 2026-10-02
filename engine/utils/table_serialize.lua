--- Serialises a plain-data Lua table to Lua source and back.
---
--- Supported values: numbers (finite), strings, booleans and nested tables of the same.
--- Functions, userdata, threads, NaN, infinities and cyclic tables are rejected.
--- Output is deterministic (keys are sorted), so serialised files diff cleanly.
---
--- Deserialisation evaluates the string as a Lua chunk with an empty environment, so it
--- cannot call any function, but only feed it data this module produced or that you trust.
--- Works on both LuaJIT and PUC Lua 5.1 (the love.js web runtime).

local M = {}

--- Orders keys so output is stable: numbers first (ascending), then strings (alphabetical),
--- then booleans.
local function keyRank(k)
  local t = type(k)
  if t == "number" then return 1 end
  if t == "string" then return 2 end
  return 3
end

local function compareKeys(a, b)
  local ra, rb = keyRank(a), keyRank(b)
  if ra ~= rb then return ra < rb end
  if ra == 3 then return tostring(a) < tostring(b) end
  return a < b
end

local function serializeValue(v, seen)
  local t = type(v)
  if t == "number" then
    if v ~= v or v == math.huge or v == -math.huge then
      error("Cannot serialise non-finite number: " .. tostring(v))
    end
    return string.format("%.17g", v)
  elseif t == "boolean" then
    return tostring(v)
  elseif t == "string" then
    return string.format("%q", v)
  elseif t == "table" then
    return M.serialize(v, seen)
  else
    error("Unsupported value type: " .. t)
  end
end

--- Serialises a table to a Lua table constructor string.
--- @param tbl table The table to serialise.
--- @param seen table? Internal cycle guard; omit when calling.
--- @return string Lua source for the table (for example `{a = 1, b = "x"}`).
function M.serialize(tbl, seen)
  seen = seen or {}
  if seen[tbl] then
    error("Cannot serialise a table that contains itself")
  end
  seen[tbl] = true

  local keys = {}
  for k in pairs(tbl) do
    local kt = type(k)
    if kt ~= "number" and kt ~= "string" and kt ~= "boolean" then
      error("Unsupported key type: " .. kt)
    end
    keys[#keys + 1] = k
  end
  table.sort(keys, compareKeys)

  local parts = {}
  for i = 1, #keys do
    local k = keys[i]
    local key
    if type(k) == "string" and k:match("^[_%a][_%w]*$") then
      key = k
    else
      key = "[" .. serializeValue(k, seen) .. "]"
    end
    parts[#parts + 1] = key .. " = " .. serializeValue(tbl[k], seen)
  end

  seen[tbl] = nil
  return "{" .. table.concat(parts, ", ") .. "}"
end

--- Deserialises a string produced by `serialize`. Never throws.
--- @param str string Lua table constructor source.
--- @return table|nil The table, or nil on failure.
--- @return string|nil An error message when the result is nil.
function M.deserialize(str)
  if type(str) ~= "string" then
    return nil, "expected a string, got " .. type(str)
  end
  -- PUC Lua 5.1 only compiles strings via loadstring; LuaJIT and 5.2+ accept load(string).
  local loadFn = loadstring or load
  local chunk, err = loadFn("return " .. str, "=save")
  if not chunk then
    return nil, tostring(err)
  end
  -- Sandbox the chunk: a data literal needs no globals at all.
  if setfenv then
    setfenv(chunk, {})
  end
  local ok, result = pcall(chunk)
  if not ok then
    return nil, tostring(result)
  end
  if type(result) ~= "table" then
    return nil, "deserialised value is not a table"
  end
  return result
end

return M
