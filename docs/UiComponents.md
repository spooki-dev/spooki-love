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

4. **InputPrompt:**
   - `InputPrompt(name, action | { actions }, label, styles)` draws what an action is bound to on the device the player is using, as glyphs from the prompt sheet followed by the label. Four directional actions bound to one stick or d-pad collapse to a single glyph. Styles: `scale`, `font`, `color`, `showAll`, `device`.

5. **FocusGroup and focusable Buttons:**
   - `FocusGroup({ columns = n })` holds objects with `focus()/blur()/activate()` (`Button` has them) and moves focus with the `ui_*` actions from the scene's `update(dt)`. Mouse hover also moves focus. Give the group `columns` for grids.

## Contracts

- Fonts are looked up by key: `body` (UIText default), `small` (Button, UIBar), `header`, `subheader`. Preload them (see `scenes/Preload.lua`).
- `Button` switches the cursor between the `active` and `default` keys from the `cursors` config in `main.lua`. `Button(name, label, styles)` accepts `height`, `font`, `color`, `highlightColor`, `width`, `margin`; hover and focus share the highlighted look.
- `InputPrompt` needs the prompt sheet preloaded: `cacheManager.preloadImage(glyphs.IMAGE_KEY, glyphs.IMAGE_PATH)` in `Preload`.
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
