---Native folding: per buffer, LSP folding ranges when the attached server
---provides them, else Tree-sitter when a parser is active, else indentation
---(the global default). Files open unfolded (foldlevelstart = 99, in
---config/options.lua); zR/zM/zr/zm are Neovim's own. zU closes the child
---folds of the fold under the cursor.
---@class ConfigFolds
local M = {}

---Provider priority: a buffer never moves to a lower-ranked provider.
local rank = { indent = 0, treesitter = 1, lsp = 2 }

---@type table<string, string>
local exprs = {
  treesitter = "v:lua.vim.treesitter.foldexpr()",
  lsp = "v:lua.vim.lsp.foldexpr()",
}

---Apply the buffer's fold provider to one window showing it.
---@param win integer
---@param buf integer
local function apply(win, buf)
  local provider = vim.b[buf].fold_provider
  if not provider or provider == "indent" then
    return
  end
  vim.wo[win][0].foldmethod = "expr"
  vim.wo[win][0].foldexpr = exprs[provider]
end

---Fold `buf` with `provider` ("treesitter" or "lsp") unless it already uses a
---higher-ranked one, in every window that shows it now or later.
---@param buf integer
---@param provider "treesitter"|"lsp"
function M.use(buf, provider)
  buf = buf == 0 and vim.api.nvim_get_current_buf() or buf
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  local current = vim.b[buf].fold_provider or "indent"
  if rank[provider] < rank[current] then
    return
  end
  vim.b[buf].fold_provider = provider
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    apply(win, buf)
  end
end

---Close the child folds of the fold under the cursor, leaving it open.
function M.close_child_folds()
  local base_level = vim.fn.foldlevel(".")
  if base_level == 0 then
    vim.notify("No fold under cursor", vim.log.levels.WARN)
    return
  end

  local start = vim.fn.line(".")
  while start > 1 and vim.fn.foldlevel(start - 1) >= base_level do
    start = start - 1
  end

  local finish = vim.fn.line(".")
  local last = vim.fn.line("$")
  while finish < last and vim.fn.foldlevel(finish + 1) >= base_level do
    finish = finish + 1
  end

  local closed = 0
  local lnum = start
  while lnum <= finish do
    if vim.fn.foldlevel(lnum) == base_level + 1 then
      if vim.fn.foldclosed(lnum) == -1 then
        vim.cmd(("silent! %dfoldclose"):format(lnum))
        if vim.fn.foldclosed(lnum) ~= -1 then
          closed = closed + 1
        end
      end

      local closed_end = vim.fn.foldclosedend(lnum)
      if closed_end ~= -1 then
        lnum = closed_end + 1
      else
        lnum = lnum + 1
      end
    else
      lnum = lnum + 1
    end
  end

  if closed == 0 then
    vim.notify("No child folds to close", vim.log.levels.INFO)
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup("config.folds", { clear = true })
  -- A buffer shown in a new window (split, :buffer) keeps its provider.
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = group,
    callback = function(ev)
      apply(vim.api.nvim_get_current_win(), ev.buf)
    end,
  })
  -- LSP folding ranges win when the server has them.
  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(ev)
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if client and client:supports_method("textDocument/foldingRange", ev.buf) then
        M.use(ev.buf, "lsp")
      end
    end,
  })
  vim.keymap.set("n", "zU", M.close_child_folds, { desc = "Close child folds" })
end

return M
