--
-- classic
--
-- Copyright (c) 2014, rxi
--
-- This module is free software; you can redistribute it and/or modify it under
-- the terms of the MIT license. See LICENSE for details.
--


---@class Object
---@field __index table
---@field super Object|nil
local Object = {}
Object.__index = Object



---Constructor for Object
function Object:new()
end

---Creates a subclass of this Object
---@return Object
function Object:extend()
  local cls = {}
  for k, v in pairs(self) do
    if k:find("__") == 1 then
      cls[k] = v
    end
  end
  cls.__index = cls
  ---@type Object
  cls.super = self
  setmetatable(cls, self)
  return cls
end

---Implements methods from other classes
---@vararg table
function Object:implement(...)
  for _, cls in pairs({ ... }) do
    for k, v in pairs(cls) do
      if self[k] == nil and type(v) == "function" then
        self[k] = v
      end
    end
  end
end

---Checks if this object is an instance of T
---@param T table
---@return boolean
function Object:is(T)
  local mt = getmetatable(self)
  while mt do
    if mt == T then
      return true
    end
    mt = getmetatable(mt)
  end
  return false
end

---String representation of Object
---@return string
function Object:__tostring()
  return "Object"
end

---Creates a new instance of Object
function Object:__call(...)
  local obj = setmetatable({}, self)
  obj:new(...)
  return obj
end

return Object
