# spooki-love

An empty LÖVE (Love2D) 11.5 game built on a small, self-contained engine (`engine/`). Clone it, rename it, and start adding scenes.

## Quick start

```sh
# love is not on PATH on macOS:
/Applications/love.app/Contents/MacOS/love .
```

You get a Menu scene with a Start button that switches to an empty `Game` scene, a CRT post-processing toggle, custom cursors, hot reload on save (backtick to force), and a dev MCP bridge on port 12345.

## Make it yours

1. Set the window title in `conf.lua` and `title` in `main.lua`.
2. Add scenes under `scenes/`, require them in `main.lua` and append them to the `scenes` array. Keep `Preload` first. See `docs/CreatingANewScene.md`.
3. Preload fonts and spritesheets in `scenes/Preload.lua`. The UI primitives expect font keys `header`, `subheader`, `body`, `small`.
4. Put entities in `gameObjects/`, data in `constants/`, and shared state in `state/GameState.lua`.
5. Do not edit `engine/`. Anything the engine needs from the game goes through the `Game` config table in `main.lua` or a scene hook (for example `updateShaderUniforms`).

See `CLAUDE.md` for the architecture and engine contracts.

## Build

```sh
# Mac + Windows
love-release -W -M --uti "com.example.newgame" --title "New Game" --author "Your Name"
# Web
love.js -c -t "New Game" ./releases/newgame.love ./releases/newgame-web/
```
