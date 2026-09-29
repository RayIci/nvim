---Inventory service sample for vale (doc comment).
---@class Repository
---@field name string
---@field items table<string, Item>
local Repository = {}
Repository.__index = Repository

local MAX_ITEMS = 1000
local PATTERN = "^(%u%u%u)-(%d%d%d%d)$"

---@param name string
---@return Repository
function Repository.new(name)
  return setmetatable({ name = name, items = {} }, Repository)
end

---@param key string
---@param value table
---@return boolean
function Repository:add(key, value)
  -- TODO: validate key before insert
  if self.items[key] ~= nil or #self.items >= MAX_ITEMS then
    return false
  end
  self.items[key] = value
  return true
end

---@param raw string
---@param strict? boolean
local function parse(raw, strict)
  local unused = 42 -- FIXME: remove
  local sku = raw:match(PATTERN)
  if not sku and strict ~= false then
    error(("bad sku: %q\n"):format(raw))
  end
  for part in raw:gmatch("[^-]+") do
    print(part, "\t")
  end
  return sku and { sku = sku, price = 3.14, active = true } or nil
end

return { Repository = Repository, parse = parse }
