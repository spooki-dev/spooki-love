# Creating a New Scene
This document outlines the steps to create a new empty Scene in the
repository, following the pattern established in `scenes/Game.lua`.

## Step-by-Step Guide
1. **Create a New Lua File:**
   - In the scenes directory create a new Lua file for your scene. For example, name it
`NewScene.lua`.


1. **Add the Following Code:**
   - Open the newly created `NewScene.lua` file and add the following code:

```
local Scene = require "engine.Scene"
local colors = require "constants.colors"

---@class NewScene : Scene
local NewScene = Scene.extend(Scene)

function NewScene:new()

NewScene.super.new(self, "NewScene")
  self.backgroundColor = colors.black
end

function NewScene:load(dt)
end

function NewScene:start()
end

function NewScene:update(dt)
end

return NewScene
```

1. **Replace `"NewScene"`:**
   - Replace `"NewScene"` with the desired name of your new scene.


4. **Adjust the `backgroundColor`:**
   - Adjust the `backgroundColor` or any other properties as needed for your specific scene.

5. **Implement the `load`, `start`, and `update` Methods:**
   - Implement the `load`, `start`, and `update` methods with the logic specific to your scene.

6. **Register the scene in `main.lua`:**
   - Require the scene and add it to the `scenes` array of the `Game` config. Scenes are
     registered in order and `load()` runs immediately, so keep `Preload` first.
   - To start on the new scene, set `defaultScene = "NewScene"`.

```lua
local NewScene = require "scenes.NewScene"

Game({
  -- ...
  scenes = { Preload, Menu, NewScene },
  defaultScene = "Menu",
})
```

   - Switch to it at runtime with `sceneManager.setCurrentScene("NewScene")`.
   - Optionally define `NewScene:updateShaderUniforms(uniforms, dt)` to feed post-processing
     shader uniforms; the table is cleared every frame before the call.
   - Read input through actions: `inputMap.down("jump")` in `update`, or define
     `NewScene:onActionPressed(name)` / `onActionReleased(name)` for events. Actions are
     declared in the `input` block of `main.lua`; see `docs/Input.md`.

## Example
Here is an example of a new scene named `MyCustomScene`:

```
local Scene = require "engine.Scene"
local colors = require "constants.colors"

---@class MyCustomScene : Scene
local MyCustomScene = Scene.extend(Scene)

function MyCustomScene:new()

MyCustomScene.super.new(self, "MyCustomScene")
  self.backgroundColor = colors.white
end

function MyCustomScene:load(dt)
  -- Load logic here
end

function MyCustomScene:start()
  -- Start logic here
end

function MyCustomScene:update(dt)
  -- Update logic here
end

return MyCustomScene
```

## Conclusion
By following these steps, you can easily create a new empty Scene in the
repository, which you can then populate with game objects, layers, and
other components as needed.