# AGENTS.md

LÖVE (Love2D) 11.5 game template in plain Lua (LuaJIT). No tests, no build step, no package manager, no CI.

## Run / verify

```sh
/Applications/love.app/Contents/MacOS/love .   # `love` is not on PATH
```

There is no lint or test command. Verify by running the game; saved edits under the directories listed in the `watch` config in `main.lua` hot-reload on save (backtick key force-reloads). Reload clears `package.loaded`, re-executes `main.lua` and re-runs `love.load()`, so any duplicate GameObject name will throw on reload.

## Structure & conventions

- `engine/` is the reusable engine and must not require anything outside itself. Game code (`scenes/`, `gameObjects/`, `constants/`, `state/`) is wired in from `main.lua`.
- Requires use dotted module paths: `require "engine.Scene"`, `require "engine.ui.UIBox"`, `require "engine.lib.classic"`. Files never need `.lua`.
- OOP = vendored `engine/lib/classic.lua` (rxi/classic). Pattern: `local Foo = Base.extend(Base)` and call `Foo.super.new(self, ...)` in the constructor.
- Scenes live in `scenes/` and are registered from `main.lua` via the `scenes` array in the `Game` config (`Preload` first, because `addScene` runs `load()` immediately). `defaultScene` picks the starting scene. Scene `name` must be unique and `setCurrentScene` errors if called with the current scene.
- GameObject handlers auto-register for dispatch: define `onClick`, `onMouseOver/onMouseEntered/onMouseExit`, `handleScroll`, `onKeyPressed`, `getHitbox/getHurtbox`. Names must be unique per scene.
- A scene may define `updateShaderUniforms(uniforms, dt)`; the engine clears `postProcessing.uniforms` every frame and calls it. The CRT shader reads `signalStrength` (1 = clean).
- Assets/fonts must be preloaded through `engine/cacheManager` (see `scenes/Preload.lua`) before use. Font keys `header`, `subheader`, `body`, `small` and cursor keys `default`, `active` are contracts relied on by `engine/ui`.
- Marketing art in `assets/generated/` is rendered by `love . --export-assets` from `scenes/assets/*.lua` (engine side: `engine/AssetExporter.lua`); `scripts/release.sh` runs that, builds every platform and pushes to itch with butler. Do not hand-edit the generated PNGs.
- `constants/colors.lua` exports decimal `{r,g,b}` tables (`black`, `dark`, `light`, `white`, `green`) plus `vec4*` variants; UI code passes `Vector4(r,g,b,a)`.

## UI system (engine/ui: UIBox, UICanvas, UIStack, UIText, UIBar, BarFill, Button)

Hand-rolled flexbox-ish layout driven by `styles` tables. Quirks to know:

- `Vector4` ordering for `padding`/`border`/`margin` is **(top, right, bottom, left)** — not CSS order.
- Supported styles: `display` (`flex`/`block`/`none`), `flexDirection` ("row"), `gap`, `justifyContent` ("center"), `alignItems` ("center"), `position` ("absolute" with `left`/`top`/`right`/`bottom`), `width` as number or `"NN%"`, explicit `height`, `zIndex`, `hover.background`/`hover.borderColor`.
- 4th ctor arg of UIBox is a debug table: `{ debugBox = true, debugPadding = true }` etc.
- Layout is computed in `UIBox:load`/`recalculateHeight`/`recalculateChildPos`; it depends on parent widths, so stacking more than a flex row needs care. Default layer for UI objects is `ui` (drawn without camera transform).

## Third-party

- `engine/lib/shadows/` is the external "Shädows" light engine (unmaintained upstream; require paths rewritten for vendoring; read its README before touching). Only `engine/components/LightManager.lua` uses it.
- `engine/lib/classic.lua` is rxi/classic. `engine/dev/mcp_bridge.lua` is the lovepilot MCP bridge (dev only).
- `ASSET_LIST.md` tracks third-party asset credits.

## Debugging

`.vscode/launch.json` uses the `lua-local` debugger; set `LOCAL_LUA_DEBUGGER_VSCODE=1` to have `main.lua` start `lldebugger`. `.luarc.json` configures LuaLS (LuaJIT runtime, love2d types).
