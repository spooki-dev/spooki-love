# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A LÖVE (Love2D) 11.5 game template written in plain Lua (LuaJIT). The reusable engine lives under `engine/` and must not require anything outside it; the game is configured from `main.lua`. No tests, no build step, no package manager, no CI.

## Running the Game

```sh
# love is not on PATH on macOS:
/Applications/love.app/Contents/MacOS/love .
```

There is no lint or test command. Verify changes by running the game. Hot-reload is active in dev mode — saved edits under the directories listed in the `watch` config in `main.lua` reload automatically. Backtick key force-reloads. Reload clears `package.loaded`, re-executes `main.lua` and re-runs `love.load()`, so **duplicate GameObject names will throw on reload**. `main.lua` sets `io.stdout:setvbuf("no")` so prints appear immediately when stdout is piped.

### Build and release

`scripts/release.sh` does the whole release: regenerates the marketing art, builds the `.love`, packages Mac and Windows from the official LÖVE 11.5 runtime with the generated icon baked in, builds the web version with a favicon, pushes every channel to itch.io with butler, then prints the page images that must be uploaded by hand and opens the itch edit page. Fill in `TITLE`, `PKG`, `UTI`, `AUTHOR` and `ITCH` at the top of the script first. `scripts/release.sh --no-push` does everything except the butler pushes.

```sh
scripts/release.sh            # full release
scripts/release.sh --no-push  # build only, artefacts in releases/<PKG>/
love . --export-assets        # just regenerate assets/generated/*.png and quit
```

Notes:
- `love-release` is capped at LÖVE 11.3, so it is only used to produce the `.love` (for its exclude list). Mac/Windows packages are assembled by the script from `love-11.5-{macos,win32,win64}.zip`, cached in `~/.cache/love-release/`.
- The tracked `DEV` marker file turns on hot reload and the MCP bridge; builds exclude it so shipped copies run clean.
- Windows icons are patched into `love.exe` by `scripts/patch-win-icon.mjs` (node, deps in `scripts/package.json`). The Mac icon is an `.icns` built with `iconutil`; the script also removes `CFBundleIconName` so macOS reads the `.icns` rather than `Assets.car`.
- butler can only push build channels. itch.io has no API for cover/screenshot images, so those remain a manual upload.
- butler comes from https://itch.io/docs/butler/ (the Homebrew `butler` cask is an unrelated app). Run `butler login` once in a real terminal.

### Marketing assets

`assets/generated/*.png` are rendered by the game itself from `scenes/assets/*.lua` via `engine/AssetExporter.lua`, so a colour or font change regenerates them (and shows up as an image diff in git). The `assets` block in `main.lua` lists each item with its exact pixel size, `postProcess = true` to run the CRT chain, or `transparent = true` for an alpha background (the two are mutually exclusive, the shader forces alpha to 1). Asset scenes take `(width, height)` in their constructor, pass them to a `UICanvas` via `styles.width/height`, and compose text with `gameObjects/Wordmark.lua`, which lazily loads fonts under keys `asset-<size>` (sizes in multiples of 8 for PixelOperator8). Edit the `lines`/`subtitle` in each asset scene for your game.

### Debugging

`.vscode/launch.json` uses the `lua-local` debugger. Set `LOCAL_LUA_DEBUGGER_VSCODE=1` to have `main.lua` start `lldebugger`. `.luarc.json` configures LuaLS with LuaJIT runtime and love2d types. In dev the engine also starts the lovepilot MCP bridge (`engine/dev/mcp_bridge.lua`) on port 12345; large screenshots can stall the bridge, so prefer `love.graphics.captureScreenshot("x.png")` into the save directory when the picture is noisy.

## Architecture

### Entry point

`main.lua` builds the game from a config table and is the only place scenes are registered:

```lua
Game({
  title = "New Game",
  env = "dev",                      -- enables hot reload and the MCP bridge
  scenes = { Preload, Menu, GameScene },
  defaultScene = "Menu",
  cursors = { default = { path = "assets/cursors/default.png", hotX = 8, hotY = 8 }, active = { ... } },
  shaders = { CRT },                -- post-processing chain, in order
  watch = { "engine", "scenes", "gameObjects", "constants", "state" },
  assets = { outputDir = "assets/generated", items = { { name = "icon", scene = AssetIcon, width = 1024, height = 1024 }, ... } },
})
```

`scenes` is registered in order and `sceneManager.addScene` calls each scene's `load()` immediately, so **`Preload` must be first** — other scenes build UI that needs its cached fonts. `defaultScene` is made current after registration. `cursors`, `shaders` and `watch` are optional.

### Core engine (`engine/`)

