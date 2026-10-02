-- title: Rebinding at runtime
-- description: rebind replaces an action's bindings for one device; isDefault and resetToDefaults track changes.
-- order: 4
-- tags: rebind, getBindings, isDefault, resetToDefaults
local Scene = require "engine.Scene"
local cacheManager = require "engine.cacheManager"
local inputMap = require "engine.input.inputMap"
local glyphs = require "engine.input.glyphs"

local ACTION = "action"
local NEW_KEY = "key:j"

---@class InputRebinding : Scene
local Example = Scene.extend(Scene)

function Example:new()
  Example.super.new(self, "input/rebinding")
  self.backgroundColor = { 0.09, 0.09, 0.13, 1 }
  self.message = "Shift / X rebinds `action` to J. P restores the defaults."
end

function Example:onActionPressed(name)
  if name == "secondary" then
    -- Replaces every keyboard/mouse binding of `action` with J (stealing it from
    -- any other action that had it). Returns the names of actions it was taken from.
    local stolen, err = inputMap.rebind(ACTION, NEW_KEY)
    self.message = stolen and ("Rebound to " .. glyphs.label(NEW_KEY) .. (#stolen > 0 and (" (taken from " ..
      table.concat(stolen, ", ") .. ")") or "")) or ("Could not rebind: " .. tostring(err))
  elseif name == "pause" then
    inputMap.resetToDefaults(ACTION)
    self.message = "Defaults restored"
  end
end

local function labels(bindings)
  local out = {}
  for i, binding in ipairs(bindings) do out[i] = glyphs.label(binding) .. " (" .. binding .. ")" end
  return table.concat(out, ", ")
end

function Example:draw()
  love.graphics.setFont(cacheManager.getFont("body"))
  love.graphics.setColor(0.78, 0.72, 0.75, 1)
  love.graphics.print(self.message, 48, 48)
  local y = 140
  for _, action in ipairs(inputMap.getActions()) do
    if not action.locked then
      local isDefault = inputMap.isDefault(action.name)
      love.graphics.setColor(isDefault and 0.6 or 1, isDefault and 0.6 or 1, isDefault and 0.65 or 0, 1)
      love.graphics.print(action.label .. (isDefault and "" or "  *"), 48, y)
      love.graphics.setColor(0.78, 0.72, 0.75, 1)
      love.graphics.print(labels(inputMap.getBindings(action.name, inputMap.DEVICE_KEYBOARD)), 260, y)
      love.graphics.print(labels(inputMap.getBindings(action.name, inputMap.DEVICE_GAMEPAD)), 760, y)
      y = y + 28
    end
  end
  love.graphics.setColor(0.6, 0.6, 0.65, 1)
  love.graphics.print("* = changed from the defaults. Bindings are not saved in the examples runner.", 48, y + 20)
  love.graphics.setColor(1, 1, 1, 1)
end

Example.script = {
  { at = 30, tap = "secondary" },
  { at = 60, tap = "pause" },
  { at = 90, tap = "secondary" },
}

function Example.check(scene, ctx)
  local keyboard = inputMap.getBindings(ACTION, inputMap.DEVICE_KEYBOARD)
  if ctx.frame == 1 then
    assert(#keyboard == 2 and inputMap.isDefault(ACTION), "space and LMB by default")
  elseif ctx.frame == 45 then
    assert(#keyboard == 1 and keyboard[1] == NEW_KEY and not inputMap.isDefault(ACTION), "rebound to J")
    assert(#inputMap.getBindings(ACTION, inputMap.DEVICE_GAMEPAD) == 1, "gamepad binding untouched")
  elseif ctx.frame == 75 then
    assert(inputMap.isDefault(ACTION), "defaults restored")
  elseif ctx.done then
    assert(#keyboard == 1 and keyboard[1] == NEW_KEY, "rebound again")
  end
end

return Example
