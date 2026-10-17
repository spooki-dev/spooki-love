---
title: Device
description: Let the player pick a file from their device and use the device camera, through one engine API with a backend per platform.
order: 11
---

Two things stock LÖVE cannot do on any platform: show the player a file picker, and open the device camera. `engine/device/` adds both as one API, with a backend per platform underneath. Game code never branches on the operating system — it asks what is possible and degrades when the answer is "nothing".

This is not programmatic file access. `filePicker` always opens a picker the player drives, and the game gets back only what they chose.

## At a glance

```lua
local filePicker = require "engine.device.filePicker"
local deviceCamera = require "engine.device.camera"

function GameScene:onActionPressed(name)
  if name == "import" and not filePicker.isOpen() then
    filePicker.open({ deliver = "image" }, function(result, event)
      if event == "picked" then self.portrait = result.image end
    end)
  end
end

function GameScene:draw()
  local frame = deviceCamera.getTexture()
  if frame then love.graphics.draw(frame, 32, 32) end
end
```

Require the camera as `deviceCamera`, never as `camera`: `engine/Camera.lua` is the 2D viewport every scene owns (see `scenes.md`), and the two read identically at a glance otherwise.

## Config

An optional `device` block in the `Game({...})` table (see `engine.md#the-game-config`) sets the defaults. Every key is optional and both modules work with none of it.

```lua
device = {
  filePicker = { deliver = "image", accept = { "image/*" }, maxBytes = 8 * 1024 * 1024, saveDir = "imported" },
  camera     = { width = 320, height = 240, fps = 15, facing = "back" },
  backend    = nil,   -- force a backend; the examples suite passes "mock"
}
```

`Game:load` applies this before any scene loads, so a scene's `load()` may already ask what the device can do.

## Picking a file

| Function | Returns | Behaviour |
|---|---|---|
| `configure(opts)` | nothing | Any subset of `deliver`, `accept`, `maxBytes`, `saveDir`, `allowDrop`. Asserts on wrong types. |
| `isAvailable()` | boolean | Whether a picker exists here. Cached; warns once when false. |
| `getCapabilities()` | table | `pick`, `multiple`, `acceptFilter`, `fromCamera`, `needsGesture`, `dragDrop`. |
| `open(opts, callback)` | `ok, err` | Opens the picker. One pick at a time. |
| `isOpen()` | boolean | Whether a pick is in flight. |
| `getState()` | string | `"idle"`, `"awaitingGesture"`, `"open"` or `"loading"`. |
| `cancel()` | nothing | Abandons the pick; the callback still fires with `(nil, "cancelled")`. |
| `update(dt)` | nothing | Pumped by `Game:update`. |
| `shutdown()` | nothing | Releases the backend; called from `Game:quit`. Cancels any pick, so its callback still fires. |
| `filedropped(file)` | boolean | Called by `Game` from `love.filedropped`; see below. |

The callback is `function(result, event, err)` and runs **exactly once**, where `event` is `"picked"`, `"cancelled"`, `"error"` or `"unavailable"`. It never fires from inside `open` — not even for `"unavailable"` — so every call site has one code path whether the answer takes a frame or a minute. The request is cleared before the callback runs, so the callback may start another pick straight away. This is the same contract as `inputMap.startCapture` (see `input.md`).

### Delivery modes

`deliver` decides what the game is handed, because different games want different things:

| `deliver` | Result fields |
|---|---|
| `"image"` (default) | `image` (a drawable `love.Image`), `width`, `height`, `name`, `mime`, `size` |
| `"bytes"` | `bytes` (the raw file), `name`, `mime`, `size` |
| `"file"` | `path` relative to the save directory, so `love.filesystem` and `cacheManager` can read it; plus `name`, `mime`, `size` |

Use `"bytes"` when the game needs the pixels or is importing something that is not an image; use `"file"` when the import must survive a restart. Names come from the device and are never trusted as paths: the directory part and anything that is not a plain file-name character are stripped before a write.

With `multiple = true` the result is `{ files = { <result>, ... }, size = <total> }`. Check `getCapabilities().multiple` first.

### Drag and drop

On desktop a file dropped on the window answers an open pick, so the player can
drag a picture in instead of browsing for it. `Game` offers every drop to
`filePicker.filedropped(file)` first; if no pick is waiting, or `allowDrop` is
`false`, it returns false and the drop goes on to the current scene's optional
`filedropped(file)` hook instead. Dropped files are read on the main thread, so a
very large one is a brief hitch — unlike the dialog, which does not block.

