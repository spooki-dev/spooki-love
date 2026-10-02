local Scene = require "engine.Scene"
local colors = require "constants.colors"
local sceneManager = require "engine.sceneManager"


---@class Game : Scene
local Game = Scene.extend(Scene)

function Game:new()
  Game.super.new(self, "Game")
  self.backgroundColor = colors.black
end

function Game:load(dt)
end

function Game:start()

end

function Game:update(dt)

end

--- Input actions arrive here (see docs/Input.md); `pause` is Escape / Start by default.
---@param name string
function Game:onActionPressed(name)
  if name == "pause" then
    sceneManager.setCurrentScene("Menu")
  end
end

return Game
