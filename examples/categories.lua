-- Categories of the examples catalogue, in display order. One entry per line:
-- the website parses this file with a regular expression, so keep the shape.
-- Every examples/<id>/ directory must be listed here and vice versa.
return {
  { id = "scenes",           title = "Scenes",           description = "Scene lifecycle, switching, layers and Y-sorting." },
  { id = "game-objects",     title = "Game objects",     description = "Declarative rendering, movement, parents and children, mouse events." },
  { id = "animation",        title = "Animation",        description = "Spritesheets, the AnimationManager and easing curves." },
  { id = "camera",           title = "Camera",           description = "Following, zooming, world versus screen space and shake." },
  { id = "input",            title = "Input",            description = "Action-based input, events, prompts, rebinding and focus." },
  { id = "ui",               title = "UI",               description = "Boxes, flex rows, text, buttons, bars and a HUD." },
  { id = "collision",        title = "Collision",        description = "AABB overlap, rigid bodies, hit and hurt boxes, triggers." },
  { id = "lighting",         title = "Lighting",         description = "Point lights with the LightManager." },
  { id = "post-processing",  title = "Post-processing",  description = "Full-screen shaders and shader chains." },
  { id = "utils",            title = "Utilities",        description = "Perlin noise, pathfinding, colours, vectors and serialisation." },
  { id = "state-and-saves",  title = "State and saves",  description = "The State container and the save manager." },
}
