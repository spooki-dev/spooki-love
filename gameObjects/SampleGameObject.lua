local GameObject = require "engine.GameObject"

---@class SampleGameObject : GameObject
local SampleGameObject = GameObject.extend(GameObject)

---@param name string The name of the SampleGameObject
---@param pos Vector2|nil The position of the SampleGameObject
---@param width number|nil The width of the SampleGameObject
---@param height number|nil The height of the SampleGameObject
---@return SampleGameObject
function SampleGameObject:new(name, pos, width, height)
  SampleGameObject.super.new(self, name, pos, width, height)

  return self
end

return SampleGameObject
