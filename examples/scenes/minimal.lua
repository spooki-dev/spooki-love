-- title: A minimal scene
-- description: The smallest scene: a background colour, an update counter and text drawn in draw().
-- order: 1
-- tags: scene, draw, update
local Scene = require "engine.Scene"
local cacheManager = require "engine.cacheManager"

---@class ScenesMinimal : Scene
local Example = Scene.extend(Scene)

function Example:new()
  -- The scene name is the example id: <category>/<slug>.
  Example.super.new(self, "scenes/minimal")
  self.backgroundColor = { 0.09, 0.09, 0.13, 1 }
  self.elapsed = 0
end

function Example:update(dt)
  self.elapsed = self.elapsed + dt
end

function Example:draw()
  love.graphics.setFont(cacheManager.getFont("header"))
  love.graphics.setColor(1, 1, 0, 1)
  love.graphics.print("Hello, spooki-love", 48, 48)
  love.graphics.setFont(cacheManager.getFont("body"))
  love.graphics.setColor(0.78, 0.72, 0.75, 1)
  love.graphics.print(string.format("%.1f seconds in this scene", self.elapsed), 48, 96)
  love.graphics.setColor(1, 1, 1, 1)
end

-- Test harness: runs after every simulated frame (dt = 1/60).
function Example.check(scene, ctx)
  if ctx.done then
    assert(math.abs(scene.elapsed - ctx.t) < 1e-6, "elapsed should equal the simulated time")
  end
end

return Example
