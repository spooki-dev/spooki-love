local Object = require "engine.lib.classic"
local AnimationManager = require "engine.AnimationManager"
local intersection = require "engine.utils.intersection"
local Vector2 = require "engine.Vector2"
local renderer = require "engine.renderer"


---@class GameObject : Object
---@field name string The name of the game object
---@field _pos Vector2 The position of the game object (private, use getPos/setPos)
---@field width number The width of the game object
---@field height number The height of the game object
---@field animation AnimationManager The animation manager for the game object
---@field active boolean Whether the game object is active
---@field scaleX number The scale factor in the x direction
---@field scaleY number The scale factor in the y direction
---@field flipX boolean Whether the game object is flipped horizontally
---@field rotationOrigin Vector2|nil Origin for rotation (default: center)
---@field positionOrigin Vector2|nil Origin for translation/positioning (default: nil)
---@field spritesheet love.Image|nil The spritesheet used for rendering
---@field quad love.Quad|nil The quad used for rendering the game object
---@field image string|nil The key of image used for rendering (if not using spritesheet)
---@field text string|nil The text to display (if applicable)
---@field textColor Vector4|nil The color of the text (if applicable)
---@field textAlign string|nil The alignment of the text: "left", "center", "right"
---@field border Vector4|nil The border thickness (top, right, bottom, left)
---@field borderColor Vector4|nil The border color (r, g, b, a)
---@field font love.Font|nil The font used for rendering text (if applicable)
---@field fillColor Vector4|nil The fill color for shapes (if applicable)
---@field opacity number|nil The opacity of the game object (0 to 1)
---@field rigidBody boolean Whether the object is a rigid body
---@field shape table Shape definition for collision
---@field debugShape boolean Show collision shape overlay
---@field scene Scene|nil Reference to the scene
---@field ysortOffset number change where the ysorting happens
---@field loaded boolean Whether the game object has been loaded
---@field isMouseOver boolean Whether or not the mouse is over the gameObject (always false if there are no mouse event handlers)
---@field onKeyPressed function Key pressed event handler (raw keys; prefer onActionPressed)
---@field onActionPressed function Input action pressed handler, receives the action name
---@field onActionReleased function Input action released handler, receives the action name
---@field onMouseOver function Mouse over event handler
---@field onMouseEntered function Mouse entered event handler
---@field onMouseExit function Mouse exit event handler
---@field onMouseDown function Mouse down event handler
---@field onClick function Mouse click event
---@field renderLog string|nil Optional log message for rendering debug
---@field debugPadding boolean Whether to draw debug padding boxes
---@field debugMargin boolean Whether to draw debug margin boxes
---@field debugGap boolean Whether to draw debug gap lines
---@field debugBox boolean Whether to draw debug box around the GameObject
local GameObject = Object:extend()


---Create a new GameObject
---@param name string The name of the game object
---@param pos Vector2|nil The position of the game object
---@param width number|nil The width of the game object
---@param height number|nil The height of the game object
---@return GameObject
function GameObject:new(name, pos, width, height)
  ---@type string
  self.name = name
  ---@type Vector2
  self._pos = pos or Vector2(0, 0)
  ---@type number
  self.width = width or 0
  ---@type number
  self.height = height or 0
  ---@type AnimationManager
  self.animation = AnimationManager()
  ---@type boolean
  self.active = true
  ---@type number
  self.scaleX = 1
  ---@type number
  self.scaleY = 1
  ---@type boolean
  self.flipX = false
  ---@type boolean
  self.flipY = false
  ---@type Vector2|nil
  self.rotationOrigin = nil           -- For rotation only
  ---@type Vector2
  self.positionOrigin = Vector2(0, 0) -- For translation/positioning only
  ---@type GameObject[]
  self.gameObjects = {}
  ---@type love.Image|nil
  self.spritesheet = nil
  ---@type love.Quad|nil
  self.quad = nil
  ---@type string|nil
  self.image = nil
  ---@type Vector4|nil
  self.fillColor = nil -- For shapes, if needed
  ---@type number|nil
  self.opacity = 1
  ---@type boolean
  self.rigidBody = false
  ---@type table
  self.shape = {
    x = 0,
    y = 0,
    width = self.width,
    height = self.height
  }
  ---@type boolean
  self.debugShape = false -- Show collision shape overlay
  ---@type number
  self.ysortOffset = 0
  ---@type boolean
  self.debugYSortOffset = false -- Show ySortOffset debug line
  ---@type boolean
  self.loaded = false           -- Whether the game object has been loaded
  ---@type number -- The amount to repeat the image horizontally
  self.repeatX = 0
  ---@type number -- The amount to repeat the image vertically
  self.repeatY = 0
  ---@type boolean -- True if the mouse is over the object
  self.isMouseOver = false

  return self
end

function GameObject:start()
  -- Custom game object start logic (override in subclass if needed)
end

