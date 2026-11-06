-- Run with: nvim --headless -u NONE -l tests/plugin-modules.lua
--
-- lua/config/pack.lua reads every setup module's `M.spec` before any plugin is
-- installed or on runtimepath, so loading a module must not require a plugin.
-- This check loads each lua/plugins/*.lua with only the configuration on
-- runtimepath and verifies its shape and that plugins/init.lua lists it.
local config = vim.fn.getcwd()
vim.opt.rtp = { config, vim.env.VIMRUNTIME }
vim.o.packpath = ""

local failures = {}
local function fail(message)
  failures[#failures + 1] = message
end

local index = require("plugins")
local listed = {}
for _, name in ipairs(index.modules) do
  if listed[name] then
    fail(("plugins/init.lua lists %q twice"):format(name))
  end
  listed[name] = true
end

for _, file in ipairs(vim.fn.globpath(config, "lua/plugins/*.lua", false, true)) do
  local name = vim.fn.fnamemodify(file, ":t:r")
  if name ~= "init" then
    local ok, mod = pcall(require, "plugins." .. name)
    if not ok then
      fail(("plugins.%s fails to load without plugins: %s"):format(name, mod))
    elseif type(mod) ~= "table" or type(mod.setup) ~= "function" then
      fail(("plugins.%s must return a table with setup()"):format(name))
    elseif mod.spec ~= nil and type(mod.spec) ~= "table" then
      fail(("plugins.%s: spec must be a list"):format(name))
    else
      for i, spec in ipairs(mod.spec or {}) do
        local src = type(spec) == "table" and spec.src or spec
        if type(src) ~= "string" or src == "" then
          fail(("plugins.%s: spec[%d] has no src"):format(name, i))
        end
      end
    end
    if not listed[name] then
      fail(("plugins.%s is not listed in plugins/init.lua"):format(name))
    end
  end
end

local specs_ok, specs = pcall(index.specs)
if not specs_ok then
  fail("plugins.specs() failed: " .. tostring(specs))
end

if #failures > 0 then
  io.stderr:write(table.concat(failures, "\n") .. "\n")
  vim.cmd.cquit(1)
end
io.stdout:write(
  ("ok - %d plugin modules load without plugins (%d specs)\n"):format(vim.tbl_count(listed), #specs)
)
vim.cmd.qall({ bang = true })
