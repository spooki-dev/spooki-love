---
title: Scenes
description: The scene lifecycle, how scenes are registered and switched, and how layers, the camera and the game object registry work.
order: 2
---

A scene is a screen of the game: the menu, a level, the controls page. Every scene extends `engine/Scene.lua`, owns a camera, a set of layers and a registry of game objects, and is registered once from `main.lua`. `engine/sceneManager.lua` holds every scene by name, decides which one is current, and forwards update, draw and input to it.

## Lifecycle and hooks

Scenes use the vendored `classic` OOP library (`engine/lib/classic.lua`). Extend `Scene`, call the parent constructor with the scene's name, and override the hooks you need. The base constructor is `Scene:new(name)`; it creates the camera, the three default layers and the registries, and sets `backgroundColor` to `{ 0, 0, 0, 1 }`.

| Hook | When the engine calls it |
|---|---|
| `load()` | Once, from `sceneManager.addScene` immediately after construction. Build your game objects here. |
| `start()` | Every time the scene becomes current, from `sceneManager.setCurrentScene`. The base `Scene:start()` calls `start()` on every game object; an override replaces that unless it calls `YourScene.super.start(self)`. |
| `update(dt)` | Every frame, before the scene's game objects update. |
| `draw()` | Every frame, after the camera transform is applied and the background colour is set, before any layer is drawn. |
| `onKeyPressed(key, scancode, isrepeat)` | Raw key press. Prefer actions. |
| `onKeyReleased(key, scancode)` | Raw key release. |
| `onActionPressed(name)`, `onActionReleased(name)` | A named input action went down or up this frame. Delivered before `update`. |
| `updateShaderUniforms(uniforms, dt)` | Every frame. `uniforms` is emptied first, so fill it completely each call. Read by the post-processing shaders in the `shaders` config. |
| `onQuit()` | From `Game:quit` on the current scene, wrapped in `pcall`. Autosave here. |

There is no scene-level mouse hook. Mouse moves, clicks, presses and scrolls are dispatched to the game objects that define handlers (see `game-objects.md`).

`backgroundColor` is a table unpacked into `love.graphics.setBackgroundColor`, so the decimal entries in `constants/colors.lua` (`colors.black`, `colors.dark` and so on) work directly.

## A minimal scene

```lua
local Scene = require "engine.Scene"
local colors = require "constants.colors"

---@class Arena : Scene
local Arena = Scene.extend(Scene)

function Arena:new()
  Arena.super.new(self, "Arena")
  self.backgroundColor = colors.black
end

function Arena:load()
  -- runs once at registration: create and add game objects here
end

function Arena:start()
  -- runs every time the scene becomes current
end

function Arena:update(dt)
end

return Arena
```

Save it as `scenes/Arena.lua`. The string passed to `Arena.super.new` is the scene's name and must be unique: the registry is keyed by it, and a second scene with the same name silently replaces the first.

## Registering in main.lua

`main.lua` is the only place scenes are registered. Require the scene and append it to the `scenes` array of the `Game` config:

```lua
local Arena = require "scenes.Arena"

Game({
  title = "New Game",
  env = "dev",
  scenes = { Preload, Menu, GameScene, Controls, Arena },
  defaultScene = "Menu",
  -- ...
})
```

Scenes are registered in array order and `sceneManager.addScene` calls each scene's `load()` immediately, so `Preload` must stay first: the other scenes build UI that needs the fonts it caches. `inputMap.init` runs before any scene loads, so prompts can read bindings during `load()`. After registration the scene named by `defaultScene` is made current. `Game:new` asserts that `scenes` is non-empty and `defaultScene` is a string. To start on your new scene, set `defaultScene = "Arena"`.

## sceneManager API

```lua
local sceneManager = require "engine.sceneManager"
```

| Function | Behaviour |
|---|---|
| `addScene(sceneFunc)` | Instantiates the constructor, registers the instance under `scene.name`, calls `load()` and returns the instance. |
| `setCurrentScene(scene)` | Takes a name. Resets the mouse cursor to the system cursor, then errors if `scene` is already current or is not registered. Otherwise makes it current, calls `inputMap.flushEdges()` so the press that triggered the switch does not fire again, and calls `start()`. |
| `getScene(name)` | The registered instance, or `nil`. |
| `getSceneConstructor(name)` | The constructor a scene was registered with, or `nil`. |
| `getCurrentScene()` | The current scene's name. |
| `getCurrentSceneObject()` | The current scene instance, or `nil`. |
| `resetScene(name)` | Drops the instance and re-registers the constructor, so `load()` runs again. Returns the fresh instance. Errors on an unknown name. |
| `checkAndCallSceneFunction(func, ...)` | Calls the named method on the current scene if it defines it, and returns its result. |

