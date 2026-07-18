---nvim-dap + dap-ui: debugging with adapters registered by language packs.
---VSCode compat: .vscode/launch.json configs are picked up automatically by
---nvim-dap's config providers; overseer runs preLaunchTask/postDebugTask.
---@class PluginDap
local M = {}

function M.setup()
  local dap = require("dap")
  local dapui = require("dapui")

  dapui.setup()

  -- Auto open/close the UI with the session lifecycle
  dap.listeners.after.event_initialized["dapui"] = function()
    dapui.open()
  end
  dap.listeners.before.event_terminated["dapui"] = function()
    dapui.close()
  end
  dap.listeners.before.event_exited["dapui"] = function()
    dapui.close()
  end

  -- Nicer breakpoint signs
  vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
  vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticWarn" })
  vim.fn.sign_define("DapLogPoint", { text = "◆", texthl = "DiagnosticInfo" })
  vim.fn.sign_define("DapStopped", { text = "", texthl = "DiagnosticOk", linehl = "Visual" })

  local map = vim.keymap.set
  map("n", "<leader>db", dap.toggle_breakpoint, { desc = "Toggle breakpoint" })
  map("n", "<leader>dB", function()
    dap.set_breakpoint(vim.fn.input("Condition: "))
  end, { desc = "Conditional breakpoint" })
  map("n", "<leader>dl", function()
    dap.set_breakpoint(nil, nil, vim.fn.input("Log message: "))
  end, { desc = "Logpoint" })
  -- .vscode/launch.json configs are read automatically on-demand (:h dap-providers)
  map("n", "<leader>dc", dap.continue, { desc = "Continue / start" })
  map("n", "<leader>do", dap.step_over, { desc = "Step over" })
  map("n", "<leader>di", dap.step_into, { desc = "Step into" })
  map("n", "<leader>dO", dap.step_out, { desc = "Step out" })
  map("n", "<leader>dt", dap.terminate, { desc = "Terminate session" })
  map("n", "<leader>dr", dap.repl.toggle, { desc = "Toggle REPL" })
  map("n", "<leader>du", dapui.toggle, { desc = "Toggle DAP UI" })
  map("n", "<leader>de", function()
    dapui.eval()
  end, { desc = "Eval expression" })
end

---Run each language pack's DAP registrar.
---@param registrars fun(dap: table)[] from the merged language packs
function M.apply(registrars)
  local dap = require("dap")
  for _, register in ipairs(registrars) do
    local ok, err = pcall(register, dap)
    if not ok then
      vim.notify("langs dap: " .. tostring(err), vim.log.levels.ERROR)
    end
  end
end

return M
