-- title: Serialising tables
-- description: table_serialize turns plain data into deterministic Lua source and back; the save manager uses it.
-- order: 4
-- tags: table_serialize, serialize, deserialize
local Scene = require "engine.Scene"
local cacheManager = require "engine.cacheManager"
local serializer = require "engine.utils.table_serialize"
local tableUtils = require "engine.utils.table"

local SAMPLE = {
  name = "ghost",
  level = 3,
  position = { x = 12.5, y = -4 },
  inventory = { "lantern", "key", "map" },
  flags = { metWitch = true, [7] = "seven" },
}

local function deepEqual(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  for k, v in pairs(a) do
    if not deepEqual(v, b[k]) then return false end
  end
  for k in pairs(b) do
    if a[k] == nil then return false end
  end
  return true
end

---@class UtilsSerialize : Scene
local Example = Scene.extend(Scene)

function Example:new()
  Example.super.new(self, "utils/table-serialize")
  self.backgroundColor = { 0.09, 0.09, 0.13, 1 }
  self.source = serializer.serialize(SAMPLE)
  self.roundTrip, self.err = serializer.deserialize(self.source)
  self.again = self.roundTrip and serializer.serialize(self.roundTrip) or nil
  -- Values the format rejects produce an error instead of bad output.
  self.rejected = select(2, pcall(serializer.serialize, { fn = print }))
end

function Example:draw()
  local body = cacheManager.getFont("body")
  love.graphics.setFont(body)
  love.graphics.setColor(1, 1, 0, 1)
  love.graphics.print("serialize(sample)  (keys sorted, so the output is stable)", 48, 48)
  love.graphics.setColor(0.78, 0.72, 0.75, 1)
  love.graphics.printf(self.source, 48, 80, 1180, "left")
  love.graphics.setColor(1, 1, 0, 1)
  love.graphics.print("deserialize(...) then serialize again", 48, 240)
  love.graphics.setColor(0.78, 0.72, 0.75, 1)
  love.graphics.printf(self.again or ("error: " .. tostring(self.err)), 48, 272, 1180, "left")
  love.graphics.setColor(1, 1, 0, 1)
  love.graphics.print("serialize({ fn = print })", 48, 430)
  love.graphics.setColor(0.9, 0.3, 0.3, 1)
  love.graphics.printf(tostring(self.rejected), 48, 462, 1180, "left")
  love.graphics.setColor(0.6, 0.6, 0.65, 1)
  love.graphics.print("Round trip equal: " .. tostring(deepEqual(SAMPLE, self.roundTrip)), 48, 560)
  love.graphics.setColor(1, 1, 1, 1)
end

function Example.check(scene, ctx)
  if ctx.done then
    assert(scene.roundTrip, "deserialize failed: " .. tostring(scene.err))
    assert(deepEqual(SAMPLE, scene.roundTrip), "round trip preserves the data")
    assert(scene.again == scene.source, "serialisation is deterministic")
    assert(deepEqual(tableUtils.deepCopy(SAMPLE), SAMPLE), "deepCopy helper agrees")
    assert(tostring(scene.rejected):find("Unsupported value type"), "functions are rejected")
    assert(select(1, serializer.deserialize("not lua {")) == nil, "garbage returns nil, never throws")
  end
end

return Example
