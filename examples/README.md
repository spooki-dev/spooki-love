# Examples

Small, self-contained scenes that each show one part of the engine. They are
published at https://spookidev.com/spooki-love/examples, where every example
runs in the browser next to its source, and they double as the engine's
regression suite: `scripts/test.sh` runs each one with a fixed timestep,
scripted input, the example's own assertions and a golden screenshot.

```sh
love . --examples                      # picker: browse and open any example
love . --example camera/follow         # run one example (hot reload is on)
scripts/test.sh                        # lint + run every example headlessly
scripts/test.sh camera ui/buttons      # only these categories / ids
scripts/test.sh --update-snapshots     # rewrite the golden screenshots
love . --gen-assets                    # regenerate examples/assets/*.png
```

`love` is `/Applications/love.app/Contents/MacOS/love` on macOS; `scripts/test.sh`
takes `LOVE=/path/to/love`. Exit status: 0 passed, 1 failures, 2 harness error.
Failures write `examples/.test-output/<category>__<slug>.actual.png` and
`.diff.png` (red = differing pixels) plus `report.txt`.

## Layout

```
examples/
  categories.lua          display order and titles; one { id, title, description } per line
  <category>/<slug>.lua   one example per file; the id is "<category>/<slug>"
  __snapshots__/          golden screenshots (also the website thumbnails)
  assets/                 generated ghost.png and tiles.png (love . --gen-assets)
  shaders/                GLSL used by the post-processing examples
  runner/                 the picker, test loop and harness (not examples)
```

Every directory under `examples/` must be listed in `categories.lua` and vice
versa; the catalogue refuses to load otherwise.

## Writing an example

An example returns a `Scene` subclass whose name is its id, with a header of
`-- key: value` comment lines. `title` and `description` are required; `order`
sorts within the category (default 999); `tags` is a comma-separated list.
The header ends at the first line that is not a comment, and the website
reads it with a regular expression, so keep it plain.

```lua
-- title: Follow target
-- description: camera:followTarget keeps the player centred and clamps the view to the world bounds.
-- order: 1
-- tags: camera, followTarget
local Scene = require "engine.Scene"

---@class CameraFollow : Scene
local Example = Scene.extend(Scene)

function Example:new()
  Example.super.new(self, "camera/follow")   -- must equal the id
  self.backgroundColor = { 0.09, 0.09, 0.13, 1 }
end

function Example:load() ... end
function Example:update(dt) ... end

Example.script = {                           -- optional scripted input for the test
  { at = 2,  press = "move_right" },
  { at = 90, release = "move_right" },
}

function Example.check(scene, ctx)           -- optional assertions, run after every frame
  if ctx.done then
    assert(scene.player:getPos().x == 1552, "player x")
  end
end

return Example
```

Rules of thumb:

- Examples never preload assets. `runner/preload.lua` loads the contract fonts
  (`header`, `subheader`, `body`, `small`), the input-prompt sheet and the two
  example sheets (`examples-ghost`, 8 frames of 16x16; `examples-tiles`, 4
  tiles) before any example runs.
- Input goes through the shared actions in `runner/actions.lua`
  (`move_left/right/up/down`, `action`, `secondary`, `pause`). Escape
  (`ui_cancel`) returns to the picker, so do not bind behaviour to it.
- Names must be unique: object names within the example, scene names across
  the catalogue. Extra scenes an example registers are named `"<id>:<suffix>"`.
- Draw deterministically. `pairs` order is not stable on LuaJIT, so objects
  that overlap must differ in `ysortOffset` or `drawPriority`; do not read the
  real mouse position or the wall clock in anything the snapshot shows.
- Prefer the `body` and `header` fonts (native multiples of the pixel font);
  `small` and `subheader` are resampled and more sensitive to the renderer.

## Harness fields

All optional, set on the class:

| Field | Default | Meaning |
|---|---|---|
| `frames` | 120 | Simulated frames at dt = 1/60 (2 seconds) |
| `seed` | 1234 | Seed for `love.math` and `math.random` before the example loads |
| `script` | none | Input timeline: `{ at, press = action }`, `{ at, release = action }`, `{ at, tap = action }` (press, release next frame), `{ at, mouse = { x, y } }`, `{ at, click = { x, y, button } }`, `{ at, call = function(scene, frame) end }`. Use `at >= 2`: the engine drops input edges on the frame a scene becomes current. |
| `check(scene, ctx)` | none | Called after every frame with `ctx = { frame, t, dt, done }`; throw (or `assert`) to fail |
| `snapshot` | true | Compare the last frame with `__snapshots__/<id>.png` |
| `snapshotTolerance` | `{ channel = 8, ratio = 0.005 }` | Per-channel difference (0..255) a pixel may have, and the share of pixels allowed to exceed it. Shaders and lighting use looser values. |
| `shaders` | none | Function returning post-processing shader definitions (see `post-processing/vignette.lua`) |

Each example runs in a fresh engine: the runner purges `package.loaded` for
engine and example modules between examples (the same trick hot reload uses),
so nothing leaks between them. Bindings are never saved, and on desktop the
runner uses the save identity `spooki-love-examples` so example saves stay out
of the game's directory.

## Goldens

Generate goldens locally with `scripts/test.sh --update-snapshots` and review
the image diffs in git. CI (`.github/workflows/ci.yml`) renders with Mesa's
software rasteriser and compares with the same tolerances; if a specific
example drifts beyond its tolerance there, loosen that example's
`snapshotTolerance` or regenerate the goldens from the `update_snapshots`
workflow dispatch.

## How the website uses this

The site pulls `categories.lua`, every `<category>/<slug>.lua` header and the
goldens, builds one `.love` from the repository (engine + examples) with
love.js, and opens `index.html?example=<category>/<slug>`, which passes
`--example <id>` to the game. `--example` prints `[example] ready <id>` once the
scene is live. A page that cannot pass arguments can set the `SPOOKI_EXAMPLE`
environment variable or ship an `examples/__selected.lua` returning the id.
