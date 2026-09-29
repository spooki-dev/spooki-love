-- Perlin Noise implementation in Lua
-- Reference: https://github.com/ashima/webgl-noise/blob/master/src/noise2D.glsl (adapted)

local Perlin = {}

local permutation = {}
for i = 1, 256 do
  permutation[i] = i - 1
end
-- Shuffle permutation table
for i = 256, 2, -1 do
  local j = math.random(i)
  permutation[i], permutation[j] = permutation[j], permutation[i]
end
for i = 1, 256 do
  permutation[256 + i] = permutation[i]
end

local function fade(t)
  return t * t * t * (t * (t * 6 - 15) + 10)
end

local function lerp(t, a, b)
  return a + t * (b - a)
end

local function grad(hash, x, y)
  local h = hash % 8
  local u = h < 4 and x or y
  local v = h < 4 and y or x
  return ((h % 2 == 0) and u or -u) + ((h % 4 < 2) and v or -v)
end

function Perlin.noise(x, y)
  local X = math.floor(x) % 256
  local Y = math.floor(y) % 256

  x = x - math.floor(x)
  y = y - math.floor(y)

  local u = fade(x)
  local v = fade(y)

  local A = permutation[X + 1] + Y
  local B = permutation[X + 2] + Y

  local aa = permutation[(A % 256) + 1]
  local ab = permutation[((A + 1) % 256) + 1]
  local ba = permutation[(B % 256) + 1]
  local bb = permutation[((B + 1) % 256) + 1]

  local res = lerp(v,
    lerp(u, grad(aa, x, y), grad(ba, x - 1, y)),
    lerp(u, grad(ab, x, y - 1), grad(bb, x - 1, y - 1))
  )
  return (res + 1) / 2   -- Normalize to [0,1]
end

return Perlin
