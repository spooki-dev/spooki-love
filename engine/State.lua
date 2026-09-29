local Object = require "engine.lib.classic"

---@class State : Object
---@field initialState table The initial state of the object
---@field state table The current state of the object
local State = Object:extend()

function State:new(initialState)
  self.initialState = initialState
  self.state = initialState
end

function State:get(key)
  return self.state[key]
end

function State:set(key, value)
  self.state[key] = value
end

function State:reset()
  self.state = self.initialState
end

return State
