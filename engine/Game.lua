local Object = require "engine.lib.classic"

local mcpOk, mcp_bridge = pcall(require, "engine.dev.mcp_bridge")
if not mcpOk then mcp_bridge = nil end

local sceneManager = require "engine.sceneManager"
local audioManager = require "engine.audioManager"
local system = require "engine.utils.system"
local cursorManager = require "engine.cursorManager"
local InputManager = require "engine.InputManager"
local PostProcessing = require "engine.PostProcessing"
local AssetExporter = require "engine.AssetExporter"

local DEFAULT_WATCH_DIRS = { "engine", "scenes", "gameObjects", "constants" }

---@class CursorConfig
---@field path string Image path for the cursor
---@field hotX number Hotspot x offset
---@field hotY number Hotspot y offset

---@class GameConfig
---@field title string Window title
---@field env string|nil 'dev' enables hot reload and the MCP bridge
---@field scenes table Array of Scene constructors, registered in order. The first entry's load() runs first, so put asset preloading there.
---@field defaultScene string Name of the scene made current after registration
---@field cursors table<string, CursorConfig>|nil Named cursors. Key "default" is applied at startup if present.
---@field shaders table|nil Array of post-processing shader definitions, applied in order
---@field watch table|nil Directories watched by hot reload in dev (defaults to engine, scenes, gameObjects, constants)
---@field assets AssetConfig|nil Marketing assets rendered by `love . --export-assets` (see engine/AssetExporter.lua)

---@class Game : Object
---@field title string name of the game
---@field env string|nil 'dev' used to enable dev only features
---@field scenes table Scene constructors to register
---@field defaultScene string Starting scene name
---@field cursors table<string, CursorConfig>
---@field shaders table
---@field watch table
---@field assets AssetConfig|nil
---@field args table Command-line arguments passed to love.load
---@field sceneManager table The scene manager
---@field audioManager table the audio manager
---@field cursorManager table cursor manager
local Game = Object:extend()

