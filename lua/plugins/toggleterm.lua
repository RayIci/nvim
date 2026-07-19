---toggleterm.nvim: toggleable terminals with an extensible hook registry.
---Other modules (language packs, plugins) integrate via the register_* functions
---— e.g. the python pack activates the project venv on terminal creation.
---Hooks may be registered at any time, including after setup: toggleterm calls
---dispatcher closures that iterate the registry at event time.
---@class PluginToggleterm
local M = {}

---@alias TermHook fun(term: table)  # term is a toggleterm Terminal
---@alias TermDataHook fun(term: table, job: number, data: string[], name: string)
---@alias TermExitHook fun(term: table, job: number, exit_code: number, name: string)

---@type table<string, function[]>
local hooks = {
  on_create = {},
  on_open = {},
  on_close = {},
  on_stdout = {},
  on_stderr = {},
  on_exit = {},
}

---@param event string
---@return function dispatcher passed to toggleterm's callback slot
local function dispatch(event)
  return function(...)
    for _, fn in ipairs(hooks[event]) do
      local ok, err = pcall(fn, ...)
      if not ok then
        vim.notify(("toggleterm %s hook: %s"):format(event, err), vim.log.levels.ERROR)
      end
    end
  end
end

---@param fn TermHook
function M.register_on_create(fn)
  table.insert(hooks.on_create, fn)
end

---@param fn TermHook
function M.register_on_open(fn)
  table.insert(hooks.on_open, fn)
end

---@param fn TermHook
function M.register_on_close(fn)
  table.insert(hooks.on_close, fn)
end

---@param fn TermDataHook
function M.register_on_stdout(fn)
  table.insert(hooks.on_stdout, fn)
end

---@param fn TermDataHook
function M.register_on_stderr(fn)
  table.insert(hooks.on_stderr, fn)
end

---@param fn TermExitHook
function M.register_on_exit(fn)
  table.insert(hooks.on_exit, fn)
end

function M.setup()
  require("toggleterm").setup({
    size = 20,
    open_mapping = [[<C-t>]], -- count-aware: 2<C-t> toggles terminal 2
    hide_numbers = true,
    shade_terminals = true,
    shading_factor = 2,
    start_in_insert = true,
    insert_mappings = true,
    persist_size = true,
    direction = "horizontal",
    close_on_exit = true,
    float_opts = { border = "curved" },
    on_create = dispatch("on_create"),
    on_open = dispatch("on_open"),
    on_close = dispatch("on_close"),
    on_stdout = dispatch("on_stdout"),
    on_stderr = dispatch("on_stderr"),
    on_exit = dispatch("on_exit"),
  })

  local map = vim.keymap.set
  map("n", "<leader>Tt", "<cmd>ToggleTerm<cr>", { desc = "Toggle terminal" })
  map("n", "<leader>Th", "<cmd>ToggleTerm direction=horizontal<cr>", { desc = "Horizontal terminal" })
  map("n", "<leader>Tv", "<cmd>ToggleTerm direction=vertical size=80<cr>", { desc = "Vertical terminal" })
  map("n", "<leader>Tf", "<cmd>ToggleTerm direction=float<cr>", { desc = "Floating terminal" })
  map("n", "<leader>Ta", "<cmd>ToggleTermToggleAll<cr>", { desc = "Toggle all terminals" })
  for i = 1, 4 do
    map("n", ("<leader>T%d"):format(i), ("<cmd>%dToggleTerm<cr>"):format(i), { desc = "Terminal " .. i })
  end
  map("n", "<leader>Tn", function()
    vim.ui.input({ prompt = "Terminal name: " }, function(name)
      if name and name ~= "" then
        vim.cmd(("TermExec cmd='echo Welcome to %s' name=%s"):format(name, name))
      end
    end)
  end, { desc = "Create named terminal" })
  map("n", "<leader>Tr", function()
    vim.ui.select(require("toggleterm.terminal").get_all(true), {
      prompt = "Select terminal to rename:",
      format_item = function(term)
        return ("%d: %s"):format(term.id, term.display_name or ("Terminal " .. term.id))
      end,
    }, function(term)
      if term then
        vim.ui.input({ prompt = "New name: ", default = term.display_name or "" }, function(name)
          if name and name ~= "" then
            term.display_name = name
          end
        end)
      end
    end)
  end, { desc = "Rename terminal" })
  map("n", "<leader>Ts", "<cmd>ToggleTermSendCurrentLine<cr>", { desc = "Send line to terminal" })
  map("v", "<leader>Ts", "<cmd>ToggleTermSendVisualSelection<cr>", { desc = "Send selection to terminal" })

  -- Buffer-local terminal-mode maps for every terminal buffer
  vim.api.nvim_create_autocmd("TermOpen", {
    group = vim.api.nvim_create_augroup("config.toggleterm.keymaps", { clear = true }),
    callback = function(ev)
      local set = vim.keymap.set
      set("t", "<C-\\>", [[<C-\><C-n>]], { buffer = ev.buf, desc = "Exit terminal mode" })
      set("t", "jk", [[<C-\><C-n>]], { buffer = ev.buf, desc = "Exit terminal mode" })
      set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], { buffer = ev.buf, desc = "Window left" })
      set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], { buffer = ev.buf, desc = "Window down" })
      set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], { buffer = ev.buf, desc = "Window up" })
      set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], { buffer = ev.buf, desc = "Window right" })
    end,
  })
end

return M
