--[[
    synth.lua

    Bridge between the pure-maths helpers in engine/utils/noise.lua and
    LÖVE's audio objects. Build a 1-indexed array of samples in [-1, 1]
    with `generate`, shape it with the noise filters, then turn it into
    a SoundData with `toSoundData` and a playable Source with `newSource`.
    Lua 5.1 safe.
--]]

local noise = require "engine.utils.noise"

local synth = {}

--- Default sample rate for generated audio, in Hz.
synth.SAMPLE_RATE = 44100

--- Generates `duration * sampleRate` samples into a 1-indexed array.
--- `fn` is called in ascending order, so a closure may carry state such as
--- an oscillator phase between calls.
---@param duration number Length in seconds
---@param fn fun(t: number, i: number): number Called with the time in seconds and the 0-based sample index, returns roughly -1..1
---@param sampleRate number|nil Defaults to synth.SAMPLE_RATE
---@return number[] samples
function synth.generate(duration, fn, sampleRate)
  sampleRate = sampleRate or synth.SAMPLE_RATE
  local count = math.floor(duration * sampleRate + 0.5)
  local samples = {}
  for i = 0, count - 1 do
    samples[i + 1] = fn(i / sampleRate, i)
  end
  return samples
end

--- Adds `src * gain` into `dst` in place. `src` may be shorter than `dst`.
---@param dst number[] Destination buffer, modified in place
---@param src number[] Buffer to add
---@param gain number|nil Multiplier applied to `src`, defaults to 1
---@return number[] dst
function synth.mix(dst, src, gain)
  gain = gain or 1
  local n = math.min(#dst, #src)
  for i = 1, n do
    dst[i] = dst[i] + src[i] * gain
  end
  return dst
end

--- Scales every sample in place.
---@param samples number[] Buffer, modified in place
---@param gain number Multiplier
---@return number[] samples
function synth.gain(samples, gain)
  for i = 1, #samples do
    samples[i] = samples[i] * gain
  end
  return samples
end

--- Cubic soft clip: clamps to [-1, 1] then applies 1.5x - 0.5x^3, which maps
--- 1 to 1 with a smooth knee instead of a hard edge.
---@param x number
---@return number
function synth.softClip(x)
  x = noise.clamp(x, -1, 1)
  return 1.5 * x - 0.5 * x * x * x
end

--- Packs a 1-indexed array of samples into 16-bit mono SoundData. Values are
--- clamped to [-1, 1] so an over-driven mix never wraps.
---@param samples number[] Sample buffer
---@param sampleRate number|nil Defaults to synth.SAMPLE_RATE
---@return love.SoundData
function synth.toSoundData(samples, sampleRate)
  sampleRate = sampleRate or synth.SAMPLE_RATE
  local count = #samples
  local soundData = love.sound.newSoundData(count, sampleRate, 16, 1)
  for i = 1, count do
    soundData:setSample(i - 1, noise.clamp(samples[i], -1, 1))
  end
  return soundData
end

--- Convenience: generates straight into SoundData with no intermediate array.
--- Use `generate` + `toSoundData` instead when the buffer needs filtering.
---@param duration number Length in seconds
---@param fn fun(t: number, i: number): number See synth.generate
---@param sampleRate number|nil Defaults to synth.SAMPLE_RATE
---@return love.SoundData
function synth.render(duration, fn, sampleRate)
  sampleRate = sampleRate or synth.SAMPLE_RATE
  local count = math.floor(duration * sampleRate + 0.5)
  local soundData = love.sound.newSoundData(count, sampleRate, 16, 1)
  for i = 0, count - 1 do
    soundData:setSample(i, noise.clamp(fn(i / sampleRate, i), -1, 1))
  end
  return soundData
end

--- Turns a buffer rendered with `preroll` extra leading samples into a
--- seamless loop. The lead-in lets filter state settle; the loop is the
--- rest of the buffer, with its last `preroll` samples crossfaded into the
--- lead-in so the wrap point is continuous. For a strictly periodic signal
--- the blend is a no-op; for noise it is the seam.
---@param samples number[] Buffer of length loop + preroll
---@param preroll number Lead-in length in samples
---@return number[] loop
function synth.loopFromPreroll(samples, preroll)
  preroll = math.floor(preroll)
  local length = #samples - preroll
  assert(length > preroll, "synth.loopFromPreroll: loop must be longer than the preroll")
  local out = {}
  for k = 1, length do
    out[k] = samples[preroll + k]
  end
  local fadeStart = length - preroll
  for k = fadeStart + 1, length do
    local w = (k - fadeStart) / preroll
    out[k] = out[k] * (1 - w) + samples[k - fadeStart] * w
  end
  return out
end

--- Wraps SoundData in a static Source ready for cacheManager.addSound.
---@param soundData love.SoundData
---@return love.Source
function synth.newSource(soundData)
  return love.audio.newSource(soundData)
end

return synth
