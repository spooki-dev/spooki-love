local UIBox = require "engine.ui.UIBox"

---@class UIStack : UIBox
local UIStack = UIBox.extend(UIBox)

---@param name string The name of the UIBox
---@param children table|nil The child game objects of the UIBox
---@param styles table|nil The styles for the UIBox
---@param options table|nil Additional debugOptions for the UIBox
---@return UIStack
function UIStack:new(name, children, styles, options)
  styles.display = "flex"
  styles.flexDirection = "row"
  UIStack.super.new(self, name, children, styles, options)
end

return UIStack
