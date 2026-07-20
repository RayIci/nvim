---.NET (C#) language pack: roslyn LSP via roslyn.nvim + easy-dotnet.nvim,
---csharpier formatting, netcoredbg DAP, neotest-dotnet, and solution-selection
---commands. easy-dotnet's builtin LSP is disabled; roslyn.nvim owns the server.

local DotnetUtils = {}

---Find the .NET project root by searching upward for a .csproj.
---@param start_path string
---@return string|nil
function DotnetUtils.find_project_root_by_csproj(start_path)
  local Path = require("plenary.path")
  local path = Path:new(start_path)

  while true do
    local csproj_files = vim.fn.glob(path:absolute() .. "/*.csproj", false, true)
    if #csproj_files > 0 then
      return path:absolute()
    end

    local parent = path:parent()
    if parent:absolute() == path:absolute() then
      return nil
    end

    path = parent
  end
end

---Highest netX.Y folder within a bin/Debug path (e.g. net9.0 over net8.0).
---@param bin_debug_path string
---@return string
function DotnetUtils.get_highest_net_folder(bin_debug_path)
  local dirs = vim.fn.glob(bin_debug_path .. "/net*", false, true)

  if #dirs == 0 then
    error("No netX.Y folders found in " .. bin_debug_path)
  end

  table.sort(dirs, function(a, b)
    local ver_a = tonumber(a:match("net(%d+%.%d+)") or "0")
    local ver_b = tonumber(b:match("net(%d+%.%d+)") or "0")
    return ver_a > ver_b
  end)

  return dirs[1]
end

---Build and return the full path to the .dll for debugging.
---@return string
function DotnetUtils.build_dll_path()
  local current_file = vim.api.nvim_buf_get_name(0)
  local current_dir = vim.fn.fnamemodify(current_file, ":p:h")

  local project_root = DotnetUtils.find_project_root_by_csproj(current_dir)
  if not project_root then
    error("Could not find project root (no .csproj found)")
  end

  local csproj_files = vim.fn.glob(project_root .. "/*.csproj", false, true)
  if #csproj_files == 0 then
    error("No .csproj file found in project root")
  end

  local project_name = vim.fn.fnamemodify(csproj_files[1], ":t:r")
  local bin_debug_path = project_root .. "/bin/Debug"
  local highest_net_folder = DotnetUtils.get_highest_net_folder(bin_debug_path)
  local dll_path = highest_net_folder .. "/" .. project_name .. ".dll"

  vim.notify("Launching: " .. dll_path, vim.log.levels.INFO)
  return dll_path
end

---@param path string directory to search for solution files
---@return string|nil
local function search_solution_in_path(path)
  local grep_cmd = "rg --files --glob='*.sln' --glob='*.slnx' " .. path
  local results = vim.fn.systemlist(grep_cmd)
  if #results == 1 then
    return results[1]
  elseif #results > 1 then
    vim.notify(
      "Multiple solution files found in " .. path .. ", please select one manually",
      vim.log.levels.WARN
    )
    return nil
  end
  return nil
end

---Search upward from start_path (stopping at cwd or /) for a solution file.
---@param start_path string
---@return string|nil
local function search_solution_upwards(start_path)
  local cwd = vim.fn.getcwd()
  local current_dir = start_path

  local solution_path = search_solution_in_path(current_dir)
  if solution_path ~= nil then
    return solution_path
  end

  while current_dir ~= "/" and current_dir ~= "" and current_dir ~= cwd do
    solution_path = search_solution_in_path(current_dir)
    if solution_path ~= nil then
      return solution_path
    end
    current_dir = vim.fn.fnamemodify(current_dir, ":h")
  end

  return nil
end

local function register_commands()
  vim.api.nvim_create_user_command("SolutionSelect", function()
    local cwd = vim.fn.getcwd()
    local grep_cmd = "rg --files --glob='*.sln' --glob='*.slnx' " .. cwd
    local results = vim.fn.systemlist(grep_cmd)

    if #results == 0 then
      vim.notify("No solution files found in " .. cwd, vim.log.levels.WARN)
      return
    end

    require("telescope.pickers")
      .new({}, {
        prompt_title = "Select .NET Solution",
        finder = require("telescope.finders").new_table({
          results = results,
          entry_maker = function(entry)
            return {
              value = entry,
              display = vim.fn.fnamemodify(entry, ":t"),
              ordinal = vim.fn.fnamemodify(entry, ":t"),
            }
          end,
        }),
        sorter = require("telescope.sorters").get_generic_fuzzy_sorter(),
        attach_mappings = function(prompt_bufnr)
          local actions = require("telescope.actions")
          actions.select_default:replace(function()
            actions.close(prompt_bufnr)
            local selection = require("telescope.actions.state").get_selected_entry()
            if selection then
              vim.cmd("Dotnet solution select " .. selection.value)
            end
          end)
          return true
        end,
      })
      :find()
  end, { desc = "Select .NET solution file in current directory" })

  vim.api.nvim_create_user_command("SolutionAutoSelect", function()
    local current_file = vim.api.nvim_buf_get_name(0)
    local current_dir = vim.fn.fnamemodify(current_file, ":p:h")

    local solution_path = search_solution_upwards(current_dir)
    if solution_path ~= nil then
      vim.cmd("Dotnet solution select " .. solution_path)
      return
    end

    vim.notify("No solution files found in current directory or any parent directories", vim.log.levels.WARN)
  end, { desc = "Automatically select .NET solution file by searching upwards from current file" })

  -- Auto-select the nearest solution when entering a .cs buffer (toggleable).
  vim.api.nvim_create_autocmd("BufEnter", {
    group = vim.api.nvim_create_augroup("langs.dotnet.autoselect", { clear = true }),
    pattern = "*.cs",
    callback = function()
      if vim.g.auto_select_solution == false then
        return
      end

      local easy_dotnet = require("easy-dotnet")
      local current_solution = easy_dotnet.try_get_selected_solution()
      local current_solution_path = current_solution and current_solution["path"] or nil

      local current_file = vim.api.nvim_buf_get_name(0)
      local current_dir = vim.fn.fnamemodify(current_file, ":p:h")
      local new_solution_path = search_solution_upwards(current_dir)

      if new_solution_path ~= nil and new_solution_path ~= current_solution_path then
        vim.cmd("Dotnet solution select " .. new_solution_path)
      end
    end,
  })

  require("which-key").add({ { "<leader>-s", group = "C# Solution" } })

  vim.keymap.set("n", "<leader>-st", function()
    if vim.g.auto_select_solution == nil then
      vim.g.auto_select_solution = true
    else
      vim.g.auto_select_solution = not vim.g.auto_select_solution
    end
    vim.notify(
      "Auto solution select: " .. (vim.g.auto_select_solution and "ON" or "OFF"),
      vim.log.levels.INFO
    )
  end, { desc = "Toggle auto solution select" })

  vim.keymap.set(
    "n",
    "<leader>-ss",
    "<cmd>SolutionSelect<cr>",
    { desc = "Manually select .NET solution file" }
  )
  vim.keymap.set(
    "n",
    "<leader>-sS",
    "<cmd>SolutionAutoSelect<cr>",
    { desc = "Auto-select .NET solution (search upward)" }
  )
end

-- roslyn.nvim and easy-dotnet spawn the `dotnet` CLI; without the SDK their
-- setup throws at startup ("'dotnet' is not executable"). Gate that wiring so
-- the pack stays silent on machines without .NET (mason still installs tools).
local has_dotnet = vim.fn.executable("dotnet") == 1

---@type LangPack
return {
  treesitter = { "c_sharp" },
  lsp = has_dotnet and { roslyn = {} } or {},
  formatters = { cs = { "csharpier" } },
  -- The roslyn server is the mason package `roslyn-language-server` (mason
  -- renamed it from `roslyn`); the LSP-server name below stays `roslyn`.
  mason = { "roslyn-language-server", "csharpier", "netcoredbg" },
  packs = {
    { src = "seblyng/roslyn.nvim" },
    { src = "GustavEikaas/easy-dotnet.nvim" },
    { src = "Issafalcon/neotest-dotnet" },
  },
  completion = {
    default = { "easy-dotnet" },
    providers = {
      ["easy-dotnet"] = {
        name = "easy-dotnet",
        enabled = true,
        module = "easy-dotnet.completion.blink",
        score_offset = 10000,
        async = true,
      },
    },
  },
  ---@param dap table the nvim-dap module
  dap = function(dap)
    local adapter = {
      type = "executable",
      command = "netcoredbg",
      args = { "--interpreter=vscode" },
    }
    dap.adapters.coreclr = adapter
    dap.adapters.netcoredbg = adapter

    dap.configurations.cs = {
      {
        type = "coreclr",
        name = "Launch - netcoredbg",
        request = "launch",
        program = function()
          return DotnetUtils.build_dll_path()
        end,
      },
      {
        type = "coreclr",
        name = "Attach - netcoredbg",
        request = "attach",
        processId = function()
          return require("dap.utils").pick_process()
        end,
      },
      {
        type = "coreclr",
        name = "Launch (with args) - netcoredbg",
        request = "launch",
        program = function()
          return DotnetUtils.build_dll_path()
        end,
        args = function()
          local args_string = vim.fn.input("Program arguments: ")
          return vim.split(args_string, " +")
        end,
      },
    }
  end,
  test = function()
    return require("neotest-dotnet")({
      dap = {
        args = { justMyCode = false },
      },
    })
  end,
  setup = function()
    -- csharpier's conform args don't need the SDK; set them regardless so
    -- formatting is configured even before .NET is installed.
    -- (--stdin-path lets csharpier find .editorconfig; without it, defaults.)
    require("conform").formatters.csharpier = {
      args = { "format", "--stdin-path", "$FILENAME" },
    }

    -- Everything below spawns `dotnet`. When the SDK is absent, skip it (so
    -- roslyn.nvim/easy-dotnet don't throw a raw "not executable" error that
    -- forces the hit-enter prompt) and surface a non-blocking reminder toast
    -- instead — deferred vim.notify goes through noice and never prompts.
    if not has_dotnet then
      vim.schedule(function()
        vim.notify(
          "dotnet not found — C#/roslyn tooling disabled. Install the .NET SDK to enable it.",
          vim.log.levels.WARN
        )
      end)
      return
    end

    require("roslyn").setup({})

    require("easy-dotnet").setup({
      lsp = {
        enabled = false, -- roslyn.nvim owns the LSP
      },
    })

    register_commands()
  end,
}
