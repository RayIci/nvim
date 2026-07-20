---Kotlin language pack: kotlin_language_server (under Java 21), ktlint,
---kotlin-debug-adapter, neotest-java (shared with the java pack), and a
---:Kotlin command for build-tool integration through Overseer.

---KLS 1.3.13 bundles an IntelliJ JavaVersion.parse() that crashes on Java 25+
---(two-digit major version). Run it under Java 21 via SDKMAN if available.
---@return string|nil java_home
local function find_sdkman_java21()
  local matches = vim.fn.glob(vim.fn.expand("~/.sdkman/candidates/java/21*/bin/java"), false, true)
  if #matches > 0 then
    return vim.fn.fnamemodify(matches[1], ":h:h")
  end
end

---@return string root dir of the attached KLS, or cwd
local function kotlin_root()
  local clients = vim.lsp.get_clients({ name = "kotlin_language_server", bufnr = 0 })
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
  if vim.fn.filereadable(cwd .. "/gradlew") == 1 then
    return "./gradlew"
  elseif
    vim.fn.filereadable(cwd .. "/build.gradle.kts") == 1 or vim.fn.filereadable(cwd .. "/build.gradle") == 1
  then
    return "gradle"
  elseif vim.fn.filereadable(cwd .. "/pom.xml") == 1 then
    return "mvn"
  end
end

---@param args string program arguments ("" for none)
local function do_run(args)
  local tool = detect_build_tool()
  if not tool then
    vim.notify("Kotlin: no build tool found (gradlew / build.gradle.kts / pom.xml)", vim.log.levels.WARN)
    return
  end

  local cmd
  if tool == "./gradlew" or tool == "gradle" then
    cmd = args ~= "" and (tool .. " run --args=" .. vim.fn.shellescape(args)) or (tool .. " run")
  elseif tool == "mvn" then
    cmd = args ~= "" and ("mvn exec:java -Dexec.args=" .. vim.fn.shellescape(args)) or "mvn exec:java"
  end

  vim.notify("Kotlin: running → " .. cmd, vim.log.levels.INFO)
  run_build_command(cmd)
end

---@param subcmd string
---@return fun() handler that runs the detected build tool subcommand
local function build_tool_subcommand(subcmd)
  return function()
    local tool = detect_build_tool()
    if not tool then
      vim.notify("Kotlin: no build tool found", vim.log.levels.WARN)
      return
    end
    vim.notify("Kotlin: running " .. tool .. " " .. subcmd, vim.log.levels.INFO)
    run_build_command(tool .. " " .. subcmd)
  end
end

local kotlin_subcommands = {
  build = build_tool_subcommand("build"),
  clean = build_tool_subcommand("clean"),
  test = build_tool_subcommand("test"),
  run = function()
    do_run("")
  end,
  runArguments = function()
    local args = vim.fn.input("Program arguments: ")
    do_run(args)
  end,
}

local kls_java_home = find_sdkman_java21()

---@type LangPack
return {
  treesitter = { "kotlin" },
  lsp = {
    kotlin_language_server = {
      cmd = kls_java_home and { "env", "JAVA_HOME=" .. kls_java_home, "kotlin-language-server" }
        or { "kotlin-language-server" },
      root_markers = {
        "settings.gradle.kts",
        "settings.gradle",
        "build.gradle.kts",
        "build.gradle",
        "pom.xml",
        ".git",
      },
    },
  },
  formatters = { kotlin = { "ktlint" } },
  linters = { kotlin = { "ktlint" } },
  mason = { "kotlin-language-server", "kotlin-debug-adapter", "ktlint" },
  packs = {
    { src = "rcasia/neotest-java" },
  },
  ---@param dap table the nvim-dap module
  dap = function(dap)
    dap.adapters.kotlin = {
      type = "executable",
      command = vim.fn.stdpath("data")
        .. "/mason/packages/kotlin-debug-adapter/adapter/bin/kotlin-debug-adapter",
    }
    dap.configurations.kotlin = {
      {
        type = "kotlin",
        name = "Launch - Select Main Class",
        request = "launch",
        mainClass = function()
          return vim.fn.input("Main class (e.g. com.example.MainKt): ")
        end,
        projectRoot = kotlin_root,
      },
      {
        type = "kotlin",
        name = "Attach - Remote JVM",
        request = "attach",
        hostName = "localhost",
        port = function()
          return tonumber(vim.fn.input("Debug port [5005]: ", "5005"))
        end,
        projectRoot = kotlin_root,
      },
    }
  end,
  test = function()
    return require("neotest-java")({
      dap = { justMyCode = false },
    })
  end,
  setup = function()
    if not kls_java_home then
      vim.notify(
        "kotlin-language-server: no Java 21 found in SDKMAN — run `sdk install java 21.0.5-tem`. KLS will crash on Java 25.",
        vim.log.levels.WARN
      )
    end

    vim.api.nvim_create_user_command("Kotlin", function(opts)
      local handler = kotlin_subcommands[opts.args]
      if handler then
        handler()
      else
        vim.notify("Kotlin: unknown subcommand '" .. opts.args .. "'", vim.log.levels.ERROR)
      end
    end, {
      nargs = 1,
      complete = function()
        return vim.tbl_keys(kotlin_subcommands)
      end,
      desc = "Kotlin project commands: build, clean, test, run, runArguments",
    })
  end,
}
