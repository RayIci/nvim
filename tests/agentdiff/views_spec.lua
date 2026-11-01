local H = require("helpers")

local function scene(before, after, opts)
  for rel, text in pairs(before) do
    H.write(rel, text)
  end
  local agentdiff = H.start(opts)
  for rel, text in pairs(after) do
    H.write(rel, text)
  end
  H.poll()
  return agentdiff
end

describe("panel", function()
  it("lists files with status and counts (Panel lists counts)", function()
    local agentdiff = scene(
      { ["a.lua"] = "1\n2\n4\n" },
      { ["a.lua"] = "1\nX\nY\nZ\n4\n", ["b.lua"] = H.numbered(20) }
    )
    agentdiff.panel()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    ok(vim.tbl_contains(lines, "M a.lua  +3 −1"), vim.inspect(lines))
    ok(vim.tbl_contains(lines, "A b.lua  +20 −0"), vim.inspect(lines))
    eq("agentdiff  2 files · 2 changes", lines[1])
  end)

  it("opens a file at its first change (Open from the panel)", function()
    local agentdiff = scene(
      { ["a.lua"] = H.numbered(10) },
      { ["a.lua"] = (H.numbered(10):gsub("l7\n", "A7\n")) }
    )
    agentdiff.panel()
    local panel_win = vim.api.nvim_get_current_win()
    local row
    for i, l in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
      if l:find("a.lua", 1, true) then
        row = i
      end
    end
    vim.api.nvim_win_set_cursor(0, { row, 0 })
    vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
    ok(vim.api.nvim_get_current_win() ~= panel_win, "left the panel")
    eq("a.lua", vim.fn.expand("%:t"))
    eq(7, vim.api.nvim_win_get_cursor(0)[1])
  end)

  it("keeps and undoes files from the panel", function()
    local agentdiff = scene(
      { ["a.lua"] = "a\n", ["b.lua"] = "b\n" },
      { ["a.lua"] = "A\n", ["b.lua"] = "B\n" }
    )
    agentdiff.panel()
    local function goto_file(name)
      for i, l in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
        if l:find(" " .. name, 1, true) then
          vim.api.nvim_win_set_cursor(0, { i, 0 })
        end
      end
    end
    goto_file("a.lua")
    vim.api.nvim_feedkeys("K", "x", false)
    goto_file("b.lua")
    vim.api.nvim_feedkeys("U", "x", false)
    H.poll()
    eq({}, H.pending())
    eq("A\n", H.read("a.lua"))
    eq("b\n", H.read("b.lua"))
  end)

  it("updates when pending changes change", function()
    local agentdiff = scene({ ["a.lua"] = "a\n" }, { ["a.lua"] = "A\n" })
    agentdiff.panel()
    local buf = vim.api.nvim_get_current_buf()
    H.write("c.lua", "new\n")
    H.poll()
    local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    ok(text:find("A c.lua", 1, true), text)
  end)
end)

