---Persisted user preferences (small key/value store).
---Write-through JSON at stdpath('state')/prefs.json. First consumer: the
---rainbow-brackets toggle; reuse for any switch that must survive restarts.
---@class Prefs
local M = {}

---@type string
local path = vim.fs.joinpath(vim.fn.stdpath("state") --[[@as string]], "prefs.json")

---@type table<string, any>|nil
local cache = nil

---@return table<string, any>
local function load()
  if cache then
    return cache
  end
  local ok, data = pcall(function()
    local lines = vim.fn.readfile(path)
    return vim.json.decode(table.concat(lines, "\n"))
  end)
  cache = (ok and type(data) == "table") and data or {}
  return cache
end

local function save()
  local dir = vim.fs.dirname(path)
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
  vim.fn.writefile({ vim.json.encode(cache) }, path)
end

---Get a preference value.
---@generic T
---@param key string
---@param default T value returned when the key was never set
---@return T
function M.get(key, default)
  local value = load()[key]
  if value == nil then
    return default
  end
  return value
end

---Set a preference value and persist immediately.
---@param key string
---@param value any JSON-encodable value
function M.set(key, value)
  load()[key] = value
  save()
end

---Flip a boolean preference and persist it.
---@param key string
---@param default boolean value assumed when the key was never set
---@return boolean new value after the toggle
function M.toggle(key, default)
  local new = not M.get(key, default)
  M.set(key, new)
  return new
end

return M
