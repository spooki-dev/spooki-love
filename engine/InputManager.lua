local Class = require "engine.lib.classic"
local InputManager = Class:extend()

---@class InputManager
function InputManager:new()
  self.keyStates = {}
end

function InputManager:onKeyPressed(key)
  self.keyStates[key] = true
end

function InputManager:onKeyReleased(key)
  self.keyStates[key] = false
end

function InputManager:isKeyPressed(key)
  return self.keyStates[key] or false
end

return InputManager
