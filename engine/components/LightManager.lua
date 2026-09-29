-- engine/components/LightManager.lua


local Shadows = require("engine.lib.shadows")
local LightWorld = require("engine.lib.shadows.LightWorld")
local Light = require("engine.lib.shadows.Light")
local hexToColor = require("engine.utils.hexcolor")

---@class LightManager
---@field lights table A list of light sources
---@field ambient number The darkness level (0 = no darkness, 1 = full black)
---@field ambientColour table The color of the ambient light (RGB normalized to [0,1])
---@field _lightCanvas love.Canvas The canvas used for lighting effects
---@field _clampShader love.Shader Shader to clamp light values to [0,1]
---@field scene Scene The scene this LightManager belongs to
---@field world LightWorld The light world used for managing lights
local LightManager = {}
LightManager.__index = LightManager

function LightManager:new(scene)
  local self = setmetatable({}, LightManager)
  self.scene = scene or nil
  self.world = LightWorld:new()
  self.lights = {}
  self._largestLightRadius = 0
  self.ambient = 0.8
  local r, g, b = unpack(hexToColor.hexToIntegerColor('#3d515b'))
  self.world:SetColor(r, g, b, 255) -- Set the default color to the ambient color
  return self
end

function LightManager:addLight(x, y, radius, color, intensity, id)
  local r, g, b = unpack(color or { 255, 255, 255 })
  local camera = self.scene and self.scene.camera or nil
  if not camera then
    error("LightManager requires a scene with a camera to add lights.")
  end
  local radiusl = radius
  local light = Light:new(self.world, radiusl)
  local xl, yl = camera:worldToScreen(x, y)
  light:SetPosition(xl, yl)
  light:SetColor(r, g, b, 255)

  self.lights[id] = light
  if radiusl > self._largestLightRadius then
    self._largestLightRadius = radiusl
  end
end

function LightManager:updateLightPosition(id, x, y)
  local light = self.lights[id]
  if light then
    local xl, yl = self.scene.camera:worldToScreen(x, y)
    light:SetPosition(xl, yl)
  end
end

function LightManager:update(dt)
  -- Ensure LightWorld canvas is large enough for the largest light and screen
  local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
  local minW = math.max(screenW, self._largestLightRadius * 2)
  local minH = math.max(screenH, self._largestLightRadius * 2)
  if self.world.Width ~= minW or self.world.Height ~= minH then
    self.world:Resize(minW, minH)
  end
  self.world:Update()
end

function LightManager:draw()
  -- local x, y = self.scene.camera:getWorldPosition()
  -- local padding = 0
  -- self.world:SetPosition(x - padding, y - padding)
  self.world:Draw()
end

return LightManager
