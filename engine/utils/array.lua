-- Checks if a value exists in an array (sequential table)
-- @param arr table: the array to search
-- @param value any: the value to search for
-- @return boolean: true if value is found, false otherwise
local function array_includes(arr, value)
  for i = 1, #arr do
    if arr[i] == value then
      return true
    end
  end
  return false
end

return {
  array_includes = array_includes
}
