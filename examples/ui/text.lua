-- title: Text styles
-- description: UIText with the four contract fonts, colours, alignment and automatic wrapping that sets its own height.
-- order: 3
-- tags: UIText, font, textAlign, getWrap
local Scene = require "engine.Scene"
local Vector4 = require "engine.Vector4"
local UICanvas = require "engine.ui.UICanvas"
local UIBox = require "engine.ui.UIBox"
local UIText = require "engine.ui.UIText"
local cacheManager = require "engine.cacheManager"

local PARAGRAPH = "UIText measures itself: the height is the number of wrapped lines times the font height, " ..
    "so boxes below it move down as the text grows. Wrapping happens at the parent width, " ..
    "or at a fixed or percentage width when one is given."

---@class UITextExample : Scene
local Example = Scene.extend(Scene)

function Example:new()
  Example.super.new(self, "ui/text")
  self.backgroundColor = { 0.09, 0.09, 0.13, 1 }
end

function Example:load()
  self.paragraph = UIText("paragraph", PARAGRAPH, { font = "body", color = Vector4(0.78, 0.72, 0.75, 1), width = "60%" })
  self:addGameObject(UICanvas("textUI", {
    UIBox("textPanel", {
      UIText("t1", "header 24px", { font = "header", color = Vector4(1, 1, 0, 1) }),
      UIText("t2", "subheader 20px", { font = "subheader", color = Vector4(0.9, 0.3, 0.3, 1) }),
      UIText("t3", "body 16px", { font = "body" }),
      UIText("t4", "small 12px", { font = "small", color = Vector4(0.6, 0.6, 0.65, 1) }),
      UIBox("alignRow", {
        UIText("left", "left", { textAlign = "left", color = Vector4(0.5, 0.7, 1, 1) }),
        UIText("centre", "center", { textAlign = "center", color = Vector4(0.5, 0.7, 1, 1) }),
        UIText("right", "right", { textAlign = "right", color = Vector4(0.5, 0.7, 1, 1) }),
      }, { display = "flex", flexDirection = "row", margin = Vector4(16, 0, 16, 0), background = Vector4(0.16, 0.16, 0.22, 1),
        padding = Vector4(8, 8, 8, 8) }),
      self.paragraph,
      UIBox("after", { UIText("afterText", "This box sits directly under the paragraph.", { color = Vector4(0.6, 0.6, 0.65, 1) }) },
        { background = Vector4(0.16, 0.16, 0.22, 1), padding = Vector4(8, 8, 8, 8), margin = Vector4(8, 0, 0, 0) }),
    }, { gap = 8 }),
  }, { padding = Vector4(48, 48, 48, 48) }))
end

function Example.check(scene, ctx)
  if ctx.done then
    local font = cacheManager.getFont("body")
    local _, lines = font:getWrap(PARAGRAPH, scene.paragraph.width)
    assert(#lines >= 3, "the paragraph wraps onto several lines")
    assert(scene.paragraph.height == #lines * font:getHeight(), "height follows the wrapped line count")
    local after = scene:getGameObject("after")
    assert(after:getPos().y >= scene.paragraph:getPos().y + scene.paragraph.height, "the next box is below the paragraph")
  end
end

return Example