| File | Purpose |
|---|---|
| `Game.lua` | Top-level game class built from the config table; `love.load(args)` is forwarded so `Game:hasArg("--flag")` works. Owns sceneManager, audioManager, cursorManager, inputManager, postProcessing. Wires all `love.*` callbacks. |
| `Scene.lua` | Base scene class. Manages layers (ground/entities/ui), gameObject registry, camera, input dispatch. Objects in `ui` layer draw without camera transform. |
| `GameObject.lua` | Base class for all entities. Handles position, rendering (sprites/quads/shapes/text), animation, mouse/keyboard events, and children. |
| `sceneManager.lua` | Singleton. Stores scenes by name, delegates update/draw/input to the current scene. `setCurrentScene` errors if called with the already-current scene. |
| `Camera.lua` | Camera with position, zoom, bounds-based culling. |
| `cacheManager.lua` | Preloads and caches spritesheets, images, fonts, sounds. Must be populated (see `scenes/Preload.lua`) before assets are used. |
| `audioManager.lua` | Centralised audio: load/play sounds and music. |
| `cursorManager.lua` | Named cursor registry populated from the `cursors` config. |
| `PostProcessing.lua` | Ping-pong canvas shader chain populated from the `shaders` config. `uniforms` is cleared every frame and refilled by the current scene's optional `updateShaderUniforms(uniforms, dt)` hook. `process(canvas, scene)` runs the chain offscreen at any size. |
| `AssetExporter.lua` | Renders asset scenes to canvases at exact sizes and writes PNGs with plain `io` (outside the save dir). Triggered by `love . --export-assets`, which quits before any dev tooling starts. |
| `renderer.lua` | Shared rendering utilities used by GameObject's `handleDraw`. |
| `InputManager.lua` | Input state tracking. |
| `State.lua` | Generic key/value state container (`state/GameState.lua` is an instance). |
| `ui/` | UI primitives: `UIBox`, `UICanvas`, `UIStack`, `UIText`, `UIBar`, `BarFill`, `Button`. |
| `shaders/CRT.lua` | CRT post-process shader. Uniform `signalStrength` (1 = clean, 0 = full interference). |
| `components/` | Optional mixins: `HitHurtBox`, `LightManager` (wraps the shadows lib). |
| `utils/` | Small helpers: easing, hexcolor, intersection, noise, perlin, theta pathfinding, table serialisation. |
| `lib/` | Vendored third-party code: `classic.lua` (rxi/classic), `hotReload.lua`, `shadows/` (Shädows light engine, unmaintained upstream; read its README before modifying). |
| `dev/mcp_bridge.lua` | lovepilot MCP bridge, loaded via `pcall` in dev only. |

### Engine contracts the game must honour

- **Font keys**: `engine/ui` looks up fonts by key `body` (UIText default), `small` (Button, UIBar), plus `header`/`subheader`. Preload them in the first scene.
- **Cursor keys**: `Button` switches between `active` and `default`. Provide both in the `cursors` config.
- **Layer names**: `ground`, `entities`, `ui`. `ui` draws in screen space; UI objects default to it.

### OOP pattern

Uses vendored `engine/lib/classic.lua` (rxi/classic):
```lua
local Foo = Base:extend()
function Foo:new(...)
  Foo.super.new(self, ...)
end
```

### Scenes (`scenes/`)

- `Preload.lua` — preloads fonts via cacheManager. Never made current; registered first for its `load()` side effect.
- `Menu.lua` — default scene. Start → `Game`; CRT toggle.
- `Game.lua` — empty scene to build on.

Scene names (passed to `Scene.super.new(self, "Name")`) must be unique. To add a scene, create it in `scenes/`, require it in `main.lua` and add it to the `scenes` array. See `docs/CreatingANewScene.md`.

### GameObjects (`gameObjects/`)

All game objects extend `GameObject`. Key naming rule: **every GameObject name must be unique within a scene** — duplicates throw an error. `SampleGameObject.lua` and `SampleUIGameObject.lua` are starting points.

Auto-registered event handlers (define on a GameObject to opt in): `onClick`, `onMouseOver`, `onMouseEntered`, `onMouseExit`, `handleScroll`, `onKeyPressed`, `getHitbox`/`getHurtbox`.

### UI system (`engine/ui/`)

Hand-rolled flexbox-style layout via `UIBox`, `UICanvas`, `UIStack`, `UIText`, `UIBar`, `BarFill`, `Button`. Require as `require "engine.ui.UIBox"`.

Key quirks:
- `Vector4` ordering for `padding`/`border`/`margin` is **(top, right, bottom, left)** — not CSS order.
- Supported styles: `display` (`flex`/`block`/`none`), `flexDirection` ("row"), `gap`, `justifyContent` ("center"), `alignItems` ("center"), `position` ("absolute" with `left`/`top`/`right`/`bottom`), `width` (number or `"NN%"`), explicit `height`, `zIndex`, `hover.background`/`hover.borderColor`.
- Debug: pass `{ debugBox = true, debugPadding = true }` as 4th UIBox ctor arg.
- UI objects default to the `ui` layer (drawn without camera transform).
- `UIBar(name, ...)` names its children `name .. "Container"` and `name .. "BarContainer"`.

### Game-side code

- `constants/colors.lua` — palette (`black`, `dark`, `light`, `white`, `green`, `yellow`, `grey`) plus `vec4*` variants. UI code passes `Vector4(r,g,b,a)`. Menu and the asset scenes take their title colours from here.
- `state/GameState.lua` — game state singleton over `engine/State.lua`.

### Scene layers

Every scene has three default layers: `ground` (z=1), `entities` (z=2), `ui` (z=3). Non-UI layers are Y-sorted and camera-culled. Set `gameObject.layer` before adding to scene.

## Conventions

- **Classes/Objects**: `PascalCase`. **Methods/Functions/Variables**: `camelCase`. **Constants**: `UPPER_CASE`.
- All functions documented with LuaDoc (`@param` with type, `@return` with type).
- Requires use dot-separated module paths: `require "engine.Scene"`, `require "engine.ui.UIBox"`. No `.lua` extension.
- Nothing under `engine/` may require from `scenes/`, `gameObjects/`, `constants/` or `state/`. Inject game data through the `Game` config or scene hooks instead.
- Avoid creating tables/objects inside `update` or `draw` loops (GC pressure).
- Use `assert()` for internal logic checks; custom error logging for non-fatal issues.
- Preloaded font keys: `header`, `subheader`, `body`, `small` (PixelOperator8.ttf). Asset scenes add `asset-<size>` on demand.
- Window: 1280x720, resizable, min 1024x600.
