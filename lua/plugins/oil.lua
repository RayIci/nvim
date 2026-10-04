---oil.nvim: edit the filesystem as a buffer, in a float on <leader>E. A trial
---explorer alongside neo-tree, which keeps <leader>e and directory buffers.
---@class PluginOil
local M = {}

---Drop oil from a freshly loaded session. auto-session never closes the last
---window and :restart runs :mksession itself (no pre-write event exists), so
---an oil window can end up in either session file. Floats close; normal
---windows fall back to their alternate file, else any listed buffer, else
---an empty one. Then the oil buffers are wiped.
local function scrub_oil_from_session()
  local function is_oil(buf)
    return vim.api.nvim_buf_get_name(buf):match("^oil://") ~= nil
  end

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) and is_oil(vim.api.nvim_win_get_buf(win)) then
      if vim.api.nvim_win_get_config(win).relative ~= "" then
        pcall(vim.api.nvim_win_close, win, true)
      else
        local alt = vim.api.nvim_win_call(win, function()
          return vim.fn.bufnr("#")
        end)
        local target = (alt > 0 and vim.bo[alt].buflisted and not is_oil(alt)) and alt or nil
        if not target then
          for _, b in ipairs(vim.api.nvim_list_bufs()) do
            if vim.bo[b].buflisted and not is_oil(b) then
              target = b
              break
            end
          end
        end
        target = target or vim.api.nvim_create_buf(true, false)
        vim.api.nvim_win_set_buf(win, target)
      end
    end
  end

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if is_oil(buf) then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end
end

function M.setup()
  require("oil").setup({
    -- neo-tree hijacks directory buffers (`nvim .`); oil must not compete.
    default_file_explorer = false,
    -- Merged with oil's defaults: <BS> goes up a directory, like `-`. Splits
    -- mirror tmux's prefix | / -. <C-s> (save), <C-h>/<C-l> (tmux-navigator)
    -- are unmapped so the global maps work in oil; :w applies oil's edits.
    keymaps = {
      ["<BS>"] = { "actions.parent", mode = "n" },
      ["g|"] = { "actions.select", opts = { vertical = true }, mode = "n" },
      ["g-"] = { "actions.select", opts = { horizontal = true }, mode = "n" },
      ["gR"] = { "actions.refresh", mode = "n" },
      ["<C-s>"] = false,
      ["<C-h>"] = false,
      ["<C-l>"] = false,
    },
  })

  -- No path: oil opens the current file's directory, or cwd for non-file buffers.
  vim.keymap.set("n", "<leader>E", function()
    require("oil").open_float()
  end, { desc = "Oil (float)" })

  -- oil sets buflisted=false only on buffer creation; returning to an existing
  -- one with :edit (e.g. toggling trash with g\ twice) relists it, and it then
  -- shows in bufferline. Re-unlist on every entry, for any oil adapter.
  vim.api.nvim_create_autocmd("BufEnter", {
    group = vim.api.nvim_create_augroup("plugins.oil.unlisted", { clear = true }),
    pattern = "oil*://*",
    callback = function(ev)
      vim.bo[ev.buf].buflisted = false
    end,
  })

  -- Any session load: auto-session's restore and :restart's own session.
  vim.api.nvim_create_autocmd("SessionLoadPost", {
    group = vim.api.nvim_create_augroup("plugins.oil.session", { clear = true }),
    callback = scrub_oil_from_session,
  })
end

return M
