local table_serialize = require "engine.utils.table_serialize"

--- Action-based input. The game declares named actions in the Game config;
--- each action has a list of bindings (keyboard scancodes, mouse buttons,
--- gamepad buttons, or one direction of a gamepad axis). Every action reports
--- a digital `down` state plus an analog `strength` (keys are 1), and axes or
--- vectors are composed from actions, so rebinding is uniform: any single
--- input can be assigned to any action.
---
--- Binding shorthand (what the config, the save file and the UI pass around):
---   "key:<scancode>"        layout independent; shown via getKeyFromScancode
---   "mouse:<button>"        1 left, 2 right, 3 middle, ...
---   "pad:<GamepadButton>"   a, b, x, y, back, guide, start, leftstick,
---                           rightstick, leftshoulder, rightshoulder,
---                           dpup, dpdown, dpleft, dpright
---   "axis:<GamepadAxis><+|->" leftx, lefty, rightx, righty, triggerleft,
---                           triggerright; the sign picks the direction
---
--- Single player, any device: keyboard, mouse and every connected gamepad
--- drive the same actions. The most recently used device is reported by
--- getActiveDevice() so prompts can show matching glyphs.
---
--- Lifecycle: Game calls init(config) before scenes load, feeds raw love
--- callbacks in (for capture, device tracking and tap latching), calls
--- update(dt) once per frame before the scene updates, then drains the
--- pressed/released lists into scene action events.
local inputMap = {}

inputMap.SAVE_VERSION = 1
inputMap.DEVICE_KEYBOARD = "keyboard"
inputMap.DEVICE_GAMEPAD = "gamepad"

-- Actions every game gets. Locked actions cannot be rebound and never have
-- bindings stolen from them, so menus always stay operable.
inputMap.UI_ACTIONS = {
  { name = "ui_up",     label = "Menu up",     category = "Menu", locked = true, bindings = { "key:up", "pad:dpup", "axis:lefty-" } },
  { name = "ui_down",   label = "Menu down",   category = "Menu", locked = true, bindings = { "key:down", "pad:dpdown", "axis:lefty+" } },
  { name = "ui_left",   label = "Menu left",   category = "Menu", locked = true, bindings = { "key:left", "pad:dpleft", "axis:leftx-" } },
  { name = "ui_right",  label = "Menu right",  category = "Menu", locked = true, bindings = { "key:right", "pad:dpright", "axis:leftx+" } },
  { name = "ui_accept", label = "Select",      category = "Menu", locked = true, bindings = { "key:return", "key:space", "pad:a" } },
  { name = "ui_cancel", label = "Back",        category = "Menu", locked = true, bindings = { "key:escape", "pad:b" } },
}

local AXIS_PRESS = 0.5    -- an axis direction counts as pressed above this
local AXIS_RELEASE = 0.3  -- and released again below this (hysteresis)
local CAPTURE_AXIS = 0.6  -- deflection needed to capture an axis as a binding
local MOUSE_MOVE_SWITCH = 4 -- pixels of mouse travel that mark the keyboard/mouse as active

local VALID_BUTTONS = {
  a = true, b = true, x = true, y = true, back = true, guide = true, start = true,
  leftstick = true, rightstick = true, leftshoulder = true, rightshoulder = true,
  dpup = true, dpdown = true, dpleft = true, dpright = true,
}
local VALID_AXES = {
  leftx = true, lefty = true, rightx = true, righty = true, triggerleft = true, triggerright = true,
}

