-- title: Picking a file
-- description: filePicker opens the device's own picker and hands the file back as a drawable Image, as raw bytes, or as a file in the save directory.
-- order: 1
-- tags: filePicker, device, import, image
local Scene = require "engine.Scene"
local cacheManager = require "engine.cacheManager"
local filePicker = require "engine.device.filePicker"

---@class DeviceFilePicker : Scene
local Example = Scene.extend(Scene)

function Example:new()
  Example.super.new(self, "device/file-picker")
  self.backgroundColor = { 0.09, 0.09, 0.13, 1 }
  -- Keep this example's imports out of the way of a real game's save data.
  filePicker.configure({ saveDir = "examples-imported" })
  self.picked = nil      -- the deliver = "image" result
  self.bytes = nil       -- the deliver = "bytes" result
  self.path = nil        -- the deliver = "file" result
  self.status = "Nothing picked yet"
  self.lastEvent = nil
end

-- Every delivery mode goes through the same call; only `deliver` changes.
function Example:pick(deliver)
  local ok, err = filePicker.open({ deliver = deliver }, function(result, event, reason)
    self.lastEvent = event
    if event ~= "picked" then
      self.status = deliver .. ": " .. event .. (reason and (" (" .. reason .. ")") or "")
      return
    end
    if deliver == "image" then
      self.picked = result
      self.status = string.format("image: %s, %dx%d, %d bytes", result.name, result.width, result.height, result.size)
    elseif deliver == "bytes" then
      self.bytes = result
      self.status = string.format("bytes: %s, %d bytes, mime %s", result.name, result.size, tostring(result.mime))
    else
      self.path = result
      self.status = string.format("file: wrote %s (%d bytes)", result.path, result.size)
    end
  end)
  if not ok then
    self.status = "could not open the picker: " .. tostring(err)
  end
end

-- Cancelling always calls back, with (nil, "cancelled"), so a caller never
-- waits forever. Here the cancel lands before the result is drained.
function Example:pickThenCancel()
  self:pick("image")
  filePicker.cancel()
end

function Example:onActionPressed(name)
  if name == "action" then
    self:pick("image")
  elseif name == "secondary" then
    self:pick("bytes")
  elseif name == "pause" then
    self:pick("file")
  end
end

function Example:draw()
  love.graphics.setFont(cacheManager.getFont("body"))
  love.graphics.setColor(0.78, 0.72, 0.75, 1)
  love.graphics.print("Space / A: pick as an Image.  Shift / X: as bytes.  P: into the save directory.", 48, 48)
  love.graphics.print(string.format("picker available: %s   capabilities: pick %s, multiple %s, needs a gesture %s",
    tostring(filePicker.isAvailable()),
    tostring(filePicker.getCapabilities().pick),
    tostring(filePicker.getCapabilities().multiple),
    tostring(filePicker.getCapabilities().needsGesture)), 48, 88)

  love.graphics.setColor(1, 1, 0, 1)
  love.graphics.printf(self.status, 48, 132, 1180, "left")

  if self.picked then
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.picked.image, 48, 200, 0, 3, 3)
  end
  love.graphics.setColor(0.78, 0.72, 0.75, 1)
  love.graphics.print("bytes held: " .. (self.bytes and (self.bytes.size .. " B") or "none"), 320, 200)
  love.graphics.print("file written: " .. (self.path and self.path.path or "none"), 320, 232)
  love.graphics.print("last event: " .. tostring(self.lastEvent), 320, 264)
  love.graphics.setColor(1, 1, 1, 1)
end

Example.script = {
  { at = 10, tap = "action" },    -- deliver = "image"
  { at = 40, tap = "secondary" }, -- deliver = "bytes"
  { at = 70, tap = "pause" },     -- deliver = "file"
  { at = 95, call = function(scene) scene:pickThenCancel() end },
  { at = 105, tap = "action" },   -- picking still works after a cancel
}

function Example.check(scene, ctx)
  if ctx.frame == 2 then
    assert(filePicker.isAvailable(), "the mock backend reports a picker")
    assert(not filePicker.isOpen(), "nothing in flight before the first pick")
  elseif ctx.frame == 11 then
    -- The pick resolves inside the same Game:update that opened it: the action
    -- event fires before filePicker.update drains the backend.
    assert(scene.picked, "image delivered")
    assert(scene.picked.image:getWidth() == 64 and scene.picked.image:getHeight() == 64, "decoded 64x64")
    assert(scene.picked.name == "mock.png" and scene.picked.mime == "image/png", "name and mime carried through")
    assert(not filePicker.isOpen(), "the request cleared before the callback ran")
  elseif ctx.frame == 41 then
    assert(scene.bytes and #scene.bytes.bytes == scene.bytes.size, "bytes delivered, size matches")
    assert(scene.bytes.bytes:sub(2, 4) == "PNG", "the raw file, undecoded")
  elseif ctx.frame == 71 then
    assert(scene.path and scene.path.path == "examples-imported/mock.png", "written under the configured folder")
    local info = love.filesystem.getInfo(scene.path.path)
    assert(info and info.type == "file", "the file really is in the save directory")
  elseif ctx.frame == 96 then
    assert(scene.lastEvent == "cancelled", "cancel calls back")
    assert(not filePicker.isOpen(), "cancel clears the request")
  elseif ctx.done then
    assert(scene.lastEvent == "picked", "the picker still works after a cancel")
    love.filesystem.remove("examples-imported/mock.png")
  end
end

return Example
