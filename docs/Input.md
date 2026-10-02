# Input: actions, bindings, prompts and rebinding

The engine never asks game code to look at keys or gamepad buttons. Games declare **actions** ("jump", "move_left") with default **bindings**, read actions, and let the engine handle devices, remapping, persistence and on-screen prompts.

## Declaring actions

In the `Game` config in `main.lua`:

```lua
input = {
  deadzone = 0.25,          -- stick deadzone 0..1 (default 0.25)
  saveFile = "bindings.lua", -- in the save directory; false disables saving
  actions = {
    { name = "move_left", label = "Move left", category = "Movement", bindings = { "key:a", "key:left", "axis:leftx-", "pad:dpleft" } },
    { name = "jump",      label = "Jump",      category = "Actions",  bindings = { "key:space", "pad:a" } },
    { name = "fire",      label = "Fire",      category = "Actions",  bindings = { "mouse:1", "axis:triggerright+" } },
  },
},
```

`label` and `category` are what the Controls scene shows. Every action is a button with an analog **strength** (0..1; keys and buttons are 1), and axes or vectors are composed from actions, so any single input can be bound to any action.

### Binding shorthand

| Form | Meaning |
|---|---|
| `key:<scancode>` | Keyboard, by physical position (`key:w` is the same key on AZERTY). Shown using the player's layout. |
| `mouse:<n>` | Mouse button: 1 left, 2 right, 3 middle. |
| `pad:<button>` | `a b x y back guide start leftstick rightstick leftshoulder rightshoulder dpup dpdown dpleft dpright` (SDL positional names). |
| `axis:<axis>+` / `axis:<axis>-` | One direction of `leftx lefty rightx righty triggerleft triggerright`, with analog strength. Triggers are `+`. |

Set `t.identity` in `conf.lua` so the save directory (and `bindings.lua`) has a stable name.

### Built-in menu actions

The engine adds locked actions every game can rely on: `ui_up`, `ui_down`, `ui_left`, `ui_right` (arrows, d-pad, left stick), `ui_accept` (Enter, Space, A) and `ui_cancel` (Escape, B). They cannot be rebound and bindings are never stolen from them, so menus always work.

## Reading actions

```lua
local inputMap = require "engine.input.inputMap"

inputMap.down("fire")           -- held
inputMap.pressed("jump")        -- went down this frame
inputMap.released("jump")       -- went up this frame
inputMap.strength("accelerate") -- 0..1 after the deadzone
inputMap.axis("move_left", "move_right")                     -- -1..1
local x, y = inputMap.vector("move_left", "move_right", "move_up", "move_down") -- unit-clamped, one radial deadzone
```

Polling happens once per frame before any scene updates, so edges are valid for the whole frame. Every connected gamepad plus the keyboard and mouse drive the same actions (single player, any device).

### Events

Scenes and GameObjects can define `onActionPressed(name)` / `onActionReleased(name)`; the engine calls them after polling and before `update`. GameObjects are registered for these when added to a scene (like `onClick`), so define the method on the class or before `addGameObject`.

```lua
function GameScene:onActionPressed(name)
  if name == "pause" then sceneManager.setCurrentScene("Menu") end
end
```

A press that switches scenes is flushed, so it cannot also activate something in the new scene.

## Devices and prompts

`inputMap.getActiveDevice()` is `"keyboard"` or `"gamepad"`, whichever the player used last; `getGamepadStyle()` is `xbox`, `playstation`, `nintendo` or `generic` (from the USB vendor id, then the name). `onDeviceChanged(fn)` notifies `fn(device, joystick, style)`. `forceDevice(device, style)` previews another style.

`engine/ui/InputPrompt.lua` shows what an action is bound to on the active device, with sprite glyphs from `assets/graphics/input-prompts.png` (Kenney Input Prompts Pixel 16×, CC0) and a drawn keycap with text for anything without a tile:

```lua
InputPrompt("JumpPrompt", "jump", "Jump")
InputPrompt("MovePrompt", { "move_up", "move_left", "move_down", "move_right" }, "Move") -- collapses to one stick/d-pad glyph on a pad
InputPrompt("FirePrompt", "fire", "Fire", { showAll = true, scale = 2, font = "body", device = "gamepad" })
```

Preload the sheet once (see `scenes/Preload.lua`): `cacheManager.preloadImage(glyphs.IMAGE_KEY, glyphs.IMAGE_PATH)`. `glyphs.label(binding, style)` gives short text ("Space", "LMB", "RT", "Cross"); `glyphs.TILES` maps key constants and buttons to `{ col, row [, widthInTiles] }` in the 34×24 sheet. Nintendo pads swap A/B and X/Y because SDL names buttons by position.

## Rebinding

`inputMap.startCapture(callback, { device = "keyboard"|"gamepad"|nil, allowMouse1 = false })` hands the next key, mouse button, gamepad button or axis deflection to `callback(binding)` as shorthand (`nil` when Escape cancels). While capturing every action reads as released and no events fire.

- `inputMap.rebind(action, binding)` replaces the action's bindings for that binding's device with the new one, stealing it from any other unlocked action; returns the list of actions it was taken from (or `nil, err`).
- `inputMap.bind` / `unbind` add or remove a single binding; `resetToDefaults(action?)`; `isDefault(action)`; `getBindings(action, device?)`.

Only actions whose bindings differ from the defaults are written to `bindings.lua` as shorthand strings, so changing a default in `main.lua` reaches players who never remapped it. Unknown actions or inputs in the file are ignored and a corrupt file falls back to defaults. Saving happens on every change.

`scenes/Controls.lua` is a complete rebinding screen: actions grouped by category with a keyboard/mouse and a gamepad cell each, press-to-rebind, stolen-binding notices, reset and back, navigable with mouse, keyboard or gamepad.

## Menus with a gamepad

`engine/ui/FocusGroup.lua` navigates focusable objects with the `ui_*` actions (hold to repeat). `Button` implements `focus()`, `blur()` and `activate()`; mouse hover moves focus too.

```lua
self.focus = FocusGroup({ columns = 1 })
self.focus:add(startButton):add(quitButton)
function Menu:update(dt) self.focus:update(dt) end
function Menu:start() if not self.focus:getFocused() then self.focus:setFocus(1) end end
```

## Dev tooling

In dev the MCP bridge's virtual input feeds the same polling: `send_input` with `type = "key_down"` presses a key constant, and `type = "action_down" | "action_up"` with `action = "jump"` drives an action directly (`inputMap.pressVirtualAction`). `run_lua` can `require("engine.input.inputMap")` to inspect state.

Hot reload rebuilds the input map from the config and the save file, so bindings and connected pads survive reloads.

## Web build notes

Browsers only expose a gamepad after its first button press, so the first press may be swallowed. `love.filesystem.write` on love.js persists to IndexedDB. Escape may also leave browser fullscreen.
