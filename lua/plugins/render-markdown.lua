---render-markdown.nvim: formatted markdown in markdown buffers and in blink.cmp
---documentation/signature windows. Hover floats need no plugin — Neovim 0.12
---renders them with treesitter natively.
---@class PluginRenderMarkdown
local M = {}

---blink reuses one buffer for its docs window while cycling candidates, so a
---FileType hook alone renders only the first candidate. Attach a listener that
---re-renders on every content change (debounced second pass for late edits).
---@param buf integer
local function attach_rerender(buf)
  local timer = assert(vim.uv.new_timer())

  local function safe_render()
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_line_count(buf) > 0 then
      pcall(require("render-markdown.api").render, { buf = buf })
    end
  end

  vim.schedule(safe_render)
  vim.api.nvim_buf_attach(buf, false, {
    on_lines = function()
      vim.schedule(safe_render)
      timer:stop()
      timer:start(200, 0, vim.schedule_wrap(safe_render))
    end,
    on_detach = function()
      if not timer:is_closing() then
        timer:stop()
        timer:close()
      end
    end,
  })
end

function M.setup()
  -- Let treesitter parse blink's scratch buffers as markdown
  vim.treesitter.language.register("markdown", "blink-cmp-documentation")
  vim.treesitter.language.register("markdown", "blink-cmp-signature")

  require("render-markdown").setup({
    file_types = { "markdown", "blink-cmp-documentation", "blink-cmp-signature" },
    render_modes = { "n", "c", "t", "i" },
    anti_conceal = { enabled = true, above = 1, below = 1 },
    completions = { blink = { enabled = true } },
    code = { conceal_delimiters = false, position = "left" },
    overrides = {
      buftype = {
        nofile = {
          render_modes = true,
          padding = { highlight = "NormalFloat" },
          sign = { enabled = false },
          anti_conceal = { enabled = false },
        },
      },
    },
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("config.render-markdown.blink", { clear = true }),
    pattern = { "blink-cmp-documentation", "blink-cmp-signature" },
    callback = function(args)
      attach_rerender(args.buf)
    end,
  })
end

return M
