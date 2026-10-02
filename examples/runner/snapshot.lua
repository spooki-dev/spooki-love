--- Golden screenshot comparison for the test runner.
---
--- Goldens live in examples/__snapshots__/<category>/<slug>.png (and double
--- as thumbnails on the website). Comparison ignores alpha and tolerates
--- small per-channel differences on a small share of pixels, so a different
--- GPU or rasteriser does not fail the suite while a moved object does.
local files = require "examples.runner.files"

local M = {}

M.DEFAULT_TOLERANCE = { channel = 8, ratio = 0.005 }

---@param entry ExampleEntry
---@return string Path relative to the project root
function M.goldenPath(entry)
  return "examples/__snapshots__/" .. entry.id .. ".png"
end

local function outputBase(entry)
  return files.source() .. "/examples/.test-output/" .. entry.id:gsub("/", "__")
end

--- Forces alpha to 1 so goldens are opaque PNGs and byte-comparable.
---@param imageData love.ImageData
local function opaque(imageData)
  imageData:mapPixel(function(_, _, r, g, b)
    return r, g, b, 1
  end)
end

--- Compares a capture with the golden, or writes the golden when updating.
--- Appends messages to result.messages and clears result.ok on failure.
---@param entry ExampleEntry
---@param actual love.ImageData Capture from love.graphics.captureScreenshot
---@param tolerance { channel: number, ratio: number }|nil
---@param opts ExampleArgs
---@param result table
function M.verify(entry, actual, tolerance, opts, result)
  tolerance = tolerance or M.DEFAULT_TOLERANCE
  opaque(actual)
  local goldenPath = M.goldenPath(entry)
  local actualPng = actual:encode("png"):getString()

  if opts.update then
    files.write(files.source() .. "/" .. goldenPath, actualPng)
    result.messages[#result.messages + 1] = "golden written"
    return
  end

  local goldenPng = love.filesystem.read(goldenPath)
  if not goldenPng then
    result.ok = false
    result.messages[#result.messages + 1] = "missing golden " .. goldenPath .. " (run scripts/test.sh --update-snapshots)"
    files.write(outputBase(entry) .. ".actual.png", actualPng)
    return
  end
  if goldenPng == actualPng then
    result.messages[#result.messages + 1] = "snapshot identical"
    return
  end

  local golden = love.image.newImageData(love.filesystem.newFileData(goldenPng, "golden.png"))
  local w, h = actual:getDimensions()
  if golden:getWidth() ~= w or golden:getHeight() ~= h then
    result.ok = false
    result.messages[#result.messages + 1] = string.format("snapshot size %dx%d differs from golden %dx%d",
      w, h, golden:getWidth(), golden:getHeight())
    files.write(outputBase(entry) .. ".actual.png", actualPng)
    return
  end

  local diff = love.image.newImageData(w, h)
  local channel = tolerance.channel / 255
  local bad = 0
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local r1, g1, b1 = actual:getPixel(x, y)
      local r2, g2, b2 = golden:getPixel(x, y)
      if math.abs(r1 - r2) > channel or math.abs(g1 - g2) > channel or math.abs(b1 - b2) > channel then
        bad = bad + 1
        diff:setPixel(x, y, 1, 0, 0, 1)
      else
        local l = (r1 + g1 + b1) / 3 * 0.25
        diff:setPixel(x, y, l, l, l, 1)
      end
    end
  end
  local ratio = bad / (w * h)
  result.messages[#result.messages + 1] = string.format("%d px (%.3f%%) differ, limit %.3f%% at +/-%d",
    bad, ratio * 100, tolerance.ratio * 100, tolerance.channel)
  if ratio > tolerance.ratio then
    result.ok = false
    files.write(outputBase(entry) .. ".actual.png", actualPng)
    files.writePng(diff, outputBase(entry) .. ".diff.png")
  end
end

return M
