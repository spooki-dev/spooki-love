local cursorManager = {}
local cursors = {}
local currentCursor = "none"

function cursorManager.new(cursorConfig)
  cursors = cursorConfig or {}
end

function cursorManager.setCursor(key)
  local cursor = cursors[key]
  if cursor then
    print("CursorManager:setCursor called with key: " .. tostring(key))
    love.mouse.setCursor(cursor)
    currentCursor = key
  else
    error("CursorManager:setCursor - No cursor found for key: " .. tostring(key))
  end
end

function cursorManager.getCurrentCursor()
  return currentCursor
end

function cursorManager.removeCursor()
  love.mouse.setCursor()
  currentCursor = "none"
end

function cursorManager.resetCursor()
  cursorManager.setCursor(currentCursor)
end

return cursorManager
