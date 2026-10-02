--- Desktop-only file helpers for writing into the repository (goldens, test
--- output, generated assets). love.filesystem can only write to the save
--- directory, so these use plain io like engine/AssetExporter.lua does.
local M = {}

--- Absolute path of the project source directory.
---@return string
function M.source()
  return love.filesystem.getSource()
end

local function dirname(path)
  return path:match("^(.*)/[^/]*$") or "."
end

---@param path string
function M.mkdirp(path)
  os.execute(string.format('mkdir -p "%s"', path))
end

--- Writes a string to an absolute path, creating parent directories.
---@param path string
---@param data string
function M.write(path, data)
  M.mkdirp(dirname(path))
  local file, err = io.open(path, "wb")
  assert(file, "cannot open " .. path .. ": " .. tostring(err))
  file:write(data)
  file:close()
end

--- Encodes ImageData as PNG and writes it.
---@param imageData love.ImageData
---@param path string Absolute path
function M.writePng(imageData, path)
  M.write(path, imageData:encode("png"):getString())
end

---@param path string Absolute path
---@return boolean
function M.exists(path)
  local file = io.open(path, "rb")
  if file then file:close() return true end
  return false
end

return M
