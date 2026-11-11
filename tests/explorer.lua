-- Run with: nvim --headless -u NONE -l tests/explorer.lua
--
-- The sidebar explorer (plugins/explorer.lua on snacks.nvim): hide lists and
-- H, never-shown files, smart opening, the global Ctrl keys in its list,
-- folder icon colours, and quitting with the explorer open (in a child
-- instance). Uses the installed plugins.
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
local config = vim.fn.getcwd()
vim.env.XDG_STATE_HOME = root .. "/state"
vim.opt.rtp:prepend(config)
vim.o.swapfile = false
vim.o.shadafile = "NONE"
vim.g.mapleader = " "

local deps = { "snacks.nvim", "nvim-web-devicons" }
for _, name in ipairs(deps) do
  local path = vim.fn.globpath(vim.o.packpath, "pack/*/opt/" .. name)
  assert(path ~= "", "Missing installed test dependency: " .. name)
  vim.opt.rtp:append(path)
end

local project = root .. "/project"
for _, dir in ipairs({ "src", "node_modules/pkg", "__pycache__", ".github" }) do
  vim.fn.mkdir(project .. "/" .. dir, "p")
end
for _, file in ipairs({ "src/main.lua", "node_modules/pkg/index.js", "__pycache__/x.pyc", ".hidden", ".conform.123.md", "README.md" }) do
  vim.fn.writefile({ "x" }, project .. "/" .. file)
end
vim.api.nvim_set_current_dir(project)

require("plugins.snacks").setup()
local explorer = require("plugins.explorer")
explorer.setup()

local passed, failed = 0, 0
local function test(name, fn)
  local ok, err = xpcall(fn, debug.traceback)
  if ok then
    passed = passed + 1
    io.stdout:write("ok " .. passed + failed .. " - " .. name .. "\n")
  else
    failed = failed + 1
    io.stdout:write("not ok " .. passed + failed .. " - " .. name .. "\n" .. err .. "\n")
  end
end

local function equal(expected, actual)
  assert(
    vim.deep_equal(expected, actual),
    ("expected %s, got %s"):format(vim.inspect(expected), vim.inspect(actual))
  )
end

---The open explorer, after its finder is done.
local function current()
  local picker
  assert(vim.wait(5000, function()
    picker = Snacks.picker.get({ source = "explorer" })[1]
    return picker ~= nil and not picker.finder:running() and picker.list:count() > 0
  end, 20), "explorer did not open")
  return picker
end

---Top-level names the explorer lists.
local function names(picker)
  local out = {}
  for _, item in ipairs(picker:items()) do
    if item.file and vim.fs.dirname(item.file) == project then
      out[#out + 1] = vim.fs.basename(item.file)
    end
  end
  table.sort(out)
  return out
end

vim.cmd.edit(project .. "/README.md")
explorer.toggle()
local picker = current()

test("hide list entries are hidden, dotfiles stay, never-shown files never show", function()
  equal({ ".hidden", "README.md", "src" }, names(picker))
end)

test("H reveals the hide list but never the never-shown files", function()
  explorer.actions.explorer_toggle_hide_list(picker)
  picker = current()
  assert(vim.wait(3000, function()
    return vim.tbl_contains(names(picker), "node_modules")
  end, 20), vim.inspect(names(picker)))
  equal({ ".github", ".hidden", "README.md", "node_modules", "src" }, names(picker))
  explorer.actions.explorer_toggle_hide_list(picker)
  assert(vim.wait(3000, function()
    return not vim.tbl_contains(names(picker), "node_modules")
  end, 20), vim.inspect(names(picker)))
end)

test("global Ctrl keys are not explorer actions in its list", function()
  local buf = picker.list.win.buf
  for _, lhs in ipairs({ "<C-H>", "<C-J>", "<C-K>", "<C-L>", "<C-S>", "<C-T>" }) do
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
      assert(vim.keycode(m.lhs) ~= vim.keycode(lhs), lhs .. " is mapped in the explorer list: " .. vim.inspect(m))
    end
  end
  for _, lhs in ipairs({ "Y", "H", "w", "<CR>" }) do
    local found = false
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
      found = found or vim.keycode(m.lhs) == vim.keycode(lhs)
    end
    assert(found, lhs .. " is not mapped in the explorer list")
  end
end)

test("with one editing window a file opens there without a window prompt", function()
  picker = current()
  local picked = false
  local pick_win = Snacks.picker.util.pick_win
  Snacks.picker.util.pick_win = function(...)
    picked = true
    return pick_win(...)
  end
  -- As a user does: cursor on the file in the explorer list, then <CR>.
  -- This case is about opening, so an explorer without follow-file (which
  -- keeps moving the cursor to the current buffer's file).
  picker:close()
  Snacks.explorer({ follow_file = false })
  picker = current()
  local index
  for i = 1, picker.list:count() do
    local it = picker.list:get(i)
    if it and it.file == project .. "/.hidden" then
      index = i
    end
  end
  assert(index, "no .hidden item")
  picker.list:move(index, true)
  equal(project .. "/.hidden", picker:current().file)
  vim.api.nvim_set_current_win(picker.list.win.win)
  vim.api.nvim_feedkeys(vim.keycode("<CR>"), "mx", false)
  Snacks.picker.util.pick_win = pick_win
  assert(vim.wait(2000, function()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)) == project .. "/.hidden" then
        return true
      end
    end
  end, 20), "file did not open")
  assert(not picked, "the window picker was used")
  equal(1, explorer.editing_windows())
end)