-- Module state. Rebuilt by init() on every hot reload (Game:load re-runs),
-- which also re-reads the save file and re-enumerates joysticks.
local actions = {}        -- array, declaration order (UI actions first)
local byName = {}         -- name -> action
local bindingIndex = {}   -- input id -> array of actions bound to it
local joysticks = {}      -- connected gamepad-capable joysticks
local config = { deadzone = 0.25, saveFile = "bindings.lua" }
local initialised = false
local version = 0         -- bumped whenever bindings change; UI polls it
local activeDevice = inputMap.DEVICE_KEYBOARD
local activeJoystick = nil
local gamepadStyle = "generic"
local deviceListeners = {}
local capture = nil
local flushPending = true
local virtualKeyDown = nil
local virtualMouseDown = nil
local virtualActions = {}
local pressedList, pressedCount = {}, 0
local releasedList, releasedCount = {}, 0

-- ---------------------------------------------------------------------------
-- Binding parsing

--- Parses binding shorthand into an input record.
--- @param str string e.g. "key:space", "axis:leftx-"
--- @return table|nil input { kind, code, sign, id }
--- @return string|nil err
function inputMap.parse(str)
  if type(str) ~= "string" then return nil, "binding must be a string" end
  local kind, rest = str:match("^(%a+):(.+)$")
  if not kind then return nil, "malformed binding '" .. str .. "'" end
  if kind == "key" then
    return { kind = "key", code = rest, id = str }
  elseif kind == "mouse" then
    local button = tonumber(rest)
    if not button or button < 1 then return nil, "bad mouse button in '" .. str .. "'" end
    return { kind = "mouse", code = button, id = "mouse:" .. button }
  elseif kind == "pad" then
    if not VALID_BUTTONS[rest] then return nil, "unknown gamepad button in '" .. str .. "'" end
    return { kind = "pad", code = rest, id = str }
  elseif kind == "axis" then
    local axis, signChar = rest:match("^(%a+)([%+%-])$")
    if not axis or not VALID_AXES[axis] then return nil, "unknown gamepad axis in '" .. str .. "'" end
    return { kind = "axis", code = axis, sign = signChar == "+" and 1 or -1, id = str }
  end
  return nil, "unknown binding kind '" .. kind .. "'"
end

--- The shorthand string for an input record.
--- @param input table
--- @return string
function inputMap.format(input)
  return input.id
end

--- Which device family a binding belongs to.
--- @param inputOrString table|string
--- @return string "keyboard" (keys and mouse) or "gamepad" (buttons and axes)
function inputMap.deviceFor(inputOrString)
  local kind = type(inputOrString) == "table" and inputOrString.kind or tostring(inputOrString):match("^(%a+):")
  if kind == "pad" or kind == "axis" then return inputMap.DEVICE_GAMEPAD end
  return inputMap.DEVICE_KEYBOARD
end

