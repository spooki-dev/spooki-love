--- Command-line parsing for the examples runner.
---
--- Reads LÖVE's global `arg` table (so the selection survives a hot reload,
--- which re-runs main.lua and calls love.load() with no arguments) and only
--- reacts to known flags, so the game path and LÖVE's own options are ignored.
---
---   love . --examples                      picker
---   love . --example camera/follow         run one example
---   love . --test [ids...] [--update-snapshots]
---   love . --gen-assets                    regenerate examples/assets/*.png
---
--- Fallbacks when no flag is present (web harnesses that cannot pass argv):
--- the SPOOKI_EXAMPLE environment variable, then examples/__selected.lua.
local M = {}

---@class ExampleArgs
---@field mode "run"|"pick"|"test"|"gen-assets"|nil
---@field ids string[] Example ids or category prefixes
---@field update boolean --update-snapshots

---@param argv table|nil
---@return ExampleArgs
function M.parse(argv)
  local out = { mode = nil, ids = {}, update = false }
  local i = 1
  while argv and argv[i] do
    local a = argv[i]
    if a == "--example" then
      out.mode = "run"
      out.ids = { argv[i + 1] }
      i = i + 1
    elseif a == "--examples" then
      out.mode = "pick"
    elseif a == "--test" then
      out.mode = "test"
    elseif a == "--gen-assets" then
      out.mode = "gen-assets"
    elseif a == "--update-snapshots" then
      out.update = true
    elseif out.mode == "test" and type(a) == "string" and not a:match("^%-%-") then
      out.ids[#out.ids + 1] = a
    end
    i = i + 1
  end
  if not out.mode then
    local env = os.getenv and os.getenv("SPOOKI_EXAMPLE")
    if env and env ~= "" then
      out.mode, out.ids = "run", { env }
    elseif love.filesystem.getInfo("examples/__selected.lua") then
      local ok, selected = pcall(require, "examples.__selected")
      if ok and type(selected) == "string" then
        out.mode, out.ids = "run", { selected }
      end
    end
  end
  return out
end

return M
