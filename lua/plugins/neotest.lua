---neotest: test running with per-language adapters from language packs.
---setup() registers keymaps; apply() resolves pack adapter factories and runs
---the real neotest.setup (deferred so adapter plugins are installed first).
---@class PluginNeotest
local M = {}

function M.setup()
  local wk = require("which-key")
  wk.add({
    { "<leader>t", group = "Test (Neotest)" },
    { "<leader>td", group = "Debug" },
    { "<leader>to", group = "Output" },
    { "<leader>tn", group = "Navigate" },
    { "<leader>tw", group = "Watch" },
  })

  ---@param lhs string
  ---@param rhs fun()
  ---@param desc string
  local function map(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { desc = desc })
  end

  -- Run
  map("<leader>tr", function()
    require("neotest").run.run()
  end, "Run nearest test")
  map("<leader>tf", function()
    require("neotest").run.run(vim.fn.expand("%"))
  end, "Run current file")
  map("<leader>ta", function()
    require("neotest").run.run(vim.fn.getcwd())
  end, "Run all tests")
  map("<leader>tl", function()
    require("neotest").run.run_last()
  end, "Run last test")
  map("<leader>tS", function()
    require("neotest").run.stop()
  end, "Stop nearest test")
  map("<leader>tA", function()
    require("neotest").run.attach()
  end, "Attach to nearest test")

  -- Debug (DAP strategy)
  map("<leader>tdd", function()
    require("neotest").run.run({ strategy = "dap" })
  end, "Debug nearest test")
  map("<leader>tdf", function()
    require("neotest").run.run({ vim.fn.expand("%"), strategy = "dap" })
  end, "Debug current file")
  map("<leader>tdl", function()
    require("neotest").run.run_last({ strategy = "dap" })
  end, "Debug last test")

  -- Output
  map("<leader>too", function()
    require("neotest").output.open({ enter = true })
  end, "Show output")
  map("<leader>tot", function()
    require("neotest").output_panel.toggle()
  end, "Toggle output panel")
  map("<leader>toO", function()
    require("neotest").output_panel.open()
  end, "Open output panel")
  map("<leader>toc", function()
    require("neotest").output_panel.close()
  end, "Close output panel")
  map("<leader>toC", function()
    require("neotest").output_panel.clear()
  end, "Clear output panel")

  -- Summary
  map("<leader>ts", function()
    require("neotest").summary.toggle()
  end, "Toggle summary")

  -- Navigation
  map("<leader>tnn", function()
    require("neotest").jump.next()
  end, "Jump to next test")
  map("<leader>tnp", function()
    require("neotest").jump.prev()
  end, "Jump to previous test")
  map("<leader>tnf", function()
    require("neotest").jump.next({ status = "failed" })
  end, "Jump to next failed")
  map("<leader>tnF", function()
    require("neotest").jump.prev({ status = "failed" })
  end, "Jump to previous failed")
  map("]t", function()
    require("neotest").jump.next()
  end, "Next test")
  map("[t", function()
    require("neotest").jump.prev()
  end, "Previous test")
  map("]T", function()
    require("neotest").jump.next({ status = "failed" })
  end, "Next failed test")
  map("[T", function()
    require("neotest").jump.prev({ status = "failed" })
  end, "Previous failed test")

  -- Watch
  map("<leader>tww", function()
    require("neotest").watch.toggle()
  end, "Toggle watch nearest")
  map("<leader>twf", function()
    require("neotest").watch.toggle(vim.fn.expand("%"))
  end, "Toggle watch file")
  map("<leader>twa", function()
    require("neotest").watch.toggle(vim.fn.getcwd())
  end, "Toggle watch all")

  -- Status / diagnostics
  map("<leader>ti", function()
    require("neotest").status.open()
  end, "Show test status")
  map("<leader>tD", function()
    require("neotest").diagnostics.open()
  end, "Show diagnostics")

  -- Close neotest windows with q
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("config.neotest.close", { clear = true }),
    pattern = { "neotest-output", "neotest-summary", "neotest-output-panel" },
    callback = function(event)
      vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true })
    end,
  })
end

---Resolve adapter factories from language packs and run neotest.setup.
---@param factories (fun(): table|table[])[] from the merged language packs
function M.apply(factories)
  ---@type table[]
  local adapters = {}
  ---@type table<string, boolean>
  local seen = {}
  ---Multiple packs may register the same adapter (java + kotlin both use
  ---neotest-java); keep the first of each name.
  ---@param adapter table
  local function add(adapter)
    local name = adapter.name or tostring(adapter)
    if not seen[name] then
      seen[name] = true
      adapters[#adapters + 1] = adapter
    end
  end
  for _, factory in ipairs(factories) do
    local ok, result = pcall(factory)
    if not ok then
      vim.notify("neotest adapter: " .. tostring(result), vim.log.levels.ERROR)
    elseif vim.islist(result) then
      for _, adapter in ipairs(result) do
        add(adapter)
      end
    else
      add(result)
    end
  end

  require("neotest").setup({
    adapters = adapters,
    consumers = {
      overseer = require("neotest.consumers.overseer"),
    },
    floating = {
      border = "rounded",
      max_height = 0.6,
      max_width = 0.6,
    },
    summary = {
      open = "botright vsplit | vertical resize 50",
      mappings = {
        expand = { "<CR>", "<2-LeftMouse>" },
        expand_all = "e",
        jumpto = "i",
        output = "o",
        run = "r",
        short = "O",
        stop = "u",
      },
    },
    icons = {
      passed = "✓",
      failed = "✗",
      running = "●",
      skipped = "○",
      unknown = "?",
    },
  })
end

return M
