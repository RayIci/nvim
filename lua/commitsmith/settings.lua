---Global, user-wide commitsmith settings: which harness to drive, which model
---per harness, and whether to invoke leanly (no tools, no MCP servers).
---
---Persisted at stdpath("data")/commitsmith/settings.json and re-read from disk
---on every access. There is deliberately no in-process cache: a cache means a
---second Neovim instance writes back a stale snapshot and silently drops the
---first one's keys, which is exactly what "global across instances" must not do.
---The file holds three keys, so reading it per access costs nothing that matters.
---@class CommitsmithSettings
local M = {}

---@class CommitsmithStoredSettings
---@field harness string?
---@field models table<string, string>?
---@field lean boolean?

local config = require("commitsmith.config")

---@type string
local path = vim.fs.joinpath(vim.fn.stdpath("data") --[[@as string]], "commitsmith", "settings.json")

---@return CommitsmithStoredSettings
local function read()
  local ok, data = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
  end)
  if not ok or type(data) ~= "table" then
    return {}
  end
  return data
end

---@param stored CommitsmithStoredSettings
local function write(stored)
  local dir = vim.fs.dirname(path)
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
  vim.fn.writefile({ vim.json.encode(stored) }, path)
end

---Merge one key into the on-disk table. Re-reads first so a concurrent
---instance's unrelated keys survive.
---@param key string
---@param value any
local function put(key, value)
  local stored = read()
  stored[key] = value
  write(stored)
end

---@return boolean true when nothing has been persisted yet
function M.is_empty()
  return next(read()) == nil
end

---Seed the store once, from `opts.seed`, when no harness has been chosen yet.
---Used to carry an existing choice across the extraction from another module.
function M.seed()
  local seed = config.options.seed
  if type(seed) ~= "function" or read().harness then
    return
  end

  local ok, value = pcall(seed)
  if not ok or type(value) ~= "table" then
    return
  end

  local harness = require("commitsmith.harness")
  local stored = read()
  if type(value.harness) == "string" and harness.get(value.harness) then
    stored.harness = value.harness
  end
  if type(value.models) == "table" then
    stored.models = stored.models or {}
    for name, model in pairs(value.models) do
      -- Only carry over a model this plugin still offers. A seeded id is a
      -- historical default, not a deliberate custom choice, and an id that has
      -- since been retired fails the generation outright rather than degrading.
      if type(model) == "string" and harness.model(name, model) then
        stored.models[name] = model
      end
    end
  end
  if type(value.lean) == "boolean" then
    stored.lean = value.lean
  end
  write(stored)
end

---@return string name of the active harness; the configured default when unset
---or no longer known
function M.harness()
  local harness = require("commitsmith.harness")
  local stored = read().harness
  if type(stored) == "string" and harness.get(stored) then
    return stored
  end
  return config.options.harness
end

---@param name string
function M.set_harness(name)
  put("harness", name)
end

---@param name string harness name
---@return string? model persisted for that harness, or its default
function M.model(name)
  local harness = require("commitsmith.harness")
  local adapter = harness.get(name)
  if not adapter then
    return nil
  end

  local models = read().models
  local stored = type(models) == "table" and models[name] or nil
  if type(stored) == "string" then
    return stored
  end
  return adapter.default_model
end

---@param name string harness name
---@param model string
function M.set_model(name, model)
  local models = read().models
  models = type(models) == "table" and models or {}
  models[name] = model
  put("models", models)
end

---@return boolean whether to invoke harnesses without tools or MCP servers
function M.lean()
  return read().lean == true
end

---@param value boolean
function M.set_lean(value)
  put("lean", value)
end

---@return boolean new value
function M.toggle_lean()
  local value = not M.lean()
  M.set_lean(value)
  return value
end

---@return string path to the settings file, for messages and tests
function M.path()
  return path
end

return M
