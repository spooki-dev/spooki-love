--- Single-slot save file manager.
---
--- Stores a plain-data table in LÖVE's save directory as Lua source. Every operation is
--- wrapped so a missing or read-only store (for example a browser without persistent
--- storage) degrades to "nothing saved" without raising. On the love.js web build the
--- save directory is backed by IndexedDB and flushed by the page template.
---
--- The engine never decides *what* to save: the game hands `save` a table and gets the
--- same table back from `load`. `Game:quit` calls the current scene's optional `onQuit`
--- hook, which is the natural place to autosave.
---
--- Usage:
--- ```lua
--- local saveManager = require "engine.saveManager"
--- saveManager.configure({ filename = "save.lua", version = 1 })
--- saveManager.save({ level = 3 })
--- local data = saveManager.load()   -- nil when absent, corrupt or incompatible
--- ```

local serializer = require "engine.utils.table_serialize"

local saveManager = {}

---@class SaveManagerConfig
---@field filename string File name inside the save directory (default "save.lua").
---@field version number Schema version written into every save (default 1).
---@field migrate (fun(data: table, fromVersion: number): table|nil)|nil Converts an older save to the current schema; return nil to reject it.

local config = {
  filename = "save.lua",
  version = 1,
  migrate = nil,
}

local available = nil -- cached result of isAvailable()

local function warn(message)
  print("[saveManager] " .. message)
end

--- Overrides the defaults. Call once before saving or loading.
--- @param opts SaveManagerConfig|table Any subset of filename, version, migrate.
function saveManager.configure(opts)
  if type(opts) ~= "table" then return end
  if opts.filename ~= nil then
    assert(type(opts.filename) == "string" and opts.filename ~= "", "saveManager: filename must be a non-empty string")
    config.filename = opts.filename
  end
  if opts.version ~= nil then
    assert(type(opts.version) == "number", "saveManager: version must be a number")
    config.version = opts.version
  end
  if opts.migrate ~= nil then
    assert(type(opts.migrate) == "function", "saveManager: migrate must be a function")
    config.migrate = opts.migrate
  end
end

--- Whether a writable save directory could be resolved. Cached after the first call.
--- @return boolean
function saveManager.isAvailable()
  if available == nil then
    local ok, dir = pcall(function()
      return love.filesystem.getSaveDirectory()
    end)
    available = ok and type(dir) == "string" and dir ~= ""
    if not available then
      warn("save directory unavailable; saving disabled")
    end
  end
  return available
end

--- Absolute path of the save file, for logging and debugging.
--- @return string|nil The path, or nil when the store is unavailable.
function saveManager.getPath()
  if not saveManager.isAvailable() then return nil end
  local ok, dir = pcall(love.filesystem.getSaveDirectory)
  if not ok then return nil end
  return dir .. "/" .. config.filename
end

--- Whether a save file exists. Does not validate its contents.
--- @return boolean
function saveManager.exists()
  if not saveManager.isAvailable() then return false end
  local ok, info = pcall(love.filesystem.getInfo, config.filename)
  return ok and type(info) == "table" and info.type == "file"
end

--- Writes `data` to the save file, stamping it with the configured schema version.
--- @param data table Plain data only: numbers, strings, booleans and nested tables.
--- @return boolean ok True when the file was written.
--- @return string|nil err Why it was not written.
function saveManager.save(data)
  if type(data) ~= "table" then
    return false, "save data must be a table"
  end
  if not saveManager.isAvailable() then
    return false, "save directory unavailable"
  end

  data.version = config.version

  local serialized, serializeErr = pcall(serializer.serialize, data)
  if not serialized then
    warn("could not serialise save data: " .. tostring(serializeErr))
    return false, tostring(serializeErr)
  end
  -- pcall returned (true, string); rebind so the name reads correctly below.
  local source = serializeErr

  local ok, success, writeErr = pcall(love.filesystem.write, config.filename, source)
  if not ok then
    warn("write failed: " .. tostring(success))
    return false, tostring(success)
  end
  if not success then
    warn("write failed: " .. tostring(writeErr))
    return false, tostring(writeErr)
  end
  return true
end

--- Reads and validates the save file.
--- A corrupt or unreadable file is left in place and reported as nil so the player can
--- still start a new game; `delete()` or the next `save()` replaces it.
--- @return table|nil The saved data, or nil when absent, unreadable, corrupt or incompatible.
function saveManager.load()
  if not saveManager.exists() then return nil end

  local ok, contents = pcall(love.filesystem.read, config.filename)
  if not ok or type(contents) ~= "string" then
    warn("read failed: " .. tostring(contents))
    return nil
  end

  local data, err = serializer.deserialize(contents)
  if not data then
    warn("save file is corrupt: " .. tostring(err))
    return nil
  end

  if data.version ~= config.version then
    if config.migrate then
      local migrated
      ok, migrated = pcall(config.migrate, data, data.version)
      if ok and type(migrated) == "table" then
        migrated.version = config.version
        return migrated
      end
      warn("migration from version " .. tostring(data.version) .. " failed")
      return nil
    end
    warn("save version " .. tostring(data.version) .. " does not match " .. tostring(config.version))
    return nil
  end

  return data
end

--- Removes the save file.
--- @return boolean True when the file is gone (including when it did not exist).
function saveManager.delete()
  if not saveManager.isAvailable() then return false end
  if not saveManager.exists() then return true end
  local ok, removed = pcall(love.filesystem.remove, config.filename)
  return ok and removed == true
end

return saveManager
