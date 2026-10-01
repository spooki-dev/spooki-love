local GameObject = require "engine.GameObject"
local Vector2 = require "engine.Vector2"
local Vector4 = require "engine.Vector4"

---@class UICanvas : GameObject
local UICanvas = GameObject.extend(GameObject)

---@param name string The name of the UICanvas
---@param children table|nil The child game objects of the UICanvas
---@param styles table|nil The styles for the UICanvas. Optional `width`/`height` fix the canvas size; otherwise the window size is used.
---@return UICanvas
function UICanvas:new(name, children, styles)
  local pos = Vector2(0, 0)
  local width = styles and styles.width or love.graphics.getWidth()
  local height = styles and styles.height or love.graphics.getHeight()
  UICanvas.super.new(self, name, pos, width, height)
  self.layer = 'ui'
  self.children = children or {}
  self.styles = styles or {}
  self.innerHeight = height
  return self
end

function UICanvas:load()
  local stackYPos = 0
  local padding = self.styles.padding or Vector4(0, 0, 0, 0)
  for _, child in ipairs(self.children) do
    if child.styles.position ~= "absolute" then
      child:setPos(Vector2(0 + padding.y, stackYPos + padding.x))
      stackYPos = stackYPos + (child.styles.height or child.height or 0)
    end
    self:addGameObject(child)
  end
end

function UICanvas:recalculateChildPos()
  local stackYPos = 0
  local padding = self.styles.padding or Vector4(0, 0, 0, 0)
  local totalHeight = 0
  for _, child in ipairs(self.children) do
    if child.styles.position ~= "absolute" then
      child:setPos(Vector2(0 + padding.y, stackYPos + padding.x))
      local padding = child.styles.padding or Vector4(0, 0, 0, 0)
      local margin = child.styles.margin or Vector4(0, 0, 0, 0)
      stackYPos = stackYPos + (child.styles.height or child.height or 0) + padding.x + padding.z
      child:recalculateChildPos()
      totalHeight = stackYPos + margin.x + margin.z
    end
  end
  self.innerHeight = totalHeight + padding.x + padding.z
end

function UICanvas:handleScroll()
  -- print("scrolling")
end

return UICanvas
