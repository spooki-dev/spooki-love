local UIBox = require "engine.ui.UIBox"
local Vector4 = require "engine.Vector4"
local opacity = 1

local red = Vector4(1, 0, 0, opacity)
local yellow = Vector4(1, 1, 0, opacity)
local green = Vector4(0, 1, 0, opacity)

---@class BarFill : UIBox
local BarFill = UIBox.extend(UIBox)

---@param name string The name of the BarFill
---@return BarFill
function BarFill:new(name, width, height)
  local children = {

  }
  local styles = {
    background = green,
    width = (width or 100) .. "%",
    height = height or 10,
  }
  self.percent = width or 100

  BarFill.super.new(self, name .. "BarFill", children, styles)

  return self
end

function BarFill:update()
  local background = green
  if (self.percent <= 33) then
    background = red    -- Red for low values
  elseif (self.percent <= 66) then
    background = yellow -- Yellow
  end
  self.styles = {
    background = background,
    width = self.percent .. "%",
    height = self.styles.height
  }
  self.fillColor = background

  -- Update actual pixel width from parent
  if self.parent then
    local parentPadding = self.parent.styles.padding or {y = 0, w = 0}
    local parentWidth = self.parent.width - (parentPadding.y or 0) - (parentPadding.w or 0)
    self:setWidth(parentWidth * (self.percent / 100))
  end
end

return BarFill
