local UIBox = require "engine.ui.UIBox"
local cacheManager = require "engine.cacheManager"
local Vector2 = require "engine.Vector2"
local Vector4 = require "engine.Vector4"

---@class UIText : UIBox
local UIText = UIBox.extend(UIBox)

---@param name string The name of the UIText
---@param children string The text
---@param styles table|nil The styles for the UIText
---@return UIText
function UIText:new(name, children, styles)
  UIText.super.new(self, name, {}, styles)
  self.font = cacheManager.getFont(styles.font or "body")
  self.text = children or ""
  self.textColor = styles.color or Vector4(1, 1, 1, 1)
  return self
end

function UIText:load()
  self.drawPriority = (self.parent.drawPriority or 0) + 1
  local parentPos = self.parent:getPos()
  local parentPadding = self.parent.styles.padding or Vector4(0, 0, 0, 0)
  local defaultX = (parentPos and parentPos.x or 0) + parentPadding.z
  local defaultY = (parentPos and parentPos.y or 0) + parentPadding.w
  local paddingX = (parentPadding.z + parentPadding.x)
  self:setPos(Vector2(defaultX, defaultY))
  local textWidth = self.font:getWidth(self.text)
  self.textAlign = self.styles.textAlign or "left"
  self.width = self.styles.width or (self.parent.width - paddingX)
  self:recalculateHeight()
end

function UIText:recalculateHeight()
  if self.styles.height then
    self.height = self.styles.height
    if self.parent and self.parent.recalculateChildPos then
      self.parent:recalculateChildPos()
    end
    return
  end
  if (self.font == nil) then
    error("Font not set for UIText: " .. self.name)
  end
  local wrapWidth = self.width or 100
  local _, lines = self.font:getWrap(self.text, wrapWidth)
  self.height = #lines * self.font:getHeight()

  -- Check if the parent has the function, because UiCanvas and Scene dont have it.
  if self.parent and self.parent.recalculateHeight then
    self.parent:recalculateHeight()
  end
  if self.parent and self.parent.recalculateChildPos then
    self.parent:recalculateChildPos()
  end
end

return UIText
