--- Scripted input for the test runner. An example declares
---
---   Example.script = {
---     { at = 2,  press = "move_right" },      -- hold from frame 2
---     { at = 30, release = "move_right" },
---     { at = 40, tap = "action" },             -- press on 40, release on 41
---     { at = 50, mouse = { 640, 360 } },       -- move the mouse
---     { at = 52, click = { 640, 360, 1 } },    -- press and release a button
---     { at = 60, call = function(scene) ... end },
---   }
---
--- Frames are 1-based. Use `at >= 2`: the engine drops input edges on the
--- frame a scene becomes current.
local M = {}

--- Expands taps into press/release pairs and indexes events by frame.
---@param script table[]|nil
---@return table<number, table[]>
function M.compile(script)
  local byFrame = {}
  local function add(frame, event)
    byFrame[frame] = byFrame[frame] or {}
    table.insert(byFrame[frame], event)
  end
  for _, event in ipairs(script or {}) do
    assert(type(event.at) == "number" and event.at >= 1, "script events need `at` (frame number)")
    if event.tap then
      add(event.at, { press = event.tap })
      add(event.at + 1, { release = event.tap })
    else
      add(event.at, event)
    end
  end
  return byFrame
end

--- Fires the events scheduled for a frame. Call before love.update.
---@param compiled table<number, table[]>
---@param frame number
---@param scene Scene
function M.apply(compiled, frame, scene)
  local events = compiled[frame]
  if not events then return end
  local inputMap = require "engine.input.inputMap"
  for _, event in ipairs(events) do
    if event.press then
      inputMap.pressVirtualAction(event.press)
    elseif event.release then
      inputMap.releaseVirtualAction(event.release)
    elseif event.mouse then
      love.mousemoved(event.mouse[1], event.mouse[2], 0, 0, false)
    elseif event.click then
      local x, y, button = event.click[1], event.click[2], event.click[3] or 1
      love.mousemoved(x, y, 0, 0, false)
      love.mousepressed(x, y, button, false, 1)
      love.mousereleased(x, y, button, false, 1)
    elseif event.call then
      event.call(scene, frame)
    else
      error("unknown script event at frame " .. frame)
    end
  end
end

return M
