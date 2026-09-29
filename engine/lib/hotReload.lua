-- hot_reload.lua
local hotReload = {
  lastModified = {},
  watchList = {},
  initialized = false
}

-- Add files or directories to watch (recursively for .lua files)
function hotReload.watch(path)
  local function addLuaFiles(dir)
    local items = love.filesystem.getDirectoryItems(dir)
    for _, item in ipairs(items) do
      local fullPath = dir ~= "" and (dir .. "/" .. item) or item
      local info = love.filesystem.getInfo(fullPath)
      if info then
        if info.type == "file" and fullPath:match("%.lua$") then
          table.insert(hotReload.watchList, fullPath)
          hotReload.lastModified[fullPath] = info.modtime or 0
        elseif info.type == "directory" then
          addLuaFiles(fullPath)
        end
      end
    end
  end

  if type(path) == "string" then
    local info = love.filesystem.getInfo(path)
    if info then
      if info.type == "file" and path:match("%.lua$") then
        table.insert(hotReload.watchList, path)
        hotReload.lastModified[path] = info.modtime or 0
      elseif info.type == "directory" then
        addLuaFiles(path)
      end
    end
  end
end

-- Check for changes in watched files
function hotReload.update()
  if not hotReload.initialized then return end

  local changed = false
  local changedFiles = {}

  for _, path in ipairs(hotReload.watchList) do
    local info = love.filesystem.getInfo(path)
    if info and info.modtime > hotReload.lastModified[path] then
      hotReload.lastModified[path] = info.modtime
      table.insert(changedFiles, path)
      changed = true
    end
  end

  if changed then
    hotReload.reload(changedFiles)
  end
end

-- Reload the game
function hotReload.reload(changedFiles)
  print("Hot reload triggered! Changed files:")
  if hotReload.cb then
    hotReload.cb()
  end
  for _, file in ipairs(changedFiles) do
    print("  - " .. file)
  end

  -- Clear package.loaded to force Lua to reload modules
  for k, _ in pairs(package.loaded) do
    if k ~= "hot_reload" and k ~= "love.filesystem" and
        k ~= "love.timer" and k ~= "love.graphics" and
        k ~= "love.event" and k ~= "love.run" then
      package.loaded[k] = nil
    end
  end

  -- Keep a reference to old love callbacks
  local oldLoad = love.load
  local oldDraw = love.draw
  local oldUpdate = love.update
  local oldKeypressed = love.keypressed
  local oldMousepressed = love.mousepressed

  -- Reload main.lua
  if love.filesystem.getInfo("main.lua") then
    local main = love.filesystem.load("main.lua")
    main()
  end

  -- Call love.load again to reinitialize game state
  if love.load then
    love.load()
  end

  print("Hot reload complete!")
end

-- Initialize hot reload
---@param cb function Callback to call after initialization
function hotReload.init(cb)
  -- Add files to watch
  hotReload.watch("main.lua")
  -- You can add more files or directories to watch here

  -- Store original keypressed callback
  local originalKeypressed = love.keypressed

  -- Override keypressed to add reload hotkey (F5)
  love.keypressed = function(key, scancode, isrepeat)
    if key == "`" then
      hotReload.reload({})
    end

    -- Call original keypressed function if it exists
    if originalKeypressed then
      originalKeypressed(key, scancode, isrepeat)
    end
  end



  hotReload.initialized = true
  if cb then
    hotReload.cb = cb
  end
  print("Hot reload initialized")
end

return hotReload
