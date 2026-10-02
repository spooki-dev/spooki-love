--- Entry point for the examples catalogue and test suite. main.lua calls
--- shouldRun(arg) and, when a runner flag is present, main(arg) instead of
--- building the game. See examples/README.md.
local args = require "examples.runner.args"

local M = {}

---@param argv table LÖVE's global arg table
---@return boolean
function M.shouldRun(argv)
  return args.parse(argv).mode ~= nil
end

---@param argv table
function M.main(argv)
  local opts = args.parse(argv)
  if love.system.getOS() ~= "Web" then
    -- Keep example saves and bindings out of the game's own save directory.
    love.filesystem.setIdentity("spooki-love-examples")
  end
  if opts.mode == "gen-assets" then
    require("examples.runner.genassets").run()
    love.event.quit()
    return
  end
  if opts.mode == "test" then
    require("examples.runner.test").install(opts)
    return
  end
  require("examples.runner.harness").start(opts)
end

return M
