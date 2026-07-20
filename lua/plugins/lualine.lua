---lualine.nvim: statusline with mode, branch, diff, diagnostics, and a set of
---buffer-scoped tooling indicators — LSP clients, conform formatters, nvim-lint
---linters — each icon-distinguished, plus a macro-recording indicator (noice
---hides the native "recording @x" message). Language packs contribute extra
---widgets (e.g. the Python venv) through M.apply(); a single bridge component
---renders them at draw time, so packs whose plugins load lazily still show up.
---@class PluginLualine
local M = {}

---@return string
local function macro_recording()
  local reg = vim.fn.reg_recording()
  if reg == "" then
    return ""
  end
  return "● REC @" .. reg
end

---Active LSP clients for the current buffer.
---@return string
local function lsp_clients()
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  if #clients == 0 then
    return ""
  end
  return " " .. table.concat(
    vim.tbl_map(function(c)
      return c.name
    end, clients),
    ", "
  )
end

---Conform formatters that would run for the current buffer.
---@return string
local function formatters()
  local conform = package.loaded["conform"]
  if not conform then
    return ""
  end
  local list = conform.list_formatters(0)
  if #list == 0 then
    return ""
  end
  return "󰉼 " .. table.concat(
    vim.tbl_map(function(f)
      return f.name
    end, list),
    ", "
  )
end

---nvim-lint linters registered for the current filetype.
---@return string
local function linters()
  local lint = package.loaded["lint"]
  if not lint then
    return ""
  end
  local list = lint.linters_by_ft[vim.bo.filetype] or {}
  if #list == 0 then
    return ""
  end
  return "󰁨 " .. table.concat(list, ", ")
end

---Statusline widgets contributed by language packs or plugins, appended via
---M.register()/M.apply(). Each: { render = fun():string, cond? = fun():boolean,
---icon? = string, color? }. The bridge component reads this at draw time.
---@type table[]
local lang_widgets = {}

---Register one statusline widget. Any code may call this — a language pack
---(indirectly, via apply()) or a plugin's own setup — at any time; the bridge
---reads the table at render time, so timing and load order do not matter.
---@param widget table
function M.register(widget)
  lang_widgets[#lang_widgets + 1] = widget
  -- Reflect the new widget immediately if the statusline is already built.
  pcall(function()
    require("lualine").refresh()
  end)
end

---Register a batch of widgets (used by require("langs").setup() for the merged
---pack widgets). Appends — it never replaces — so widgets a plugin registered
---earlier survive.
---@param widgets table[]|nil
function M.apply(widgets)
  for _, widget in ipairs(widgets or {}) do
    M.register(widget)
  end
end

---Bridge: render every pack widget whose cond holds and whose render() is
---non-empty, each prefixed with its icon. A widget wanting its own color embeds
---a `%#Group#…%*` highlight in its render() string.
---@return string
local function lang_status()
  local parts = {}
  for _, w in ipairs(lang_widgets) do
    if not w.cond or w.cond() then
      local ok, text = pcall(w.render)
      if ok and text and text ~= "" then
        parts[#parts + 1] = (w.icon and (w.icon .. " ") or "") .. text
      end
    end
  end
  return table.concat(parts, " ")
end

function M.setup()
  -- The statusline doesn't redraw on its own when recording starts/stops.
  vim.api.nvim_create_autocmd({ "RecordingEnter", "RecordingLeave" }, {
    group = vim.api.nvim_create_augroup("config.lualine.recording", { clear = true }),
    callback = function()
      require("lualine").refresh()
    end,
  })

  require("lualine").setup({
    options = {
      theme = "auto",
      globalstatus = true,
      component_separators = { left = "", right = "" },
      section_separators = { left = "", right = "" },
    },
    sections = {
      lualine_a = { "mode" },
      lualine_b = { "branch", "diff", "diagnostics" },
      lualine_c = { { "filename", path = 1 } },
      lualine_x = {
        { macro_recording, color = { fg = "#ff5555", gui = "bold" } },
        { lsp_clients, color = { fg = "#7aa2f7", gui = "bold" } },
        { formatters, color = { fg = "#9ece6a", gui = "bold" } },
        { linters, color = { fg = "#bb9af7", gui = "bold" } },
        { lang_status },
        "filetype",
      },
      lualine_y = { "progress" },
      lualine_z = { "location" },
    },
    extensions = { "neo-tree", "nvim-dap-ui", "quickfix", "overseer" },
  })
end

return M
