local Game = require "engine.Game"
local CRT = require "engine.shaders.CRT"

local Preload = require "scenes.Preload"
local Menu = require "scenes.Menu"
local GameScene = require "scenes.Game"

-- Flush prints immediately so logs are readable when stdout is piped.
io.stdout:setvbuf("no")

if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
  local lldebugger = require "lldebugger"
  lldebugger.start()
end

Game({
  title = "New Game",
  env = "dev",
  -- Registered in order; Preload must come first because addScene runs load() immediately.
  scenes = { Preload, Menu, GameScene },
  defaultScene = "Menu",
  cursors = {
    default = { path = "assets/cursors/default.png", hotX = 8, hotY = 8 },
    active = { path = "assets/cursors/active.png", hotX = 8, hotY = 8 },
  },
  shaders = { CRT },
  watch = { "engine", "scenes", "gameObjects", "constants", "state" },
})
