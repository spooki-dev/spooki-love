local State = require "engine.State"

--- Global game state singleton. Add the fields your game needs here and
--- read/write them with GameState:get(key) / GameState:set(key, value).
---@class GameState : State
local GameState = State({
  timer = 0,
})

return GameState
