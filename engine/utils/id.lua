---Creates a random ID
local function create_random_id()
  local id = ""
  for i = 1, 8 do
    local char = string.char(math.random(97, 122)) -- Random lowercase letter
    id = id .. char
  end
  return id
end

return {
  create_random_id = create_random_id
}
