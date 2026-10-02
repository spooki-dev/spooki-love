-- title: Boxes, padding and margins
-- description: UICanvas and UIBox stack children vertically; padding and margin are Vector4(top, right, bottom, left), and debug flags show them.
-- order: 1
-- tags: UICanvas, UIBox, padding, margin
local Scene = require "engine.Scene"
local Vector4 = require "engine.Vector4"
local UICanvas = require "engine.ui.UICanvas"
local UIBox = require "engine.ui.UIBox"
local UIText = require "engine.ui.UIText"

local grey = Vector4(0.6, 0.6, 0.65, 1)

---@class UIBoxLayout : Scene
local Example = Scene.extend(Scene)

function Example:new()
  Example.super.new(self, "ui/box-layout")
  self.backgroundColor = { 0.09, 0.09, 0.13, 1 }
end

function Example:load()
  self.first = UIBox("firstCard", {
    UIText("firstText", "A block child fills the parent width. Padding 16 all round.", { color = grey }),
  }, {
    background = Vector4(0.16, 0.16, 0.22, 1),
    padding = Vector4(16, 16, 16, 16),
  }, { debugPadding = true })

  self.second = UIBox("secondCard", {
    UIText("secondText", "Margin Vector4(24, 0, 24, 0): 24 above and below (block flow only uses vertical margins). Height is fixed at 72.",
      { color = grey }),
  }, {
    background = Vector4(0.16, 0.16, 0.22, 1),
    margin = Vector4(24, 0, 24, 0),
    padding = Vector4(12, 12, 12, 12),
    height = 72,
  }, { debugMargin = true, debugPadding = true })

  self.third = UIBox("thirdCard", {
    UIText("thirdText", "Width \"60%\" of the parent, border 2 px with a borderColor. debugBox shows the content box.",
      { color = grey }),
  }, {
    width = "60%",
    border = Vector4(2, 2, 2, 2),
    borderColor = Vector4(1, 1, 0, 1),
    padding = Vector4(12, 12, 12, 12),
  }, { debugBox = true })

  self.panel = UIBox("panel", {
    UIText("title", "UIBox layout", { font = "header", color = Vector4(1, 1, 0, 1) }),
    self.first,
    self.second,
    self.third,
  }, {
    gap = 12,
  })

  -- The canvas is the size of the window; its padding insets every child.
  self:addGameObject(UICanvas("layoutUI", { self.panel }, { padding = Vector4(48, 48, 48, 48) }))
end

function Example.check(scene, ctx)
  if ctx.done then
    local panel = scene.panel:getPos()
    assert(panel.x == 48 and panel.y == 48, string.format("panel at canvas padding, got %.0f,%.0f", panel.x, panel.y))
    assert(scene.panel.width == 1280 - 96, "panel fills the canvas minus padding")
    -- Block flow: each child starts after the previous one's height, the gap and both margins.
    local a, b = scene.first, scene.second
    local expected = a:getPos().y + a.height + 12 + b.styles.margin.x
    assert(math.abs(b:getPos().y - expected) < 0.01, string.format("second card y %.1f, expected %.1f", b:getPos().y, expected))
    assert(b.height == 72 + 24, "fixed height plus vertical padding")
    assert(math.abs(scene.third.width - scene.panel.width * 0.6) < 0.01, "percentage width")
  end
end

return Example
