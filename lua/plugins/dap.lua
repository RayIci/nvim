---nvim-dap + dap-ui: debugging with adapters registered by language packs.
---VSCode compat: .vscode/launch.json configs are picked up automatically by
---nvim-dap's config providers; overseer runs preLaunchTask/postDebugTask.
---Keymap scheme ported from the old dotfiles config (FN keys + <leader>d tree).
---dap-ui never opens on its own — toggle it with <leader>duu.
---@class PluginDap
local M = {}

---Write all modified buffers before launching/continuing a session.
local function save_all_buffers()
  vim.cmd("silent! wall")
end

---Pick one of the active sessions and focus it.
local function switch_session()
  local dap = require("dap")
  local sessions = dap.sessions()
  if vim.tbl_isempty(sessions) then
    vim.notify("No active debug sessions", vim.log.levels.INFO)
    return
  end

  local session_list = {}
  for id, session in pairs(sessions) do
    table.insert(session_list, { id = id, session = session, name = session.config.name or ("Session " .. id) })
  end

  local current = dap.session()
  vim.ui.select(session_list, {
    prompt = "Select session to focus:",
    format_item = function(item)
      local prefix = (current and current.id == item.id) and "→ " or "  "
      local status = item.session.stopped_thread_id and " [stopped]" or " [running]"
      return prefix .. item.name .. " (id: " .. item.id .. ")" .. status
    end,
  }, function(choice)
    if choice then
      dap.set_session(choice.session)
      vim.notify("Focused: " .. choice.name, vim.log.levels.INFO)
    end
  end)
end

