local UIBox = require "engine.ui.UIBox"
local UIText = require "engine.ui.UIText"

--- Example of a composite UI object: a UIBox with labelled children.
--- Copy and rename this file to build your own UI components.
---@class SampleUIGameObject : UIBox
local SampleUIGameObject = UIBox.extend(UIBox)

---@param name string The name of the SampleUIGameObject (must be unique in the scene)
---@return SampleUIGameObject
function SampleUIGameObject:new(name)
  local children = {
    UIText(name .. "Heading", "Heading", {
      textAlign = "right",
      font = "header",
    }),
    UIText(name .. "Body", "Body text", {
      textAlign = "right",
    }),
  }
  local styles = {}
  SampleUIGameObject.super.new(self, name, children, styles)

  return self
end

return SampleUIGameObject
