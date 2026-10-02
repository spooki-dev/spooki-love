# spooki-love

An empty LÖVE (Love2D) 11.5 game built on a small, self-contained engine (`engine/`). Scaffold a copy with `init.sh`, then start adding scenes.

## Scaffold a new game

```sh
# from a checkout of this repo:
./init.sh ../my-game

# without a checkout:
curl -fsSL https://raw.githubusercontent.com/spooki-dev/spooki-love/main/init.sh | bash -s my-game

# or clone first and rename in place:
git clone https://github.com/spooki-dev/spooki-love.git my-game && cd my-game && ./init.sh
```

The wizard asks for the game title, author and itch.io username (Enter keeps the default shown in brackets) and derives the slug, package name and bundle id. It rewrites the window title, the Menu and marketing wordmarks, the variables at the top of `scripts/release.sh`, and writes a fresh `README.md` and `CHANGELOG.md`. Pass `--title`, `--author`, `--itch`, `--uti` and `--yes` to skip the prompts. It leaves `git init` and `love . --export-assets` to you and prints them as next steps.

## Quick start

```sh
# love is not on PATH on macOS:
/Applications/love.app/Contents/MacOS/love .
```

You get a Menu scene with a Start button that switches to an empty `Game` scene, custom cursors, hot reload on save (backtick to force), and a dev MCP bridge on port 12345.

## Make it yours

1. If you did not use `init.sh`: set the window title and `t.identity` (save directory name) in `conf.lua`, `title` in `main.lua` and the wordmarks in `scenes/Menu.lua` and `scenes/assets/*.lua`.
2. Add scenes under `scenes/`, require them in `main.lua` and append them to the `scenes` array. Keep `Preload` first. See `docs/CreatingANewScene.md`.
3. Preload fonts and spritesheets in `scenes/Preload.lua`. The UI primitives expect font keys `header`, `subheader`, `body`, `small`.
4. Put entities in `gameObjects/`, data in `constants/`, and shared state in `state/GameState.lua`.
5. Edit the `lines`/`subtitle` in `scenes/assets/*.lua`; `love . --export-assets` regenerates the icon, favicon, cover, social, wide and logo images in `assets/generated/`.
6. Declare input actions in the `input` block of `main.lua` and read them with `inputMap`; the Controls scene lets players remap them and `InputPrompt` shows the bindings (`docs/Input.md`).
7. Do not edit `engine/`. Anything the engine needs from the game goes through the `Game` config table in `main.lua` or a scene hook (for example `updateShaderUniforms`).

See `CLAUDE.md` for the architecture and engine contracts.

## Build and release

```sh
scripts/release.sh            # export assets, build Mac/Windows/web/.love, push to itch.io
scripts/release.sh --no-push  # build only; artefacts land in releases/<PKG>/
love . --export-assets        # regenerate assets/generated/*.png only
```

Set `TITLE`, `PKG`, `UTI`, `AUTHOR` and `ITCH` at the top of `scripts/release.sh`. Requires `love-release`, `love.js`, `butler` (logged in), node and the macOS `iconutil`/`sips`/`plutil` tools. See `CLAUDE.md` for details and for which itch.io page images still need a manual upload.

The web build runs on Lua 5.1 (love.js), not LuaJIT, so avoid `goto` and LuaJIT-only modules. `scripts/lint-lua51.sh` checks every tracked Lua file with a real Lua 5.1 parser; enable the pre-commit hook with `git config core.hooksPath .githooks`. The web page itself is `scripts/web/index.html` plus `theme/love.css`: a bare canvas on black, with no love.js heading or footer.
