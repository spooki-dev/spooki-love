-- title: Saving and loading
-- description: saveManager writes one table to the save directory and reads it back; delete clears the slot and nothing ever throws.
-- order: 2
-- tags: saveManager, save, load, delete
local Scene = require "engine.Scene"
local GameObject = require "engine.GameObject"
local Vector2 = require "engine.Vector2"
local Vector4 = require "engine.Vector4"
local cacheManager = require "engine.cacheManager"
local saveManager = require "engine.saveManager"

---@class SaveAndLoad : Scene
local Example = Scene.extend(Scene)

function Example:new()
  Example.super.new(self, "state-and-saves/save-and-load")
  self.backgroundColor = { 0.09, 0.09, 0.13, 1 }
  -- One file per game; version is stamped into every save.
  saveManager.configure({ filename = "examples-save.lua", version = 1 })
  self.level = 1
  self.status = "Nothing saved yet"
  self.loaded = nil
end

function Example:load()
  self.player = self:addGameObject(GameObject("player", Vector2(200, 400), 40, 40))
  self.player.fillColor = Vector4(1, 1, 0, 1)
end

function Example:snapshotData()
  local pos = self.player:getPos()
  return { level = self.level, x = pos.x, y = pos.y }
end

function Example:onActionPressed(name)
  if name == "action" then
    local ok, err = saveManager.save(self:snapshotData())
    self.status = ok and ("Saved level " .. self.level .. " to " .. tostring(saveManager.getPath())) or ("Save failed: " .. err)
  elseif name == "secondary" then
    self.loaded = saveManager.load() -- nil when absent, corrupt or a different version
    if self.loaded then
      self.level = self.loaded.level
      self.player:setPos(Vector2(self.loaded.x, self.loaded.y))
      self.status = "Loaded level " .. self.loaded.level
    else
      self.status = "Nothing to load"
    end
  elseif name == "pause" then
    saveManager.delete()
    self.status = "Save deleted"
  end
end

function Example:update(dt)
  -- The world keeps changing so a load visibly rewinds it.
  self.level = self.level + dt * 0.5
  local pos = self.player:getPos()
  pos.x = pos.x + 60 * dt
  self.player:setPos(pos)
end

-- Game:quit calls this on the current scene: the natural place to autosave.
function Example:onQuit()
  saveManager.save(self:snapshotData())
end

function Example:draw()
  love.graphics.setFont(cacheManager.getFont("body"))
  love.graphics.setColor(0.78, 0.72, 0.75, 1)
  love.graphics.print("Space / A: save.  Shift / X: load.  P: delete.  (The scene also autosaves in onQuit.)", 48, 48)
  love.graphics.print(string.format("level %.2f   player x %.0f   save exists: %s", self.level, self.player:getPos().x,
    tostring(saveManager.exists())), 48, 96)
  love.graphics.setColor(1, 1, 0, 1)
  love.graphics.printf(self.status, 48, 140, 1180, "left")
  love.graphics.setColor(1, 1, 1, 1)
end

Example.script = {
  { at = 10, tap = "pause" },     -- start from a clean slot
  { at = 30, tap = "action" },    -- save at level ~1.25, x ~ 229
  { at = 60, tap = "secondary" }, -- load: rewinds
  { at = 100, tap = "pause" },
}

function Example.check(scene, ctx)
  if ctx.frame == 20 then
    assert(not saveManager.exists(), "slot empty after delete")
  elseif ctx.frame == 31 then
    assert(saveManager.exists(), "file written")
  elseif ctx.frame == 60 then
    assert(scene.loaded and scene.loaded.version == 1, "loaded with the version stamp")
    assert(math.abs(scene.loaded.level - (1 + 29 * (1 / 60) * 0.5)) < 1e-6, "saved level restored")
    -- The load ran in this frame's action event, then update advanced one frame.
    assert(math.abs(scene.level - (scene.loaded.level + (1 / 60) * 0.5)) < 1e-6, "world rewound to the save")
    assert(math.abs(scene.player:getPos().x - (scene.loaded.x + 1)) < 1e-6, "player rewound")
  elseif ctx.done then
    assert(not saveManager.exists() and saveManager.load() == nil, "deleted; load returns nil without throwing")
  end
end

return Example
