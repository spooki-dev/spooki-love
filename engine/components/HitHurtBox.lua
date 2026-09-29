--- HitHurtBox.lua
--
---@class HitHurtBoxFields
---@field setHurtbox fun(self: table, box: table)
---@field getHurtbox fun(self: table): table|nil
---@field setHitbox fun(self: table, box: table)
---@field getHitbox fun(self: table): table|nil
---@field intersectsWith fun(self: table, other: table): boolean
---@field drawHitHurtBoxDebug fun(self: table)
---@field checkCollisionsWith fun(self: table, classRef: table, objectsTable: table, callback: function)
-- Composable mixin for hitbox/hurtbox logic

local HitHurtBox = {}

function HitHurtBox:setHurtbox(box)
  self._hurtbox = box
end

function HitHurtBox:getHurtbox()
  if self._hurtbox then
    return {
      x = self._pos.x + (self._hurtbox.x or 0),
      y = self._pos.y + (self._hurtbox.y or 0),
      width = self._hurtbox.width,
      height = self._hurtbox.height
    }
  end
  return nil
end

function HitHurtBox:setHitbox(box)
  self._hitbox = box
end

function HitHurtBox:getHitbox()
  if self._hitbox then
    return {
      x = self._pos.x + (self._hitbox.x or 0),
      y = self._pos.y + (self._hitbox.y or 0),
      width = self._hitbox.width,
      height = self._hitbox.height
    }
  end
  return nil
end

function HitHurtBox:intersectsWith(other)
  local a = self.getHitbox and self:getHitbox() or nil
  local b = other.getHurtbox and other:getHurtbox() or nil
  if not a or not b then return false end
  return a.x < b.x + b.width and a.x + a.width > b.x and
      a.y < b.y + b.height and a.y + a.height > b.y
end

-- Debug draw for hit/hurt boxes
function HitHurtBox:drawHitHurtBoxDebug()
  if self.debugHitHurtBox then
    local hb = self.getHitbox and self:getHitbox() or nil
    local hur = self.getHurtbox and self:getHurtbox() or nil
    if hb then
      love.graphics.setColor(1, 0, 0, 0.4)
      love.graphics.rectangle("fill", hb.x, hb.y, hb.width, hb.height)
    end
    if hur then
      love.graphics.setColor(0, 0, 1, 0.4)
      love.graphics.rectangle("fill", hur.x, hur.y, hur.width, hur.height)
    end
    love.graphics.setColor(1, 1, 1, 1)
  end
end

-- Check for intersection with all objects of a given class in a table, and call a callback for each
function HitHurtBox:checkCollisionsWith(classRef, objectsTable, callback)
  -- If the table is a Scene, use its hitHurtBoxObjects table
  if type(objectsTable) == "table" and objectsTable.hitHurtBoxObjects then
    objectsTable = objectsTable.hitHurtBoxObjects
  end
  for _, obj in pairs(objectsTable) do
    if obj.is and obj:is(classRef) and obj.active and self.intersectsWith and self:intersectsWith(obj) then
      callback(obj)
    end
  end
end

return HitHurtBox