--- Get the width of the game object
--- @return number
function GameObject:getWidth()
  return self.width
end

--- Set the width of the game object
--- @param newWidth number
function GameObject:setWidth(newWidth)
  self.width = newWidth
end

function GameObject:getHeight()
  return self.height
end

function GameObject:setHeight(newHeight)
  if newHeight == nil then
    return
  end
  self.height = newHeight
end

---Get the position of the game object
---@return Vector2
function GameObject:getPos()
  return self._pos
end

---Sets the position of the game object
---@param newPos Vector2 The new position to set
---@return boolean True if the position was set successfully, false if it collides with another rigid body
function GameObject:setPos(newPos)
  local newX, newY = newPos.x, newPos.y
  if self.rigidBody then
    local rigidBodies = (self.scene and self.scene.rigidBodies) or nil
    local checkList = rigidBodies and (function()
      local t = {}
      for obj, _ in pairs(rigidBodies) do table.insert(t, obj) end
      return t
    end)() or (self.scene and self.scene.gameObjects) or {}
    if not self:canMoveTo(newX, newY, checkList) then
      return false
    end
  end
  self._pos = Vector2(newX, newY)
  return true
end

---Set the shape of the game object
---@param shape table
function GameObject:setShape(shape)
  self.shape = shape
end

---Returns the current shape (rectangle) of the GameObject used for checking collisions and ridgid bodies,
--- not necessarily the rendered shape.
---@return table
function GameObject:getShape()
  -- Return the shape offset by the current position
  return {
    x = self._pos.x + (self.shape.x or 0),
    y = self._pos.y + (self.shape.y or 0),
    width = self.shape.width,
    height = self.shape.height
  }
end

---Returns the current rendered rect of the GameObject x, y, width, height, adusted for transforms
---@return table
function GameObject:getRect()
  local pos = self:getPos()
  return {
    x = pos.x - (self.width * (self.positionOrigin.x or 0)),
    y = pos.y - (self.height * (self.positionOrigin.y or 0)),
    width = self.width,
    height = self.height,
  }
end

---Static method to check if two rectangles intersect
---@param a table
---@param b table
---@return boolean
function GameObject.rectsIntersect(a, b)
  return a.x < b.x + b.width and
      a.x + a.width > b.x and
      a.y < b.y + b.height and
      a.y + a.height > b.y
end

---Checks if this object can move to (newX, newY) without colliding with other rigid bodies
---@param newX number
---@param newY number
---@param allGameObjects GameObject[]
---@return boolean
function GameObject:canMoveTo(newX, newY, allGameObjects)
  if not self.rigidBody then return true end
  -- Use the object's shape definition, but offset by the new position
  local futureShape = {
    x = newX + (self.shape.x or 0),
    y = newY + (self.shape.y or 0),
    width = self.shape.width,
    height = self.shape.height
  }
  for _, obj in ipairs(allGameObjects) do
    if obj ~= self and obj.rigidBody then
      local otherShape = obj:getShape()
      if GameObject.rectsIntersect(futureShape, otherShape) then
        return false
      end
    end
  end
  return true
end

---Main lifecycle method: load
function GameObject:handleLoad()
  if not self.loaded then
    self:load()
    self.loaded = true
  end
  for i, child in ipairs(self.gameObjects) do
    child:handleLoad()
  end
end

---Main lifecycle method: update
---@param dt number
function GameObject:handleUpdate(dt)
  self:update(dt)
end

---Main lifecycle method: draw
function GameObject:handleDraw()
  if self.image or (self.spritesheet and self.quad) or self.fillColor or (self.text and self.textColor) or self.border then
    renderer.draw(self)
  end

  if self.draw then
    self:draw()
  end
  if self.debugHitHurtBox then
    -- Draw hit/hurt box debug overlay if enabled
    self:drawHitHurtBoxDebug()
  end
  self:drawShapeDebug()
  self:drawYSortOffsetDebug()
end

---Override in subclasses if needed
function GameObject:load()
end

---Override in subclasses
---@param dt number
function GameObject:update(dt)
end

---Override in subclasses
function GameObject:draw()
end

---Add a child game object
---@generic T: GameObject
---@param gameObject T
---@return T
function GameObject:addGameObject(gameObject)
  if not gameObject then
    error("Cannot add nil game object.")
  end
  if not gameObject.name then
    error("GameObject must have a name.")
  end
  if not self.scene then
    error("GameObject must be added to a scene before adding child game objects.")
  end
  table.insert(self.gameObjects, gameObject)
  gameObject.parent = self
  self.scene:addGameObject(gameObject)
  return gameObject
end

---Remove a child game object
---@param gameObject GameObject
function GameObject:removeGameObject(gameObject)
  for i, obj in ipairs(self.gameObjects) do
    if obj == gameObject then
      table.remove(self.gameObjects, i)
      return
    end
  end
end

