-- title: Save versioning
-- description: A migrate function upgrades older saves to the current schema; incompatible saves without one load as nil.
-- order: 3
-- tags: saveManager, version, migrate
local Scene = require "engine.Scene"
local cacheManager = require "engine.cacheManager"
local saveManager = require "engine.saveManager"

local FILE = "examples-migration.lua"
local OLD_SAVE = '{hp = 50, name = "old ghost", version = 1}'

---@class SaveMigration : Scene
local Example = Scene.extend(Scene)

function Example:new()
  Example.super.new(self, "state-and-saves/save-migration")
  self.backgroundColor = { 0.09, 0.09, 0.13, 1 }
  self.log = {}
  self.loaded = nil
end

function Example:record(text)
  self.log[#self.log + 1] = text
end

function Example:writeOldSave()
  love.filesystem.write(FILE, OLD_SAVE)
  self:record("Wrote a version 1 file: " .. OLD_SAVE)
end

function Example:loadWithoutMigration()
  saveManager.configure({ filename = FILE, version = 2, migrate = nil })
  self.loaded = saveManager.load()
  self:record("version 2, no migrate: load() -> " .. tostring(self.loaded))
end

function Example:loadWithMigration()
  saveManager.configure({
    filename = FILE,
    version = 2,
    -- Called with the old table and its version; return the upgraded table (or nil to reject).
    migrate = function(data, fromVersion)
      if fromVersion == 1 then
        return { health = data.hp, maxHealth = 100, name = data.name }
      end
      return nil
    end,
  })
  self.loaded = saveManager.load()
  if self.loaded then
    self:record(string.format("version 2 with migrate: health %d/%d, name %q, version %d", self.loaded.health,
      self.loaded.maxHealth, self.loaded.name, self.loaded.version))
  else
    self:record("migration failed")
  end
end

function Example:onActionPressed(name)
  if name == "action" then
    self.log = {}
    self:writeOldSave()
    self:loadWithoutMigration()
    self:loadWithMigration()
    love.filesystem.remove(FILE)
  end
end

function Example:draw()
  love.graphics.setFont(cacheManager.getFont("body"))
  love.graphics.setColor(0.78, 0.72, 0.75, 1)
  love.graphics.print("Space / A: write a v1 save, then load it as v2 without and with a migrate function.", 48, 48)
  for i, line in ipairs(self.log) do
    love.graphics.setColor(i == #self.log and 1 or 0.78, i == #self.log and 1 or 0.72, i == #self.log and 0 or 0.75, 1)
    love.graphics.printf(line, 48, 120 + (i - 1) * 40, 1180, "left")
  end
  love.graphics.setColor(1, 1, 1, 1)
end

Example.script = {
  { at = 30, tap = "action" },
}

function Example.check(scene, ctx)
  if ctx.done then
    assert(#scene.log == 3, "three steps logged")
    assert(scene.log[2]:find("-> nil", 1, true), "no migrate: nil")
    local data = scene.loaded
    assert(data and data.health == 50 and data.maxHealth == 100 and data.name == "old ghost", "migrated fields")
    assert(data.version == 2 and data.hp == nil, "stamped with the new version, old field gone")
    assert(not love.filesystem.getInfo(FILE), "temporary file removed")
  end
end

return Example
