local cacheManager = require "engine.cacheManager"
local audioManager = {}
local music = nil
local disableMusic = false
local disableSounds = false
local musicVolume = 0.2
local soundVolume = 0.5
--- Per-key pools of cloned Sources so one sound can overlap itself.
---@type table<string, { voices: love.Source[], next: number }>
local voicePools = {}

---@param key string The key to look up the sound
---@param [loop] optional boolean Whether to loop the music
---@return love.Source|nil The cached music object or nil if not found
function audioManager.playMusic(key, loop)
  if disableMusic then
    return
  end
  if music then
    music:stop()
  end

  local musicTrack = cacheManager.getMusic(key)
  if not musicTrack then
    error("Music not found in cache: " .. key)
  end
  musicTrack:setLooping(loop or true)
  musicTrack:setVolume(musicVolume)
  musicTrack:play()
  music = musicTrack
end

function audioManager.pauseMusic()
  if music then
    music:pause()
  end
end

function audioManager.resumeMusic()
  if music then
    music:play()
  end
end

--- Plays a generated music source such as an engine.Sequencer: anything
--- with play/pause/stop/setVolume and an optional update(dt), which
--- audioManager.update drives every frame.
---@param generator table The generator; replaces any current music
function audioManager.playGenerated(generator)
  if disableMusic then
    return
  end
  if music then
    music:stop()
  end
  generator:setVolume(musicVolume)
  generator:play()
  music = generator
end

--- Drives the current music when it needs per-frame updates. Called by
--- engine.Game every frame after the scene update.
---@param dt number
function audioManager.update(dt)
  if music and music.update then
    music:update(dt)
  end
end

---@param volume number 0..1, stored for future tracks and applied to the current one
function audioManager.setMusicVolume(volume)
  musicVolume = math.max(0, math.min(volume, 1))
  if music then
    music:setVolume(musicVolume)
  end
end

---@return number
function audioManager.getMusicVolume()
  return musicVolume
end

function audioManager.setSoundVolume(volume)
  soundVolume = math.max(0, math.min(volume, 1))
end

function audioManager.stopMusic()
  if music then
    music:stop()
    music = nil
  end
end

---@class PlaySoundOptions
---@field volume number|nil Multiplier on the global sound volume, 0..1 (default 1)
---@field pitch number|nil Base pitch multiplier (default 1)
---@field pitchVariance number|nil Uniform random offset applied to the pitch, e.g. 0.1 gives 0.9..1.1 (default 0)
---@field voices number|nil Max simultaneous instances of this sound (default 1, which restarts the sound like a plain play)

--- Picks a voice from the pool for a key: the first idle one, a new clone
--- while the pool is below `wanted`, otherwise the oldest voice round-robin.
--- Clones share the cached Source's SoundData, so growth is cheap and bounded.
---@param key string The cache key of the sound
---@param wanted number Max voices for this pool
---@return love.Source
local function acquireVoice(key, wanted)
  local pool = voicePools[key]
  if not pool then
    pool = { voices = { cacheManager.getSound(key) }, next = 1 }
    voicePools[key] = pool
  end
  local voices = pool.voices
  for i = 1, #voices do
    if not voices[i]:isPlaying() then
      return voices[i]
    end
  end
  if #voices < wanted then
    local voice = voices[1]:clone()
    voices[#voices + 1] = voice
    return voice
  end
  local voice = voices[pool.next]
  pool.next = pool.next % #voices + 1
  voice:stop()
  return voice
end

--- Plays a cached sound. With `opts.voices` above 1, rapid calls overlap
--- instead of cutting each other off.
---@param key string The key to look up the sound
---@param opts PlaySoundOptions|nil
---@return love.Source|nil The voice that was started, or nil when sounds are disabled
function audioManager.playSound(key, opts)
  if disableSounds then
    return nil
  end

  local wanted = 1
  local volume = 1
  local pitch = 1
  if opts then
    wanted = opts.voices or 1
    volume = opts.volume or 1
    pitch = opts.pitch or 1
    if opts.pitchVariance then
      pitch = pitch + (love.math.random() * 2 - 1) * opts.pitchVariance
    end
  end

  local voice = acquireVoice(key, wanted)
  voice:setVolume(soundVolume * volume)
  voice:setPitch(math.max(0.05, pitch))
  voice:play()
  return voice
end

return audioManager
