local Object = require "engine.lib.classic"
local tableUtils = require "engine.utils.table"

---@class State : Object
---@field initialState table The defaults captured at construction (never mutated)
---@field state table The current state
local State = Object:extend()

--- Creates a state container. The initial table is deep-copied so later `set` calls never
--- touch the defaults and `reset` genuinely restores them.
--- @param initialState table? The default values.
function State:new(initialState)
  self.initialState = tableUtils.deepCopy(initialState or {})
  self.state = tableUtils.deepCopy(self.initialState)
end

--- @param key any
--- @return any
function State:get(key)
  return self.state[key]
end

--- @param key any
--- @param value any
function State:set(key, value)
  self.state[key] = value
end

--- Restores every value to the defaults given at construction.
function State:reset()
  self.state = tableUtils.deepCopy(self.initialState)
end

return State
