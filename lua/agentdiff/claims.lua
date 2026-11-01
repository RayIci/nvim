---Claims: "the next disk changes to these paths are mine".
---
---Claims live as files in the store's `claims/` directory so every Neovim
---instance on the project sees them. A claim names one path and the wall-clock
---time it was made; it expires after `claim_ttl` ms.
---
---Shell commands run from Neovim (`:!cmd`, `:{range}!filter`, `:r !cmd`,
---`:w !cmd`) are handled by detect.lua: changes still pending attribution are
---settled as the agent's before the command runs, and every change found right
---after it is the user's.
---@class AgentdiffClaims
local M = {}

local util = require("agentdiff.util")

---@param store AgentdiffStore
---@param path string
---@return string
local function claim_file(store, path)
  return store.dir .. "/claims/" .. vim.fn.sha256(path):sub(1, 24)
end

---Claim project-relative paths for the user.
---@param store AgentdiffStore
---@param paths string[]
function M.add(store, paths)
  local now = util.now_ms()
  for _, p in ipairs(paths) do
    util.write_file(claim_file(store, p), now .. "\n" .. p .. "\n")
  end
end

---True when a live claim covers the path.
---@param store AgentdiffStore
---@param path string
---@param ttl integer
---@return boolean
function M.claimed(store, path, ttl)
  local data = util.read_file(claim_file(store, path))
  if not data then
    return false
  end
  local t, p = data:match("^(%d+)\n(.-)\n")
  return p == path and (util.now_ms() - tonumber(t)) <= ttl
end

---Consume a claim (after the change it covered has been processed).
---@param store AgentdiffStore
---@param path string
function M.release(store, path)
  os.remove(claim_file(store, path))
end

---Delete expired claims.
---@param store AgentdiffStore
---@param ttl integer
function M.gc(store, ttl)
  local dir = store.dir .. "/claims"
  local now = util.now_ms()
  for name, kind in vim.fs.dir(dir) do
    if kind == "file" then
      local data = util.read_file(dir .. "/" .. name) or ""
      local t = tonumber(data:match("^(%d+)") or 0)
      if now - t > ttl then
        os.remove(dir .. "/" .. name)
      end
    end
  end
end

local modifiers = {
  "aboveleft",
  "belowright",
  "botright",
  "browse",
  "confirm",
  "hide",
  "keepalt",
  "keepjumps",
  "keepmarks",
  "keeppatterns",
  "leftabove",
  "legacy",
  "lockmarks",
  "noautocmd",
  "noswapfile",
  "rightbelow",
  "sandbox",
  "silent",
  "tab",
  "topleft",
  "unsilent",
  "verbose",
  "vertical",
  "vim9cmd",
}

---@param w string
---@return boolean
local function is_modifier(w)
  if #w < 2 then
    return false
  end
  for _, m in ipairs(modifiers) do
    if m:sub(1, #w) == w then
      return true
    end
  end
  return false
end

---True when an Ex command line runs a shell command that can write files.
---@param cmdline string
---@return boolean
function M.is_shell_cmdline(cmdline)
  local s = cmdline:gsub("^[%s:]*", "")
  -- strip command modifiers (`:silent`, `:keepalt`, `:5verbose`, …)
  while true do
    local w, rest = s:match("^%d*(%a+)!?%s+(.*)$")
    if w and is_modifier(w) then
      s = rest
    else
      break
    end
  end
  -- strip a leading range: numbers, marks, patterns, %, $, ., +/- offsets, commas
  s = s:gsub("^[%d%s,;%.%$%%'<>%+%-]*", "")
  if s:sub(1, 1) == "!" then
    return true
  end
  return s:match("^r[ead]*%s*!") ~= nil or s:match("^w[rite]*%s+!") ~= nil -- `:w !cmd`, not the forced write `:w!`
end

return M