local function parseList(list, context)
  local out = {}
  for _, str in ipairs(list or {}) do
    local input, err = inputMap.parse(str)
    if input then
      out[#out + 1] = input
    else
      print("inputMap: ignoring binding for " .. context .. ": " .. err)
    end
  end
  return out
end

local function rebuildIndex()
  bindingIndex = {}
  for _, action in ipairs(actions) do
    for _, input in ipairs(action.bindings) do
      local list = bindingIndex[input.id]
      if not list then
        list = {}
        bindingIndex[input.id] = list
      end
      list[#list + 1] = action
    end
  end
  version = version + 1
end

-- ---------------------------------------------------------------------------
-- Devices

local VENDOR_STYLES = { [0x045e] = "xbox", [0x054c] = "playstation", [0x057e] = "nintendo" }

--- Guesses the glyph style for a joystick from its USB vendor id, then its name.
--- @param joystick love.Joystick
--- @return string "xbox" | "playstation" | "nintendo" | "generic"
function inputMap.styleFor(joystick)
  if joystick.getDeviceInfo then
    local ok, vendor = pcall(joystick.getDeviceInfo, joystick)
    if ok and vendor and VENDOR_STYLES[vendor] then
      return VENDOR_STYLES[vendor]
    end
  end
  local name = (joystick:getName() or ""):lower()
  if name:find("xbox") or name:find("x%-box") or name:find("xinput") then return "xbox" end
  if name:find("dualshock") or name:find("dualsense") or name:find("playstation") or name:find("sony")
      or name:find("ps4") or name:find("ps5") or name:find("wireless controller") then
    return "playstation"
  end
  if name:find("nintendo") or name:find("pro controller") or name:find("joy%-con") or name:find("switch") then
    return "nintendo"
  end
  return "generic"
end

local function notifyDevice()
  for _, fn in ipairs(deviceListeners) do
    fn(activeDevice, activeJoystick, gamepadStyle)
  end
end

local function setDevice(device, joystick)
  local changed = device ~= activeDevice
  if device == inputMap.DEVICE_GAMEPAD and joystick and joystick ~= activeJoystick then
    activeJoystick = joystick
    gamepadStyle = inputMap.styleFor(joystick)
    changed = true
  end
  activeDevice = device
  if changed then notifyDevice() end
end

local function addJoystick(joystick)
  if not joystick:isGamepad() then return end
  for _, j in ipairs(joysticks) do
    if j == joystick then return end
  end
  joysticks[#joysticks + 1] = joystick
  if not activeJoystick then
    activeJoystick = joystick
    gamepadStyle = inputMap.styleFor(joystick)
  end
  notifyDevice()
end

--- love.joystickadded forwarder.
function inputMap.joystickadded(joystick)
  addJoystick(joystick)
end

--- love.joystickremoved forwarder.
function inputMap.joystickremoved(joystick)
  for i = #joysticks, 1, -1 do
    if joysticks[i] == joystick then table.remove(joysticks, i) end
  end
  if activeJoystick == joystick then
    activeJoystick = joysticks[1]
    gamepadStyle = activeJoystick and inputMap.styleFor(activeJoystick) or "generic"
    if not activeJoystick then activeDevice = inputMap.DEVICE_KEYBOARD end
  end
  notifyDevice()
end

--- "keyboard" or "gamepad": whichever the player touched last.
--- @return string
function inputMap.getActiveDevice()
  return activeDevice
end

--- Glyph style of the active (or first connected) gamepad.
--- @return string "xbox" | "playstation" | "nintendo" | "generic"
function inputMap.getGamepadStyle()
  return gamepadStyle
end

--- The joystick that was used most recently, if any.
--- @return love.Joystick|nil
function inputMap.getActiveJoystick()
  return activeJoystick
end

--- All connected gamepad-capable joysticks.
--- @return table
function inputMap.getJoysticks()
  return joysticks
end

--- Human readable name of the active device.
--- @return string
function inputMap.getDeviceName()
  if activeDevice == inputMap.DEVICE_GAMEPAD then
    return activeJoystick and activeJoystick:getName() or "Gamepad"
  end
  return "Keyboard & Mouse"
end

--- Overrides the active device and gamepad style, for previews and tests
--- (e.g. showing PlayStation glyphs without a PlayStation pad connected).
--- The next real input switches back.
--- @param device string "keyboard" | "gamepad"
--- @param style string|nil "xbox" | "playstation" | "nintendo" | "generic"
function inputMap.forceDevice(device, style)
  activeDevice = device
  if style then gamepadStyle = style end
  notifyDevice()
end

--- Registers a listener called with (device, joystick, style) whenever the
--- active device, its style, or the set of joysticks changes.
--- @param fn function
function inputMap.onDeviceChanged(fn)
  deviceListeners[#deviceListeners + 1] = fn
end

--- Removes a listener added with onDeviceChanged.
--- @param fn function
function inputMap.removeDeviceListener(fn)
  for i = #deviceListeners, 1, -1 do
    if deviceListeners[i] == fn then table.remove(deviceListeners, i) end
  end
end

-- ---------------------------------------------------------------------------
-- Init and persistence

local function newAction(def)
  assert(type(def.name) == "string" and def.name ~= "", "input action needs a name")
  assert(not byName[def.name], "duplicate input action '" .. def.name .. "'")
  local action = {
    name = def.name,
    label = def.label or def.name,
    category = def.category or "General",
    locked = def.locked or false,
    defaults = parseList(def.bindings, def.name),
    bindings = {},
    down = false,
    prevDown = false,
    strength = 0,
    raw = 0,
    latched = false,
  }
  for i, input in ipairs(action.defaults) do
    action.bindings[i] = { kind = input.kind, code = input.code, sign = input.sign, id = input.id }
  end
  return action
end

local function sameBindings(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do
    if a[i].id ~= b[i].id then return false end
  end
  return true
end

--- Whether an action still has its default bindings.
--- @param name string
--- @return boolean
function inputMap.isDefault(name)
  local action = assert(byName[name], "unknown action " .. tostring(name))
  return sameBindings(action.bindings, action.defaults)
end

--- Writes non-default bindings to the save file (or removes the file when
--- everything is default).
function inputMap.save()
  local data = { version = inputMap.SAVE_VERSION, bindings = {} }
  local any = false
  for _, action in ipairs(actions) do
    if not action.locked and not sameBindings(action.bindings, action.defaults) then
      local list = {}
      for i, input in ipairs(action.bindings) do list[i] = input.id end
      data.bindings[action.name] = list
      any = true
    end
  end
  if not config.saveFile then return end
  if any then
    love.filesystem.write(config.saveFile, table_serialize.serialize(data))
  else
    love.filesystem.remove(config.saveFile)
  end
end

local function loadSaved()
  if not config.saveFile then return end
  -- Check first: reading a missing file raises a LOVE exception internally, and
  -- love.js cannot catch it, so the web build would abort on first run.
  if not love.filesystem.getInfo(config.saveFile, "file") then return end
  local contents = love.filesystem.read(config.saveFile)
  if not contents then return end
  local ok, data = pcall(table_serialize.deserialize, contents)
  if not ok or type(data) ~= "table" or type(data.bindings) ~= "table" then
    print("inputMap: ignoring unreadable " .. config.saveFile)
    return
  end
  for name, list in pairs(data.bindings) do
    local action = byName[name]
    if action and not action.locked and type(list) == "table" then
      action.bindings = parseList(list, name)
    end
  end
end

--- Builds the action table from the Game config. Safe to call again (hot
--- reload): state is rebuilt, the save file re-read and joysticks re-listed.
--- @param cfg table|nil { actions = {...}, deadzone = 0.25, saveFile = "bindings.lua" }
function inputMap.init(cfg)
  cfg = cfg or {}
  config.deadzone = cfg.deadzone or 0.25
  if cfg.saveFile == false then
    config.saveFile = nil
  else
    config.saveFile = cfg.saveFile or "bindings.lua"
  end
  actions, byName = {}, {}
  deviceListeners = {}
  capture = nil
  virtualActions = {}
  pressedCount, releasedCount = 0, 0
  for _, def in ipairs(inputMap.UI_ACTIONS) do
    local action = newAction(def)
    actions[#actions + 1] = action
    byName[action.name] = action
  end
  for _, def in ipairs(cfg.actions or {}) do
    local action = newAction(def)
    actions[#actions + 1] = action
    byName[action.name] = action
  end
  loadSaved()
  rebuildIndex()

  joysticks = {}
  activeJoystick = nil
  gamepadStyle = "generic"
  if love.joystick then
    for _, joystick in ipairs(love.joystick.getJoysticks()) do
      addJoystick(joystick)
    end
  end
  activeDevice = inputMap.DEVICE_KEYBOARD
  flushPending = true
  initialised = true
end

--- Whether init() has run.
--- @return boolean
function inputMap.isInitialised()
  return initialised
end

--- Changes every time bindings change; cheap to compare each frame.
--- @return number
function inputMap.getVersion()
  return version
end

--- Scalar deadzone used by strength() and vector().
--- @return number
function inputMap.getDeadzone()
  return config.deadzone
end

-- ---------------------------------------------------------------------------
-- Action and binding queries / edits

--- All actions in declaration order (engine ui_* actions first).
--- @return table actions { name, label, category, locked, bindings, defaults }
function inputMap.getActions()
  return actions
end

--- One action record, or nil.
--- @param name string
--- @return table|nil
function inputMap.getAction(name)
  return byName[name]
end

--- Bindings of an action as shorthand strings, optionally for one device.
--- Returns a new table, so call it on change (version bump), not per frame.
--- @param name string
--- @param device string|nil "keyboard" | "gamepad"
--- @return table strings
function inputMap.getBindings(name, device)
  local action = assert(byName[name], "unknown action " .. tostring(name))
  local out = {}
  for _, input in ipairs(action.bindings) do
    if not device or inputMap.deviceFor(input) == device then
      out[#out + 1] = input.id
    end
  end
  return out
end

--- First binding of an action for a device, as an input record (no allocation).
--- @param name string
--- @param device string|nil
--- @return table|nil input
function inputMap.firstBinding(name, device)
  local action = byName[name]
  if not action then return nil end
  for _, input in ipairs(action.bindings) do
    if not device or inputMap.deviceFor(input) == device then
      return input
    end
  end
  return nil
end

--- Actions currently bound to an input.
--- @param str string shorthand
--- @return table actions (possibly empty, shared; do not modify)
function inputMap.actionsBoundTo(str)
  return bindingIndex[str] or {}
end

local function removeBindingFrom(action, id)
  for i = #action.bindings, 1, -1 do
    if action.bindings[i].id == id then table.remove(action.bindings, i) end
  end
end

--- Adds a binding to an action, stealing it from any other unlocked action.
--- Saves afterwards.
--- @param name string
--- @param str string shorthand
--- @return table|nil stolen names of actions that lost the binding, or nil on failure
--- @return string|nil err
function inputMap.bind(name, str)
  local action = byName[name]
  if not action then return nil, "unknown action " .. tostring(name) end
  if action.locked then return nil, action.label .. " cannot be rebound" end
  local input, err = inputMap.parse(str)
  if not input then return nil, err end
  local stolen = {}
  for _, other in ipairs(bindingIndex[input.id] or {}) do
    if other ~= action then
      if other.locked then
        return nil, "that input is reserved for " .. other.label
      end
      stolen[#stolen + 1] = other.name
    end
  end
  for _, otherName in ipairs(stolen) do
    removeBindingFrom(byName[otherName], input.id)
  end
  local already = false
  for _, existing in ipairs(action.bindings) do
    if existing.id == input.id then already = true end
  end
  if not already then
    action.bindings[#action.bindings + 1] = input
  end
  rebuildIndex()
  inputMap.save()
  return stolen
end

--- Replaces the action's bindings for one device with a single input (the
--- usual "press a key to rebind" behaviour), stealing it from other actions.
--- @param name string
--- @param str string shorthand
--- @return table|nil stolen, string|nil err
function inputMap.rebind(name, str)
  local action = byName[name]
  if not action then return nil, "unknown action " .. tostring(name) end
  if action.locked then return nil, action.label .. " cannot be rebound" end
  local input, err = inputMap.parse(str)
  if not input then return nil, err end
  local device = inputMap.deviceFor(input)
  for i = #action.bindings, 1, -1 do
    if inputMap.deviceFor(action.bindings[i]) == device then
      table.remove(action.bindings, i)
    end
  end
  rebuildIndex()
  return inputMap.bind(name, str)
end

--- Removes one binding from an action and saves.
--- @param name string
--- @param str string shorthand
function inputMap.unbind(name, str)
  local action = assert(byName[name], "unknown action " .. tostring(name))
  if action.locked then return end
  removeBindingFrom(action, str)
  rebuildIndex()
  inputMap.save()
end

--- Restores default bindings for one action, or for all when name is nil.
--- @param name string|nil
function inputMap.resetToDefaults(name)
  -- Parenthesised: assert returns every argument, and the message must not join the list.
  local list = actions
  if name then
    list = { (assert(byName[name], "unknown action " .. tostring(name))) }
  end
  for _, action in ipairs(list) do
    action.bindings = {}
    for i, input in ipairs(action.defaults) do
      action.bindings[i] = { kind = input.kind, code = input.code, sign = input.sign, id = input.id }
    end
  end
  rebuildIndex()
  inputMap.save()
end

-- ---------------------------------------------------------------------------
-- Virtual input (dev MCP bridge, tests)

--- Injects virtual-only state readers used alongside the real devices.
--- @param accessors table|nil { keyDown = fun(keyConstant): boolean, mouseDown = fun(button): boolean }
function inputMap.setVirtualInput(accessors)
  virtualKeyDown = accessors and accessors.keyDown or nil
  virtualMouseDown = accessors and accessors.mouseDown or nil
end

--- Holds an action down without any device, for `duration` seconds (or until
--- releaseVirtualAction).
--- @param name string
--- @param duration number|nil
function inputMap.pressVirtualAction(name, duration)
  assert(byName[name], "unknown action " .. tostring(name))
  virtualActions[name] = duration and (love.timer.getTime() + duration) or math.huge
end

--- Releases a virtual action press.
--- @param name string
function inputMap.releaseVirtualAction(name)
  virtualActions[name] = nil
end

-- ---------------------------------------------------------------------------
-- Polling

local function keyConstantFor(scancode)
  local ok, key = pcall(love.keyboard.getKeyFromScancode, scancode)
  return ok and key or scancode
end

-- Reads one binding. Returns raw (0..1 before deadzone) and whether it counts
-- as digitally down.
local function readBinding(input)
  if input.kind == "key" then
    local down = love.keyboard.isScancodeDown(input.code)
    if not down and virtualKeyDown then
      down = virtualKeyDown(keyConstantFor(input.code)) and true or false
    end
    return down and 1 or 0, down
  elseif input.kind == "mouse" then
    local down = love.mouse.isDown(input.code)
    if not down and virtualMouseDown then
      down = virtualMouseDown(input.code) and true or false
    end
    return down and 1 or 0, down
  elseif input.kind == "pad" then
    for _, joystick in ipairs(joysticks) do
      if joystick:isGamepadDown(input.code) then
        return 1, true
      end
    end
    return 0, false
  elseif input.kind == "axis" then
    local raw = 0
    for _, joystick in ipairs(joysticks) do
      local v = joystick:getGamepadAxis(input.code) * input.sign
      if v > raw then raw = v end
    end
    if input.axisDown then
      if raw <= AXIS_RELEASE then input.axisDown = false end
    else
      if raw >= AXIS_PRESS then input.axisDown = true end
    end
    return raw, input.axisDown == true
  end
  return 0, false
end

--- Polls every binding and computes this frame's edges. Call once per frame
--- before the scene updates.
--- @param dt number
function inputMap.update(dt)
  pressedCount, releasedCount = 0, 0
  local now = love.timer and love.timer.getTime() or 0
  local capturing = capture ~= nil
  for _, action in ipairs(actions) do
    action.prevDown = action.down
    local raw, down = 0, false
    for _, input in ipairs(action.bindings) do
      local r, d = readBinding(input)
      if r > raw then raw = r end
      if d then down = true end
    end
    if action.latched then
      down = true
      if raw < 1 then raw = 1 end
      action.latched = false
    end
    local virtualUntil = virtualActions[action.name]
    if virtualUntil then
      if now <= virtualUntil then
        down = true
        raw = 1
      else
        virtualActions[action.name] = nil
      end
    end
    if capturing then
      down, raw = false, 0
    end
    action.down = down
    action.raw = raw
    if raw <= config.deadzone then
      action.strength = down and 1 or 0
      if action.strength == 1 and raw < 1 then action.strength = raw end
    else
      action.strength = math.min(1, (raw - config.deadzone) / (1 - config.deadzone))
    end
    if not flushPending then
      if down and not action.prevDown then
        pressedCount = pressedCount + 1
        pressedList[pressedCount] = action.name
      elseif action.prevDown and not down then
        releasedCount = releasedCount + 1
        releasedList[releasedCount] = action.name
      end
    end
  end
  flushPending = false
end

--- Drops this frame's edges (and any already computed). Called on scene
--- changes and when a capture ends so a held key cannot act twice.
function inputMap.flushEdges()
  flushPending = true
  pressedCount, releasedCount = 0, 0
  for _, action in ipairs(actions) do
    action.latched = false
  end
end

--- Forgets held state: latches, virtual presses and edges. Polling makes the
--- device state self-correct, so this is enough on focus loss.
function inputMap.releaseAll()
  virtualActions = {}
  inputMap.flushEdges()
end

--- Names of actions that went down this frame.
--- @return table list, number count
function inputMap.getPressed()
  return pressedList, pressedCount
end

--- Names of actions that went up this frame.
--- @return table list, number count
function inputMap.getReleased()
  return releasedList, releasedCount
end

local function get(name)
  local action = byName[name]
  if not action then error("unknown input action '" .. tostring(name) .. "'", 3) end
  return action
end

--- Whether the action is held.
--- @param name string
--- @return boolean
function inputMap.down(name)
  return get(name).down
end

--- Whether the action went down this frame.
--- @param name string
--- @return boolean
function inputMap.pressed(name)
  local action = get(name)
  return action.down and not action.prevDown
end

--- Whether the action went up this frame.
--- @param name string
--- @return boolean
function inputMap.released(name)
  local action = get(name)
  return action.prevDown and not action.down
end

--- Analog strength 0..1 after the deadzone (keys and buttons are 1).
--- @param name string
--- @return number
function inputMap.strength(name)
  return get(name).strength
end

--- Signed axis from two actions, -1..1.
--- @param negative string
--- @param positive string
--- @return number
function inputMap.axis(negative, positive)
  return get(positive).strength - get(negative).strength
end

--- 2D vector from four actions with one radial deadzone, clamped to length 1.
--- Returns two numbers so no table is allocated per frame.
--- @param left string
--- @param right string
--- @param up string
--- @param down string
--- @return number x, number y
function inputMap.vector(left, right, up, down)
  local x = get(right).raw - get(left).raw
  local y = get(down).raw - get(up).raw
  local len = math.sqrt(x * x + y * y)
  if len <= config.deadzone then return 0, 0 end
  local scaled = math.min(1, (len - config.deadzone) / (1 - config.deadzone))
  return x / len * scaled, y / len * scaled
end

-- ---------------------------------------------------------------------------
-- Rebind capture

--- Waits for the next raw input and hands its shorthand to the callback
--- (nil when cancelled). While capturing, every action reads as released.
--- @param callback fun(binding: string|nil, event: string)
--- @param opts table|nil { device = "keyboard"|"gamepad"|nil, allowMouse1 = false, cancelKey = "escape" }
function inputMap.startCapture(callback, opts)
  opts = opts or {}
  capture = {
    callback = callback,
    device = opts.device,
    allowMouse1 = opts.allowMouse1 or false,
    cancelKey = opts.cancelKey == nil and "escape" or opts.cancelKey,
    heldAxes = {},
  }
  -- Axes already deflected keep reporting gamepadaxis; ignore them until
  -- they return to centre.
  for _, joystick in ipairs(joysticks) do
    for axis in pairs(VALID_AXES) do
      local v = joystick:getGamepadAxis(axis)
      if math.abs(v) >= AXIS_RELEASE then
        capture.heldAxes["axis:" .. axis .. (v > 0 and "+" or "-")] = true
      end
    end
  end
  inputMap.flushEdges()
end

--- Whether a capture is in progress.
--- @return boolean
function inputMap.isCapturing()
  return capture ~= nil
end

--- Cancels a capture (callback receives nil).
function inputMap.cancelCapture()
  if not capture then return end
  local cb = capture.callback
  capture = nil
  inputMap.flushEdges()
  cb(nil, "cancelled")
end

local function finishCapture(binding)
  local cb = capture.callback
  capture = nil
  inputMap.flushEdges()
  cb(binding, "captured")
end

local function captureAccepts(device)
  return not capture.device or capture.device == device
end

-- ---------------------------------------------------------------------------
-- Raw event forwarders (Game calls these before the scene sees the event)

local function latch(id)
  if capture then return end
  local list = bindingIndex[id]
  if not list then return end
  for _, action in ipairs(list) do
    action.latched = true
  end
end

--- love.keypressed forwarder.
--- @return boolean consumed true when a capture took the event
function inputMap.keypressed(key, scancode, isrepeat)
  setDevice(inputMap.DEVICE_KEYBOARD)
  if capture then
    if isrepeat then return true end
    if capture.cancelKey and key == capture.cancelKey then
      inputMap.cancelCapture()
    elseif captureAccepts(inputMap.DEVICE_KEYBOARD) then
      finishCapture("key:" .. scancode)
    end
    return true
  end
  if not isrepeat then latch("key:" .. scancode) end
  return false
end

--- love.keyreleased forwarder.
function inputMap.keyreleased(key, scancode)
end

--- love.mousepressed forwarder.
--- @return boolean consumed
function inputMap.mousepressed(x, y, button, istouch, presses)
  setDevice(inputMap.DEVICE_KEYBOARD)
  if capture then
    if captureAccepts(inputMap.DEVICE_KEYBOARD) and (button ~= 1 or capture.allowMouse1) then
      finishCapture("mouse:" .. button)
    end
    return true
  end
  latch("mouse:" .. button)
  return false
end

--- love.mousereleased forwarder.
--- @return boolean consumed
function inputMap.mousereleased(x, y, button, istouch, presses)
  return capture ~= nil
end

--- love.mousemoved forwarder.
function inputMap.mousemoved(x, y, dx, dy)
  if math.abs(dx or 0) + math.abs(dy or 0) >= MOUSE_MOVE_SWITCH then
    setDevice(inputMap.DEVICE_KEYBOARD)
  end
end

--- love.wheelmoved forwarder.
function inputMap.wheelmoved(x, y)
  setDevice(inputMap.DEVICE_KEYBOARD)
end

--- love.gamepadpressed forwarder.
--- @return boolean consumed
function inputMap.gamepadpressed(joystick, button)
  setDevice(inputMap.DEVICE_GAMEPAD, joystick)
  if capture then
    if captureAccepts(inputMap.DEVICE_GAMEPAD) then
      finishCapture("pad:" .. button)
    end
    return true
  end
  latch("pad:" .. button)
  return false
end

--- love.gamepadreleased forwarder.
function inputMap.gamepadreleased(joystick, button)
end

--- love.gamepadaxis forwarder.
function inputMap.gamepadaxis(joystick, axis, value)
  local magnitude = math.abs(value)
  if magnitude > config.deadzone then
    setDevice(inputMap.DEVICE_GAMEPAD, joystick)
  end
  if not capture then return end
  local id = "axis:" .. axis .. (value > 0 and "+" or "-")
  if magnitude < AXIS_RELEASE then
    capture.heldAxes["axis:" .. axis .. "+"] = nil
    capture.heldAxes["axis:" .. axis .. "-"] = nil
    return
  end
  if magnitude >= CAPTURE_AXIS and not capture.heldAxes[id] and captureAccepts(inputMap.DEVICE_GAMEPAD) then
    finishCapture(id)
  end
end

return inputMap
