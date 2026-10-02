-- title: State container
-- description: engine/State holds game state with get, set and reset; the defaults are deep-copied so reset really restores them.
-- order: 1
-- tags: State, get, set, reset
local Scene = require "engine.Scene"
local cacheManager = require "engine.cacheManager"
local State = require "engine.State"

---@class StateContainer : Scene
local Example = Scene.extend(Scene)

function Example:new()
  Example.super.new(self, "state-and-saves/state-container")
  self.backgroundColor = { 0.09, 0.09, 0.13, 1 }
  self.state = State({ coins = 0, lives = 3, name = "ghost", visited = {} })
end

function Example:onActionPressed(name)
  if name == "action" then
    self.state:set("coins", self.state:get("coins") + 1)
    -- Nested tables are plain values; mutate what get returns.
    table.insert(self.state:get("visited"), "room" .. self.state:get("coins"))
  elseif name == "secondary" then
    self.state:set("lives", self.state:get("lives") - 1)
  elseif name == "pause" then
    self.state:reset()
  end
end

function Example:draw()
  love.graphics.setFont(cacheManager.getFont("body"))
  love.graphics.setColor(0.78, 0.72, 0.75, 1)
  love.graphics.print("Space / A: +1 coin.  Shift / X: -1 life.  P: reset to the defaults.", 48, 48)
  local y = 120
  for _, key in ipairs({ "coins", "lives", "name" }) do
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.print(key, 48, y)
    love.graphics.setColor(0.78, 0.72, 0.75, 1)
    love.graphics.print(tostring(self.state:get(key)), 200, y)
    y = y + 28
  end
  love.graphics.setColor(1, 1, 0, 1)
  love.graphics.print("visited", 48, y)
  love.graphics.setColor(0.78, 0.72, 0.75, 1)
  love.graphics.print(table.concat(self.state:get("visited"), ", "), 200, y)
  love.graphics.setColor(0.6, 0.6, 0.65, 1)
  love.graphics.print("Defaults (never mutated): coins " .. self.state.initialState.coins .. ", visited " ..
    #self.state.initialState.visited, 48, y + 48)
  love.graphics.setColor(1, 1, 1, 1)
end

Example.script = {
  { at = 20, tap = "action" },
  { at = 30, tap = "action" },
  { at = 40, tap = "action" },
  { at = 60, tap = "secondary" },
  { at = 90, tap = "pause" },
  { at = 110, tap = "action" },
}

function Example.check(scene, ctx)
  local state = scene.state
  if ctx.frame == 70 then
    assert(state:get("coins") == 3 and state:get("lives") == 2, "three coins, one life lost")
    assert(#state:get("visited") == 3 and #state.initialState.visited == 0, "defaults untouched by nested mutation")
  elseif ctx.frame == 100 then
    assert(state:get("coins") == 0 and state:get("lives") == 3 and #state:get("visited") == 0, "reset restores defaults")
  elseif ctx.done then
    assert(state:get("coins") == 1, "state keeps working after reset")
  end
end

return Example
