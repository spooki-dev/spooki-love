local UIBox = require "engine.ui.UIBox"
local UIText = require "engine.ui.UIText"
local Vector4 = require "engine.Vector4"
local cursorManager = require "engine.cursorManager"

local green = Vector4(0.5, 1, 0.5, 1)
local blue = Vector4(0.5, 0.5, 1, 1)

--- Clickable, focusable button. Attach behaviour by defining `onClick` on the
--- instance before adding it to a scene; keyboard/gamepad activation goes
--- through the same handler via activate(). Hover and focus share one
--- highlighted look, so a mouse hover moves focus when the button belongs to
--- a FocusGroup (see engine/ui/FocusGroup.lua).
---
---   local start = Button("Start", "Start", { height = 32, font = "small" })
---   function start:onClick() ... end
---
--- Styles (all optional): height (50), font ("small"), color, highlightColor,
--- width, margin, padding.
---@class Button : UIBox
local Button = UIBox.extend(UIBox)

---@param name string Unique name within the scene (the box is named name .. "Button")
---@param label string Text shown on the button
---@param styles table|nil See class notes
---@return Button
function Button:new(name, label, styles)
  styles = styles or {}
  self.color = styles.color or green
  self.highlightColor = styles.highlightColor or blue
  self.focused = false
  self.text = UIText(name .. "Title", label, {
    font = styles.font or "small",
    color = self.color,
    textAlign = "center",
  })
  local children = {
    self.text
  }
  local boxStyles = {
    height = styles.height or 50,
    width = styles.width,
    margin = styles.margin,
    padding = styles.padding,
    border = Vector4(2, 2, 2, 2),
    borderColor = self.color,
    display = "flex",
    flexDirection = "row",
    alignItems = "center",
    justifyContent = "center",
    hover = {
      borderColor = self.highlightColor,
    }
  }
  Button.super.new(self, name .. "Button", children, boxStyles)
  return self
end

--- Changes the label text.
---@param label string
function Button:setLabel(label)
  self.text.text = label
end

--- Applies or removes the highlighted (hovered/focused) look.
---@param on boolean
function Button:setHighlighted(on)
  if on then
    Button.super.onMouseEntered(self)
    self.text.textColor = self.highlightColor
  else
    Button.super.onMouseExit(self)
    self.text.textColor = self.color
  end
end

--- FocusGroup contract: gain focus.
function Button:focus()
  self.focused = true
  self:setHighlighted(true)
end

--- FocusGroup contract: lose focus.
function Button:blur()
  self.focused = false
  self:setHighlighted(false)
end

--- FocusGroup contract: trigger the button as if clicked.
function Button:activate()
  if self.onClick then self:onClick() end
end

function Button:onMouseEntered()
  if self.focusGroup then
    self.focusGroup:setFocus(self)
  else
    self:setHighlighted(true)
  end
  cursorManager.setCursor("active")
end

function Button:onMouseExit()
  if not self.focused then
    self:setHighlighted(false)
  end
  cursorManager.setCursor("default")
end

function Button:onMouseDown()

end

return Button
