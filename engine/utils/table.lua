--- Small table helpers shared across the engine.

--- Counts every key in a table (not just the array part).
--- @param t table The table to measure.
--- @return number The number of entries.
local function getTableSize(t)
  local count = 0
  for _ in pairs(t) do
    count = count + 1
  end
  return count
end

--- Recursively copies a table. Handles cycles and shared sub-tables (each source
--- table is copied once) and preserves metatables. Non-table values are returned as-is.
--- @param t any The value to copy.
--- @param seen table? Internal map of already-copied tables; omit when calling.
--- @return any The copy.
local function deepCopy(t, seen)
  if type(t) ~= "table" then
    return t
  end
  seen = seen or {}
  if seen[t] then
    return seen[t]
  end
  local copy = {}
  seen[t] = copy
  for k, v in pairs(t) do
    copy[deepCopy(k, seen)] = deepCopy(v, seen)
  end
  return setmetatable(copy, getmetatable(t))
end

return {
  getTableSize = getTableSize,
  deepCopy = deepCopy,
}
