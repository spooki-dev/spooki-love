local Object = require "engine.lib.classic"
local cacheManager = require "engine.cacheManager"
---@class Animation
---@field frames number[] Array of frame indices
---@field name string Name of the animation
---@field sheet string Name of the spritesheet
---@field onFrame table<number, fun()> Optional callbacks for specific frames
---@field frameRate? number Optional frame rate for the animation (default is 4)

---@class AnimationManager : Object
---@field animations table<string, Animation> Table of animations by name
---@field currentAnimation Animation|nil Currently active animation
---@field currentFrame integer Current frame index
---@field frameTime number Time accumulator for frame updates
---@field state 'playing'|'paused'|'stopped' Animation playback state
local AnimationManager = Object:extend()
function AnimationManager:new()
  ---@type table<string, Animation>
  self.animations = {}
  ---@type Animation|nil
  self.currentAnimation = nil
  ---@type integer
  self.currentFrame = 1
  ---@type number
  self.frameTime = 0
  ---@type 'playing'|'paused'|'stopped'
  self.state = "playing"
end

---Add an animation to the manager
---@param name string The name of the animation
---@param sheet string The name of the spritesheet
---@param frames string[] A table of frame indices for the animation
---@param onFrame? table<integer, fun()> Optional callbacks for specific frames
---@param frameRate? number Optional frame rate for the animation (default is 4)
function AnimationManager:add(name, sheet, frames, onFrame, frameRate)
  ---@type Animation
  local anim = {
    frames = frames,
    name = name,
    sheet = sheet,
    onFrame = onFrame or {},
    frameRate = frameRate or 16
  }
  self.animations[name] = anim
end

---Set the current animation by name
---@param name string
function AnimationManager:set(name)
  if self.animations[name] then
    if self.currentAnimation then
      if self.currentAnimation.name ~= name then
        self.currentFrame = 1
      end
    end
    self.currentAnimation = self.animations[name]
  else
    error("Animation " .. name .. " not found.")
  end
end

---Update the animation manager
---@param dt number Delta time
function AnimationManager:update(dt)
  if self.state == "playing" and self.currentAnimation then
    self.frameTime = self.frameTime + dt

    if self.frameTime >= 1 / self.currentAnimation.frameRate then
      self.frameTime = 0
      self.currentFrame = self.currentFrame + 1
      if self.currentFrame > #self.currentAnimation.frames then
        self.currentFrame = 1
      end

      if self.currentAnimation.onFrame[self.currentFrame] then
        self.currentAnimation.onFrame[self.currentFrame]()
      end
    end
  end
end

---Draw the current animation frame for an object
---@param object table Object to draw (must have getPos, scaleX, scaleY, flipX, flipY, rotation, active, debugOrigins)
function AnimationManager:draw(object)
  if not object.active then
    return
  end
  if self.currentAnimation then
    local rotation = 0
    local frame = self.currentAnimation.frames[self.currentFrame]
    local spritesheet = cacheManager.getSpritesheet(self.currentAnimation.sheet)
    local quad = spritesheet.quads[frame]

    -- Get the actual dimensions of the current quad
    local _, _, quadWidth, quadHeight = quad:getViewport()

    -- Calculate center point of the sprite
    local centerX = quadWidth / 2
    local centerY = quadHeight / 2

    -- Scale factors
    local scaleX = object.flipX and -object.scaleX or object.scaleX
    local scaleY = (object.flipY and -1 or 1) * object.scaleY

    -- Determine drawing position
    -- We need to offset from the top-left to center if using center origin
    local pos = object.getPos and object:getPos() or object:getPos()
    local drawX = pos.x + centerX * object.scaleX
    local drawY = pos.y + centerY * object.scaleY
    local rotation = object.rotation or 0
    -- Draw the sprite using center origin for flipping
    love.graphics.draw(
      spritesheet.image,
      quad,
      drawX,    -- Adjusted x position to account for centering
      drawY,    -- Adjusted y position to account for centering
      rotation, -- No rotation
      scaleX,   -- Possibly flipped X scale
      scaleY,   -- Normal Y scale
      centerX,  -- Using center X as origin for flipping
      centerY   -- Using center Y as origin for flipping
    )

    -- Debug visualization
    if object.debugOrigins then
      local dotSize = 2
      -- Draw dot at the actual position (top-left)
      love.graphics.setColor(0, 0, 1, 0.5)
      love.graphics.rectangle("fill", pos.x, pos.y, dotSize, dotSize)

      -- Draw dot at the center point we're using for flipping
      love.graphics.setColor(1, 0, 0, 0.5)
      love.graphics.rectangle("fill", drawX - (dotSize / 2), drawY - (dotSize / 2), dotSize, dotSize)

      love.graphics.setColor(1, 1, 1, 1)
    end
  end
end

---Stop the animation
function AnimationManager:stop()
  self.state = "stopped"
end

---Play the animation
function AnimationManager:play()
  self.state = "playing"
end

---Pause the animation
function AnimationManager:pause()
  self.state = "paused"
end

---Get the current frame index
---@return integer
function AnimationManager:getCurrentFrame()
  return self.currentFrame
end

---Set the current frame index
---@param frame integer
function AnimationManager:setCurrentFrame(frame)
  if self.currentAnimation and frame >= 1 and frame <= #self.currentAnimation.frames then
    self.currentFrame = frame
    if self.currentAnimation.onFrame[self.currentFrame] then
      self.currentAnimation.onFrame[self.currentFrame]()
    end
  else
    error("Invalid frame index: " .. tostring(frame))
  end
end

---Get the current animation
---@return Animation|nil
function AnimationManager:getCurrentAnimation()
  return self.currentAnimation
end

return AnimationManager
