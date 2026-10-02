local inputMap = require "engine.input.inputMap"
local cacheManager = require "engine.cacheManager"

--- Turns a binding into something a player can read: a short text label
--- ("Space", "LMB", "A" / "Cross", "LT", "LS Up") and, when the prompt sheet
--- is loaded, a quad into the Kenney Input Prompts Pixel 16x tilemap.
---
--- Styles follow inputMap.getGamepadStyle(): "xbox", "playstation",
--- "nintendo", "generic". SDL maps gamepad buttons positionally, so on a
--- Nintendo pad `pad:a` is the physical B button; labels and tiles swap.
local glyphs = {}

--- Cache key of the prompt sheet image (preload it in your Preload scene with
--- cacheManager.preloadImage(glyphs.IMAGE_KEY, glyphs.IMAGE_PATH)).
glyphs.IMAGE_KEY = "input-prompts"
glyphs.IMAGE_PATH = "assets/graphics/input-prompts.png"
glyphs.TILE = 16

-- Pretty names for scancodes/key constants that are not single characters.
local KEY_LABELS = {
  space = "Space", ["return"] = "Enter", kpenter = "Enter", escape = "Esc", tab = "Tab",
  backspace = "Bksp", delete = "Del", insert = "Ins", home = "Home", ["end"] = "End",
  pageup = "PgUp", pagedown = "PgDn", capslock = "Caps",
  lshift = "L Shift", rshift = "R Shift", lctrl = "L Ctrl", rctrl = "R Ctrl",
  lalt = "L Alt", ralt = "R Alt", lgui = "L Cmd", rgui = "R Cmd",
  up = "Up", down = "Down", left = "Left", right = "Right",
  ["`"] = "`", ["-"] = "-", ["="] = "=", ["["] = "[", ["]"] = "]", ["\\"] = "\\",
  [";"] = ";", ["'"] = "'", [","] = ",", ["."] = ".", ["/"] = "/",
}

local MOUSE_LABELS = { [1] = "LMB", [2] = "RMB", [3] = "MMB" }

-- Button labels per style. Order: xbox, playstation, nintendo, generic.
local BUTTON_LABELS = {
  a             = { xbox = "A",    playstation = "Cross",    nintendo = "B",     generic = "1" },
  b             = { xbox = "B",    playstation = "Circle",   nintendo = "A",     generic = "2" },
  x             = { xbox = "X",    playstation = "Square",   nintendo = "Y",     generic = "3" },
  y             = { xbox = "Y",    playstation = "Triangle", nintendo = "X",     generic = "4" },
  back          = { xbox = "View", playstation = "Share",    nintendo = "-",     generic = "Select" },
  start         = { xbox = "Menu", playstation = "Options",  nintendo = "+",     generic = "Start" },
  guide         = { xbox = "Xbox", playstation = "PS",       nintendo = "Home",  generic = "Home" },
  leftshoulder  = { xbox = "LB",   playstation = "L1",       nintendo = "L",     generic = "L1" },
  rightshoulder = { xbox = "RB",   playstation = "R1",       nintendo = "R",     generic = "R1" },
  leftstick     = { xbox = "LS",   playstation = "L3",       nintendo = "LS",    generic = "L3" },
  rightstick    = { xbox = "RS",   playstation = "R3",       nintendo = "RS",    generic = "R3" },
  dpup          = { xbox = "D-Up",    playstation = "D-Up",    nintendo = "D-Up",    generic = "D-Up" },
  dpdown        = { xbox = "D-Down",  playstation = "D-Down",  nintendo = "D-Down",  generic = "D-Down" },
  dpleft        = { xbox = "D-Left",  playstation = "D-Left",  nintendo = "D-Left",  generic = "D-Left" },
  dpright       = { xbox = "D-Right", playstation = "D-Right", nintendo = "D-Right", generic = "D-Right" },
}

local AXIS_LABELS = {
  ["triggerleft+"]  = { xbox = "LT", playstation = "L2", nintendo = "ZL", generic = "L2" },
  ["triggerright+"] = { xbox = "RT", playstation = "R2", nintendo = "ZR", generic = "R2" },
  ["leftx-"] = "LS Left", ["leftx+"] = "LS Right", ["lefty-"] = "LS Up", ["lefty+"] = "LS Down",
  ["rightx-"] = "RS Left", ["rightx+"] = "RS Right", ["righty-"] = "RS Up", ["righty+"] = "RS Down",
}

local function keyLabel(scancode)
  local key = scancode
  if love and love.keyboard and love.keyboard.getKeyFromScancode then
    local ok, k = pcall(love.keyboard.getKeyFromScancode, scancode)
    if ok and k and k ~= "unknown" then key = k end
  end
  if KEY_LABELS[key] then return KEY_LABELS[key] end
  if #key == 1 then return key:upper() end
  if key:match("^f%d+$") then return key:upper() end
  if key:match("^kp") then return "Num " .. key:sub(3) end
  return (key:gsub("^%l", string.upper))