The remaining functions (`update`, `draw`, `click`, `keypressed`, `mouseMoved`, `wheelMoved`, `actionPressed` and friends) are called by `engine/Game.lua` and are not meant for game code.

Switching is one call. `scenes/Menu.lua` does it from a button:

```lua
function startButton:onClick()
  sceneManager.setCurrentScene("Game")
end
```

Because `setCurrentScene` throws when given the already-current scene, guard any switch that might repeat, for example from a pause action:

```lua
if sceneManager.getCurrentScene() ~= "Menu" then
  sceneManager.setCurrentScene("Menu")
end
```

`resetScene` is how a menu rebuilds a level before entering it. It returns the new instance, so you can hand it data before `setCurrentScene` runs `start()`.

## Layers

Every scene has three layers created by `addDefaultLayers()`:

| Layer | zIndex | Drawn |
|---|---|---|
| `ground` | 1 | In world space, under the camera transform |
| `entities` | 2 | In world space, under the camera transform |
| `ui` | 3 | In screen space, after the camera is unset |

Add more with `scene:addLayer(layerName, zIndex)`; the draw order is rebuilt and sorted by `zIndex` ascending each time. A game object goes into the layer named by its `layer` field, read when it is added, and defaults to `entities`. Set it before adding:

```lua
local floor = Floor("Floor")
floor.layer = "ground"
self:addGameObject(floor)
```

Adding to a layer that does not exist is an error. The UI primitives in `engine/ui/` set `layer = 'ui'` in their constructors.

Each frame `Scene:handleDraw()` applies the camera, sets the background colour, calls your `draw()`, then draws every non-`ui` layer in order. Within a layer only objects whose rectangle (`getPos()` plus `width` and `height`) overlaps `camera:getBounds()` are drawn, sorted by `getPos().y + ysortOffset` with `drawPriority` breaking ties. The `lightManager`, if the scene set one, draws after those layers. The camera is then unset and the `ui` layer is drawn sorted by `drawPriority` only, with no culling.

## Camera

`scene.camera` is created by `Camera.new()` at position (0, 0) with zoom 1. `engine/Camera.lua` is a plain metatable class, not a `classic` one.

| Method | Behaviour |
|---|---|
| `move(dx, dy)` | Offsets the position. |
| `setPosition(x, y)`, `getPosition()` | Sets or returns `x, y`. |
| `setZoom(zoom)`, `getZoom()` | Sets or returns the zoom factor applied in `set()`. |
| `getBounds()` | `{ top, bottom, left, right }` from the position and the window size. Zoom is not applied, and this is what culling uses. |
| `getWorldPosition()` | Position divided by zoom. |
| `getWorldMousePosition()` | The mouse position as a `Vector2` in world space, accounting for zoom and position. |
| `worldToScreen(worldX, worldY)` | Converts a world point to screen coordinates. |
| `followTarget(target, width, height)` | Centres on `target` (anything with `getPos()`, `width` and `height`). With `width` and `height` the camera is clamped so it never shows beyond a map of that size. |

`set()` and `unset()` push and pop the transform and are called by `Scene:handleDraw()`. A typical use is in `update`:

```lua
function Arena:update(dt)
  self.camera:followTarget(self.player, self.mapWidth, self.mapHeight)
end
```

## Game objects in a scene

| Method | Behaviour |
|---|---|
| `addGameObject(gameObject)` | Errors on `nil` or a missing `name`. Registers the object, places it in its layer, sets `gameObject.scene` (and `parent`, if it has none), registers whichever event handlers it defines at that moment, calls `handleLoad()` and returns the object. |
| `getGameObject(name)` | Looks up the registry by name. |
| `getObjectsByClass(classRef)` | An array of every registered object for which `obj:is(classRef)` is true. |
| `removeGameObject(gameObject)` | Unregisters the object from the registry, its layer, `rigidBodies` and every event table. Does not touch its children or clear its `scene` field. |
| `destroyGameObject(gameObjectOrName)` | Accepts an object or a name and calls `obj:destroy()`, which removes it from its parent and the scene and destroys its children. |

Children added through `GameObject:addGameObject` are also added to the scene, so `scene.gameObjects` is a flat registry of every object, parents and children alike.

## Unique names

Every game object name must be unique within a scene. When a second object with the same name lands in the same layer the engine throws `Game object with name <name> already exists in layer <layer>.` A duplicate in a different layer does not throw; it silently overwrites the registry entry, so treat names as unique per scene regardless of layer.

Two things make this bite in practice:

- Hot reload re-executes `main.lua` and `love.load()`, which re-registers every scene and runs every `load()` again. Any duplicate throws the moment you save a file.
- `start()` runs on every activation, so objects added there without being destroyed first throw the second time the scene is entered. Add long-lived objects in `load()`.
