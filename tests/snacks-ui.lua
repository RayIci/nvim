-- Run with: nvim --headless -u NONE -l tests/snacks-ui.lua
--
-- The snacks-based UI: find keys and their ignore rules, LSP navigation
-- through pickers (single target jumps, refs + impls finder), and LSP
-- reference jumps with ]] / [[. Uses the installed plugins and a fake
-- in-process language server.
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
local config = vim.fn.getcwd()
vim.env.XDG_STATE_HOME = root .. "/state"
vim.opt.rtp:prepend(config)
vim.o.swapfile = false
vim.o.shadafile = "NONE"
vim.g.mapleader = " "

for _, name in ipairs({ "snacks.nvim", "blink.cmp", "todo-comments.nvim", "plenary.nvim" }) do
  local path = vim.fn.globpath(vim.o.packpath, "pack/*/opt/" .. name)
  assert(path ~= "", "Missing installed test dependency: " .. name)
  vim.opt.rtp:append(path)
end

require("plugins.snacks").setup()
require("plugins.todo-comments").setup()
require("plugins.lsp").setup()

local passed, failed = 0, 0
local function test(name, fn)
  local ok, err = xpcall(fn, debug.traceback)
  if ok then
    passed = passed + 1
    io.stdout:write("ok " .. passed + failed .. " - " .. name .. "\n")
  else
    failed = failed + 1
    io.stdout:write("not ok " .. passed + failed .. " - " .. name .. "\n" .. err .. "\n")
  end
  for _, p in ipairs(Snacks.picker.get({ tab = false })) do
    p:close()
  end
end

local function equal(expected, actual)
  assert(
    vim.deep_equal(expected, actual),
    ("expected %s, got %s"):format(vim.inspect(expected), vim.inspect(actual))
  )
end

---Run a picker until its finder is done and return it.
local function run(picker)
  assert(vim.wait(5000, function()
    return not picker.finder:running() and picker.list:count() > 0
  end, 20), "picker found nothing")
  return picker
end

test("find, grep, notification and reference keys exist with descriptions", function()
  for _, lhs in ipairs({ " ", "ff", "fg", "fb", "fh", "fr", "fw", "fd", "fk", "fs", "ft", "fn" }) do
    local key = lhs == " " and "<leader><leader>" or "<leader>" .. lhs
    local m = vim.fn.maparg(key, "n", false, true)
    assert(m.desc and m.desc ~= "", "missing or undescribed " .. key)
  end
  for _, key in ipairs({ "<leader>un", "]]", "[[" }) do
    assert(vim.fn.maparg(key, "n", false, true).desc, "missing " .. key)
  end
end)

test("find-files lists hidden files and skips dependency folders", function()
  local dir = root .. "/project"
  vim.fn.mkdir(dir .. "/node_modules/pkg", "p")
  vim.fn.mkdir(dir .. "/src", "p")
  vim.fn.writefile({ "x" }, dir .. "/.hidden")
  vim.fn.writefile({ "x" }, dir .. "/src/main.lua")
  vim.fn.writefile({ "x" }, dir .. "/node_modules/pkg/index.js")
  local picker = run(Snacks.picker.files({ cwd = dir }))
  local files = vim.tbl_map(function(item)
    return item.file
  end, picker:items())
  table.sort(files)
  equal({ ".hidden", "src/main.lua" }, files)
end)

---Fake server answering navigation and highlight requests from `answers`.
---@param answers table<string, any>
local function start_server(buf, answers)
  local function fake(dispatchers)
    local closing, id = false, 0
    return {
      request = function(method, _, callback, notify_reply)
        id = id + 1
        local rid = id
        local result
        if method == "initialize" then
          result = {
            capabilities = {
              definitionProvider = true,
              referencesProvider = true,
              implementationProvider = true,
              documentHighlightProvider = true,
            },
          }
        else
          result = answers[method]
        end
        vim.schedule(function()
          if notify_reply then
            notify_reply(rid)
          end
          callback(nil, result, rid)
        end)
        return true, rid
      end,
      notify = function(method)
        if method == "exit" then
          dispatchers.on_exit(0, 15)
        end
        return true
      end,
      is_closing = function()
        return closing
      end,
      terminate = function()
        closing = true
      end,
    }
  end
  local id = assert(vim.lsp.start({ name = "fake", cmd = fake, root_dir = root }, { bufnr = buf }))
  assert(vim.wait(2000, function()
    return #vim.lsp.get_clients({ bufnr = buf }) > 0 and vim.fn.maparg("gd", "n", false, true).buffer == 1
  end, 10), "fake server did not attach")
  return id
end

local file = root .. "/code.lua"
vim.fn.writefile({ "local value = 1", "print(value)", "", "return value" }, file)
vim.cmd.edit(file)
local buf = vim.api.nvim_get_current_buf()
local uri = vim.uri_from_fname(file)
local function loc(line, col)
  return { uri = uri, range = { start = { line = line, character = col }, ["end"] = { line = line, character = col + 5 } } }
end
local client_id = start_server(buf, {
  ["textDocument/definition"] = { loc(0, 6) },
  ["textDocument/references"] = { loc(1, 6), loc(3, 7) },
  ["textDocument/implementation"] = { loc(0, 6) },
  ["textDocument/documentHighlight"] = {
    { range = loc(0, 6).range, kind = 1 },
    { range = loc(1, 6).range, kind = 2 },
  },
})

test("gd with a single definition jumps without a picker", function()
  vim.api.nvim_win_set_cursor(0, { 4, 8 })
  vim.api.nvim_feedkeys("gd", "mx", false)
  assert(vim.wait(3000, function()
    return vim.api.nvim_win_get_cursor(0)[1] == 1
  end, 20), "cursor did not reach the definition")
  equal({ 1, 6 }, vim.api.nvim_win_get_cursor(0))
  equal(0, #Snacks.picker.get({ tab = false }))
end)

test("<leader>lf lists references and implementations, tagged by kind", function()
  -- Away from every result: snacks hides the location under the cursor.
  vim.api.nvim_win_set_cursor(0, { 3, 0 })
  vim.api.nvim_feedkeys(" lf", "mx", false)
  local picker
  assert(vim.wait(3000, function()
    picker = Snacks.picker.get({ tab = false })[1]
    return picker ~= nil and not picker.finder:running() and picker.list:count() == 3
  end, 20), "finder did not list three items: " .. vim.inspect(picker and vim.tbl_map(function(i)
    return { i.source_id, i.pos }
  end, picker:items())))
  local by_source = {}
  for _, item in ipairs(picker:items()) do
    by_source[item.source_id] = (by_source[item.source_id] or 0) + 1
  end
  equal({ 2, 1 }, by_source)
end)

test("]] jumps to the next reference of the symbol under the cursor", function()
  vim.api.nvim_win_set_cursor(0, { 1, 7 })
  vim.lsp.buf.document_highlight()
  assert(vim.wait(2000, function()
    return #require("snacks.words").get() == 2
  end, 20), "no document highlights")
  vim.api.nvim_feedkeys("]]", "mx", false)
  equal({ 2, 6 }, vim.api.nvim_win_get_cursor(0))
  vim.api.nvim_feedkeys("[[", "mx", false)
  equal(1, vim.api.nvim_win_get_cursor(0)[1])
end)

vim.lsp.get_client_by_id(client_id):stop(true)
io.stdout:write(("%d passed, %d failed\n"):format(passed, failed))
vim.cmd(failed > 0 and "cquit" or "qall!")
