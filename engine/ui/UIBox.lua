local GameObject = require "engine.GameObject"
local Vector2 = require "engine.Vector2"
local Vector4 = require "engine.Vector4"

---@class UIBox : GameObject
---@field children table The child game objects of the UIBox
---@field styles table The styles for the UIBox
local UIBox = GameObject.extend(GameObject)

---@param name string The name of the UIBox
---@param children table|nil The child game objects of the UIBox
---@param styles table|nil The styles for the UIBox
---@param options table|nil Additional debugOptions for the UIBox
---@return UIBox
function UIBox:new(name, children, styles, debugOptions)
  UIBox.super.new(self, name)
  self.layer = 'ui'
  self.children = children or {}
  self.styles = styles or {}
  self.fillColor = self.styles.background or self.styles.fillColor -- Default to white
  self.border = self.styles.border or Vector4(0, 0, 0, 0)
  self.borderColor = self.styles.borderColor
  self.isFlexChild = false
  local debug = debugOptions or {}
  if debug then
    self.debugPadding = debug.debugPadding or false
    self.debugMargin = debug.debugMargin or false
    self.debugGap = debug.debugGap or false
    self.debugBox = debug.debugBox or false
  end
  return self
end

function UIBox:load()
  self.drawPriority = self.styles.zIndex or (self.parent.drawPriority or 0) + 1
  self.active = self.styles.display ~= "none"
  local parentPos = self.parent:getPos()
  local parentPadding = self.parent.styles.padding or Vector4(0, 0, 0, 0)

  local defaultX = parentPos and parentPos.x or 0
  local defaultY = parentPos and parentPos.y or 0
  local paddingX = (parentPadding.y + parentPadding.w)

  local stackYPos = defaultY + parentPadding.x
  local stackXPos = defaultX + parentPadding.z
  local padding = self.styles.padding or Vector4(0, 0, 0, 0)
  -- Width is set by the parent when the parent is flex
  if not self.isFlexChild then
    if self.styles.width and string.find(self.styles.width, "%%") then
      local percent = tonumber(self.styles.width:sub(1, -2)) / 100
      self:setWidth((self.parent.width - paddingX) * percent)
    else
      self:setWidth(self.styles.width or (self.parent.width - paddingX))
    end
  end

  self:setHeight(self.styles.height)
  local display = self.styles.display or "block"
  local totalWidth = self.width

  local gap = self.styles.gap or 0
  for _, child in ipairs(self.children) do
    if display == "flex" and self.styles.flexDirection == "row" then
      -- Resolve child width (percentage or number)
      local childW = child.styles.width
      if type(childW) == "string" and string.find(childW, "%%") then
        local percent = tonumber(childW:sub(1, -2)) / 100
        childW = (totalWidth - (gap * (#self.children - 1))) * percent
      elseif type(childW) ~= "number" then
        childW = (totalWidth - (gap * (#self.children - 1))) / #self.children
      end

      local posY = defaultY + padding.x
      if self.styles.justifyContent == "center" then
        local posX = defaultX + (totalWidth / 2) - (childW / 2)
        child:setPos(Vector2(posX, posY))
      else
        child:setPos(Vector2(stackXPos, posY))
      end
      child:setWidth(childW)
      child.isFlexChild = true

      stackXPos = stackXPos + childW
    elseif display == "block" then
      child:setPos(Vector2(defaultX + padding.w, stackYPos + padding.x))
      stackYPos = stackYPos + (child.styles.height or child.height or 0)
      child:setWidth(self.width)
    end
    self:addGameObject(child)
  end
  self:recalculateHeight()
end

function UIBox:recalculateHeight()
  local gap = self.styles.gap or 0
  local padding = self.styles.padding or Vector4(0, 0, 0, 0)
  local paddingY = padding.x + padding.z
  if self.styles.height then
    self:setHeight(self.styles.height + paddingY)
    if self.parent and self.parent.recalculateChildPos then
      self.parent:recalculateChildPos()
    end
    return
  end
  local totalHeight = 0

  -- Absolute children are skipped: they do not contribute to flow height.
  for i, child in ipairs(self.children) do
    if child.styles.position ~= "absolute" then
      local childHeight = child.height or 0
      if self.styles.display == "flex" and self.styles.flexDirection == "row" then
        totalHeight = math.max(totalHeight, childHeight)
      else
        local childMargin = child.styles.margin or Vector4(0, 0, 0, 0)
        local childPadding = child.styles.padding or Vector4(0, 0, 0, 0)
        local marginHeight = childMargin.x + childMargin.z
        local paddingHeight = childPadding.x + childPadding.z
        totalHeight = totalHeight + (childHeight) + marginHeight + paddingHeight
        if i < #self.children then
          totalHeight = totalHeight + gap
        end
      end
    end
  end

  self:setHeight(totalHeight)

  -- Check if the parent has the function, because UiCanvas and Scene dont have it.
  if self.parent and self.parent.recalculateHeight then
    self.parent:recalculateHeight()
  end
  if self.parent and self.parent.recalculateChildPos then
    self.parent:recalculateChildPos()
  end
end

function UIBox:recalculateChildPos()
  local parentPos = self:getPos()
  local padding = self.styles.padding or Vector4(0, 0, 0, 0)
  local paddingX = padding.y + padding.w
  local defaultX = (parentPos and parentPos.x or 0) + padding.w
  local defaultY = (parentPos and parentPos.y or 0) + padding.x
  local totalWidth = self.width - paddingX
  local display = self.styles.display or "block"
  local gap = self.styles.gap or 0
  local stackYPos = defaultY
  local stackXPos = defaultX
  local totalChildWidth = 0


  -- Calculate widths for flex children first block children are full width minus paddingX
  -- Absolute children are skipped here and sized in the positioning pass below.
  for _, child in ipairs(self.children) do
    if child.styles.position ~= "absolute" then
      if display == "flex" and self.styles.flexDirection == "row" then
        if child.styles.width then
          if string.find(child.styles.width, "%%") then
            local percent = tonumber(child.styles.width:sub(1, -2)) / 100
            child:setWidth((totalWidth - (gap * (#self.children - 1))) * percent);
          else
            child:setWidth(child.styles.width)
          end
        else
          child:setWidth((totalWidth - (gap * (#self.children - 1))) / #self.children);
        end
        totalChildWidth = totalChildWidth + child.width
      else
        if child.styles.width then
          if string.find(child.styles.width, "%%") then
            local percent = tonumber(child.styles.width:sub(1, -2)) / 100
            child:setWidth((self.width - paddingX) * percent)
          else
            child:setWidth(child.styles.width)
          end
        else
          child:setWidth(self.width - paddingX)
        end
        totalChildWidth = math.min(totalChildWidth + child.width, self.width - paddingX)
      end
    end
  end

  if display == "flex" and self.styles.flexDirection == "row" and self.styles.justifyContent == "center" then
    stackXPos = defaultX + ((totalWidth - totalChildWidth) / 2)
  end

  -- Calculate child positions
  for _, child in ipairs(self.children) do
    local childMargin = child.styles.margin or Vector4(0, 0, 0, 0)
    if child.styles.position == "absolute" then
      local left = child.styles.left or 0
      local top = child.styles.top or 0
      local right = child.styles.right
      local bottom = child.styles.bottom
      local parentPos = self:getPos()
      if not child.styles.width and right then
        child:setWidth(self.width - (right - left))
      end
      if not child.styles.height and bottom then
        child:setHeight(self.height - (bottom - top))
      end
      child:setPos(parentPos:add(Vector2(child.styles.left or 0, child.styles.top or 0)))
    elseif display == "flex" then
      if self.styles.flexDirection == "row" then
        local x = 0
        local y = 0
        if self.styles.justifyContent == "center" then
          x = stackXPos
          stackXPos = stackXPos + child.width + gap + childMargin.y
        else
          stackXPos = stackXPos + childMargin.w
          x = stackXPos
          stackXPos = stackXPos + child.width + gap + childMargin.y
        end

        if self.styles.alignItems == "center" then
          if self.height then
            y = defaultY + (self.height - child.height) * 0.5
          else
            y = defaultY
          end
        else
          y = defaultY + childMargin.x
        end

        child:setPos(Vector2(x, y))
      end

      child.isFlexChild = true
    elseif display == "block" then
      stackYPos = stackYPos + childMargin.x
      child:setPos(Vector2(stackXPos, stackYPos))

      stackYPos = stackYPos + (child.styles.height or child.height or 0) + gap + childMargin.z
    end
    child:recalculateChildPos()
  end
end

function UIBox:onMouseEntered()
  if not self.styles.hover then return end
  if self.styles.hover.background then
    self.fillColor = self.styles.hover.background
  end
  if self.styles.hover.borderColor then
    self.borderColor = self.styles.hover.borderColor
  end
end

function UIBox:onMouseExit()
  self.fillColor = self.styles.background or self.styles.fillColor
  self.borderColor = self.styles.borderColor
end

return UIBox
