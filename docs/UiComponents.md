# UI Component Hierarchy Convention

## Overview

This convention outlines the recommended approach for structuring UI components using the `children` parameter. By following this convention, you can create a hierarchical and organized UI structure, making it easier to manage and maintain.

The primitives live in `engine/ui/` and are required as `require "engine.ui.UIBox"`, `require "engine.ui.Button"`, and so on.

## Structure

1. **UICanvas:**
   - The `UICanvas` serves as the root container for all UI elements.
   - It can contain multiple child UI components, such as `UIStack`, `Button`, etc.

2. **UIStack:**
   - The `UIStack` is a container that arranges its child components in a row.
   - It can contain multiple child UI components, such as `Button`, `UIText`, etc.

3. **UI Components:**
   - UI components like `Button`, `UIText`, etc., are added as children to `UIStack` or `UICanvas`.
   - Each UI component can have its own styles and properties.

## Contracts

- Fonts are looked up by key: `body` (UIText default), `small` (Button, UIBar), `header`, `subheader`. Preload them (see `scenes/Preload.lua`).
- `Button` switches the cursor between the `active` and `default` keys from the `cursors` config in `main.lua`.
- UI objects default to the `ui` layer, which draws without the camera transform.

## Example

```lua
local UICanvas = require "engine.ui.UICanvas"
local UIStack = require "engine.ui.UIStack"
local Button = require "engine.ui.Button"
local Vector4 = require "engine.Vector4"

self:addGameObject(UICanvas("MainCanvas", {
  UIStack("MainStack", {
    Button("PlayButton", "Play"),
    Button("PauseButton", "Pause"),
    Button("StopButton", "Stop"),
  }, { padding = Vector4(5, 5, 5, 5), gap = 10 }),
}, { padding = Vector4(10, 10, 10, 10) }))
```

`Vector4` padding/border/margin order is (top, right, bottom, left).
