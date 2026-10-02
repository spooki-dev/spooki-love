---
title: Game objects
description: How to define a GameObject, what the engine draws for you, which event handlers it wires up, and how children, layers and unique names work.
order: 3
---

Everything that lives in a scene is a `GameObject` (`engine/GameObject.lua`): sprites, text, collision volumes, UI boxes. The base class gives you a position, a size, a renderer that draws whatever fields you set, an animation manager, mouse and keyboard event dispatch, rigid body movement and a child list. You extend it, override a few lifecycle methods and add instances to a scene.

## Defining a class

The project uses the vendored `classic` library (`engine/lib/classic.lua`). `GameObject.lua` itself is declared with `Object:extend()`; the samples write the equivalent `GameObject.extend(GameObject)`. Either is fine. Call the parent constructor from your own:

```lua
local GameObject = require "engine.GameObject"

---@class Player : GameObject
local Player = GameObject.extend(GameObject)

function Player:new(name, pos, width, height)
  Player.super.new(self, name, pos, width, height)
  return self
end

return Player
```

The base constructor is `GameObject:new(name, pos, width, height)`. `pos` is a `Vector2` (`require "engine.Vector2"`) and defaults to `Vector2(0, 0)`; `width` and `height` default to 0. Instances are created by calling the class: `Player("Player", Vector2(100, 100), 16, 16)`.

## Lifecycle

The engine calls the `handle*` methods. You override the plain ones.

| Engine calls | What it does | You override |
|---|---|---|
| `handleLoad()` | Calls `load()` once (guarded by `loaded`), then `handleLoad()` on each child. Triggered by `Scene:addGameObject`. | `load()` |
| `handleUpdate(dt)` | Calls `update(dt)`. Does not recurse: children are registered with the scene and updated by it. | `update(dt)` |
| `handleDraw()` | Runs the shared renderer if any renderable field is set, then calls `draw()`, then the debug overlays. Does not recurse. | `draw()` |
| `start()` | Called by the base `Scene:start()` each time the scene becomes current. | `start()` |

Because `Scene:addGameObject` sets `gameObject.scene` before calling `handleLoad()`, your `load()` can rely on `self.scene`.

## Position, size and collision

| Method | Behaviour |
|---|---|
| `getPos()` | Returns the `Vector2` position. |
| `setPos(newPos)` | Takes a `Vector2`. For rigid bodies it first checks `canMoveTo` against the scene's other rigid bodies and returns `false` without moving on a collision; otherwise sets the position and returns `true`. |
| `getWidth()`, `setWidth(newWidth)`, `getHeight()`, `setHeight(newHeight)` | Size accessors. `setHeight(nil)` is ignored. |
| `getRect()` | The rendered rectangle `{ x, y, width, height }`, offset by `positionOrigin`. Used for mouse hit tests. |
| `setShape(shape)`, `getShape()` | The collision rectangle. `shape` is `{ x, y, width, height }` relative to the position; `getShape()` returns it in world space. The default is captured at construction from `width` and `height`, so update it if the size changes later. |
| `setRigidBody(isRigid)` | Sets `rigidBody` and adds or removes the object in `scene.rigidBodies`. Call it once the object has a scene, for example in `load()`. |
| `canMoveTo(newX, newY, allGameObjects)` | `true` when the shape at the new position overlaps no other rigid body in the list. Always `true` for non-rigid objects. |
| `GameObject.rectsIntersect(a, b)` | Static axis-aligned rectangle test. |

Set `debugShape = true` to draw the collision rectangle in green.

## What the renderer draws

`handleDraw()` hands the object to `engine/renderer.lua` when any of `image`, `spritesheet` with `quad`, `fillColor`, `text` with `textColor`, or `border` is set. You draw nothing yourself unless you override `draw()`.

| Field | Meaning |
|---|---|
| `image` | A `cacheManager` image key. Drawn at `getPos()`. |
| `spritesheet`, `quad` | A `love.Image` and a `love.Quad`. Takes precedence over `image`. |
| `width`, `height` | Fall back to the quad or image size when 0. |
| `fillColor` | A `Vector4(r, g, b, a)`; fills the rectangle. `borderRadius` (a `Vector4`) rounds the corners. |
| `text`, `textColor`, `font`, `textAlign` | Text is printed with `love.graphics.printf` across `width`. All three of `text`, `textColor` and `font` (a `love.Font`) must be set for it to appear. `textAlign` is `"left"`, `"center"` or `"right"`. |
| `border`, `borderColor` | `Vector4` thicknesses in (top, right, bottom, left) order and a `Vector4` colour. |
| `opacity` | 0 to 1, applied to the image or quad. |
| `scaleX`, `scaleY`, `flipX`, `flipY` | Scaling and flipping, always about the centre. `setFlipX(flip)` sets `flipX`. |
| `rotation`, `rotationOrigin` | Radians, and an optional `Vector2` origin relative to the top left (default centre). |
| `positionOrigin` | A normalised `Vector2`; `(0.5, 0.5)` positions the object by its centre. Default `(0, 0)`. |
| `repeatX`, `repeatY` | Pixel extents to tile the image or quad across; 0 disables tiling. |
| `ysortOffset` | Added to `y` when non-UI layers are Y-sorted. `debugYSortOffset = true` draws the line. |
| `drawPriority` | Tie-breaker for Y-sorting and the only sort key in the `ui` layer. |

The window uses `love.graphics.setDefaultFilter("nearest", "nearest", 1)`, so pixel art stays crisp.

## Animation

Each object owns `self.animation`, an `AnimationManager` (`engine/AnimationManager.lua`). The engine never updates or draws it for you: call both from your overrides.

