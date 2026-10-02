local Game = require "engine.Game"

local Preload = require "scenes.Preload"
local Menu = require "scenes.Menu"
local GameScene = require "scenes.Game"

-- Marketing asset scenes, rendered by `love . --export-assets` (never registered as game scenes).
local AssetIcon = require "scenes.assets.Icon"
local AssetFavicon = require "scenes.assets.Favicon"
local AssetCover = require "scenes.assets.Cover"
local AssetSocial = require "scenes.assets.Social"
local AssetWide = require "scenes.assets.Wide"
local AssetLogo = require "scenes.assets.Logo"

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
  watch = { "engine", "scenes", "gameObjects", "constants", "state" },
  -- Exported to assets/generated/<name>.png; scripts/release.sh bakes icon/favicon into the builds.
  assets = {
    outputDir = "assets/generated",
    items = {
      { name = "icon",    scene = AssetIcon,    width = 1024, height = 1024 },
      { name = "favicon", scene = AssetFavicon, width = 64,   height = 64 },
      { name = "cover",   scene = AssetCover,   width = 630,  height = 500 },
      { name = "social",  scene = AssetSocial,  width = 1200, height = 630 },
      { name = "wide",    scene = AssetWide,    width = 1920, height = 1080 },
      { name = "logo",    scene = AssetLogo,    width = 1600, height = 400,  transparent = true },
    },
  },
})
