local Object = require "engine.lib.classic"

---@class PostProcessing : Object
---@field shaders table[] Ordered list of shader definitions
---@field canvas love.Canvas Primary capture canvas
---@field swapCanvas love.Canvas Ping-pong target canvas
---@field time number Elapsed time for animated uniforms
---@field enabled boolean Global toggle
---@field uniforms table Shared uniform values accessible by all shaders
local PostProcessing = Object:extend()

function PostProcessing:new()
  self.shaders = {}
  self.canvas = nil
  self.swapCanvas = nil
  self.time = 0
  self.enabled = true
  self.uniforms = {}
end

--- Creates canvases at current screen dimensions. Call after window setup.
function PostProcessing:load()
  local w, h = love.graphics.getDimensions()
  self.canvas = love.graphics.newCanvas(w, h)
  self.swapCanvas = love.graphics.newCanvas(w, h)
end

--- Adds a shader definition to the chain.
---@param shaderDef table { name: string, shader: love.Shader, enabled: boolean, sendUniforms: function(shader, time, w, h) }
function PostProcessing:addShader(shaderDef)
  table.insert(self.shaders, shaderDef)
end

--- Removes a shader from the chain by name.
---@param name string
function PostProcessing:removeShader(name)
  for i, def in ipairs(self.shaders) do
    if def.name == name then
      table.remove(self.shaders, i)
      return
    end
  end
end

--- Redirects all subsequent drawing to the capture canvas.
function PostProcessing:beginCapture()
  if not self.enabled or not self.canvas then return end
  love.graphics.setCanvas(self.canvas)
  love.graphics.clear()
end

--- Restores drawing to the backbuffer.
function PostProcessing:endCapture()
  if not self.enabled or not self.canvas then return end
  love.graphics.setCanvas()
end

--- Applies all enabled shaders in sequence, then draws the result to screen.
function PostProcessing:apply()
  if not self.canvas then return end

  if not self.enabled or #self.shaders == 0 then
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.canvas, 0, 0)
    return
  end

  local source = self.canvas
  local dest = self.swapCanvas
  local w, h = source:getDimensions()

  for _, shaderDef in ipairs(self.shaders) do
    if shaderDef.enabled ~= false then
      love.graphics.setCanvas(dest)
      love.graphics.clear()
      love.graphics.setShader(shaderDef.shader)
      shaderDef.sendUniforms(shaderDef.shader, self.time, w, h, self.uniforms)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(source, 0, 0)
      love.graphics.setShader()
      love.graphics.setCanvas()
      source, dest = dest, source
    end
  end

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(source, 0, 0)
end

--- Updates elapsed time for shader animations.
---@param dt number Delta time
function PostProcessing:update(dt)
  self.time = self.time + dt
end

--- Recreates canvases at new dimensions. Wire to love.resize.
---@param w number New width
---@param h number New height
function PostProcessing:resize(w, h)
  self.canvas = love.graphics.newCanvas(w, h)
  self.swapCanvas = love.graphics.newCanvas(w, h)
end

return PostProcessing
