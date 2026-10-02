--[[
    Sequencer.lua

    Generic step sequencer over cached one-shot and loop samples. The game
    supplies the instruments (cache keys plus the semitone each sample was
    rendered at) and an onStep callback that decides what to play; the
    sequencer keeps the clock, the voice pools, pitch mapping and the
    attack/release ramps for held notes.

    Transport methods are named like a love.Source (play/pause/stop/
    setVolume/isPlaying) so audioManager can hold a Sequencer as its
    current music and drive it through update(dt).
    Lua 5.1 safe.
--]]

local Object = require "engine.lib.classic"
local cacheManager = require "engine.cacheManager"

---@class SequencerZone
---@field key string cacheManager sound key of the one-shot or loop sample
---@field root number Semitone the sample was rendered at (same reference as note calls)

---@class SequencerInstrument
---@field key string|nil Shorthand for a single zone
---@field root number|nil Root of the single zone, default 0
---@field zones SequencerZone[]|nil Multi-sample keymap; the nearest root is used
---@field voices number|nil Max simultaneous voices per zone (default 1)
---@field loop boolean|nil Clones are set looping; use with noteOn/releaseAll

---@class SequencerConfig
---@field bpm number
---@field stepsPerBeat number|nil Default 4 (16ths)
---@field beatsPerBar number|nil Default 4
---@field instruments table<string, SequencerInstrument>
---@field onStep fun(seq: Sequencer, bar: number, beat: number, sub: number, step: number) bar counts from 1 and never wraps; beat 1..beatsPerBar; sub 1..stepsPerBeat; step 1..stepsPerBeat*beatsPerBar

---@class SequencerVoice
---@field source love.Source
---@field base number Volume asked for by the note
---@field level number Ramp level 0..1
---@field rate number Ramp rate per second (0 = idle)
---@field held boolean Started by noteOn and not yet released
---@field paused boolean Paused by Sequencer:pause

---@class Sequencer : Object
---@field bar number Current bar, from 1 (0 before the first step)
---@field step number Current step within the bar
---@field volume number Master multiplier applied to every voice
local Sequencer = Object:extend()

local MAX_STEPS_PER_FRAME = 2
local MIN_PITCH = 0.05

--- Builds a zone pool entry.
---@param key string
---@param root number
---@param voices number
---@param loop boolean
---@return table
local function newZone(key, root, voices, loop)
  local master = cacheManager.getSound(key)
  master:setLooping(loop)
  return {
    key = key,
    root = root,
    maxVoices = voices,
    loop = loop,
    next = 1,
    voices = { { source = master, base = 0, level = 1, rate = 0, held = false, paused = false } },
  }
end

