---Java language pack: jdtls (+ debug bundles, inlay hints, codelens),
---google-java-format, checkstyle, neotest-java, and a :Java command for
---build-tool integration through Overseer.

---@return string root dir of the attached jdtls, or cwd
local function jdtls_root()
  local clients = vim.lsp.get_clients({ name = "jdtls", bufnr = 0 })
  if clients[1] then
    return clients[1].config.root_dir
  end
  return vim.fn.getcwd()
end

---@param cmd string
local function run_build_command(cmd)
  local overseer = require("overseer")
  local task = overseer.new_task({ cmd = cmd })
  task:start()
  overseer.open({ enter = false })
end

---@return string|nil build tool invocation, nil when none detected
local function detect_build_tool()
  local cwd = vim.fn.getcwd()
  if vim.fn.filereadable(cwd .. "/pom.xml") == 1 then
    return "mvn"
  elseif vim.fn.filereadable(cwd .. "/gradlew") == 1 then
    return "./gradlew"
  elseif
    vim.fn.filereadable(cwd .. "/build.gradle") == 1 or vim.fn.filereadable(cwd .. "/build.gradle.kts") == 1
  then
    return "gradle"
  end
end

---@param args string program arguments ("" for none)
local function do_run(args)
  local tool = detect_build_tool()
  local cmd

  if tool == "./gradlew" then
    cmd = args ~= "" and ("./gradlew run --args=" .. vim.fn.shellescape(args)) or "./gradlew run"
  elseif tool == "mvn" then
    cmd = args ~= "" and ("mvn exec:java -Dexec.args=" .. vim.fn.shellescape(args)) or "mvn exec:java"
  elseif tool == "gradle" then
    cmd = args ~= "" and ("gradle run --args=" .. vim.fn.shellescape(args)) or "gradle run"
  else
    local file = vim.api.nvim_buf_get_name(0)
    if file == "" or not file:match("%.java$") then
      vim.notify("Java: no build tool found and current buffer is not a .java file", vim.log.levels.WARN)
      return
    end
    cmd = "java " .. vim.fn.shellescape(file) .. (args ~= "" and (" " .. args) or "")
  end

  vim.notify("Java: running → " .. cmd, vim.log.levels.INFO)
  run_build_command(cmd)
end

---@param subcmd string
---@return fun() handler that runs the detected build tool subcommand
local function build_tool_subcommand(subcmd)
  return function()
    local tool = detect_build_tool()
    if not tool then
      vim.notify("Java: no build tool found (pom.xml / gradlew / build.gradle)", vim.log.levels.WARN)
      return
    end
    vim.notify("Java: running " .. tool .. " " .. subcmd, vim.log.levels.INFO)
    run_build_command(tool .. " " .. subcmd)
  end
end

local java_subcommands = {
  build = build_tool_subcommand("build"),
  clean = build_tool_subcommand("clean"),
  test = build_tool_subcommand("test"),
  organize = function()
    require("jdtls").organize_imports()
  end,
  extractVariable = function()
    require("jdtls").extract_variable()
  end,
  extractMethod = function()
    require("jdtls").extract_method()
  end,
  extractConstant = function()
    require("jdtls").extract_constant()
  end,
  doc = function()
    require("neogen").generate()
  end,
  run = function()
    do_run("")
  end,
  runArguments = function()
    local args = vim.fn.input("Program arguments: ")
    do_run(args)
  end,
  reloadProject = function()
    require("jdtls").update_project_config()
  end,
}

---@type LangPack
return {
  treesitter = { "java" },
  lsp = {
    jdtls = {
      init_options = {
        bundles = vim.tbl_filter(
          function(p)
            return p ~= ""
          end,
          vim.split(
            vim.fn.glob(
              vim.fn.stdpath("data")
                .. "/mason/packages/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar"
            ),
            "\n",
            { trimempty = true }
          )
        ),
      },
      on_attach = function(_, bufnr)
        vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })

        vim.lsp.codelens.refresh()
        vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
          buffer = bufnr,
          callback = vim.lsp.codelens.refresh,
        })

        -- Registers the "java" DAP adapter type; enables hot-code replace
        require("jdtls").setup_dap({ hotcodereplace = "auto" })
      end,
      settings = {
        java = {
          signatureHelp = { enabled = true },
          contentProvider = { preferred = "fernflower" },
          completion = {
            favoriteStaticMembers = {
              "org.junit.Assert.*",
              "org.junit.jupiter.api.Assertions.*",
              "org.mockito.Mockito.*",
            },
            importOrder = { "java", "javax", "com", "org" },
          },
          sources = {
            organizeImports = { starThreshold = 9999, staticStarThreshold = 9999 },
          },
          codeGeneration = {
            toString = { template = "${object.className}{${member.name()}=${member.value}, ...}" },
            useBlocks = true,
          },
          eclipse = { downloadSources = true },
          maven = { downloadSources = true },
          inlayHints = { parameterNames = { enabled = "all" } },
        },
      },
    },
  },
  formatters = { java = { "google-java-format" } },
  linters = { java = { "checkstyle" } },
  mason = { "jdtls", "java-debug-adapter", "google-java-format", "checkstyle" },
  packs = {
    { src = "mfussenegger/nvim-jdtls" },
    { src = "rcasia/neotest-java" },
    { src = "danymat/neogen" },
  },
  ---@param dap table the nvim-dap module
  dap = function(dap)
    dap.configurations.java = {
      {
        type = "java",
        name = "Launch - Current File",
        request = "launch",
        mainClass = "${file}",
        cwd = jdtls_root,
      },
      {
        type = "java",
        name = "Launch - Select Main Class",
        request = "launch",
        mainClass = function()
          return vim.fn.input("Main class (e.g. com.example.Main): ")
        end,
        cwd = jdtls_root,
      },
      {
        type = "java",
        name = "Attach - Remote JVM",
        request = "attach",
        hostName = "localhost",
        port = function()
          return tonumber(vim.fn.input("Debug port [5005]: ", "5005"))
        end,
        cwd = jdtls_root,
      },
    }
  end,
  test = function()
    return require("neotest-java")({
      dap = { justMyCode = false },
    })
  end,
  setup = function()
    require("neogen").setup({})

    vim.api.nvim_create_user_command("Java", function(opts)
      local handler = java_subcommands[opts.args]
      if handler then
        handler()
      else
        vim.notify("Java: unknown subcommand '" .. opts.args .. "'", vim.log.levels.ERROR)
      end
    end, {
      nargs = 1,
      complete = function()
        return vim.tbl_keys(java_subcommands)
      end,
      desc = "Java project commands: build, clean, test, run, runArguments, organize, extractVariable, extractMethod, extractConstant, doc, reloadProject",
    })
  end,
}
