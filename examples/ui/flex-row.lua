-- title: Flex row
-- description: display = "flex" with flexDirection = "row" lays children out horizontally, with gap, percentage widths, justifyContent and alignItems.
-- order: 2
-- tags: UIBox, flex, gap, justifyContent
local Scene = require "engine.Scene"
local Vector4 = require "engine.Vector4"
local UICanvas = require "engine.ui.UICanvas"
local UIBox = require "engine.ui.UIBox"
local UIText = require "engine.ui.UIText"

local grey = Vector4(0.6, 0.6, 0.65, 1)

local function cell(name, label, styles)
  styles = styles or {}
  styles.background = styles.background or Vector4(0.16, 0.16, 0.22, 1)
  styles.padding = styles.padding or Vector4(12, 12, 12, 12)
  return UIBox(name, { UIText(name .. "Text", label, { color = grey, textAlign = "center" }) }, styles)
end

---@class UIFlexRow : Scene
local Example = Scene.extend(Scene)

function Example:new()
  Example.super.new(self, "ui/flex-row")
  self.backgroundColor = { 0.09, 0.09, 0.13, 1 }
end

function Example:load()
  -- Percentage widths share the row minus the gaps.
  self.percentRow = UIBox("percentRow", {
    cell("p25", "25%", { width = "25%" }),
    cell("p50", "50%", { width = "50%" }),
    cell("p25b", "25%", { width = "25%" }),
  }, { display = "flex", flexDirection = "row", gap = 16 })

  -- Without widths the children split the row evenly.
  self.evenRow = UIBox("evenRow", {
    cell("e1", "even"), cell("e2", "even"), cell("e3", "even"), cell("e4", "even"),
  }, { display = "flex", flexDirection = "row", gap = 16 })

  -- Fixed widths centred as a group.
  self.centredRow = UIBox("centredRow", {
    cell("c1", "200 px", { width = 200 }),
    cell("c2", "200 px", { width = 200 }),
  }, { display = "flex", flexDirection = "row", gap = 16, justifyContent = "center" })

  -- alignItems centres children of different heights in a fixed-height row.
  self.alignedRow = UIBox("alignedRow", {
    cell("a1", "short", { width = 240, height = 24 }),
    cell("a2", "tall", { width = 240, height = 72 }),
    cell("a3", "short", { width = 240, height = 24 }),
  }, { display = "flex", flexDirection = "row", gap = 16, height = 96, alignItems = "center" })

  self:addGameObject(UICanvas("flexUI", {
    UIBox("flexPanel", {
      UIText("flexTitle", "Flex rows", { font = "header", color = Vector4(1, 1, 0, 1) }),
      UIText("l1", "width = \"25%\" / \"50%\" / \"25%\", gap 16", { color = grey }),
      self.percentRow,
      UIText("l2", "no widths: even split", { color = grey }),
      self.evenRow,
      UIText("l3", "fixed widths, justifyContent = \"center\"", { color = grey }),
      self.centredRow,
      UIText("l4", "height 96, alignItems = \"center\"", { color = grey }),
      self.alignedRow,
    }, { gap = 10 }),
  }, { padding = Vector4(48, 48, 48, 48) }))
end

function Example.check(scene, ctx)
  if ctx.done then
    local row = scene.percentRow
    local a, b, c = row.children[1], row.children[2], row.children[3]
    assert(math.abs(a.width + b.width + c.width + 2 * 16 - row.width) < 0.01, "percentages plus gaps fill the row")
    assert(math.abs(b.width - a.width * 2) < 0.01, "50% is twice 25%")
    assert(math.abs(b:getPos().x - (a:getPos().x + a.width + 16)) < 0.01, "gap between cells")
    local even = scene.evenRow.children
    assert(math.abs(even[1].width - even[4].width) < 0.01, "even split")
    local c1 = scene.centredRow.children[1]
    local rowPos = scene.centredRow:getPos()
    -- The engine centres the children's total width; the gap is then added between them.
    assert(math.abs((c1:getPos().x - rowPos.x) - (scene.centredRow.width - 200 * 2) / 2) < 0.01, "group centred")
    local c2 = scene.centredRow.children[2]
    assert(math.abs(c2:getPos().x - (c1:getPos().x + 200 + 16)) < 0.01, "gap between the centred cells")
    local tall, short = scene.alignedRow.children[2], scene.alignedRow.children[1]
    assert(short:getPos().y > tall:getPos().y, "short cell centred below the tall cell's top")
  end
end

return Example
