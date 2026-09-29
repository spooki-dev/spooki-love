local UIBox = require "engine.ui.UIBox"
local UIText = require "engine.ui.UIText"
local Vector4 = require "engine.Vector4"
local BarFill = require "engine.ui.BarFill"

local opacity = 1

local headerStyles = {
  display = "flex",
  flexDirection = "row",
  justifyContent = "space-between",
  margin = Vector4(0, 0, 5, 0),
}

local barContainerStyles = {
  background = Vector4(0.2, 0.2, 0.2, opacity),
  padding = Vector4(2, 2, 2, 2),
  borderRadius = Vector4(5, 5, 5, 5),
}

local labelStyles = {
  font = "small",
}

local valueStyles = {
  textAlign = "right",
  font = "small",
}


---@class UIBar : UIBox
local UIBar = UIBox.extend(UIBox)

---@param name string The name of the UIBar
---@param title string The title of the bar
---@param value string The value to display on the bar
---@param width integer The width of the bar as a percentage integer (e.g., 50 for 50%)
---@param height integer|nil The height of the bar (optional, defaults to 10)
---@return UIBar
function UIBar:new(name, title, value, width, height)
  local uniqueName = name .. "Container"

  self.valueText = UIText(name .. "ValueText", value, valueStyles)
  self.barFill = BarFill(name, width, height)
  -- TODO pass width as integer instead of percent string
  local children = {
    UIBox(name .. "Header", {
      UIText(name .. "Label", title, labelStyles),
      self.valueText,
    }, headerStyles, {
      -- debugMargin = true,
    }),
    UIBox(name .. "BarContainer", {
      self.barFill,
    }, barContainerStyles, {
      -- debugPadding = true,
      -- debugBox = true,
    }),
  }
  local styles = {
  }
  UIBar.super.new(self, uniqueName, children, styles)
  self:updateValue(width, value)
  return self
end

-- Update the bar's fill width and value text
---@param newWidth integer The new width of the bar fill as a percentage integer (e.gameObjectOrName 50 for 50%)
---@param newLabel string The new value text to display
function UIBar:updateValue(newWidth, newLabel)
  self.valueText.text = newLabel
  self.barFill.percent = newWidth
end

return UIBar