test("folder icons use FolderIcon when the theme defines it, #E5C07B otherwise", function()
  picker = current()
  vim.api.nvim_set_hl(0, "FolderIcon", {})
  vim.api.nvim_exec_autocmds("ColorScheme", {})
  equal(tonumber("E5C07B", 16), vim.api.nvim_get_hl(0, { name = "SnacksExplorerFolderIcon" }).fg)
  vim.api.nvim_set_hl(0, "FolderIcon", { fg = "#123456" })
  vim.api.nvim_exec_autocmds("ColorScheme", {})
  equal("FolderIcon", vim.api.nvim_get_hl(0, { name = "SnacksExplorerFolderIcon" }).link)
  local dir
  for _, it in ipairs(picker:items()) do
    if it.dir and it.file == project .. "/src" then
      dir = it
    end
  end
  local ret = explorer.format(dir, picker)
  local icon
  for _, chunk in ipairs(ret) do
    if chunk.virtual then
      icon = chunk
      break
    end
  end
  equal("SnacksExplorerFolderIcon", icon[2])
end)

test(":q in the only editing window quits with the explorer open", function()
  local script = root .. "/quit.lua"
  vim.fn.writefile({
    ("vim.opt.rtp:prepend(%q)"):format(config),
    ("vim.opt.rtp:append(%q)"):format(vim.fn.globpath(vim.o.packpath, "pack/*/opt/snacks.nvim")),
    ("vim.opt.rtp:append(%q)"):format(vim.fn.globpath(vim.o.packpath, "pack/*/opt/nvim-web-devicons")),
    "vim.o.swapfile = false",
    "vim.o.shadafile = 'NONE'",
    "require('plugins.snacks').setup()",
    "require('plugins.explorer').setup()",
    ("vim.cmd.edit(%q)"):format(project .. "/README.md"),
    "local file_win = vim.api.nvim_get_current_win()",
    "require('plugins.explorer').toggle()",
    "vim.wait(3000, function() return #Snacks.picker.get({ source = 'explorer' }) > 0 end, 20)",
    "vim.api.nvim_set_current_win(file_win)",
    "vim.cmd('quit')",
    -- Still alive after the scheduled close: report and fail.
    "vim.defer_fn(function() io.stdout:write('STILL RUNNING') vim.cmd('cquit 3') end, 3000)",
  }, script)
  local result = vim.system({ vim.v.progpath, "--headless", "-u", "NONE", "-c", "luafile " .. script }, {
    cwd = project,
    text = true,
    env = { XDG_STATE_HOME = root .. "/child-state" },
  }):wait(15000)
  assert(not result.stdout:match("STILL RUNNING"), "Neovim stayed open: " .. result.stdout .. result.stderr)
  equal(0, result.code)
end)

io.stdout:write(("%d passed, %d failed\n"):format(passed, failed))
vim.cmd(failed > 0 and "cquit" or "qall!")
