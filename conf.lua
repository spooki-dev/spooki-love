function love.conf(t)
  t.window.title = "New Game"
  -- Pins the save directory name so saves are shared between source runs and fused builds.
  t.identity = "newgame"
  t.window.width = 1280
  t.window.height = 720
  t.window.resizable = true
  t.window.minwidth = 1024
  t.window.minheight = 600
  t.window.vsync = 1
  t.window.msaa = 0
end
