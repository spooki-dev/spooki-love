local Scene = require "engine.Scene"
local colors = require "constants.colors"
local Vector4 = require "engine.Vector4"
local UICanvas = require "engine.ui.UICanvas"
local UIBox = require "engine.ui.UIBox"
local UIText = require "engine.ui.UIText"
local Button = require "engine.ui.Button"
local sceneManager = require "engine.sceneManager"
local CRT = require "engine.shaders.CRT"

---@class Menu : Scene
local Menu = Scene.extend(Scene)

function Menu:new()
  Menu.super.new(self, "Menu")
  self.backgroundColor = colors.black
end

function Menu:load()
  local startButton = Button("Start", "Start")

  function startButton:onClick()
    sceneManager.setCurrentScene("Game")
  end

  local crtLabel = CRT.enabled and "CRT: On" or "CRT: Off"
  local crtButton = Button("CRTToggle", crtLabel)

  function crtButton:onClick()
    CRT.enabled = not CRT.enabled
    self.text.text = CRT.enabled and "CRT: On" or "CRT: Off"
  end

  self:addGameObject(UICanvas("MenuUI", {
    UIBox("MenuContainer", {
      UIBox("MenuSpacer", {}, {
        height = 150,
      }),
      UIBox("MenuContent", {
        UIText("MenuTitle", "NEW GAME", {
          font = "header",
          textAlign = "center",
          color = colors.vec4Yellow,
        }),
        UIText("MenuSubtitle", "Built with spooki-love", {
          textAlign = "center",
          color = colors.vec4Grey,
        }),
        UIBox("MenuButtonRow", {
          UIBox("MenuButtonContainer", {
            startButton,
            crtButton,
          }, {
            width = "40%",
            gap = 10,
          }),
        }, {
          display = "flex",
          flexDirection = "row",
          justifyContent = "center",
          margin = Vector4(40, 0, 0, 0),
        }),
      }, {}),
    }, {
      padding = Vector4(10, 10, 10, 10),
    }),
  }, {
    padding = Vector4(10, 10, 10, 10),
  }))
end

function Menu:start()
end

function Menu:update(dt)
end

return Menu
