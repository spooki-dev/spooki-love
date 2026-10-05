local Vector2 = require "engine.Vector2"
local Object = require "engine.lib.classic"

---@class Camera : Object
---@field x number The x position of the cameraBounds
---@field y number The y position of the cameraBounds
---@field zoom number The zoom level of the camera
---@field rotation number The rotation of the camera in radians
---@field shakeX number Current shake offset in world units, applied only when drawing
---@field shakeY number
local Camera = Object:extend()

-- World units added on every side of the visible area when culling.
local CULL_MARGIN = 32

---@param x number|nil World x, default 0
---@param y number|nil World y, default 0
---@param zoom number|nil Default 1
function Camera:new(x, y, zoom)
  self.x = x or 0
  self.y = y or 0
  self.zoom = zoom or 1
  self.rotation = 0
  -- Screen shake: a random offset that decays to zero over shakeDuration.
  self.shakeAmount = 0
  self.shakeDuration = 0
  self.shakeTime = 0
  self.shakeX = 0
  self.shakeY = 0
end

--- Starts a screen shake. A stronger shake replaces a weaker one in
--- progress; a weaker one leaves the current shake alone.
---@param amount number Peak offset in world units (a few pixels is plenty for pixel art)
---@param duration number Seconds to decay back to still
function Camera:shake(amount, duration)
  duration = duration or 0.15
  local remaining = self:getShakeStrength()
  if amount >= remaining then
    self.shakeAmount = amount
    self.shakeDuration = duration
    self.shakeTime = duration
  end
end

--- Current peak offset the shake can produce, in world units.
---@return number
function Camera:getShakeStrength()
  if self.shakeTime <= 0 or self.shakeDuration <= 0 then
    return 0
  end
  return self.shakeAmount * (self.shakeTime / self.shakeDuration)
end

--- Advances the shake. Scenes call this every frame from Scene:handleUpdate.
---@param dt number
function Camera:update(dt)
  if self.shakeTime <= 0 then
    if self.shakeX ~= 0 or self.shakeY ~= 0 then
      self.shakeX, self.shakeY = 0, 0
    end
    return
  end
  self.shakeTime = math.max(0, self.shakeTime - dt)
  local strength = self:getShakeStrength()
  self.shakeX = (love.math.random() * 2 - 1) * strength
  self.shakeY = (love.math.random() * 2 - 1) * strength
end

--- Stops any shake immediately.
function Camera:stopShake()
  self.shakeTime = 0
  self.shakeX, self.shakeY = 0, 0
end

--- Applies the camera transform. The shake offset is applied here only, so
--- culling, mouse-to-world and worldToScreen all use the steady position.
function Camera:set()
  love.graphics.push()
  love.graphics.rotate(-self.rotation)
  love.graphics.scale(self.zoom, self.zoom)
  love.graphics.translate(-(self.x + self.shakeX), -(self.y + self.shakeY))
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

--- World-space rectangle the camera can see, padded by CULL_MARGIN so objects drawn
--- partly before their position (rotation/position origins) are not culled at the edge.
---@return {top: number, bottom: number, left: number, right: number}
function Camera:getBounds()
  local zoom = self.zoom or 1
  local bounds = {}
  bounds.top = self.y - CULL_MARGIN
  bounds.bottom = self.y + love.graphics.getHeight() / zoom + CULL_MARGIN
  bounds.left = self.x - CULL_MARGIN
  bounds.right = self.x + love.graphics.getWidth() / zoom + CULL_MARGIN
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
