local UIBox = require "engine.ui.UIBox"
local UIText = require "engine.ui.UIText"
local Vector4 = require "engine.Vector4"
local cursorManager = require "engine.cursorManager"

local green = Vector4(0.5, 1, 0.5, 1)
local blue = Vector4(0.5, 0.5, 1, 1)

---@class Button : UIBox
local Button = UIBox.extend(UIBox)

---@param name string The name of the Button
---@return Button
function Button:new(name, label)
  print('new button ' .. label)
  self.text = UIText(name .. "Title", label, {
    font = "small",
    color = green,
    textAlign = "center",
  })
  local children = {
    self.text
  }
  local styles = {
    height = 50,
    border = Vector4(2, 2, 2, 2),
    borderColor = green,
    display = "flex",
    flexDirection = "row",
    alignItems = "center",
    justifyContent = "center",
    hover = {
      borderColor = blue,
    }
  }
  -- height and width are set to 0 initially, they will be set later by the text
  Button.super.new(self, name .. "Button", children, styles)
  return self
end

function Button:onMouseEntered()
  Button.super.onMouseEntered(self)
  self.text.textColor = blue
  cursorManager.setCursor("active")
end

function Button:onMouseExit()
  Button.super.onMouseExit(self)
  self.text.textColor = green
  cursorManager.setCursor("default")
end

function Button:onMouseDown()

end

return Button