## The camera

| Function | Returns | Behaviour |
|---|---|---|
| `configure(opts)` | nothing | `width`, `height`, `fps`, `facing`, `deviceId`, `maxBytes`, `saveDir`. Takes effect on the next `start`. |
| `isAvailable()` | boolean | Whether a camera exists here. Cached; warns once when false. |
| `getCapabilities()` | table | `preview`, `capture`, `facingSwitch`, `needsGesture`. |
| `listDevices()` | table | Array of `{ id, name, facing }`; empty when the platform cannot enumerate. |
| `start(opts, callback)` | `ok, err` | Opens the stream. `callback(ok, event, err)` with `"started"`, `"denied"`, `"error"` or `"unavailable"`. |
| `stop()` | nothing | Closes the device and releases the texture. |
| `isRunning()` | boolean | True from a successful `start`, before the first frame. |
| `getState()` | string | `"idle"`, `"awaitingGesture"`, `"starting"`, `"running"` or `"denied"`. |
| `getTexture()` | `image, w, h` | The newest frame, or nil before the first one. |
| `getFrameNumber()` | number | Monotonic; resets on `start`. |
| `capture(opts, callback)` | `ok, err` | One still, with the same delivery modes and result shapes as the picker. |
| `update(dt)` | nothing | Pumped by `Game:update`. |

`start` is callback-based rather than a plain boolean because on several platforms it spans a permission dialog and can legitimately take seconds. `"denied"` is a normal outcome, not an error.

### The preview texture, and what it costs

`getTexture()` returns **the same `love.Image` every frame**. One texture is created when the stream starts and updated in place with `replacePixels`; `stop()` releases it. Draw it, scale it, put it in a shader — but never release it yourself, and do not assume it is a new object (`getFrameNumber()` is the cheap way to tell whether the pixels changed).

Moving pixels into a texture without `ffi` means building one `ImageData` per frame, so the design bounds the cost rather than avoiding it: the defaults are **320×240 at 15 fps**, about 300 KiB a frame, and each frame's `ImageData` is released the moment it has been uploaded so the big buffers never reach the collector. The cost is linear in `width`, `height` and `fps` — raise them deliberately.

## Capabilities, not platforms

Ask `isAvailable()` and `getCapabilities()`; never branch on `love.system.getOS()`. A capability can be false for reasons that have nothing to do with the operating system — a missing helper binary, a camera-less machine, a browser that refuses. `engine/utils/system.lua` (`getOS`, `isWeb`, `isMobile`, `isDesktop`) exists for the backends, not for game code.

`needsGesture` deserves a word. Browsers will not open a file dialog or grant the camera except from a real player tap, so on web the request is *armed* rather than opened: `getState()` becomes `"awaitingGesture"`, the page shows a button, and the dialog opens when the player taps it. Word in-game prompts from that flag instead of assuming the picker appears at once. It never happens on a native platform.

Nothing here throws for an environmental failure. A missing picker, a denied camera, a corrupt file or a save directory that will not accept a write all arrive through the callback, with a `[filePicker]` or `[camera]` warning printed — the same posture as `engine/saveManager.lua` (see `engine.md#saving`). Only misuse of the API itself asserts.

## Backends

| Backend | Covers | Status |
|---|---|---|
| `null` | anything else | Everything unavailable. The contract lives here: read `engine/device/backends/null.lua` to learn what a backend implements. |
| `mock` | tests | Deterministic synthetic data. The examples catalogue always uses it. |
| `web` | love.js | **Implemented**, picker and camera. Needs a player gesture; see below. |
| `desktop` | macOS, Windows, Linux | **File picker implemented**; camera not yet, so it falls through to `null` and reports `preview = false`. |
| `mobile` | iOS, Android | Not yet implemented, and needs a native module compiled into LÖVE. |

### The web backend

love.js exposes no `js` module, no `ccall` and no `FS`, so neither direction of
the bridge is built from an API meant for it.

**Lua to JS** is a character device. The page registers `/dev/spooki` with
`Module.FS_createDevice`, whose write callback runs in JS, and Lua writes
newline-terminated `key=value` commands to it with plain `io`. If that device
cannot be created, the page sniffs `Module.print` instead and Lua falls back to
a prefixed `print`; both halves implement both channels.

