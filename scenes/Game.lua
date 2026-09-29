local Scene = require "engine.Scene"
local colors = require "constants.colors"


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

return Game