```lua
-- in scenes/Preload.lua
cacheManager.preloadSpritesheet("player", "assets/graphics/player.png", 16, 16, { "idle1", "idle2", "run1", "run2" })

-- in Player
function Player:load()
  self.animation:add("idle", "player", { "idle1", "idle2" }, nil, 4)
  self.animation:add("run", "player", { "run1", "run2" }, nil, 8)
  self.animation:set("idle")
end

function Player:update(dt)
  self.animation:update(dt)
end

function Player:draw()
  self.animation:draw(self)
end
```

`add(name, sheet, frames, onFrame, frameRate)` takes a spritesheet key, an array of quad keys from `cacheManager.preloadSpritesheet`, an optional table of per-frame callbacks keyed by frame index, and a frame rate that defaults to 16. `set(name)` switches animation (erroring on an unknown name) and rewinds when the name changes. `play()`, `pause()` and `stop()` set the state; `getCurrentFrame()`, `setCurrentFrame(frame)` and `getCurrentAnimation()` inspect it. `draw(object)` honours `scaleX`, `scaleY`, `flipX`, `flipY`, `rotation` and `active`, and `debugOrigins = true` marks the position and centre.

## Event handlers

Define any of these on the class, or on the instance before it is added, and `Scene:addGameObject` registers the object for dispatch. Handlers only fire while `active` is true.

| Handler | Fires when |
|---|---|
| `onClick()` | The left button is released inside `getRect()`. |
| `onMouseOver(x, y)` | Every mouse move while the pointer is inside `getRect()`. |
| `onMouseEntered()`, `onMouseExit()` | The pointer crosses into or out of `getRect()`. Tracked through `isMouseOver`. |
| `onMouseDown(x, y, button, istouch, presses)` | A button is pressed inside `getRect()`. Only dispatched to objects that also define one of the mouse-over handlers. |
| `handleScroll(x, y)` | The wheel moves. |
| `onKeyPressed(key, scancode, isrepeat)` | A raw key press. Prefer actions. |
| `onActionPressed(name)`, `onActionReleased(name)` | A named input action went down or up. |
| `getHitbox()`, `getHurtbox()` | Not events, but defining either registers the object in `scene.hitHurtBoxObjects` for collision queries. |

Mouse hit tests compare raw window coordinates with `getRect()`; no camera transform is applied, so they are exact for the `ui` layer and for world objects while the camera sits at (0, 0) with zoom 1.

## Children

| Method | Behaviour |
|---|---|
| `addGameObject(gameObject)` | Errors if the parent is not yet in a scene. Appends to the child list, sets `parent`, and adds the child to the scene, so it needs a scene-unique name and lands in its own `layer`. Returns the child. |
| `getGameObject(name)` | Finds a direct child by name. |
| `removeGameObject(gameObject)` | Removes from the child list only. |
| `destroyGameObject(gameObjectOrName)` | Finds the child and calls `destroy()` on it. |
| `destroy()` | Removes the object from its parent and scene, then destroys every child. |
| `toggleActive(active, toggleChildren)` | Sets `active`. Deactivating always cascades to children; activating cascades only when `toggleChildren` is true. |

## Layers and names

An object's `layer` field is read when it is added to a scene and defaults to `entities`; set `self.layer = "ground"` (or any layer the scene has added) beforehand. The UI primitives set `layer = 'ui'` in their constructors. See `scenes.md` for how layers are drawn.

Names must be unique within a scene. A duplicate in the same layer throws when the object is added; a duplicate in a different layer silently overwrites the registry entry. Hot reload re-runs every scene's `load()`, so a duplicate surfaces as a crash the moment you save, and `start()` runs on every activation, so create long-lived objects in `load()`. Composite objects should prefix their children's names, as `gameObjects/SampleUIGameObject.lua` does with `name .. "Heading"`.

## The samples

- `gameObjects/SampleGameObject.lua` is the bare class above: extend, forward the constructor arguments, return `self`.
- `gameObjects/SampleUIGameObject.lua` extends `UIBox` and builds two `UIText` children in its constructor. Copy it for composite UI components; `ui.md` covers the primitives and their `styles`.

## Mixins

`Object:implement(...)` copies every function a class does not already define, which is how the optional components in `engine/components/` are attached.

`HitHurtBox` adds `setHitbox(box)`, `setHurtbox(box)`, `getHitbox()`, `getHurtbox()`, `intersectsWith(other)`, `checkCollisionsWith(classRef, objectsTable, callback)` and `drawHitHurtBoxDebug()`. Boxes are `{ x, y, width, height }` relative to the position. Pass the scene as `objectsTable` and it searches `scene.hitHurtBoxObjects`. Set `debugHitHurtBox = true` to draw them; only do so on objects that implement the mixin, because `handleDraw()` calls `drawHitHurtBoxDebug()` whenever that flag is set.

```lua
local HitHurtBox = require "engine.components.HitHurtBox"
Player:implement(HitHurtBox)
```

`LightManager` wraps the vendored Shädows library. Create one with `LightManager:new(scene)`, assign it to `scene.lightManager`, and the scene updates and draws it after the world layers. `addLight(x, y, radius, color, intensity, id)` takes world coordinates and a `{ r, g, b }` colour in 0 to 255; `updateLightPosition(id, x, y)` moves a light. See `engine.md`.

## Performance

Do not create tables or objects inside `update` or `draw`. `Vector2` operations such as `add` and `scale` return new vectors, so compute them once and reuse the result, or mutate `x` and `y` directly on a vector you already hold. Pre-allocate anything created frequently.
