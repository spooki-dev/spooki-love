local function getTableSize(t)
  local count = 0
  for _ in pairs(t) do
    count = count + 1
  end
end

return {
  getTableSize = getTableSize
}
