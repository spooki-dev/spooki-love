--- Discovers examples/<category>/<slug>.lua and parses their metadata headers.
---
--- A header is a run of `-- key: value` comment lines at the top of the file;
--- it ends at the first line that is not a comment. `title` and `description`
--- are required, `order` and `tags` optional. The website parses the same
--- lines with a regular expression, so keep them plain.
---
--- Categories come from examples/categories.lua, in display order. Every
--- directory must be listed there and vice versa so the two cannot drift.
local M = {}

local RESERVED = { runner = true, assets = true, shaders = true, __snapshots__ = true, [".test-output"] = true }
local ID = "^[a-z0-9-]+$"

---@class ExampleEntry
---@field id string "category/slug"
---@field category string
---@field slug string
---@field module string "examples.category.slug"
---@field path string "examples/category/slug.lua"
---@field title string
---@field description string
---@field order number
---@field tags string[]

--- Parses the metadata header of one example file.
---@param path string
---@return table<string, string>
function M.readHeader(path)
  local src, err = love.filesystem.read(path)
  assert(src, "cannot read " .. path .. ": " .. tostring(err))
  local meta = {}
  for line in (src .. "\n"):gmatch("([^\n]*)\n") do
    if not line:match("^%-%-") then break end
    local k, v = line:match("^%-%-%s*([%w_]+):%s*(.-)%s*$")
    if k then meta[k] = v end
  end
  assert(meta.title and meta.title ~= "", path .. ": missing `-- title:` header")
  assert(meta.description and meta.description ~= "", path .. ": missing `-- description:` header")
  return meta
end

local function splitTags(s)
  local tags = {}
  for tag in (s or ""):gmatch("[^,]+") do
    tag = tag:match("^%s*(.-)%s*$")
    if tag ~= "" then tags[#tags + 1] = tag end
  end
  return tags
end

---@return table[] categories in display order, each { id, title, description, examples = ExampleEntry[] }
---@return ExampleEntry[] flat list in display order
---@return table<string, ExampleEntry> by id
function M.load()
  local categories = require "examples.categories"
  local listed = {}
  for _, cat in ipairs(categories) do
    assert(type(cat.id) == "string" and cat.id:match(ID), "categories.lua: bad category id " .. tostring(cat.id))
    assert(type(cat.title) == "string", "categories.lua: " .. cat.id .. " needs a title")
    assert(not listed[cat.id], "categories.lua: duplicate category " .. cat.id)
    listed[cat.id] = cat
    cat.examples = {}
  end
  for _, item in ipairs(love.filesystem.getDirectoryItems("examples")) do
    local info = love.filesystem.getInfo("examples/" .. item)
    if info and info.type == "directory" and not RESERVED[item] and item:sub(1, 1) ~= "." and item:sub(1, 1) ~= "_" then
      assert(listed[item], "examples/" .. item .. "/ is not listed in examples/categories.lua")
    end
  end

  local flat, byId = {}, {}
  for _, cat in ipairs(categories) do
    local dir = "examples/" .. cat.id
    local info = love.filesystem.getInfo(dir)
    assert(info and info.type == "directory", "categories.lua lists " .. cat.id .. " but " .. dir .. "/ does not exist")
    for _, file in ipairs(love.filesystem.getDirectoryItems(dir)) do
      local slug = file:match("^(.-)%.lua$")
      if slug then
        assert(slug:match(ID), dir .. "/" .. file .. ": file names must be lowercase letters, digits and hyphens")
        local path = dir .. "/" .. file
        local meta = M.readHeader(path)
        local entry = {
          id = cat.id .. "/" .. slug,
          category = cat.id,
          slug = slug,
          module = "examples." .. cat.id .. "." .. slug,
          path = path,
          title = meta.title,
          description = meta.description,
          order = tonumber(meta.order) or 999,
          tags = splitTags(meta.tags),
        }
        cat.examples[#cat.examples + 1] = entry
        byId[entry.id] = entry
      end
    end
    table.sort(cat.examples, function(a, b)
      if a.order ~= b.order then return a.order < b.order end
      return a.slug < b.slug
    end)
    for _, entry in ipairs(cat.examples) do flat[#flat + 1] = entry end
  end
  return categories, flat, byId
end

--- Resolves ids or category prefixes against the catalogue.
---@param flat ExampleEntry[]
---@param byId table<string, ExampleEntry>
---@param ids string[] Empty selects everything
---@return ExampleEntry[]
function M.select(flat, byId, ids)
  if #ids == 0 then return flat end
  local out, seen = {}, {}
  for _, id in ipairs(ids) do
    if byId[id] then
      if not seen[id] then out[#out + 1] = byId[id]; seen[id] = true end
    else
      local matched = false
      for _, entry in ipairs(flat) do
        if entry.category == id then
          matched = true
          if not seen[entry.id] then out[#out + 1] = entry; seen[entry.id] = true end
        end
      end
      assert(matched, "unknown example or category: " .. tostring(id))
    end
  end
  return out
end

return M