describe("side-by-side", function()
  it("shows a read-only baseline next to the file in diff mode and toggles back (Toggle the view)", function()
    local agentdiff = scene({ ["s.lua"] = "a\nold\nc\n" }, { ["s.lua"] = "a\nnew\nc\n" })
    local buf = H.edit("s.lua")
    local file_win = vim.api.nvim_get_current_win()
    agentdiff.toggle_view()
    local wins = vim.api.nvim_tabpage_list_wins(0)
    eq(2, #wins)
    local base_win = wins[1] == file_win and wins[2] or wins[1]
    local base_buf = vim.api.nvim_win_get_buf(base_win)
    eq({ "a", "old", "c" }, vim.api.nvim_buf_get_lines(base_buf, 0, -1, false))
    eq(false, vim.bo[base_buf].modifiable)
    ok(vim.wo[base_win].diff and vim.wo[file_win].diff, "both windows in diff mode")
    eq(0, #vim.api.nvim_buf_get_extmarks(buf, require("agentdiff.render").ns, 0, -1, {}), "overlay hidden")
    -- keep works in this view, from the file window
    vim.api.nvim_win_set_cursor(file_win, { 2, 0 })
    agentdiff.keep()
    eq({}, H.pending())
    eq({ "a", "new", "c" }, vim.api.nvim_buf_get_lines(base_buf, 0, -1, false), "baseline window follows")
    agentdiff.toggle_view()
    eq(1, #vim.api.nvim_tabpage_list_wins(0))
    ok(not vim.wo[file_win].diff)
  end)

  it("undoes from the baseline window", function()
    local agentdiff = scene({ ["u.lua"] = "a\nold\nc\n" }, { ["u.lua"] = "a\nnew\nc\n" })
    H.edit("u.lua")
    agentdiff.toggle_view()
    local base_win = vim.fn.win_getid(1)
    vim.api.nvim_set_current_win(base_win)
    ok(vim.b.agentdiff_baseline_of ~= nil, "in the baseline window")
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    agentdiff.undo()
    eq("a\nold\nc\n", H.read("u.lua"))
  end)
end)

describe("binary and oversized files", function()
  it("lists binary files without an overlay, kept or undone whole (Binary file changed)", function()
    local agentdiff = scene({ ["logo.png"] = "\137PNG\0\1\2" }, { ["logo.png"] = "\137PNG\0\9\9\9" })
    eq({ "binary logo.png +0 -0 #0" }, H.pending())
    local buf = H.edit("logo.png")
    eq(0, #vim.api.nvim_buf_get_extmarks(buf, require("agentdiff.render").ns, 0, -1, {}))
    agentdiff.undo({ scope = "hunk" })
    eq("\137PNG\0\1\2", H.read("logo.png"), "undone as a whole file")
    H.poll()
    eq({}, H.pending())
  end)

  it("treats files above the size limit as whole files", function()
    local agentdiff = scene(
      { ["big.txt"] = ("x"):rep(200) .. "\n" },
      { ["big.txt"] = ("y"):rep(200) .. "\n" },
      {
        max_file_size = 100,
      }
    )
    eq({ "binary big.txt +0 -0 #0" }, H.pending())
    agentdiff.keep({ path = "big.txt" })
    eq({}, H.pending())
  end)
end)

describe("command, event and status", function()
  it("completes subcommand names (Subcommand completion)", function()
    H.start()
    local got = vim.fn.getcompletion("Agentdiff ", "cmdline")
    for _, n in ipairs({ "keep", "undo", "next", "prev", "panel", "view", "overlay", "resolve" }) do
      ok(vim.tbl_contains(got, n), n .. " in " .. vim.inspect(got))
    end
    eq({ "keep", "keep_all", "keep_file" }, vim.fn.getcompletion("Agentdiff ke", "cmdline"))
  end)

  it("runs actions through :Agentdiff, with a range", function()
    H.write("c.lua", H.numbered(9))
    H.start()
    H.write("c.lua", (H.numbered(9):gsub("l9\n", "l9\nn10\nn11\n")))
    H.poll()
    H.edit("c.lua")
    vim.cmd("10,10Agentdiff keep")
    eq({ "modified c.lua +1 -0 #1" }, H.pending())
    vim.cmd("Agentdiff keep_file")
    eq({}, H.pending())
  end)

  it("fires User AgentdiffChanged when pending changes change (Change event)", function()
    H.write("e.lua", "a\n")
    local agentdiff = H.start()
    local fired = 0
    vim.api.nvim_create_autocmd("User", {
      pattern = "AgentdiffChanged",
      callback = function()
        fired = fired + 1
      end,
    })
    H.write("e.lua", "b\n")
    H.poll()
    eq(1, fired, "on detection")
    H.edit("e.lua")
    agentdiff.keep()
    eq(2, fired, "on keep")
    H.poll()
    eq(2, fired, "not when nothing changed")
  end)

  it("summarises pending changes (Summary with pending changes / Nothing pending)", function()
    local agentdiff = scene({ ["a.lua"] = H.numbered(30), ["b.lua"] = "b\n", ["c.lua"] = "c\n" }, {
      ["a.lua"] = H.numbered(30)
        :gsub("l2\n", "X\n")
        :gsub("l10\n", "X\n")
        :gsub("l20\n", "X\n")
        :gsub("l29\n", "X\n"),
      ["b.lua"] = "B\n",
      ["c.lua"] = "C\nC2\n",
    })
    eq(7, #H.pending() + 4, "sanity")
    eq("3 files · 6 changes", agentdiff.status())
    agentdiff.keep_all({ force = true })
    eq("", agentdiff.status())
  end)
end)

describe("path status", function()
  it("marks a changed file and every parent directory (File and its parents)", function()
    H.write("src/app/main.lua", "a\n")
    H.write("src/other.lua", "o\n")
    local agentdiff = H.start()
    H.write("src/app/main.lua", "agent\n")
    H.write("gone/old.lua", "x\n")
    H.poll()
    eq("file", agentdiff.path_status(H.path("src/app/main.lua")))
    eq("file", agentdiff.path_status("src/app/main.lua"))
    eq("dir", agentdiff.path_status(H.path("src/app")))
    eq("dir", agentdiff.path_status(H.path("src") .. "/"))
    eq("dir", agentdiff.path_status(H.project))
    eq(nil, agentdiff.path_status(H.path("src/other.lua")))
    eq(nil, agentdiff.path_status("/somewhere/else.lua"))
    -- created files count; deleted files mark their directory
    eq("file", agentdiff.path_status("gone/old.lua"))
    H.remove("gone/old.lua")
    H.poll()
    eq(nil, agentdiff.path_status("gone/old.lua"), "created then deleted: nothing pending")
  end)

  it("returns nil everywhere once everything is reviewed (Nothing pending)", function()
    H.write("src/main.lua", "a\n")
    H.write("src/gone.lua", "g\n")
    local agentdiff = H.start()
    H.write("src/main.lua", "agent\n")
    H.remove("src/gone.lua")
    H.poll()
    eq("file", agentdiff.path_status("src/gone.lua"), "a deleted file is pending")
    eq("dir", agentdiff.path_status("src"))
    agentdiff.keep_all({ force = true })
    eq(nil, agentdiff.path_status("src/main.lua"))
    eq(nil, agentdiff.path_status("src"))
    eq(nil, agentdiff.path_status(H.project))
  end)

  it("defines the tree highlight groups", function()
    require("agentdiff.render").define_highlights()
    eq("DiagnosticWarn", vim.api.nvim_get_hl(0, { name = "AgentdiffTreeFile" }).link)
    eq("DiagnosticWarn", vim.api.nvim_get_hl(0, { name = "AgentdiffTreeDir" }).link)
  end)
end)
