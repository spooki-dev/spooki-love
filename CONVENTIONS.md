# Project Conventions

## Naming Conventions
- **Classes/Objects**: Use `PascalCase` (e.g., `GameObject`, `HitHurtBox`).
- **Methods/Functions**: Use `camelCase` (e.g., `getSpritePosition`).
- **Variables/Local Variables**: Use `camelCase`.
- **Constants**: Use `UPPER_CASE_WITH_UNDERSCORES`.

## LuaDoc Requirements
- All functions must be documented using LuaDoc.
- **Parameters**: Every `@param` must include the type and a brief description.
- **Return Values**: Every `@return` must specify the type.
- Example:
  ```lua
  --- Gets the width of the object.
  --- @param newWidth number? The width to set (optional).
  --- @return number The current width.
  function GameObject:getWidth()
  ```

## Performance Guidelines
- **Garbage Collection**: Avoid creating new tables or objects inside the main `update` or `draw` loops.
- **Pre-allocation**: Use pre-allocated tables or object pools for frequently created objects.

## Error Handling
- Use `assert()` for internal logic checks that should never fail.
- Use custom error logging for non-fatal issues.

## File Organization
- `engine/`: Reusable engine. Must not require anything outside `engine/`.
  - `engine/ui/`: UI primitives (UIBox, UICanvas, UIStack, UIText, UIBar, BarFill, Button).
  - `engine/lib/`: Vendored third-party code (classic, hotReload, shadows).
  - `engine/dev/`: Development-only tooling (MCP bridge).
  - `engine/shaders/`, `engine/components/`, `engine/utils/`.
- `main.lua`: Builds the `Game` from a config table (scenes, default scene, cursors, shaders, watch dirs).
- `scenes/`: Game scenes.
- `gameObjects/`: Game-specific entities and interactive objects.
- `constants/`, `classes/`, `state/`, `audio/`: Game data and logic.
