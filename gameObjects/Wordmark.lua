local UIBox = require "engine.ui.UIBox"
local UIText = require "engine.ui.UIText"
local cacheManager = require "engine.cacheManager"
local colors = require "constants.colors"

local FONT_PATH = "assets/fonts/PixelOperator8.ttf"

--- Centred title block (one UIText per line plus an optional subtitle) used
--- by the marketing asset scenes so every image shares one typographic
--- treatment. Pass `canvasHeight` to centre the block vertically.
---@class Wordmark : UIBox
local Wordmark = UIBox.extend(UIBox)

---@class WordmarkOptions
---@field lines string[] Title lines, drawn top to bottom
---@field subtitle string|nil Smaller line under the title
---@field titleSize number Title font size (use multiples of 8 for PixelOperator8)
---@field subtitleSize number|nil Subtitle font size (default titleSize / 3, rounded to 8)
---@field color Vector4|nil Title colour (default colors.vec4Yellow)
---@field subtitleColor Vector4|nil Subtitle colour (default colors.vec4Grey)
---@field gap number|nil Vertical gap between lines (default titleSize / 4)
---@field canvasHeight number|nil Available height; when set the block is vertically centred within it

--- Returns the cache key for an asset font of the given size, loading it on first use.
--- Fonts use "mono" hinting so glyph edges stay binary (no fringes on transparent exports).
---@param size number
---@return string key
function Wordmark.font(size)
  local key = "asset-" .. size
  if not cacheManager.hasFont(key) then
    cacheManager.preloadFont(key, FONT_PATH, size, "mono")
  end
  return key
end

--- Rounds a size down to the nearest multiple of 8 (minimum 8).
---@param size number
---@return number
local function snap8(size)
  return math.max(8, math.floor(size / 8) * 8)
end

--- Measures the block height assuming each line fits on one row.
---@param opts WordmarkOptions
---@return number height
function Wordmark.measure(opts)
  local gap = opts.gap or opts.titleSize / 4
  local titleFont = cacheManager.getFont(Wordmark.font(opts.titleSize))
  local height = #opts.lines * titleFont:getHeight() + gap * (#opts.lines - 1)
  if opts.subtitle then
    local subtitleSize = opts.subtitleSize or snap8(opts.titleSize / 3)
    local subtitleFont = cacheManager.getFont(Wordmark.font(subtitleSize))
    height = height + gap + subtitleFont:getHeight()
  end
  return height
end

---@param name string Unique name within the scene
---@param opts WordmarkOptions
---@return Wordmark
function Wordmark:new(name, opts)
  assert(opts and opts.lines and #opts.lines > 0, "Wordmark needs at least one title line")
  assert(opts.titleSize, "Wordmark needs a titleSize")
  local gap = opts.gap or opts.titleSize / 4
  local titleKey = Wordmark.font(opts.titleSize)
  local subtitleSize = opts.subtitleSize or snap8(opts.titleSize / 3)
  local children = {}

  if opts.canvasHeight then
    local spacer = math.max(0, math.floor((opts.canvasHeight - Wordmark.measure(opts)) / 2))
    -- The spacer is the first child, so subtract the gap the layout adds after it.
    table.insert(children, UIBox(name .. "Spacer", {}, { height = math.max(0, spacer - gap) }))
  end

  for i, line in ipairs(opts.lines) do
    table.insert(children, UIText(name .. "Line" .. i, line, {
      font = titleKey,
      textAlign = "center",
      color = opts.color or colors.vec4Yellow,
    }))
  end

  if opts.subtitle then
    table.insert(children, UIText(name .. "Subtitle", opts.subtitle, {
      font = Wordmark.font(subtitleSize),
      textAlign = "center",
      color = opts.subtitleColor or colors.vec4Grey,
    }))
  end

  Wordmark.super.new(self, name, children, { gap = gap })
  return self
end

return Wordmark
