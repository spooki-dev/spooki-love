--[[
    noise.lua

    Pure math utilities for procedural audio generation.
    No dependency on love.audio/love.sound — these are plain functions
    that take/return numbers or tables of numbers, so they're easy to
    unit test or reuse outside LÖVE entirely.
--]]

local noise = {}

-- ---------------------------------------------------------------------
-- Random number source
-- ---------------------------------------------------------------------
-- Uses love.math.random if available (better quality RNG), otherwise
-- falls back to Lua's math.random so this file works standalone too.
local rng = (love and love.math and love.math.random) or math.random

-- ---------------------------------------------------------------------
-- White noise: uniform random values in [-1, 1]
-- ---------------------------------------------------------------------
function noise.white(amplitude)
  amplitude = amplitude or 1
  return (rng() * 2 - 1) * amplitude
end

-- ---------------------------------------------------------------------
-- One-pole low-pass filter applied to an array of samples in place.
-- `alpha` (0-1) controls cutoff: lower = smoother/darker, higher = brighter.
-- Good for turning harsh white noise into "distant static" or "wind".
-- ---------------------------------------------------------------------
function noise.lowPass(samples, alpha)
  alpha = alpha or 0.15
  local prev = samples[1] or 0
  for i = 1, #samples do
    prev = prev + alpha * (samples[i] - prev)
    samples[i] = prev
  end
  return samples
end

-- ---------------------------------------------------------------------
-- One-pole high-pass filter (complement of low-pass).
-- Useful for thinning out a signal, e.g. making static feel "crackly"
-- rather than "rumbly".
-- ---------------------------------------------------------------------
function noise.highPass(samples, alpha)
  alpha = alpha or 0.15
  local prevIn, prevOut = samples[1] or 0, 0
  for i = 1, #samples do
    local x = samples[i]
    prevOut = alpha * (prevOut + x - prevIn)
    prevIn = x
    samples[i] = prevOut
  end
  return samples
end

-- ---------------------------------------------------------------------
-- Simple 1D value noise (smoothed random walk), useful for slow organic
-- drift — e.g. wobbling a hum's frequency or a light's brightness.
-- Returns a closure: call it once per sample/step to advance the walk.
--   local drift = noise.driftGenerator(0.02, 1)
--   local v = drift() -- call repeatedly, returns smoothly wandering value
-- ---------------------------------------------------------------------
function noise.driftGenerator(step, bound)
  step = step or 0.02
  bound = bound or 1
  local value = 0
  return function()
    value = value + (noise.white() * step)
    if value > bound then value = bound end
    if value < -bound then value = -bound end
    return value
  end
end

-- ---------------------------------------------------------------------
-- Waveform generators. Each takes phase in radians and returns [-1, 1].
-- ---------------------------------------------------------------------
function noise.sine(phase)
  return math.sin(phase)
end

function noise.square(phase, dutyCycle)
  dutyCycle = dutyCycle or 0.5
  local t = (phase % (2 * math.pi)) / (2 * math.pi)
  return (t < dutyCycle) and 1 or -1
end

function noise.saw(phase)
  local t = (phase % (2 * math.pi)) / (2 * math.pi)
  return 2 * t - 1
end

-- ---------------------------------------------------------------------
-- Envelope generator: linear attack, sustain, release, expressed as a
-- multiplier in [0,1] for a given elapsed time `t` inside a sound of
-- total length `duration`. Prevents clicks/pops at start and end.
--   attack / release given in seconds.
-- ---------------------------------------------------------------------
function noise.envelope(t, duration, attack, release)
  attack = attack or 0.01
  release = release or 0.05
  if t < attack then
    return t / attack
  elseif t > duration - release then
    return math.max(0, (duration - t) / release)
  end
  return 1
end

-- ---------------------------------------------------------------------
-- Clamp helper, handy when summing multiple noise layers to avoid
-- exceeding the -1..1 sample range LÖVE expects.
-- ---------------------------------------------------------------------
function noise.clamp(v, lo, hi)
  lo = lo or -1
  hi = hi or 1
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

return noise
