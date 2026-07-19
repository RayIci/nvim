---bufferline.nvim: top bufferline with diagnostics and pinnable buffers.
---Pin persistence: bufferline stores pins in vim.g.BufferlinePinnedBuffers and
---re-pins on SessionLoadPost; sessionoptions 'globals' + auto-session's
---post-restore hook round-trip that global.
---@class PluginBufferline
local M = {}

---Whether a buffer sits in bufferline's pinned group (private API, pcall-guarded).
---@param buf integer
---@return boolean
local function is_buffer_pinned(buf)
  local ok_groups, groups = pcall(require, "bufferline.groups")
  local ok_state, state = pcall(require, "bufferline.state")
  if not (ok_groups and ok_state and state.components) then
    return false
  end
  for _, component in ipairs(state.components) do
    if component.id == buf then
      return groups._is_pinned(component)
    end
  end
  return false
end

---@param buf integer
---@return boolean deletable neither pinned nor modified, and a listed real buffer
local function is_deletable(buf)
  return vim.api.nvim_buf_is_valid(buf)
    and vim.bo[buf].buflisted
    and not vim.bo[buf].modified
    and not is_buffer_pinned(buf)
end

---Close every deletable buffer. Creates a scratch buffer first so Neovim
---survives, then lands on a remaining real buffer if one is left.
local function close_all_buffers()
  vim.cmd.enew()
  local scratch = vim.api.nvim_get_current_buf()

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if buf ~= scratch and is_deletable(buf) then
      pcall(vim.api.nvim_buf_delete, buf, {})
    end
  end

  local remaining = vim.tbl_filter(function(b)
    return b ~= scratch and vim.api.nvim_buf_is_valid(b) and vim.bo[b].buflisted
  end, vim.api.nvim_list_bufs())
  if #remaining > 0 then
    vim.api.nvim_set_current_buf(remaining[1])
    pcall(vim.api.nvim_buf_delete, scratch, {})
  end
end

---Close every deletable buffer except the current one.
local function close_other_buffers()
  local current = vim.api.nvim_get_current_buf()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if buf ~= current and is_deletable(buf) then
      pcall(vim.api.nvim_buf_delete, buf, {})
    end
  end
end

function M.setup()
  require("bufferline").setup({
    options = {
      diagnostics = "nvim_lsp",
      separator_style = "thin",
      always_show_bufferline = true,
      offsets = {
        { filetype = "neo-tree", text = "Files", highlight = "Directory", separator = true },
      },
      groups = {
        items = {
          require("bufferline.groups").builtin.pinned:with({ icon = "󰐃 " }),
        },
      },
    },
  })

  local map = vim.keymap.set
  map("n", "<leader>bp", "<cmd>BufferLineTogglePin<cr>", { desc = "Pin/unpin buffer" })
  map("n", "<leader>bo", "<cmd>BufferLineCloseOthers<cr>", { desc = "Close other buffers" })
  map("n", "<leader>xa", close_all_buffers, { desc = "Close all buffers (keep pinned/unsaved)" })
  map("n", "<leader>xA", close_other_buffers, { desc = "Close other buffers (keep pinned/unsaved)" })
  map("n", "<leader>bl", "<cmd>BufferLineCloseLeft<cr>", { desc = "Close buffers to the left" })
  map("n", "<leader>br", "<cmd>BufferLineCloseRight<cr>", { desc = "Close buffers to the right" })
  map("n", "[b", "<cmd>BufferLineMovePrev<cr>", { desc = "Move buffer left" })
  map("n", "]b", "<cmd>BufferLineMoveNext<cr>", { desc = "Move buffer right" })
end

return M
