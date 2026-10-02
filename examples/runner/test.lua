--- `love . --test`: runs every example (or the given ids / categories) with a
--- fixed timestep, scripted input, the example's own `check` assertions and a
--- golden screenshot, then exits 0 (all passed), 1 (failures) or 2 (harness
--- error). Desktop only.
---
--- Each example runs in a fresh engine: `package.loaded` is purged for
--- engine/example modules (the same trick hot reload uses), so scene and
--- object registries, caches and input state cannot leak between examples.
local args = require "examples.runner.args"
local catalogue = require "examples.runner.catalogue"
local harness = require "examples.runner.harness"
local script = require "examples.runner.script"
local snapshot = require "examples.runner.snapshot"
local files = require "examples.runner.files"

local M = {}

M.DT = 1 / 60
M.DEFAULT_FRAMES = 120
M.DEFAULT_SEED = 1234

-- Runner modules that survive the purge between examples.
local KEEP = {
  ["examples.runner"] = true,
  ["examples.runner.args"] = true,
  ["examples.runner.catalogue"] = true,
  ["examples.runner.harness"] = true,
  ["examples.runner.script"] = true,
  ["examples.runner.snapshot"] = true,
  ["examples.runner.files"] = true,
  ["examples.runner.test"] = true,
}

local PURGE = { "^engine%.", "^examples%.", "^constants%.", "^scenes%.", "^gameObjects%.", "^state%." }

local function freshWorld(seed)
  for name in pairs(package.loaded) do
    if not KEEP[name] then
      for _, pattern in ipairs(PURGE) do
        if name:match(pattern) then
          package.loaded[name] = nil
          break
        end
      end
    end
  end
  collectgarbage("collect")
  love.graphics.setCanvas()
  love.graphics.setShader()
  love.graphics.reset()
  love.math.setRandomSeed(seed)
  math.randomseed(seed)
end

local function traceback(err)
  local text = tostring(err)
  local tb = debug.traceback("", 2)
  -- Keep the first few frames of the traceback for context.
  local lines, count = {}, 0
  for line in tb:gmatch("[^\n]+") do
    if count > 0 and count <= 6 and not line:find("examples/runner/test.lua") then
      lines[#lines + 1] = line:match("^%s*(.-)%s*$")
    end
    count = count + 1
  end
  if #lines > 0 then text = text .. "\n      " .. table.concat(lines, "\n      ") end
  return text
end

---@param entry ExampleEntry
---@param opts ExampleArgs
---@return table result { id, ok, messages, frames }
local function runOne(entry, opts)
  local result = { id = entry.id, ok = true, messages = {}, frames = 0 }
  local ok, err = xpcall(function()
    freshWorld(M.DEFAULT_SEED)
    local Example = require(entry.module)
    if Example.seed and Example.seed ~= M.DEFAULT_SEED then
      love.math.setRandomSeed(Example.seed)
      math.randomseed(Example.seed)
    end
    local frames = Example.frames or M.DEFAULT_FRAMES
    result.frames = frames
    local game = harness.buildGame({ harness.wrapExample(entry) }, entry.id, harness.shadersFor(Example), { dev = false })
    love.load({})
    local scene = game.sceneManager.getCurrentSceneObject()
    assert(scene and scene.name == entry.id, "example scene did not become current")
    local timeline = script.compile(Example.script)
    local shot = nil
    local wantSnapshot = Example.snapshot ~= false
    for frame = 1, frames do
      script.apply(timeline, frame, scene)
      love.update(M.DT)
      love.graphics.origin()
      love.graphics.clear(love.graphics.getBackgroundColor())
      love.draw()
      if frame == frames and wantSnapshot then
        love.graphics.captureScreenshot(function(imageData) shot = imageData end)
      end
      love.graphics.present()
      if Example.check then
        Example.check(scene, { frame = frame, t = frame * M.DT, dt = M.DT, done = frame == frames })
      end
    end
    if wantSnapshot then
      assert(shot, "captureScreenshot produced no image")
      snapshot.verify(entry, shot, Example.snapshotTolerance, opts, result)
    else
      result.messages[#result.messages + 1] = "snapshot disabled"
    end
    game.inputManager.releaseAll()
  end, traceback)
  if not ok then
    result.ok = false
    result.messages[#result.messages + 1] = err
  end
  return result
end

local function report(results, opts)
  local lines = {}
  local failed = 0
  for _, r in ipairs(results) do
    if not r.ok then failed = failed + 1 end
    lines[#lines + 1] = string.format("%s %s  (%d frames; %s)", r.ok and "PASS" or "FAIL", r.id, r.frames,
      table.concat(r.messages, "; "))
  end
  local summary = string.format("%d examples, %d passed, %d failed%s", #results, #results - failed, failed,
    opts.update and " (goldens updated)" or "")
  lines[#lines + 1] = summary
  local text = table.concat(lines, "\n") .. "\n"
  print(text)
  files.write(files.source() .. "/examples/.test-output/report.txt", text)
  return failed == 0 and 0 or 1
end

--- Installs the test run loop. Called from main.lua before LÖVE starts love.run.
---@param opts ExampleArgs
function M.install(opts)
  assert(love.system.getOS() ~= "Web", "--test runs on desktop only")
  function love.run()
    love.window.setVSync(0)
    local pw, ph = love.graphics.getPixelDimensions()
    if pw ~= 1280 or ph ~= 720 then
      print(string.format("tests need a 1280x720 backbuffer, got %dx%d (see conf.lua)", pw, ph))
      return function() return 2 end
    end
    local okCat, flatOrErr, byId = pcall(function()
      local _, flat, byIdInner = catalogue.load()
      return flat, byIdInner
    end)
    if not okCat then
      print("catalogue error: " .. tostring(flatOrErr))
      return function() return 2 end
    end
    local okSel, entries = pcall(catalogue.select, flatOrErr, byId, opts.ids)
    if not okSel then
      print(tostring(entries))
      return function() return 2 end
    end
    print(string.format("running %d example%s at %dx%d, dt=1/60%s", #entries, #entries == 1 and "" or "s", pw, ph,
      opts.update and ", updating goldens" or ""))
    local results, index = {}, 0
    return function()
      love.event.pump()
      for name in love.event.poll() do
        if name == "quit" then return 1 end
      end
      index = index + 1
      local entry = entries[index]
      if not entry then
        return report(results, opts)
      end
      local result = runOne(entry, opts)
      results[#results + 1] = result
      print(string.format("%s %s", result.ok and "PASS" or "FAIL", result.id))
    end
  end
end

return M