end

--- Short readable label for a binding.
--- @param binding string|table shorthand or parsed input
--- @param style string|nil gamepad style, defaults to the active one
--- @return string
function glyphs.label(binding, style)
  local input = type(binding) == "table" and binding or inputMap.parse(binding)
  if not input then return "?" end
  style = style or inputMap.getGamepadStyle()
  if input.kind == "key" then
    return keyLabel(input.code)
  elseif input.kind == "mouse" then
    return MOUSE_LABELS[input.code] or ("M" .. input.code)
  elseif input.kind == "pad" then
    local labels = BUTTON_LABELS[input.code]
    return labels and (labels[style] or labels.generic) or input.code
  elseif input.kind == "axis" then
    local entry = AXIS_LABELS[input.code .. (input.sign > 0 and "+" or "-")]
    if type(entry) == "table" then return entry[style] or entry.generic end
    return entry or input.id
  end
  return input.id
end

-- ---------------------------------------------------------------------------
-- Sprite tiles

-- Tile coordinates { col, row [, widthInTiles] } in the Kenney Input Prompts
-- Pixel 16x packed tilemap (34 x 24 tiles, no spacing). Keyboard tiles are
-- keyed by key constant, pad tiles by style and button, axis tiles by style
-- and "axis+"/"axis-". See docs/Input.md for how to add more.
local STICKS = {
  ["leftx-"] = { 12, 6 }, ["leftx+"] = { 10, 6 }, ["lefty-"] = { 9, 6 }, ["lefty+"] = { 11, 6 },
  ["rightx-"] = { 12, 8 }, ["rightx+"] = { 10, 8 }, ["righty-"] = { 9, 8 }, ["righty+"] = { 11, 8 },
  leftstick = { 16, 6 }, rightstick = { 16, 8 },
}
local CROSS_DPAD = { dpup = { 1, 1 }, dpright = { 2, 1 }, dpdown = { 3, 1 }, dpleft = { 4, 1 } }

local function merge(...)
  local out = {}
  for _, set in ipairs({ ... }) do
    for k, v in pairs(set) do out[k] = v end
  end
  return out
end

glyphs.TILES = {
  keyboard = {
    escape = { 17, 0 }, f1 = { 18, 0 }, f2 = { 19, 0 }, f3 = { 20, 0 }, f4 = { 21, 0 }, f5 = { 22, 0 },
    f6 = { 23, 0 }, f7 = { 24, 0 }, f8 = { 25, 0 }, f9 = { 26, 0 }, f10 = { 27, 0 }, f11 = { 28, 0 },
    f12 = { 29, 0 }, ["`"] = { 30, 0 },
    ["1"] = { 17, 1 }, ["2"] = { 18, 1 }, ["3"] = { 19, 1 }, ["4"] = { 20, 1 }, ["5"] = { 21, 1 },
    ["6"] = { 22, 1 }, ["7"] = { 23, 1 }, ["8"] = { 24, 1 }, ["9"] = { 25, 1 }, ["0"] = { 26, 1 },
    ["-"] = { 27, 1 }, ["="] = { 29, 1 }, backspace = { 32, 1, 2 },
    q = { 17, 2 }, w = { 18, 2 }, e = { 19, 2 }, r = { 20, 2 }, t = { 21, 2 }, y = { 22, 2 }, u = { 23, 2 },
    i = { 24, 2 }, o = { 25, 2 }, p = { 26, 2 }, ["["] = { 27, 2 }, ["]"] = { 28, 2 }, ["\\"] = { 31, 2 },
    a = { 18, 3 }, s = { 19, 3 }, d = { 20, 3 }, f = { 21, 3 }, g = { 22, 3 }, h = { 23, 3 }, j = { 24, 3 },
    k = { 25, 3 }, l = { 26, 3 }, ["'"] = { 27, 3 }, [";"] = { 30, 3 }, ["return"] = { 32, 3, 2 },
    kpenter = { 32, 3, 2 },
    z = { 19, 4 }, x = { 20, 4 }, c = { 21, 4 }, v = { 22, 4 }, b = { 23, 4 }, n = { 24, 4 }, m = { 25, 4 },
    [","] = { 27, 6 }, ["."] = { 27, 5 }, ["/"] = { 29, 4 },
    up = { 30, 4 }, right = { 31, 4 }, down = { 32, 4 }, left = { 33, 4 },
    lgui = { 18, 4 }, rgui = { 18, 4 },
    lalt = { 17, 5, 2 }, ralt = { 17, 5, 2 }, tab = { 19, 5, 2 }, delete = { 21, 5, 2 }, ["end"] = { 23, 5, 2 },
    numlock = { 25, 5, 2 },
    lctrl = { 17, 6, 2 }, rctrl = { 17, 6, 2 }, capslock = { 19, 6, 2 }, home = { 21, 6, 2 },
    pageup = { 23, 6, 2 }, pagedown = { 25, 6, 2 }, space = { 31, 6, 3 },
    lshift = { 17, 7, 2 }, rshift = { 17, 7, 2 }, insert = { 19, 7, 2 }, printscreen = { 21, 7, 2 },
    scrolllock = { 23, 7, 2 }, pause = { 25, 7, 2 },
  },
  mouse = { [1] = { 9, 2 }, [2] = { 10, 2 }, [3] = { 11, 2 } },
  xbox = merge(STICKS, CROSS_DPAD, {
    a = { 4, 0 }, b = { 5, 0 }, x = { 6, 0 }, y = { 7, 0 },
    back = { 4, 18 }, start = { 5, 18 },
    leftshoulder = { 9, 16 }, rightshoulder = { 10, 16 },
    ["triggerleft+"] = { 7, 16 }, ["triggerright+"] = { 8, 16 },
  }),
  playstation = merge(STICKS, {
    dpup = { 1, 7 }, dpright = { 2, 7 }, dpdown = { 3, 7 }, dpleft = { 4, 7 },
    a = { 23, 16 }, b = { 19, 16 }, x = { 21, 16 }, y = { 17, 16 }, -- cross, circle, square, triangle
    back = { 19, 22 }, start = { 20, 22 },
    leftshoulder = { 19, 18 }, rightshoulder = { 20, 18 },
    ["triggerleft+"] = { 17, 18 }, ["triggerright+"] = { 18, 18 },
  }),
  -- SDL maps Nintendo pads positionally: pad:a is the physical B button.
  nintendo = merge(STICKS, CROSS_DPAD, {
    a = { 1, 18 }, b = { 0, 18 }, x = { 2, 18 }, y = { 3, 18 },
    back = { 13, 20 }, start = { 14, 20 }, guide = { 2, 20 },
    leftshoulder = { 11, 18 }, rightshoulder = { 12, 18 },
    ["triggerleft+"] = { 13, 18 }, ["triggerright+"] = { 14, 18 },
  }),
  generic = merge(STICKS, CROSS_DPAD, {
    a = { 13, 0 }, b = { 14, 0 }, x = { 15, 0 }, y = { 16, 0 },
    back = { 4, 18 }, start = { 5, 18 },
    leftshoulder = { 9, 16 }, rightshoulder = { 10, 16 },
    ["triggerleft+"] = { 7, 16 }, ["triggerright+"] = { 8, 16 },
  }),
}

