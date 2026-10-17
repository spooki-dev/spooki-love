-- title: Camera preview and capture
-- description: deviceCamera streams the device camera into one reused texture and takes stills; the preview is a love.Image you draw like any other.
-- order: 2
-- tags: camera, device, preview, capture, texture
local Scene = require "engine.Scene"
local cacheManager = require "engine.cacheManager"
local deviceCamera = require "engine.device.camera"

---@class DeviceCameraPreview : Scene
local Example = Scene.extend(Scene)

function Example:new()
  Example.super.new(self, "device/camera-preview")
  self.backgroundColor = { 0.09, 0.09, 0.13, 1 }
  -- The defaults; spelled out because the cost of a preview is linear in all
  -- three and a game should choose them deliberately.
  deviceCamera.configure({ width = 320, height = 240, fps = 15 })
  self.still = nil
  self.status = "starting the camera"
  self.textureIdentity = nil  -- proves the same Image is reused frame to frame
  self.seenFrames = 0
end

function Example:start()
  Example.super.start(self)
  self:open()
end

function Example:open()
  local ok, err = deviceCamera.start(nil, function(started, event, reason)
    if started then
      self.status = "camera running"
    else
      self.status = "camera " .. event .. (reason and (": " .. reason) or "")
    end
  end)
  if not ok then
    self.status = "could not start: " .. tostring(err)
  end
end

function Example:onActionPressed(name)
  if name == "action" then
    -- A still is independent of the preview: the backend may re-open the device
    -- at a higher resolution for it.
    deviceCamera.capture({ deliver = "image" }, function(result, event, reason)
      if event == "picked" then
        self.still = result
        self.status = string.format("captured %dx%d (%d bytes)", result.width, result.height, result.size)
      else
        self.status = "capture " .. event .. (reason and (": " .. reason) or "")
      end
    end)
  elseif name == "secondary" then
    if deviceCamera.isRunning() then
      deviceCamera.stop()
      self.status = "camera stopped"
    else
      self:open()
    end
  end
end

function Example:update(dt)
  local texture = deviceCamera.getTexture()
  if texture then
    -- Held only to assert the texture is not rebuilt per frame.
    if self.textureIdentity ~= texture then
      self.textureIdentity = texture
      self.seenFrames = self.seenFrames + 1
    end
  end
end

function Example:draw()
  love.graphics.setFont(cacheManager.getFont("body"))
  love.graphics.setColor(0.78, 0.72, 0.75, 1)
  love.graphics.print("Space / A: take a still.  Shift / X: stop or restart the camera.", 48, 48)
  love.graphics.print(string.format("available: %s   state: %s   running: %s   frames: %d   textures built: %d",
    tostring(deviceCamera.isAvailable()), deviceCamera.getState(), tostring(deviceCamera.isRunning()),
    deviceCamera.getFrameNumber(), self.seenFrames), 48, 88)

  love.graphics.setColor(1, 1, 0, 1)
  love.graphics.print(self.status, 48, 128)

  local texture, width, height = deviceCamera.getTexture()
  love.graphics.setColor(1, 1, 1, 1)
  if texture then
    love.graphics.draw(texture, 48, 172, 0, 2, 2)
    love.graphics.setColor(0.78, 0.72, 0.75, 1)
    love.graphics.print(string.format("preview %dx%d", width, height), 48, 172 + height * 2 + 8)
  else
    love.graphics.setColor(0.35, 0.35, 0.42, 1)
    love.graphics.rectangle("fill", 48, 172, 640, 480)
    love.graphics.setColor(0.78, 0.72, 0.75, 1)
    love.graphics.print("no frame yet", 64, 188)
  end

  if self.still then
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.still.image, 740, 172, 0, 3, 3)
    love.graphics.setColor(0.78, 0.72, 0.75, 1)
    love.graphics.print("last still", 740, 172 + self.still.height * 3 + 8)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

Example.script = {
  { at = 30, tap = "action" },    -- take a still
  { at = 50, tap = "secondary" }, -- stop
  { at = 70, tap = "secondary" }, -- restart
}

function Example.check(scene, ctx)
  if ctx.frame == 2 then
    assert(deviceCamera.isAvailable(), "the mock backend reports a camera")
    assert(deviceCamera.isRunning(), "started from the scene's start() hook")
  elseif ctx.frame == 25 then
    local texture, width, height = deviceCamera.getTexture()
    assert(texture, "a frame arrived")
    assert(width == 320 and height == 240, "the frame is the configured size")
    assert(deviceCamera.getState() == "running", "state tracks the stream")
    -- 15 fps against the runner's fixed 1/60 dt is one frame every four updates.
    assert(deviceCamera.getFrameNumber() == math.floor(25 / 4), "frames arrive at the requested rate")
    assert(scene.seenFrames == 1, "one Image, reused: replacePixels, not newImage")
  elseif ctx.frame == 32 then
    assert(scene.still and scene.still.image, "the still decoded")
  elseif ctx.frame == 55 then
    assert(not deviceCamera.isRunning(), "stopped")
    assert(deviceCamera.getTexture() == nil, "stop released the preview texture")
    assert(deviceCamera.getFrameNumber() == 0, "the frame count resets with the stream")
  elseif ctx.done then
    assert(deviceCamera.isRunning(), "restarted")
    assert(deviceCamera.getFrameNumber() > 0, "frames flowing again after a restart")
    deviceCamera.stop()
  end
end

return Example