---@param config GameConfig
function Game:new(config)
  assert(type(config) == "table", "Game expects a config table")
  assert(type(config.title) == "string", "Game config requires a title")
  assert(type(config.scenes) == "table" and #config.scenes > 0, "Game config requires a non-empty scenes array")
  assert(type(config.defaultScene) == "string", "Game config requires a defaultScene name")

  self.title = config.title
  self.env = config.env
  self.scenes = config.scenes
  self.defaultScene = config.defaultScene
  self.cursors = config.cursors or {}
  self.shaders = config.shaders or {}
  self.watch = config.watch or DEFAULT_WATCH_DIRS
  self.assets = config.assets
  self.args = {}
  self.sceneManager = sceneManager
  self.audioManager = audioManager
  self.cursorManager = cursorManager
  self.inputManager = InputManager()
  self.postProcessing = PostProcessing()

  self:initializeEvents()

  return self
end

function Game:initializeEvents()
  function love.load(args)
    self:load(args)
  end

  function love.update(dt)
    self:update(dt)
  end

  function love.draw()
    self:draw()
  end

  function love.mousepressed(x, y, button, istouch, presses)
    self:mousepressed(x, y, button, istouch, presses)
  end

  function love.mousereleased(x, y, button, istouch, presses)
    self:mousereleased(x, y, button, istouch, presses)
  end

  function love.mousemoved(x, y, dx, dy, isTouch)
    self:mousemoved(x, y)
  end

  function love.wheelmoved(x, y)
    self:wheelmoved(x, y)
  end

  function love.keypressed(key, scancode, isrepeat)
    self:keypressed(key, scancode, isrepeat)
  end

  function love.focus(focused)
    self:focus(focused)
  end

  function love.resize(w, h)
    self:resize(w, h)
  end

  function love.quit()
    self:quit()
  end
end

--- Whether a flag was passed on the command line, e.g. `love . --export-assets`.
---@param flag string
---@return boolean
function Game:hasArg(flag)
  for _, a in ipairs(self.args) do
    if a == flag then return true end
  end
  return false
end

---@param args table|nil Arguments from love.load
function Game:load(args)
  self.args = args or {}
  if not system.isWeb() then
    -- Restore window position and display if saved
    local pos = love.filesystem.read("windowpos.txt")
    if pos then
      local display, x, y = pos:match("(%d+),(%d+),(%d+)")
      display, x, y = tonumber(display), tonumber(x), tonumber(y)
      if display and x and y then
        local numDisplays = love.window.getDisplayCount and love.window.getDisplayCount() or 1
        if display >= 1 and display <= numDisplays then
          local desktopWidth, desktopHeight =
              love.window.getDesktopDimensions and love.window.getDesktopDimensions(display) or love.graphics.getWidth(),
              love.graphics.getHeight()
          if x >= 0 and y >= 0 and x < desktopWidth and y < desktopHeight then
            love.window.setPosition(x, y, display)
          else
            love.window.setPosition(0, 0, display)
          end
        else
          love.window.setPosition(0, 0, 1)
        end
      end
    end
  end

  -- Set up the window
  love.window.setTitle(self.title)
  love.graphics.setColor(1, 1, 1)
  love.graphics.setFont(love.graphics.newFont(30))
  love.graphics.setLineWidth(5)
  love.graphics.setLineStyle("smooth")
  love.graphics.setBlendMode("alpha")
  love.graphics.setDefaultFilter("nearest", "nearest", 1)

  local cursors = {}
  for key, cursor in pairs(self.cursors) do
    cursors[key] = love.mouse.newCursor(cursor.path, cursor.hotX or 0, cursor.hotY or 0)
  end
  self.cursorManager.new(cursors)
  if cursors.default then
    self.cursorManager.setCursor("default")
  end

  for _, SceneConstructor in ipairs(self.scenes) do
    self.sceneManager.addScene(SceneConstructor)
  end
  self.sceneManager.setCurrentScene(self.defaultScene)

  self.postProcessing:load()
  for _, shaderDef in ipairs(self.shaders) do
    self.postProcessing:addShader(shaderDef)
  end

  -- Asset export runs before any dev tooling so it never binds the MCP port
  -- or starts hot reload, then quits without drawing a frame.
  if self:hasArg("--export-assets") then
    assert(self.assets, "--export-assets passed but no `assets` config was given to Game")
    local outputDir = love.filesystem.getSource() .. "/" .. (self.assets.outputDir or "assets/generated")
    AssetExporter.export(self.assets, outputDir, self.postProcessing)
    love.event.quit()
    return
  end

  if self.env == "dev" then
    local hotReload = require "engine.lib.hotReload"
    hotReload.init(function()
      self.audioManager.stopMusic()
    end)
    for _, dir in ipairs(self.watch) do
      hotReload.watch(dir)
    end

    if mcp_bridge then
      mcp_bridge.init(12345)
      mcp_bridge.setObjectGetter(function()
        local scene = sceneManager.getCurrentSceneObject()
        return scene and scene.gameObjects or {}
      end)
    end
  end
end

function Game:update(dt)
  self.postProcessing:update(dt)
  self.sceneManager.update(dt)

  -- Shader uniforms are rebuilt every frame by the current scene so that
  -- switching scenes never leaves stale values behind.
  local uniforms = self.postProcessing.uniforms
  for key in pairs(uniforms) do
    uniforms[key] = nil
  end
  local scene = self.sceneManager.getCurrentSceneObject()
  if scene and scene.updateShaderUniforms then
    scene:updateShaderUniforms(uniforms, dt)
  end

  if self.env == "dev" then
    local hotReload = require "engine.lib.hotReload"
    hotReload.update()
    if mcp_bridge then mcp_bridge.update() end
  end
end

function Game:draw()
  self.postProcessing:beginCapture()
  self.sceneManager.draw()
  self.postProcessing:endCapture()
  self.postProcessing:apply()
  if mcp_bridge then mcp_bridge.captureIfPending() end
end

function Game:resize(w, h)
  self.postProcessing:resize(w, h)
end

function Game:mousepressed(x, y, button, istouch, presses)
  print("Game.mousePressed called with x: " .. x .. ", y: " .. y .. ", button: " .. button)
  self.sceneManager.mousePressed(x, y, button, istouch, presses)
end

function Game:mousereleased(x, y, button, istouch, presses)
  if button == 1 then
    self.sceneManager.click(x, y, button, istouch, presses)
  end
end

function Game:mousemoved(x, y, dx, dy, isTouch)
  self.sceneManager.mouseMoved(x, y)
end

function Game:wheelmoved(x, y)
  self.sceneManager.wheelMoved(x, y)
end

function Game:keypressed(key, scancode, isrepeat)
  if not self.sceneManager then
    error("sceneManager is nil in Game:keypressed")
  end
  self.sceneManager.keypressed(key, scancode, isrepeat)
end

function Game:focus(focused)
  if focused then
    self.cursorManager.resetCursor()
  end
end

function Game:quit()
  -- Give the current scene a chance to persist state (see Scene.onQuit). Never let a
  -- failing hook block the quit.
  local hookOk, hookErr = pcall(self.sceneManager.checkAndCallSceneFunction, "onQuit")
  if not hookOk then
    print("Scene onQuit failed: " .. tostring(hookErr))
  end
  if not system.isWeb() then
    local x, y, display = love.window.getPosition()
    if not display then display = 1 end
    love.filesystem.write("windowpos.txt", string.format("%d,%d,%d", display, x, y))
  end
  if mcp_bridge then mcp_bridge.shutdown() end
  print("Goodbye!")
end

return Game
