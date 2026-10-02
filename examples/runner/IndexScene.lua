local Scene = require "engine.Scene"
local GameObject = require "engine.GameObject"
local Vector2 = require "engine.Vector2"
local cacheManager = require "engine.cacheManager"
local inputMap = require "engine.input.inputMap"

--- The desktop picker: every example grouped by category, in columns.
--- Arrow keys / d-pad move, Enter / A opens, Escape quits. The mouse hovers
--- and clicks through one full-screen hit object. Tooling, so it draws
--- itself directly rather than through the UI system.
---@class IndexScene : Scene
local IndexScene = Scene.extend(Scene)

local ROW = 18
local TOP = 88
local LEFT = 48
local COLUMN = 400

---@param categories table[] From catalogue.load()
---@param onOpen fun(id: string)
function IndexScene:new(categories, onOpen)
  IndexScene.super.new(self, "examples/index")
  self.backgroundColor = { 0.05, 0.05, 0.07, 1 }
  self.onOpen = onOpen
  self.rows = {}  -- { kind = "category"|"example", text, entry }
  self.items = {} -- row indices of examples, in order
  for _, cat in ipairs(categories) do
    self.rows[#self.rows + 1] = { kind = "category", text = cat.title:upper() }
    for _, entry in ipairs(cat.examples) do
      self.rows[#self.rows + 1] = { kind = "example", text = entry.title, entry = entry }
      self.items[#self.items + 1] = #self.rows
    end
  end
  self.selected = 1
  self.rowsPerColumn = math.floor((love.graphics.getHeight() - TOP - 32) / ROW)
end

function IndexScene:load()
  local w, h = love.graphics.getDimensions()
  local hit = GameObject("examples/index/hit", Vector2(0, 0), w, h)
  hit.layer = "ui"
  local scene = self
  function hit:onMouseOver(x, y)
    local item = scene:itemAt(x, y)
    if item then scene.selected = item end
  end

  function hit:onClick()
    local item = scene:itemAt(love.mouse.getPosition())
    if item then
      scene.selected = item
      scene:activate()
    end
  end

  self:addGameObject(hit)
end

--- Screen position of a row.
---@param rowIndex number
---@return number x, number y
function IndexScene:rowPosition(rowIndex)
  local column = math.floor((rowIndex - 1) / self.rowsPerColumn)
  local row = (rowIndex - 1) % self.rowsPerColumn
  return LEFT + column * COLUMN, TOP + row * ROW
end

--- Item index under a screen point, or nil.
---@return number|nil
function IndexScene:itemAt(x, y)
  for i, rowIndex in ipairs(self.items) do
    local rx, ry = self:rowPosition(rowIndex)
    if x >= rx and x < rx + COLUMN - 16 and y >= ry and y < ry + ROW then
      return i
    end
  end
  return nil
end

function IndexScene:activate()
  local row = self.rows[self.items[self.selected]]
  if row and row.entry then
    self.onOpen(row.entry.id)
  end
end

function IndexScene:update(dt)
  local count = #self.items
  if count == 0 then return end
  local step = 0
  if inputMap.pressed("ui_down") then step = 1 end
  if inputMap.pressed("ui_up") then step = -1 end
  if step ~= 0 then
    self.selected = ((self.selected - 1 + step) % count) + 1
  end
  -- Left/right jump to the same row in the neighbouring column.
  local jump = 0
  if inputMap.pressed("ui_right") then jump = 1 end
  if inputMap.pressed("ui_left") then jump = -1 end
  if jump ~= 0 then
    local rowIndex = self.items[self.selected]
    local target = rowIndex + jump * self.rowsPerColumn
    local best, bestDistance = nil, math.huge
    for i, candidate in ipairs(self.items) do
      local distance = math.abs(candidate - target)
      if distance < bestDistance then best, bestDistance = i, distance end
    end
    if best then self.selected = best end
  end
  if inputMap.pressed("ui_accept") then
    self:activate()
  end
end

function IndexScene:onActionPressed(name)
  if name == "ui_cancel" then
    love.event.quit()
  end
end

function IndexScene:draw()
  local header = cacheManager.getFont("header")
  local small = cacheManager.getFont("small")
  love.graphics.setFont(header)
  love.graphics.setColor(1, 1, 0, 1)
  love.graphics.print("spooki-love examples", LEFT, 32)
  love.graphics.setFont(small)
  love.graphics.setColor(0.78, 0.72, 0.75, 1)
  love.graphics.print("Arrows / d-pad: move    Enter / A: open    Esc: quit    (Esc inside an example returns here)",
    LEFT, 64)
  local selectedRow = self.items[self.selected]
  for i, row in ipairs(self.rows) do
    local x, y = self:rowPosition(i)
    if row.kind == "category" then
      love.graphics.setColor(1, 1, 0, 1)
      love.graphics.print(row.text, x, y + 3)
    else
      if i == selectedRow then
        love.graphics.setColor(1, 1, 0, 0.18)
        love.graphics.rectangle("fill", x - 6, y, COLUMN - 24, ROW)
        love.graphics.setColor(0.98, 0.98, 0.96, 1)
      else
        love.graphics.setColor(0.78, 0.72, 0.75, 1)
      end
      love.graphics.print(row.text, x, y + 3)
    end
  end
  local row = self.rows[selectedRow]
  if row and row.entry then
    love.graphics.setColor(0.6, 0.6, 0.65, 1)
    love.graphics.printf(row.entry.id .. "  -  " .. row.entry.description, LEFT, love.graphics.getHeight() - 28,
      love.graphics.getWidth() - LEFT * 2, "left")
  end
  love.graphics.setColor(1, 1, 1, 1)
end

return IndexScene
