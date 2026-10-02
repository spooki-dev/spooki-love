--- Generates the example spritesheets as PNGs from pixel-art strings, so the
--- examples need no third-party art. Run with `love . --gen-assets` and commit
--- the result. Both sheets are 16x16 frames in one row.
local files = require "examples.runner.files"

local M = {}

local PALETTE = {
  ["."] = nil,
  W = { 0.98, 0.98, 0.96, 1 }, -- ghost body
  G = { 0.78, 0.72, 0.75, 1 }, -- ghost shading
  B = { 0.05, 0.05, 0.07, 1 }, -- eyes
  g = { 0.45, 0.65, 0.25, 1 }, -- grass
  h = { 0.60, 0.80, 0.35, 1 }, -- grass highlight
  d = { 0.45, 0.30, 0.18, 1 }, -- dirt
  e = { 0.55, 0.38, 0.22, 1 }, -- dirt highlight
  s = { 0.42, 0.44, 0.50, 1 }, -- stone
  t = { 0.55, 0.57, 0.63, 1 }, -- stone highlight
  k = { 0.30, 0.32, 0.38, 1 }, -- stone crack
  w = { 0.15, 0.35, 0.70, 1 }, -- water
  v = { 0.35, 0.60, 0.90, 1 }, -- water highlight
}

local GHOST = {
  "......WWWW......",
  "....WWWWWWWW....",
  "...WWWWWWWWWW...",
  "..WWWWWWWWWWWW..",
  "..WWBBWWWWBBWW..",
  "..WWBBWWWWBBWW..",
  ".WWWWWWWWWWWWWW.",
  ".WWWWWWWWWWWWWW.",
  ".WWWWWWWWWWWWWW.",
  ".WWWWWWWWWWWWWW.",
  ".WWWWWWWWWWWWWW.",
  ".WWWWWWGGWWWWWW.",
  ".WWGWWWWWWWWGWW.",
  ".WGGWWGGWWGGWGW.",
  ".WW.WWW..WWW.WW.",
  "................",
}

local TILES = {
  grass = {
    "hhghhgghhhgghhgh",
    "gggggggggggggggg",
    "gggggggggggggggg",
    "gdgggggdgggggdgg",
    "dddddddddddddddd",
    "dddeddddddeddddd",
    "dddddddddddddddd",
    "ddddddeddddddddd",
    "dddddddddddddedd",
    "ddeddddddddddddd",
    "dddddddddeddeddd",
    "dddddddddddddddd",
    "ddddeddddddddddd",
    "dddddddddddddddd",
    "dddddddeddddddde",
    "dddddddddddddddd",
  },
  dirt = {
    "dddddddddddddddd",
    "ddeddddddddeeddd",
    "dddddddddddddddd",
    "dddddeddddddddde",
    "dddddddddddddddd",
    "deddddddddeddddd",
    "dddddddddddddddd",
    "ddddddddeddddddd",
    "ddeddddddddddedd",
    "dddddddddddddddd",
    "dddddeddddddddde",
    "dddddddddddddddd",
    "deddddddddeddddd",
    "dddddddddddddddd",
    "dddddddeddddddde",
    "dddddddddddddddd",
  },
  stone = {
    "ssssssssssssssss",
    "sttsssssssttssss",
    "stsssssksssstsss",
    "sssssskssssssssss",
    "ssssskssssssssss",
    "ssssskssssttssss",
    "sssskssssssstsss",
    "ssskkkkkssssssss",
    "sssssssskkkkssss",
    "sttsssssssskksss",
    "stssssssssssskss",
    "ssssssttsssssskk",
    "sssssstsssssssss",
    "ssssssssssssssss",
    "sttsssssssttssss",
    "ssssssssssssssss",
  },
  water = {
    "wwwwwwwwwwwwwwww",
    "wvvwwwwwwwvvwwww",
    "wwwwwwwwwwwwwwww",
    "wwwwwwvvwwwwwwww",
    "wwwwwwwwwwwwwwww",
    "wvvvwwwwwwwwvvww",
    "wwwwwwwwwwwwwwww",
    "wwwwwwwwvvwwwwww",
    "wwwwwwwwwwwwwwww",
    "wwvvwwwwwwwwwvvw",
    "wwwwwwwwwwwwwwww",
    "wwwwwwvvvwwwwwww",
    "wwwwwwwwwwwwwwww",
    "wvvwwwwwwwwvvwww",
    "wwwwwwwwwwwwwwww",
    "wwwwwwwwvvwwwwww",
  },
}

local function paint(imageData, frame, rows, dy)
  dy = dy or 0
  for y, row in ipairs(rows) do
    for x = 1, 16 do
      local colour = PALETTE[row:sub(x, x)]
      local py = y - 1 + dy
      if colour and py >= 0 and py < 16 then
        imageData:setPixel(frame * 16 + x - 1, py, colour[1], colour[2], colour[3], colour[4])
      end
    end
  end
end

--- Ghost sheet: four floating frames (bobbing) and four waving frames (an arm).
local function ghost()
  local sheet = love.image.newImageData(16 * 8, 16)
  local bob = { 0, -1, 0, 1 }
  for i = 1, 4 do paint(sheet, i - 1, GHOST, bob[i]) end
  local arm = { 8, 7, 6, 7 }
  for i = 1, 4 do
    paint(sheet, 4 + i - 1, GHOST, 0)
    local y = arm[i]
    for x = 13, 15 do
      sheet:setPixel((4 + i - 1) * 16 + x, y, PALETTE.W[1], PALETTE.W[2], PALETTE.W[3], 1)
    end
    sheet:setPixel((4 + i - 1) * 16 + 15, y - 1, PALETTE.W[1], PALETTE.W[2], PALETTE.W[3], 1)
  end
  return sheet
end

local function tiles()
  local order = { "grass", "dirt", "stone", "water" }
  local sheet = love.image.newImageData(16 * #order, 16)
  for i, name in ipairs(order) do paint(sheet, i - 1, TILES[name], 0) end
  return sheet
end

function M.run()
  local base = files.source() .. "/examples/assets/"
  files.writePng(ghost(), base .. "ghost.png")
  files.writePng(tiles(), base .. "tiles.png")
  print("wrote examples/assets/ghost.png (8 frames) and examples/assets/tiles.png (4 tiles)")
end

return M