local quads = {}      -- "col,row" -> love.Quad
local image = nil
local imageChecked = false

local function sheet()
  if imageChecked then return image end
  imageChecked = true
  local ok, img = pcall(cacheManager.getImage, glyphs.IMAGE_KEY)
  image = ok and img or nil
  return image
end

local function quadFor(tile)
  local width = tile[3] or 1
  local key = tile[1] .. "," .. tile[2] .. "," .. width
  local quad = quads[key]
  if not quad then
    local img = sheet()
    if not img then return nil end
    quad = love.graphics.newQuad(tile[1] * glyphs.TILE, tile[2] * glyphs.TILE, glyphs.TILE * width, glyphs.TILE,
      img:getDimensions())
    quads[key] = quad
  end
  return quad
end

--- Image and cached quad for an explicit tile { col, row [, width] }.
--- @param tile table
--- @return love.Image|nil image, love.Quad|nil quad, number widthInTiles
function glyphs.quadAt(tile)
  local quad = quadFor(tile)
  if not quad then return nil, nil, tile[3] or 1 end
  return image, quad, tile[3] or 1
end

--- Looks up the tile for a binding.
--- @param binding string|table
--- @param style string|nil
--- @return love.Image|nil image, love.Quad|nil quad, number|nil widthInTiles
function glyphs.tile(binding, style)
  local input = type(binding) == "table" and binding or inputMap.parse(binding)
  if not input then return nil end
  style = style or inputMap.getGamepadStyle()
  local tile
  if input.kind == "key" then
    local key = input.code
    if love and love.keyboard and love.keyboard.getKeyFromScancode then
      local ok, k = pcall(love.keyboard.getKeyFromScancode, input.code)
      if ok and k and k ~= "unknown" then key = k end
    end
    tile = glyphs.TILES.keyboard[key]
  elseif input.kind == "mouse" then
    tile = glyphs.TILES.mouse[input.code]
  elseif input.kind == "pad" then
    local set = glyphs.TILES[style] or glyphs.TILES.generic
    tile = set[input.code] or glyphs.TILES.generic[input.code]
  elseif input.kind == "axis" then
    local id = input.code .. (input.sign > 0 and "+" or "-")
    local set = glyphs.TILES[style] or glyphs.TILES.generic
    tile = set[id] or glyphs.TILES.generic[id]
  end
  if not tile then return nil end
  local quad = quadFor(tile)
  if not quad then return nil end
  return image, quad, tile[3] or 1
end

--- Forgets cached quads (call if the sheet image is replaced at runtime).
function glyphs.reset()
  quads = {}
  image = nil
  imageChecked = false
end

return glyphs