**JS to Lua** is files under `/tmp/spooki/`, written with
`Module.FS_createDataFile` and read with plain `io`: `events` (one line per
event, each with a `seq`), `cam.hdr` (a sixteen-byte `seq width height`, so an
unchanged frame costs one tiny read), `cam.rgba` (the newest frame) and
`blob-<id>.bin` (a picked file or a still). They live in `/tmp` and **not** in
the save directory, because the save directory is the IndexedDB mount and the
page's ten-second flush would copy every camera frame into IndexedDB.

`scripts/release.sh` fails the build if either `FS_createDevice` or
`FS_createDataFile` disappears from the love.js output, so a toolchain upgrade
that breaks the bridge is caught at build time rather than silently shipping a
page where both features do nothing. If that ever happens, the escape hatch is
to patch `Module["FS"] = FS;` into the love.js output and read the filesystem
directly.

**The gesture.** Browsers refuse to open a file dialog or grant a camera except
from a real user activation, and a command from the game arrives inside the wasm
main loop, which is not one. So a request is *armed*: `getState()` becomes
`"awaitingGesture"`, the page shows a full-screen overlay, and the dialog opens
from the player's tap on it. Web file import therefore always costs one extra
tap. The overlay is `position: fixed` so it stays out of the page's flex
centring, and it sits above the canvas so the arming tap never also reaches the
game.

**Camera budget on web.** Frames go `getUserMedia` → a hidden `<video>` → an
offscreen canvas → `getImageData` → raw RGBA (never an encoded image: a PNG
round trip per frame would cost far more than the copy). At the 320x240 default
that is about 300 KiB a frame. `INITIAL_MEMORY` in `scripts/web/index.html` is
32 MiB because growing the heap copies the whole buffer, which shows up as a
hitch. A still is captured at the camera's own resolution, not the preview's.

### The desktop backend

The picker shells out to the platform's own dialog — `osascript` on macOS, a
Windows Forms `OpenFileDialog` through PowerShell (`-STA`, which the dialog
requires), `zenity` or `kdialog` on Linux — so there is nothing to install and
nothing to bundle. Each dialog blocks for as long as the player browses, so it
runs in a `love.thread` (`engine/device/threads/pickerThread.lua`) and the
answer comes back on a channel drained once a frame. The worker also reads the
file and checks `maxBytes` before reading, so neither a large read nor the
dialog itself ever touches the main thread.

One thread is started per pick and exits once it has answered. A pick is a rare,
player-initiated action, so a thread per pick costs nothing and avoids the
stale-worker and hot-reload-leak problems a persistent worker would bring. If a
worker dies, `Game` forwards `love.threaderror` and the pick fails with a
message rather than waiting forever.

Two known edges. A dialog cannot be closed from code, so `cancel()` makes the
front end stop caring about the answer — it is matched by request id and
discarded — but **quitting the game with a dialog still open waits for the
player to dismiss it**. And on Linux, a box with neither `zenity` nor `kdialog`
reports available and fails the first pick with a message naming them, because
the helpers can only be probed by running them.

A backend is loaded with `pcall` and anything it leaves out falls back to `null`, so an absent or half-finished backend reports `isAvailable() == false` instead of erroring at the call site. A backend deals only in bytes and platform mechanics: the config, the request in flight, the delivery conversion, the texture and the callbacks all live in the two front-end modules, so adding a platform is one file.

## Testing

`SPOOKI_DEVICE_BACKEND` overrides the config, which is how a real backend is
driven from the examples catalogue (it otherwise forces `mock`):

```sh
SPOOKI_DEVICE_BACKEND=desktop love . --example device/file-picker
```

Nothing in the test suite sets it, so CI is unaffected.

Pass `device = { backend = "mock" }` to get a deterministic device that needs no hardware and no window manager. It returns a 64×64 checkerboard PNG for picks and stills, and colour-bar camera frames paced by the requested `fps`, all derived from a request and a frame counter so golden screenshots are stable. `mock.setNextResult("cancelled")` and `("error")` reach the unhappy paths.

The examples catalogue always runs on it (`examples/runner/harness.lua`), which is how `scripts/test.sh` and CI cover the whole public API — open and cancel ordering, all three delivery modes, frame pacing, texture reuse and capability degradation — on machines with no camera. See `examples/device/file-picker.lua` and `examples/device/camera-preview.lua`, and `examples.md` for the suite itself. Run the game rather than the examples to exercise a real device.