---Get a child game object by name
---@param name string
---@return GameObject|nil
function GameObject:getGameObject(name)
  for _, obj in ipairs(self.gameObjects) do
    if obj.name == name then
      return obj
    end
  end
  return nil
end

---Set whether this object is a rigid body
---@param isRigid boolean
function GameObject:setRigidBody(isRigid)
  self.rigidBody = isRigid and true or false
  if self.scene then
    self.scene.rigidBodies = self.scene.rigidBodies or {}
    if isRigid then
      -- Add to rigidBodies table if not already present
      if not self.scene.rigidBodies[self] then
        self.scene.rigidBodies[self] = true
      end
    else
      -- Remove from rigidBodies table
      self.scene.rigidBodies[self] = nil
    end
  end
end

---Draw the debug shape overlay
function GameObject:drawShapeDebug()
  if self.debugShape then
    local shape = self:getShape()
    love.graphics.setColor(0, 1, 0, 0.5)
    love.graphics.rectangle("fill", shape.x, shape.y, shape.width, shape.height)
    love.graphics.setColor(1, 1, 1, 1)
  end
end

---Draw a debug line for ySortOffset
function GameObject:drawYSortOffsetDebug()
  if self.debugYSortOffset then
    local pos = self:getPos()
    local y = pos.y + (self.ysortOffset or 0)
    love.graphics.setColor(1, 0, 0, 0.7)
    love.graphics.line(pos.x, y, pos.x + (self.width or 16), y)
    love.graphics.setColor(1, 1, 1, 1)
  end
end

---Set whether the object is active
---@param active boolean
---@param toggleChildren boolean If true, toggle all child game objects as well
function GameObject:toggleActive(active, toggleChildren)
  self.active = active

  --- if active is false Iterate through all child game objects and set their active state
  if not active or toggleChildren then
    for _, child in ipairs(self.gameObjects) do
      if child.toggleActive then
        child:toggleActive(active, toggleChildren)
      end
    end
  end
end

---Destroy this GameObject, removing it from parent GameObject, Scene, and rigidBodies
function GameObject:destroy()
  -- Remove from parent GameObject if any
  if self.parent then
    self.parent:removeGameObject(self)
    self.parent = nil
  end
  -- Remove from scene tables if present
  if self.scene then
    if self.scene.removeGameObject then
      self.scene:removeGameObject(self)
    end
    self.scene = nil
  end

  ---- I think this can be removed because it is handled in the scene.removeGameObject
  -- Remove from rigidBodies if present
  -- if self.rigidBody and self.scene and self.scene.rigidBodies then
  --   self.scene.rigidBodies[self] = nil
  -- end

  -- Destroy all children recursively. Each child's destroy() removes it from
  -- this list, so iterate a detached copy or every second child survives.
  local children = self.gameObjects
  self.gameObjects = {}
  for _, child in ipairs(children) do
    if child.destroy then child:destroy() end
  end
end

---Destroy a child GameObject by reference or name
---@param gameObjectOrName GameObject|string
function GameObject:destroyGameObject(gameObjectOrName)
  local obj
  if type(gameObjectOrName) == "string" then
    obj = self:getGameObject(gameObjectOrName)
  else
    obj = gameObjectOrName
  end
  if obj ~= nil and type(obj) ~= "string" and obj.destroy then
    obj:destroy()
  end
end

function GameObject:setFlipX(flip)
  self.flipX = flip
end

function GameObject:handleMouseOver(x, y)
  if not self.active then
    return
  end
  if not self.onMouseOver and not self.onMouseEntered and not self.onMouseExit then
    error("Tried to handle mouse over on game object with no event: " .. self.name)
  end

  local mouseRect = {
    x = x,
    y = y,
    width = 1,
    height = 1,
  }
  local intersects = intersection.rectangleIntersection(mouseRect, self:getRect())
  if intersects and self.onMouseOver then
    self:onMouseOver(x, y)
  end
  if intersects and not self.isMouseOver then
    self.isMouseOver = true
    if self.onMouseEntered then
      self:onMouseEntered()
    end
  end
  if not intersects and self.isMouseOver then
    self.isMouseOver = false
    if self.onMouseExit then
      self:onMouseExit()
    end
  end
end

function GameObject:handleClick(x, y)
  if not self.active then return end
  local mouseRect = {
    x = x,
    y = y,
    width = 1,
    height = 1,
  }
  local intersects = intersection.rectangleIntersection(mouseRect, self:getRect())

  if intersects and self.onClick then
    self:onClick()
  end
end

function GameObject:handleMouseDown(x, y, button, istouch, presses)
  if not self.active then return end
  local mouseRect = { x = x, y = y, width = 1, height = 1 }
  if intersection.rectangleIntersection(mouseRect, self:getRect()) then
    if self.onMouseDown then
      self:onMouseDown(x, y, button, istouch, presses)
    end
  end
end

return GameObject
