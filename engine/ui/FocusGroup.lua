local Object = require "engine.lib.classic"
local inputMap = require "engine.input.inputMap"

--- Keyboard/gamepad navigation over a set of focusable UI objects. One group
--- per scene (scenes coexist, so this is a class, not a singleton). Items
--- need `focus()`, `blur()` and `activate()`; `Button` and the Controls
--- scene's binding cells provide them. Mouse hover syncs focus when the item
--- calls `group:setFocus(self)` from its onMouseEntered.
---
---   self.focus = FocusGroup({ columns = 2 })
---   self.focus:add(startButton):add(quitButton)
---   function Menu:update(dt) self.focus:update(dt) end   -- reads ui_* actions
---
--- Navigation uses the engine's locked ui_up/ui_down/ui_left/ui_right/ui_accept
--- actions and repeats while a direction is held.
---@class FocusGroup
local FocusGroup = Object:extend()

local REPEAT_DELAY = 0.4
local REPEAT_RATE = 0.1

---@param opts table|nil { columns = 1, wrap = true, horizontal = false }
function FocusGroup:new(opts)
  opts = opts or {}
  self.items = {}
  self.index = 0
  self.columns = opts.columns or 1
  self.wrap = opts.wrap ~= false
  self.horizontal = opts.horizontal or false -- single row navigated with left/right
  self.enabled = true
  self.holdAction = nil
  self.holdTime = 0
end

--- Adds a focusable item. Returns the group so calls chain.
---@param item table Object with focus(), blur(), activate()
---@return FocusGroup
function FocusGroup:add(item)
  self.items[#self.items + 1] = item
  item.focusGroup = self
  return self
end

--- Removes every item (blurring the focused one).
function FocusGroup:clear()
  local current = self:getFocused()
  if current and current.blur then current:blur() end
  for _, item in ipairs(self.items) do item.focusGroup = nil end
  self.items = {}
  self.index = 0
end

--- The focused item, or nil.
---@return table|nil
function FocusGroup:getFocused()
  return self.items[self.index]
end

--- Focuses an item (by reference or index). Blurs the previous one.
---@param target table|number
function FocusGroup:setFocus(target)
  local index = target
  if type(target) ~= "number" then
    index = nil
    for i, item in ipairs(self.items) do
      if item == target then index = i end
    end
  end
  if not index or not self.items[index] or index == self.index then return end
  local previous = self.items[self.index]
  if previous and previous.blur then previous:blur() end
  self.index = index
  local item = self.items[index]
  if item.focus then item:focus() end
end

--- Removes focus from the current item.
function FocusGroup:blur()
  local previous = self.items[self.index]
  if previous and previous.blur then previous:blur() end
  self.index = 0
end

--- Moves focus by a number of items (negative = backwards). Skips items whose
--- `active` is false. Wraps around when `wrap` is set.
---@param delta number
function FocusGroup:move(delta)
  local count = #self.items
  if count == 0 then return end
  if self.index == 0 then
    self:setFocus(delta >= 0 and 1 or count)
    return
  end
  local index = self.index
  for _ = 1, count do
    index = index + delta
    if index < 1 then
      if not self.wrap then return end
      index = index + count
    elseif index > count then
      if not self.wrap then return end
      index = index - count
    end
    local item = self.items[index]
    if item and item.active ~= false then
      self:setFocus(index)
      return
    end
  end
end

--- Activates the focused item (its onClick, via activate()).
function FocusGroup:activate()
  local item = self:getFocused()
  if item and item.activate and item.active ~= false then
    item:activate()
  end
end

local function stepFor(self, action)
  if self.horizontal then
    if action == "ui_left" then return -1 end
    if action == "ui_right" then return 1 end
    return nil
  end
  if action == "ui_up" then return -self.columns end
  if action == "ui_down" then return self.columns end
  if self.columns > 1 then
    if action == "ui_left" then return -1 end
    if action == "ui_right" then return 1 end
  end
  return nil
end

local DIRECTIONS = { "ui_up", "ui_down", "ui_left", "ui_right" }

--- Polls the ui_* actions. Call from the owning scene's update(dt).
---@param dt number
function FocusGroup:update(dt)
  if not self.enabled or #self.items == 0 or inputMap.isCapturing() then
    self.holdAction = nil
    return
  end
  for _, action in ipairs(DIRECTIONS) do
    local step = stepFor(self, action)
    if step then
      if inputMap.pressed(action) then
        self:move(step)
        self.holdAction = action
        self.holdTime = -REPEAT_DELAY
      elseif self.holdAction == action and inputMap.down(action) then
        self.holdTime = self.holdTime + dt
        if self.holdTime >= REPEAT_RATE then
          self.holdTime = self.holdTime - REPEAT_RATE
          self:move(step)
        end
      elseif self.holdAction == action then
        self.holdAction = nil
      end
    end
  end
  if inputMap.pressed("ui_accept") then
    self:activate()
  end
end

return FocusGroup
