local UIBox = require "engine.ui.UIBox"
local Vector4 = require "engine.Vector4"
local cacheManager = require "engine.cacheManager"
local inputMap = require "engine.input.inputMap"
local glyphs = require "engine.input.glyphs"

--- Shows what an action is bound to on the device the player is using,
--- as sprite glyphs (or a drawn keycap with text when no tile exists)
--- followed by a label, e.g. [Space] Jump. Re-reads bindings and the active
--- device every frame, so it updates when the player rebinds or picks up a
--- gamepad; it has no children and a fixed height, so nothing relayouts.
---
---   InputPrompt("JumpPrompt", "jump", "Jump")
---   InputPrompt("MovePrompt", { "move_up", "move_left", "move_down", "move_right" }, "Move")
---   InputPrompt("FirePrompt", "fire", "Fire", { showAll = true, scale = 2, font = "small" })
---
--- Styles: `scale` (tile scale, default 2), `font` (default "small"),
--- `color`/`labelColor` (Vector4), `showAll` (every binding for the device,
--- default false: first binding only), `device` ("keyboard"/"gamepad" to pin
--- a device instead of following the active one), `gap`, `width`, `height`.
---@class InputPrompt : UIBox
local InputPrompt = UIBox.extend(UIBox)

--- Composite actions whose four parts are one stick or d-pad collapse to a
--- single glyph: the plain stick/d-pad tile from the first binding.
local COMPOSITE_TILES = {
  left = { 8, 6 },
  right = { 8, 8 },
  dpad = { xbox = { 0, 1 }, nintendo = { 0, 1 }, generic = { 0, 1 }, playstation = { 0, 7 } },
}
local STICK_OF_AXIS = { leftx = "left", lefty = "left", rightx = "right", righty = "right" }

---@param name string Unique name within the scene
---@param actions string|table One action name, or an ordered list of names shown together (e.g. up/left/down/right)
---@param label string|nil Text drawn after the glyphs
---@param styles table|nil See class notes
---@return InputPrompt
function InputPrompt:new(name, actions, label, styles)
  styles = styles or {}
  self.actions = type(actions) == "table" and actions or { actions }
  self.label = label or ""
  self.scale = styles.scale or 2
  self.fontKey = styles.font or "small"
  self.gap = styles.gap or 6
  self.showAll = styles.showAll or false
  self.pinnedDevice = styles.device
  self.labelColor = styles.labelColor or styles.color or Vector4(1, 1, 1, 1)
  self.keycapColor = styles.keycapColor or Vector4(0.86, 0.86, 0.9, 1)
  self.keycapTextColor = styles.keycapTextColor or Vector4(0.15, 0.15, 0.2, 1)
  local font = cacheManager.getFont(self.fontKey)
  local tileHeight = glyphs.TILE * self.scale
  styles.height = styles.height or math.max(tileHeight, font:getHeight())
  styles.padding = styles.padding or Vector4(0, 0, 0, 0)
  InputPrompt.super.new(self, name, {}, styles)
  return self
end

--- Changes the label text.
---@param label string
function InputPrompt:setLabel(label)
  self.label = label or ""
end

--- Changes which action(s) the prompt describes.
---@param actions string|table
function InputPrompt:setActions(actions)
  self.actions = type(actions) == "table" and actions or { actions }
end

local function device(self)
  return self.pinnedDevice or inputMap.getActiveDevice()
end

-- Draws one glyph at x; returns the width used.
local function drawGlyph(self, input, x, y, height, font)
  local scale = self.scale
  local tile = glyphs.TILE * scale
  local image, quad, widthTiles = glyphs.tile(input)
  if image and quad then
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, quad, x, y + (height - tile) / 2, 0, scale, scale)
    return tile * (widthTiles or 1)
  end
  -- Fallback keycap: rounded box with the text label.
  local text = glyphs.label(input)
  local padX = 4 * scale / 2
  local w = math.max(tile, font:getWidth(text) + padX * 2)
  local boxY = y + (height - tile) / 2
  local c = self.keycapColor
  love.graphics.setColor(c.x, c.y, c.z, c.w)
  love.graphics.rectangle("fill", x, boxY, w, tile, 3, 3)
  local t = self.keycapTextColor
  love.graphics.setColor(t.x, t.y, t.z, t.w)
  love.graphics.print(text, math.floor(x + (w - font:getWidth(text)) / 2), math.floor(boxY + (tile - font:getHeight()) / 2))
  return w
end

-- For composites (four directional actions) whose first bindings are one
-- stick or d-pad on the current device, returns a single tile to draw.
local function compositeTile(self, dev)
  if #self.actions < 2 then return nil end
  local axisGroup, dpad = nil, true
  for _, name in ipairs(self.actions) do
    local input = inputMap.firstBinding(name, dev)
    if not input then return nil end
    if input.kind == "axis" then
      local group = STICK_OF_AXIS[input.code]
      if not group then return nil end
      if axisGroup and axisGroup ~= group then return nil end
      axisGroup = group
      dpad = false
    elseif input.kind == "pad" and input.code:match("^dp") then
      axisGroup = axisGroup or false
      if axisGroup then return nil end
    else
      return nil
    end
  end
  if axisGroup then
    return COMPOSITE_TILES[axisGroup]
  end
  if dpad then
    local set = COMPOSITE_TILES.dpad
    return set[inputMap.getGamepadStyle()] or set.generic
  end
  return nil
end

function InputPrompt:draw()
  if not self.active then return end
  local pos = self:getPos()
  local x, y = math.floor(pos.x), math.floor(pos.y)
  local height = self.height or glyphs.TILE * self.scale
  local font = cacheManager.getFont(self.fontKey)
  local dev = device(self)
  love.graphics.setFont(font)

  local drewAny = false
  local tile = compositeTile(self, dev)
  if tile then
    local img, quad = glyphs.quadAt(tile)
    if img and quad then
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(img, quad, x, y + (height - glyphs.TILE * self.scale) / 2, 0, self.scale, self.scale)
      x = x + glyphs.TILE * self.scale + self.gap
      drewAny = true
    end
  end

  if not drewAny then
    for _, name in ipairs(self.actions) do
      local action = inputMap.getAction(name)
      if action then
        for _, input in ipairs(action.bindings) do
          if inputMap.deviceFor(input) == dev then
            x = x + drawGlyph(self, input, x, y, height, font) + self.gap
            drewAny = true
            if not self.showAll then break end
          end
        end
      end
    end
  end

  if not drewAny then
    local c = self.labelColor
    love.graphics.setColor(c.x, c.y, c.z, c.w * 0.5)
    love.graphics.print("unbound", x, math.floor(y + (height - font:getHeight()) / 2))
    x = x + font:getWidth("unbound") + self.gap
  end

  if self.label ~= "" then
    local c = self.labelColor
    love.graphics.setColor(c.x, c.y, c.z, c.w)
    love.graphics.print(self.label, x, math.floor(y + (height - font:getHeight()) / 2))
  end
  love.graphics.setColor(1, 1, 1, 1)
end

return InputPrompt
