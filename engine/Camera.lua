local Vector2 = require "engine.Vector2"

---@class Camera
---@field x number The x position of the cameraBounds
---@field y number The y position of the cameraBounds
---@field zoom number The zoom level of the camera
---@field rotation number The rotation of the camera in radians
local Camera = {}
Camera.__index = Camera

function Camera.new(x, y, zoom)
  local self = setmetatable({}, Camera)
  self.x = x or 0
  self.y = y or 0
  self.zoom = zoom or 1
  self.rotation = 0
  return self
end

function Camera:set()
  love.graphics.push()
  love.graphics.rotate(-self.rotation)
  love.graphics.scale(self.zoom, self.zoom)
  love.graphics.translate(-self.x, -self.y)
end

function Camera:unset()
  love.graphics.pop()
end

function Camera:move(dx, dy)
  self.x = self.x + dx
  self.y = self.y + dy
end

function Camera:setPosition(x, y)
  self.x = x
  self.y = y
end

function Camera:getBounds()
  local bounds = {}
  bounds.top = self.y
  bounds.bottom = (self.y + love.graphics.getHeight())
  bounds.left = self.x
  bounds.right = (self.x + love.graphics.getWidth())
  return bounds
end

function Camera:getPosition()
  return self.x, self.y
end

--- Gets the world position of the camera
---@return number
---@return number
function Camera:getWorldPosition()
  return self.x / self.zoom, self.y / self.zoom
end

function Camera:getWorldMousePosition()
  local mouseX, mouseY = love.mouse.getPosition()
  return Vector2(mouseX, mouseY):divide(Vector2(self.zoom, self.zoom)):add(Vector2(self.x, self.y))
end

function Camera:worldToScreen(worldX, worldY)
  return (worldX - self.x) * self.zoom, (worldY - self.y) * self.zoom
end

function Camera:setZoom(zoom)
  self.zoom = zoom
end

function Camera:getZoom()
  return self.zoom
end

function Camera:followTarget(target, width, height)
  -- Center the camera on the target
  local windowWidth, windowHeight = love.graphics.getDimensions()

  -- Calculate the center of the targets coordinates
  local pos = target.getPos and target:getPos() or target:getPos()
  local targetCenterX = pos.x + (target.width / 2)
  local targetCenterY = pos.y + (target.height / 2)

  -- calculate the center of the window
  local halfWindowWidth = windowWidth / 2
  local halfWindowHeight = windowHeight / 2

  -- Adjust for zoom
  local halfScreenWorldWidth = halfWindowWidth / self.zoom
  local halfScreenWorldHeight = halfWindowHeight / self.zoom

  -- Position camera to the center of the target
  local camX = targetCenterX - halfScreenWorldWidth
  local camY = targetCenterY - halfScreenWorldHeight
  if width and height then
    -- Limit camera position to prevent showing beyond the map boundaries
    local rightBound = width - windowWidth / self.zoom
    local bottomBound = height - windowHeight / self.zoom

    -- Keep camera within boundaries
    camX = math.max(0, math.min(camX, rightBound))
    camY = math.max(0, math.min(camY, bottomBound))
  end

  self:setPosition(camX, camY)
end

return Camera
