---
title: Getting started
description: What the spooki-love template is, how to scaffold a game from it, run it, and find your way around the repository.
order: 1
---

spooki-love is an empty LÖVE (Love2D) 11.5 game written in plain Lua and built on a small, self-contained engine. Desktop builds run on LuaJIT; the love.js web build runs on PUC Lua 5.1, so game and engine code stay within the subset the two share (no `goto`, no `ffi`/`jit`/`bit`, no `table.unpack`). The engine lives under `engine/` and never requires anything outside it. Everything it needs from your game is passed in through the `Game` config table in `main.lua`.

## Scaffold a new game

`init.sh` at the repo root copies the template into a new directory and runs a short wizard. There are three ways to invoke it:

```sh
# from a checkout of this repo:
./init.sh ../my-game

# without a checkout:
curl -fsSL https://raw.githubusercontent.com/spooki-dev/spooki-love/main/init.sh | bash -s my-game

# or clone first and rename in place:
git clone https://github.com/spooki-dev/spooki-love.git my-game && cd my-game && ./init.sh
```

The wizard asks for the game title, author and itch.io username. Enter keeps the default shown in brackets; the title defaults to a version of the target directory name and the author to `git config user.name`. From the title it derives a slug (also used as the package name) and a bundle id (`com.spooki.<slug>`), prints a summary and asks `Create? [Y/n]`.

It then rewrites every place the template says "New Game": the window title and `t.identity` in `conf.lua`, `title` in `main.lua`, the wordmark literals in `scenes/Menu.lua` and `scenes/assets/*.lua`, the `TITLE`/`PKG`/`UTI`/`AUTHOR`/`ITCH` lines at the top of `scripts/release.sh`, the example config in `CLAUDE.md`, and it writes a fresh `README.md` and `CHANGELOG.md`. It deletes itself from the copy. It does not run `git init` or export assets; it prints those as next steps. It needs bash 3.2+, git, perl and tar.

| Flag | Effect |
|---|---|
| `--title "Name"` | Game title (default derived from the target directory name) |
| `--author "Name"` | Author written into `scripts/release.sh` (default `git config user.name`) |
| `--itch user` | itch.io username; fills `ITCH` and `ITCH_EDIT_URL` in `scripts/release.sh` |
| `--uti id` | macOS bundle identifier (default `com.spooki.<slug>`) |
| `-y`, `--yes` | Accept defaults for anything not given, no prompts |
| `-h`, `--help` | Show usage |

Prompts read from the terminal directly so `curl ... | bash` still works. Without a terminal, pass `--yes` or the flags. The `TEMPLATE_REPO` environment variable overrides the git URL cloned when the script is not run from a checkout.

## Run the game

```sh
# love is not on PATH on macOS:
/Applications/love.app/Contents/MacOS/love .
```

There is no build step. `scripts/test.sh` runs the examples regression suite (see `examples.md`); you verify visual changes by running the game. `main.lua` sets `io.stdout:setvbuf("no")`, so `print` output appears immediately when stdout is piped.

## What you get out of the box

- A `Menu` scene (the `defaultScene`) with a Start button that switches to an empty `Game` scene, and a Controls button that opens the rebinding screen. Arrow keys, d-pad or stick move focus between the buttons.
- Custom cursors from the `cursors` config in `main.lua` (`default` and `active`).
- Hot reload while `env = "dev"`: saving a `.lua` file under any directory in the `watch` list reloads the game, and backtick forces a reload. Reload clears `package.loaded`, re-executes `main.lua` and calls `love.load()` again.
- A dev MCP bridge (`engine/dev/mcp_bridge.lua`) on port 12345, loaded with `pcall` so a missing bridge is not fatal.
- Action-based input configured in the `input` block of `main.lua`. Game code reads named actions, never raw keys.

## Make it yours

1. If you did not use `init.sh`: set the window title and `t.identity` in `conf.lua`, `title` in `main.lua`, and the wordmarks in `scenes/Menu.lua` and `scenes/assets/*.lua`.
2. Add scenes under `scenes/`, require them in `main.lua` and append them to the `scenes` array. Keep `Preload` first. See `scenes.md`.
3. Preload fonts and spritesheets in `scenes/Preload.lua`. The UI primitives expect the font keys `header`, `subheader`, `body` and `small`.
4. Put entities in `gameObjects/`, data in `constants/` and shared state in `state/GameState.lua`.
5. Edit the `lines` and `subtitle` in `scenes/assets/*.lua`; `love . --export-assets` regenerates the icon, favicon, cover, social, wide and logo images in `assets/generated/`. See `assets.md`.
6. Do not edit `engine/`. Anything the engine needs from the game goes through the `Game` config table in `main.lua` or a scene hook such as `updateShaderUniforms`.

## Directory map

| Path | What lives there |
|---|---|
| `main.lua` | Builds the game from a `Game` config table. The only place scenes are registered. |
| `conf.lua` | LÖVE config: window title, `t.identity` (save directory name), 1280x720 resizable window with a 1024x600 minimum. |
| `engine/` | The reusable engine: `Game`, `Scene`, `GameObject`, `sceneManager`, `Camera`, `cacheManager`, `ui/`, `input/`, `components/`, `utils/`, vendored `lib/`. Never requires game code. |
| `scenes/` | Game scenes (`Preload`, `Menu`, `Game`, `Controls`) and, under `scenes/assets/`, the scenes that render marketing art. |
| `gameObjects/` | Game-specific entities. `SampleGameObject.lua` and `SampleUIGameObject.lua` are starting points. |
| `constants/` | Game data. `colors.lua` is the palette. |
| `state/` | Shared state. `GameState.lua` is a `State` instance. |
| `assets/` | Fonts, cursors, graphics, music, sounds, and the generated marketing images in `assets/generated/`. |
| `scripts/` | `release.sh`, `lint-lua51.sh`, `patch-win-icon.mjs` and the `web/` page template for the love.js build. |
| `docs/` | This documentation. |

## Where next

- `scenes.md` for the scene lifecycle, registration, layers and the camera.
- `game-objects.md` for the `GameObject` base class, rendering fields, events and children.
- `ui.md` for the UI primitives in `engine/ui/`.
- `engine.md` for a module-by-module tour of `engine/`.
- `development.md` for hot reload, linting and debugging; `build-and-release.md` for shipping.
