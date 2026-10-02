# Changelog

## 2026-10-02

- `engine/saveManager.lua`: single-slot save file in the save directory, serialised as Lua source; `save`/`load`/`exists`/`delete` never throw, saves carry a schema `version` with an optional `migrate` hook. `Game:quit` now calls the current scene's optional `onQuit()`; `sceneManager.addScene`/`resetScene` return the instance and `getScene(name)` was added.
- Engine fixes: `State:reset()` restores the defaults (the initial table is deep-copied; before, `set` mutated it), `table_serialize.deserialize` uses `loadstring` so it runs under PUC Lua 5.1, rejects non-finite numbers and emits sorted keys, and `utils/table.lua` gains `deepCopy` and a working `getTableSize`.
- `conf.lua` sets `t.identity = "newgame"` (rewritten by `init.sh`) so saves share one directory between source runs and builds; `scripts/web/index.html` flushes the IndexedDB save directory on `pagehide`, tab hide and every 10 s.
- `init.sh` scaffold wizard: copies the template into a new directory (or renames a clone in place), asks for title/author/itch.io username, and rewrites the window title, wordmarks, release variables, README and changelog. `scripts/release.sh` excludes it from the `.love`.
- Lua 5.1 compatibility for the love.js web build: `UIBox` layout loops no longer use `goto` (PUC Lua 5.1 rejects it, so the browser build crashed on load).
- `scripts/lint-lua51.sh` parses Lua with a real `luac` 5.1 (built once into `~/.cache/love-release/`); `.githooks/pre-commit` and `scripts/release.sh` run it, and `.luarc.json` now targets Lua 5.1 so the editor flags the same errors.
- Bare web page template in `scripts/web/` replaces the stock love.js page (no heading, footer or "Powered by" text); the release checklist explains the itch.io browser-play flag.

## 2026-09-29

- Initial engine template extracted from "Houston, We Have a Problem".
