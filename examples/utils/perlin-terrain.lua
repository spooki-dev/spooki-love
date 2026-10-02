-- title: Perlin noise
-- description: engine/utils/perlin samples 2D noise in 0..1; thresholds turn it into a terrain map.
-- order: 1
-- tags: perlin, noise, procedural
local Scene = require "engine.Scene"
local cacheManager = require "engine.cacheManager"
local Perlin = require "engine.utils.perlin"

local CELL = 20
local COLS, ROWS = 64, 30
local SCALE = 0.08
local TERRAIN = {
  { limit = 0.42, colour = { 0.15, 0.35, 0.70 }, name = "water" },
  { limit = 0.48, colour = { 0.85, 0.80, 0.55 }, name = "sand" },
  { limit = 0.65, colour = { 0.30, 0.55, 0.25 }, name = "grass" },
  { limit = 1.01, colour = { 0.45, 0.47, 0.52 }, name = "stone" },
}

---@class UtilsPerlin : Scene
local Example = Scene.extend(Scene)

function Example:new()
  Example.super.new(self, "utils/perlin-terrain")
  self.backgroundColor = { 0.09, 0.09, 0.13, 1 }
  self.offset = 0
  self.samples = {}
  self.counts = {}
end

function Example:generate()
  self.samples, self.counts = {}, {}
  for y = 0, ROWS - 1 do
    self.samples[y] = {}
    for x = 0, COLS - 1 do
      -- The permutation table is shuffled once at require time (seeded by the runner in tests).
      local n = Perlin.noise((x + self.offset) * SCALE, y * SCALE)
      self.samples[y][x] = n
      for i, band in ipairs(TERRAIN) do
        if n < band.limit then
          self.counts[i] = (self.counts[i] or 0) + 1
          break
        end
      end
    end
  end
end

function Example:load()
  self:generate()
end

function Example:onActionPressed(name)
  if name == "action" then
    self.offset = self.offset + 7 -- scroll the sample window
    self:generate()
  end
end

function Example:draw()
  for y = 0, ROWS - 1 do
    for x = 0, COLS - 1 do
      local n = self.samples[y][x]
      for _, band in ipairs(TERRAIN) do
        if n < band.limit then
          love.graphics.setColor(band.colour[1], band.colour[2], band.colour[3], 1)
          break
        end
      end
      love.graphics.rectangle("fill", x * CELL, 100 + y * CELL, CELL, CELL)
    end
  end
  love.graphics.setFont(cacheManager.getFont("body"))
  love.graphics.setColor(0.78, 0.72, 0.75, 1)
  local parts = {}
  for i, band in ipairs(TERRAIN) do parts[#parts + 1] = band.name .. " " .. (self.counts[i] or 0) end
  love.graphics.print("Perlin.noise(x * " .. SCALE .. ", y * " .. SCALE .. ") -> " .. table.concat(parts, ", ") ..
    ".  Space / A shifts the window.", 48, 48)
  love.graphics.setColor(1, 1, 1, 1)
end

function Example.check(scene, ctx)
  if ctx.done then
    local kinds = 0
    for _ in pairs(scene.counts) do kinds = kinds + 1 end
    assert(kinds >= 2, "several terrain types")
    for y = 0, ROWS - 1 do
      for x = 0, COLS - 1 do
        local n = scene.samples[y][x]
        assert(n >= 0 and n <= 1, "noise in 0..1")
      end
    end
    assert(scene.samples[3][3] == Perlin.noise(3 * SCALE, 3 * SCALE), "noise is a pure function of its inputs")
  end
end

return Example
