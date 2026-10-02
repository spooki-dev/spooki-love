# Changelog

## 2026-10-02

- `init.sh` scaffold wizard: copies the template into a new directory (or renames a clone in place), asks for title/author/itch.io username, and rewrites the window title, wordmarks, release variables, README and changelog. `scripts/release.sh` excludes it from the `.love`.
- Lua 5.1 compatibility for the love.js web build: `UIBox` layout loops no longer use `goto` (PUC Lua 5.1 rejects it, so the browser build crashed on load).
- `scripts/lint-lua51.sh` parses Lua with a real `luac` 5.1 (built once into `~/.cache/love-release/`); `.githooks/pre-commit` and `scripts/release.sh` run it, and `.luarc.json` now targets Lua 5.1 so the editor flags the same errors.
- Bare web page template in `scripts/web/` replaces the stock love.js page (no heading, footer or "Powered by" text); the release checklist explains the itch.io browser-play flag.

## 2026-09-29

- Initial engine template extracted from "Houston, We Have a Problem".
