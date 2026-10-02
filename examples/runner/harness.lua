--- Builds the Game that hosts examples (interactive runs, the picker and the
--- test suite) and switches between examples from the picker.
---
--- Engine modules are required lazily inside functions: the test runner purges
--- `package.loaded` between examples, and this module must always talk to the
--- freshly loaded engine, never a stale copy.
local M = {}

M.game = nil
M.INDEX_SCENE = "examples/index"

local catalogueCache = nil

local function isWeb()
  return love.system.getOS() == "Web"
end

--- Loads (once) and returns the catalogue.
---@return { categories: table[], flat: ExampleEntry[], byId: table<string, ExampleEntry> }
function M.catalogue()
  if not catalogueCache then
    local categories, flat, byId = require("examples.runner.catalogue").load()
    catalogueCache = { categories = categories, flat = flat, byId = byId }
  end
  return catalogueCache
end

--- Post-processing shader definitions declared by an example class.
---@param Example table
---@return table[]
function M.shadersFor(Example)
  if type(Example.shaders) == "function" then return Example.shaders() end
  return Example.shaders or {}
end

--- Wraps an example module into a scene constructor that checks the scene is
--- named after its id and, from the picker, routes ui_cancel back to the list.
---@param entry ExampleEntry
---@param opts { backToPicker: boolean }|nil
---@return fun(): Scene
function M.wrapExample(entry, opts)
  opts = opts or {}
  return function()
    local Example = require(entry.module)
    local scene = Example()
    assert(scene.name == entry.id,
      string.format("%s: the scene must be named %q (got %q)", entry.path, entry.id, tostring(scene.name)))
    if opts.backToPicker then
      local original = scene.onActionPressed
      scene.onActionPressed = function(s, name)
        if name == "ui_cancel" then
          M.back()
          return
        end
        if original then return original(s, name) end
      end
    end
    return scene
  end
end

--- Creates the Game. ExamplesPreload is always registered first.
---@param ctors table Scene constructors to register after the preload scene
---@param defaultScene string
---@param shaderDefs table[]|nil
---@param opts { dev: boolean }|nil dev enables hot reload (desktop only)
---@return Game
function M.buildGame(ctors, defaultScene, shaderDefs, opts)
  opts = opts or {}
  local Game = require "engine.Game"
  local ExamplesPreload = require "examples.runner.preload"
  local actions = require "examples.runner.actions"
  local scenes = { ExamplesPreload }
  for _, ctor in ipairs(ctors) do scenes[#scenes + 1] = ctor end
  M.game = Game({
    title = "spooki-love examples",
    env = (opts.dev and not isWeb()) and "dev" or nil,
    scenes = scenes,
    defaultScene = defaultScene,
    cursors = {
      default = { path = "assets/cursors/default.png", hotX = 8, hotY = 8 },
      active = { path = "assets/cursors/active.png", hotX = 8, hotY = 8 },
    },
    watch = { "engine", "examples" },
    -- Never persist bindings: the rebinding example would otherwise change
    -- every other example's controls on the next run.
    input = { deadzone = actions.deadzone, actions = actions.actions, saveFile = false },
    shaders = shaderDefs or {},
  })
  return M.game
end

--- Interactive entry: `--example <id>` or `--examples` (picker).
---@param opts ExampleArgs
function M.start(opts)
  local cat = M.catalogue()
  if opts.mode == "pick" then
    local IndexScene = require "examples.runner.IndexScene"
    M.buildGame({
      function() return IndexScene(cat.categories, function(id) M.open(id) end) end,
    }, M.INDEX_SCENE, {}, { dev = true })
    return
  end
  local id = opts.ids[1]
  local entry = cat.byId[id]
  if not entry then
    error("unknown example " .. tostring(id) .. " (list them with `love . --examples`)")
  end
  local Example = require(entry.module)
  M.buildGame({ M.wrapExample(entry) }, entry.id, M.shadersFor(Example), { dev = true })
  -- Announce once the scene is live so a web page embedding the game can hide its loader.
  local load = love.load
  love.load = function(...)
    load(...)
    print("[example] ready " .. entry.id)
  end
end

--- Opens an example from the picker.
---@param id string
function M.open(id)
  local entry = assert(M.catalogue().byId[id], "unknown example " .. tostring(id))
  local sceneManager = require "engine.sceneManager"
  local Example = require(entry.module)
  if sceneManager.getScene(id) then
    sceneManager.resetScene(id)
  else
    sceneManager.addScene(M.wrapExample(entry, { backToPicker = true }))
  end
  local postProcessing = M.game.postProcessing
  postProcessing.shaders = {}
  for _, def in ipairs(M.shadersFor(Example)) do
    postProcessing:addShader(def)
  end
  sceneManager.setCurrentScene(id)
  print("[example] ready " .. id)
end

--- Returns to the picker (no-op when it is already showing).
function M.back()
  local sceneManager = require "engine.sceneManager"
  if not sceneManager.getScene(M.INDEX_SCENE) then return end
  M.game.postProcessing.shaders = {}
  if sceneManager.getCurrentScene() ~= M.INDEX_SCENE then
    sceneManager.setCurrentScene(M.INDEX_SCENE)
  end
end

return M