---@param config SequencerConfig
function Sequencer:new(config)
  assert(config and config.bpm, "Sequencer needs a bpm")
  assert(config.onStep, "Sequencer needs an onStep callback")
  self.stepsPerBeat = config.stepsPerBeat or 4
  self.beatsPerBar = config.beatsPerBar or 4
  self.stepsPerBar = self.stepsPerBeat * self.beatsPerBar
  self.onStep = config.onStep
  self.volume = 1
  self.bar = 0
  self.step = 0
  self.accumulator = 0
  self.playing = false
  self:setBpm(config.bpm)

  ---@type table<string, table>
  self.instruments = {}
  ---@type table[]
  self.instrumentList = {}
  for name, inst in pairs(config.instruments or {}) do
    local zones = {}
    if inst.zones then
      for i = 1, #inst.zones do
        zones[i] = newZone(inst.zones[i].key, inst.zones[i].root or 0, inst.voices or 1, inst.loop or false)
      end
    else
      assert(inst.key, "Sequencer instrument '" .. name .. "' needs a key or zones")
      zones[1] = newZone(inst.key, inst.root or 0, inst.voices or 1, inst.loop or false)
    end
    local entry = { name = name, zones = zones }
    self.instruments[name] = entry
    self.instrumentList[#self.instrumentList + 1] = entry
  end
end

---@param bpm number Takes effect on the next step
function Sequencer:setBpm(bpm)
  self.bpm = bpm
  self.stepLength = 60 / bpm / self.stepsPerBeat
end

---@return number
function Sequencer:getBpm()
  return self.bpm
end

--- Applies a voice's current level to its Source.
---@param voice SequencerVoice
function Sequencer:applyVoiceVolume(voice)
  voice.source:setVolume(voice.base * voice.level * self.volume)
end

---@param volume number 0..1, reapplied to every live voice
function Sequencer:setVolume(volume)
  self.volume = math.max(0, math.min(volume, 1))
  for i = 1, #self.instrumentList do
    local zones = self.instrumentList[i].zones
    for z = 1, #zones do
      local voices = zones[z].voices
      for v = 1, #voices do
        self:applyVoiceVolume(voices[v])
      end
    end
  end
end

--- Picks the zone whose root is nearest the requested semitone.
---@param inst table
---@param semitones number
---@return table zone
local function nearestZone(inst, semitones)
  local zones = inst.zones
  local best = zones[1]
  local bestDist = math.abs(semitones - best.root)
  for i = 2, #zones do
    local dist = math.abs(semitones - zones[i].root)
    if dist < bestDist then
      best, bestDist = zones[i], dist
    end
  end
  return best
end

--- Finds a free voice in a zone: the first idle one, a new clone while the
--- pool is below its cap, otherwise the next voice round-robin (stopped first).
---@param zone table
---@return SequencerVoice
local function acquireVoice(zone)
  local voices = zone.voices
  for i = 1, #voices do
    local voice = voices[i]
    if not voice.held and voice.rate == 0 and not voice.source:isPlaying() then
      return voice
    end
  end
  if #voices < zone.maxVoices then
    local source = voices[1].source:clone()
    source:setLooping(zone.loop)
    local voice = { source = source, base = 0, level = 1, rate = 0, held = false, paused = false }
    voices[#voices + 1] = voice
    return voice
  end
  local voice = voices[zone.next]
  zone.next = zone.next % #voices + 1
  voice.source:stop()
  voice.held = false
  voice.rate = 0
  return voice
end

--- Starts a voice at the given pitch and level.
---@param voice SequencerVoice
---@param zone table
---@param semitones number
---@param volume number
---@param level number Initial ramp level
---@param pitchVariance number|nil
local function startVoice(self, voice, zone, semitones, volume, level, pitchVariance)
  local pitch = 2 ^ ((semitones - zone.root) / 12)
  if pitchVariance and pitchVariance > 0 then
    pitch = pitch * (1 + (love.math.random() * 2 - 1) * pitchVariance)
  end
  voice.base = volume
  voice.level = level
  voice.paused = false
  voice.source:setPitch(math.max(MIN_PITCH, pitch))
  self:applyVoiceVolume(voice)
  voice.source:play()
end

--- Fire-and-forget hit.
---@param instrument string Instrument name
---@param semitones number Pitch, in the same semitone reference as the zone roots
---@param volume number 0..1, scaled by the master volume
---@param pitchVariance number|nil Uniform random pitch offset, e.g. 0.05 for +/-5%
---@return love.Source
function Sequencer:note(instrument, semitones, volume, pitchVariance)
  local inst = self.instruments[instrument]
  assert(inst, "Sequencer: unknown instrument " .. tostring(instrument))
  local zone = nearestZone(inst, semitones)
  local voice = acquireVoice(zone)
  voice.held = false
  voice.rate = 0
  startVoice(self, voice, zone, semitones, volume, 1, pitchVariance)
  return voice.source
end

--- Starts a held voice that ramps from silence to `volume` over `attack`
--- seconds. Loops if the instrument is a loop. Release it with releaseAll.
---@param instrument string
---@param semitones number
---@param volume number 0..1
---@param attack number Seconds; 0 starts at full level
function Sequencer:noteOn(instrument, semitones, volume, attack)
  local inst = self.instruments[instrument]
  assert(inst, "Sequencer: unknown instrument " .. tostring(instrument))
  local zone = nearestZone(inst, semitones)
  local voice = acquireVoice(zone)
  voice.held = true
  if attack and attack > 0 then
    voice.rate = 1 / attack
    startVoice(self, voice, zone, semitones, volume, 0, nil)
  else
    voice.rate = 0
    startVoice(self, voice, zone, semitones, volume, 1, nil)
  end
end

--- Ramps every held voice of an instrument to silence over `release`
--- seconds, then stops it.
---@param instrument string
---@param release number Seconds; 0 stops immediately
function Sequencer:releaseAll(instrument, release)
  local inst = self.instruments[instrument]
  assert(inst, "Sequencer: unknown instrument " .. tostring(instrument))
  for z = 1, #inst.zones do
    local voices = inst.zones[z].voices
    for v = 1, #voices do
      local voice = voices[v]
      if voice.held then
        voice.held = false
        if release and release > 0 then
          voice.rate = -1 / release
        else
          voice.rate = 0
          voice.level = 0
          voice.source:stop()
        end
      end
    end
  end
end

--- Advances every ramping voice.
---@param dt number
function Sequencer:updateRamps(dt)
  for i = 1, #self.instrumentList do
    local zones = self.instrumentList[i].zones
    for z = 1, #zones do
      local voices = zones[z].voices
      for v = 1, #voices do
        local voice = voices[v]
        if voice.rate ~= 0 then
          local level = voice.level + voice.rate * dt
          if level >= 1 then
            level = 1
            voice.rate = 0
          elseif level <= 0 then
            level = 0
            voice.rate = 0
            voice.held = false
            voice.source:stop()
          end
          voice.level = level
          self:applyVoiceVolume(voice)
        end
      end
    end
  end
end

--- Advances the clock, runs the ramps and fires onStep for each elapsed
--- step. At most MAX_STEPS_PER_FRAME steps fire per call; any further
--- backlog (after a hitch or a hidden browser tab) is dropped rather than
--- played as a burst.
---@param dt number
function Sequencer:update(dt)
  if not self.playing then
    return
  end
  self:updateRamps(dt)
  self.accumulator = self.accumulator + dt
  local fired = 0
  while self.accumulator >= self.stepLength and fired < MAX_STEPS_PER_FRAME do
    self.accumulator = self.accumulator - self.stepLength
    fired = fired + 1
    self.step = self.step + 1
    if self.step > self.stepsPerBar then
      self.step = 1
      self.bar = self.bar + 1
    end
    local beat = math.floor((self.step - 1) / self.stepsPerBeat) + 1
    local sub = (self.step - 1) % self.stepsPerBeat + 1
    self.onStep(self, self.bar, beat, sub, self.step)
  end
  if self.accumulator >= self.stepLength then
    self.accumulator = self.accumulator % self.stepLength
  end
end

--- Starts the clock. The first step fires on the next update. After
--- pause(), resumes the paused voices and the clock where they were.
function Sequencer:play()
  if self.playing then
    return
  end
  self.playing = true
  if self.bar == 0 then
    self.bar = 1
    self.step = 0
    self.accumulator = self.stepLength
  end
  for i = 1, #self.instrumentList do
    local zones = self.instrumentList[i].zones
    for z = 1, #zones do
      local voices = zones[z].voices
      for v = 1, #voices do
        local voice = voices[v]
        if voice.paused then
          voice.paused = false
          voice.source:play()
        end
      end
    end
  end
end

--- Halts the clock and pauses every sounding voice.
function Sequencer:pause()
  if not self.playing then
    return
  end
  self.playing = false
  for i = 1, #self.instrumentList do
    local zones = self.instrumentList[i].zones
    for z = 1, #zones do
      local voices = zones[z].voices
      for v = 1, #voices do
        local voice = voices[v]
        if voice.source:isPlaying() then
          voice.paused = true
          voice.source:pause()
        end
      end
    end
  end
end

--- Stops every voice, clears ramps and resets the clock to the start.
function Sequencer:stop()
  self.playing = false
  self.bar = 0
  self.step = 0
  self.accumulator = 0
  for i = 1, #self.instrumentList do
    local zones = self.instrumentList[i].zones
    for z = 1, #zones do
      local voices = zones[z].voices
      for v = 1, #voices do
        local voice = voices[v]
        voice.source:stop()
        voice.held = false
        voice.paused = false
        voice.rate = 0
        voice.level = 1
      end
    end
  end
end

---@return boolean
function Sequencer:isPlaying()
  return self.playing
end

return Sequencer