---Focus the next/previous active session in id order.
---@param direction 1|-1
local function cycle_session(direction)
  local dap = require("dap")
  local sessions = dap.sessions()
  if vim.tbl_isempty(sessions) then
    vim.notify("No active debug sessions", vim.log.levels.INFO)
    return
  end

  local session_list = {}
  for id, session in pairs(sessions) do
    table.insert(session_list, { id = id, session = session })
  end
  table.sort(session_list, function(a, b)
    return a.id < b.id
  end)

  local current, current_idx = dap.session(), 1
  if current then
    for i, item in ipairs(session_list) do
      if item.id == current.id then
        current_idx = i
        break
      end
    end
  end

  local target = session_list[((current_idx - 1 + direction) % #session_list) + 1]
  dap.set_session(target.session)
  vim.notify("Focused: " .. (target.session.config.name or ("Session " .. target.id)), vim.log.levels.INFO)
end

---Pick a config for the current filetype and run it (optionally as new session).
---@param opts? { new: boolean }
local function pick_and_run(opts)
  save_all_buffers()
  local dap = require("dap")
  local configs = dap.configurations[vim.bo.filetype] or {}
  if #configs == 0 then
    vim.notify("No debug configurations for " .. vim.bo.filetype, vim.log.levels.WARN)
    return
  end
  vim.ui.select(configs, {
    prompt = opts and opts.new and "Select configuration (NEW session):" or "Select configuration:",
    format_item = function(config)
      return config.name
    end,
  }, function(config)
    if not config then
      return
    end
    if opts and opts.new then
      local new_config = vim.deepcopy(config)
      -- internalConsole avoids terminal-buffer clashes across parallel sessions
      new_config.console = "internalConsole"
      dap.run(new_config, { new = true })
    else
      dap.run(config)
    end
  end)
end

function M.setup()
  local dap = require("dap")
  local dapui = require("dapui")
  local prefs = require("config.prefs")

  dapui.setup()

  -- Inline variable values while debugging; toggle state survives restarts.
  require("nvim-dap-virtual-text").setup({
    virt_text_pos = "eol",
    enabled = prefs.get("dap_virtual_text", true),
  })

  -- No auto-open: the UI is toggled manually (<leader>duu). Closing on session
  -- end stays so a finished session doesn't leave the layout behind.
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

  require("which-key").add({
    { "<leader>db", group = "breakpoints" },
    { "<leader>ds", group = "step" },
    { "<leader>dw", group = "windows" },
    { "<leader>du", group = "ui" },
    { "<leader>dr", group = "repl" },
    { "<leader>dS", group = "sessions" },
    { "<leader>dl", group = "launch" },
  })

  local map = vim.keymap.set

  -- Session control
  map("n", "<leader>dc", function()
    save_all_buffers()
    dap.continue()
  end, { desc = "Continue / start" })
  map("n", "<leader>dR", function()
    save_all_buffers()
    dap.restart()
  end, { desc = "Restart" })
  map("n", "<leader>dp", dap.pause, { desc = "Pause" })
  map("n", "<leader>dC", function()
    save_all_buffers()
    dap.run_to_cursor()
  end, { desc = "Run to cursor" })
  map("n", "<leader>dN", function()
    pick_and_run({ new = true })
  end, { desc = "Start NEW parallel session" })
  map("n", "<leader>dq", dap.terminate, { desc = "Terminate" })
  map("n", "<leader>dQ", function()
    dap.terminate(nil, nil, function()
      dap.close()
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_get_name(buf):match("dap%-terminal") then
          pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end
      end
    end)
  end, { desc = "Force close session" })

  -- FN keys mirror the primary flow
  map("n", "<F5>", function()
    save_all_buffers()
    dap.continue()
  end, { desc = "DAP continue" })
  map("n", "<F9>", dap.step_into, { desc = "DAP step into" })
  map("n", "<F10>", dap.step_over, { desc = "DAP step over" })
  map("n", "<F11>", dap.step_out, { desc = "DAP step out" })

  -- Breakpoints
  map("n", "<leader>dd", dap.toggle_breakpoint, { desc = "Toggle breakpoint" })
  map("n", "<leader>B", dap.toggle_breakpoint, { desc = "Toggle breakpoint" })
  map("n", "<leader>dbb", dap.toggle_breakpoint, { desc = "Toggle breakpoint" })
  map("n", "<leader>dbB", function()
    vim.ui.input({ prompt = "Breakpoint condition: " }, function(condition)
      if condition then
        dap.set_breakpoint(condition)
      end
    end)
  end, { desc = "Conditional breakpoint" })
  map("n", "<leader>dbl", function()
    vim.ui.input({ prompt = "Log point message: " }, function(message)
      if message then
        dap.set_breakpoint(nil, nil, message)
      end
    end)
  end, { desc = "Logpoint" })
  map("n", "<leader>dbc", dap.clear_breakpoints, { desc = "Clear all breakpoints" })
  map("n", "<leader>dbs", function()
    dap.list_breakpoints()
    vim.cmd.copen()
  end, { desc = "List breakpoints (quickfix)" })

  -- Stepping
  map("n", "<leader>dsi", dap.step_into, { desc = "Step into" })
  map("n", "<leader>dso", dap.step_over, { desc = "Step over" })
  map("n", "<leader>dsO", dap.step_out, { desc = "Step out" })
  map("n", "<leader>dsb", dap.step_back, { desc = "Step back" })

  -- Floating UI elements (full-screen, like the old config)
  local float_opts = { enter = true, width = vim.o.columns, height = vim.o.lines }
  for key, element in pairs({ r = "repl", c = "console", s = "scopes", b = "breakpoints", S = "stacks", w = "watches" }) do
    map("n", "<leader>dw" .. key, function()
      dapui.float_element(element, float_opts)
    end, { desc = element:sub(1, 1):upper() .. element:sub(2) })
  end
  map("n", "<leader>dwk", switch_session, { desc = "Switch session" })

  -- UI control
  map("n", "<leader>duu", dapui.toggle, { desc = "Toggle UI" })
  map("n", "<leader>duo", dapui.open, { desc = "Open UI" })
  map("n", "<leader>duc", dapui.close, { desc = "Close UI" })
  map("n", "<leader>dur", function()
    dapui.close()
    dapui.open({ reset = true })
    vim.notify("DAP UI reset", vim.log.levels.INFO)
  end, { desc = "Reset UI layout" })

  -- REPL (closures: dap.repl resolves its functions lazily)
  map("n", "<leader>dro", function()
    dap.repl.open()
  end, { desc = "Open REPL" })
  map("n", "<leader>drc", function()
    dap.repl.close()
  end, { desc = "Close REPL" })
  map("n", "<leader>drr", function()
    dap.repl.toggle()
  end, { desc = "Toggle REPL" })
  map("n", "<leader>drl", function()
    if dap.repl.run_last then
      dap.repl.run_last()
    else
      vim.notify("dap.repl.run_last is not available in this nvim-dap version", vim.log.levels.WARN)
    end
  end, { desc = "REPL run last" })

  -- Multi-session
  map("n", "<leader>dSs", switch_session, { desc = "Switch/list sessions" })
  map("n", "<leader>dSw", function()
    local widgets = require("dap.ui.widgets")
    widgets.centered_float(widgets.sessions)
  end, { desc = "Sessions widget" })
  map("n", "<leader>dSn", function()
    cycle_session(1)
  end, { desc = "Focus next session" })
  map("n", "<leader>dSp", function()
    cycle_session(-1)
  end, { desc = "Focus previous session" })

  -- Launch
  map("n", "<leader>dll", function()
    save_all_buffers()
    dap.run_last()
  end, { desc = "Run last configuration" })
  map("n", "<leader>dlc", pick_and_run, { desc = "Select and run configuration" })
  map("n", "<leader>dln", function()
    pick_and_run({ new = true })
  end, { desc = "New parallel session" })

  -- Evaluation
  map({ "n", "v" }, "<leader>de", function()
    dapui.eval()
  end, { desc = "Eval expression" })
  map("n", "<leader>dE", function()
    vim.ui.input({ prompt = "Expression: " }, function(expr)
      if expr then
        dapui.eval(expr)
      end
    end)
  end, { desc = "Eval custom expression" })
  map("n", "<leader>dh", function()
    require("dap.ui.widgets").hover()
  end, { desc = "Hover variables" })
  map("n", "<leader>dv", function()
    local on = prefs.toggle("dap_virtual_text", true)
    vim.cmd(on and "DapVirtualTextEnable" or "DapVirtualTextDisable")
    vim.notify("DAP virtual text: " .. (on and "on" or "off"))
  end, { desc = "Toggle DAP virtual text (persisted)" })
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
