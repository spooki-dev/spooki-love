local cacheManager = require "engine.cacheManager"
local audioManager = {}
local music = nil
local disableMusic = false
local disableSounds = false
local musicVolume = 0.2
local soundVolume = 0.5

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

function audioManager.setMusicVolume(volume)
  local nextVolume = math.max(0, math.min(volume, 1))
  if music then
    music:setVolume(nextVolume)
  end
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

function audioManager.playSound(key)
  if disableSounds then
    return
  end

  local sound = cacheManager.getSound(key)
  if not sound then
    error("Sound not found in cache: " .. key)
  end
  sound:stop()
  sound:setVolume(soundVolume)
  sound:play()
end

return audioManager
