local H = require("helpers")

local function cursor()
  return { vim.fn.expand("%:t"), vim.api.nvim_win_get_cursor(0)[1] }
end

---Start, then let an agent rewrite files; returns the plugin.
local function scene(files_before, files_after, opts)
  for rel, text in pairs(files_before) do
    H.write(rel, text)
  end
  local agentdiff = H.start(opts)
  for rel, text in pairs(files_after) do
    if text == false then
      H.remove(rel)
    else
      H.write(rel, text)
    end
  end
  H.poll()
  return agentdiff
end

local function notices()
  local got = {}
  local orig = vim.notify
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.notify = function(msg)
    got[#got + 1] = msg
  end
  return got, function()
    vim.notify = orig
  end
end

describe("navigation", function()
  it("crosses into the next file after the last change (Cross into the next file)", function()
    local a = H.numbered(20)
    local agentdiff = scene({ ["a.lua"] = a, ["b.lua"] = a }, {
      ["a.lua"] = a:gsub("l3\n", "A3\n"):gsub("l12\n", "A12\n"),
      ["b.lua"] = a:gsub("l7\n", "B7\n"),
    })
    H.edit("a.lua")
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    agentdiff.next()
    eq({ "a.lua", 3 }, cursor())
    agentdiff.next()
    eq({ "a.lua", 12 }, cursor())
    agentdiff.next()
    eq({ "b.lua", 7 }, cursor(), "opens b.lua at its first pending change")
    agentdiff.prev()
    eq({ "a.lua", 12 }, cursor())
  end)

  it("wraps around with a notice (Wrap around)", function()
    local a = H.numbered(10)
    local agentdiff = scene({ ["a.lua"] = a, ["b.lua"] = a }, {
      ["a.lua"] = a:gsub("l2\n", "A2\n"),
      ["b.lua"] = a:gsub("l9\n", "B9\n"),
    })
    H.edit("b.lua")
    vim.api.nvim_win_set_cursor(0, { 9, 0 })
    local got, restore = notices()
    agentdiff.next()
    restore()
    eq({ "a.lua", 2 }, cursor())
    ok(got[1] and got[1]:find("wrapped"), "a notice reports the wrap")
  end)

  it("moves between changed files", function()
    local a = H.numbered(10)
    local agentdiff = scene({ ["a.lua"] = a, ["b.lua"] = a, ["c.lua"] = a }, {
      ["a.lua"] = a:gsub("l4\n", "A\n"),
      ["c.lua"] = a:gsub("l6\n", "C\n"),
    })
    H.edit("a.lua")
    agentdiff.next_file()
    eq({ "c.lua", 6 }, cursor())
    agentdiff.prev_file()
    eq({ "a.lua", 4 }, cursor())
  end)
end)

describe("keep", function()
  it("keeps only the change under the cursor (Keep one change)", function()
    local a = H.numbered(20)
    local after = a:gsub("l3\n", "A3\n"):gsub("l15\n", "A15\n")
    local agentdiff = scene({ ["k.lua"] = a }, { ["k.lua"] = after })
    H.edit("k.lua")
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    agentdiff.keep()
    eq(after, H.read("k.lua"), "file unchanged on disk")
    eq({ "modified k.lua +1 -1 #1" }, H.pending())
    eq(14, agentdiff.files()[1].hunks[1].b_lo, "the other change is still pending")
  end)

  it("keeps every change of a file", function()
    local a = H.numbered(20)
    local agentdiff = scene({ ["f.lua"] = a }, { ["f.lua"] = a:gsub("l3\n", "A\n"):gsub("l15\n", "B\n") })
    H.edit("f.lua")
    agentdiff.keep_file()
    eq({}, H.pending())
  end)

  it("asks before keeping all files (Keep all asks first)", function()
    local a = H.numbered(5)
    local agentdiff = scene({ ["a.lua"] = a, ["b.lua"] = a }, {
      ["a.lua"] = a:gsub("l1\n", "A\n"),
      ["b.lua"] = a:gsub("l1\n", "B\n"),
    })
    local asked = 0
    local orig = vim.fn.confirm
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.fn.confirm = function()
      asked = asked + 1
      return asked == 1 and 2 or 1 -- first: No, second: Yes
    end
    agentdiff.keep_all()
    eq(2, #H.pending(), "declining keeps everything pending")
    agentdiff.keep_all()
    vim.fn.confirm = orig
    eq(2, asked)
    eq({}, H.pending())
  end)
end)

describe("undo", function()
  it("restores the baseline of the change under the cursor on disk (Undo one change)", function()
    local a = H.numbered(20)
    local agentdiff = scene({ ["u.lua"] = a }, { ["u.lua"] = a:gsub("l3\n", "A3\n"):gsub("l15\n", "A15\n") })
    H.edit("u.lua")
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    agentdiff.undo()
    eq(a:gsub("l15\n", "A15\n"), H.read("u.lua"))
    H.poll()
    eq({ "modified u.lua +1 -1 #1" }, H.pending())
  end)

  it("restores the baseline in the region, discarding a tweak inside it (Tweak then undo)", function()
    local agentdiff = scene({ ["t.lua"] = "one\ntwo\nthree\n" }, { ["t.lua"] = "one\nTWO\nthree\n" })
    H.edit("t.lua")
    H.change(2, 2, { "TWO tweaked" })
    H.save()
    H.poll()
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    agentdiff.undo()
    eq("one\ntwo\nthree\n", H.read("t.lua"))
    H.poll()
    eq({}, H.pending())
  end)

  it("undoes a change in a file that has no buffer", function()
    local agentdiff = scene({ ["n.lua"] = "a\nb\n" }, { ["n.lua"] = "a\nB\n" })
    agentdiff.undo({ scope = "file", path = "n.lua" })
    eq("a\nb\n", H.read("n.lua"))
    H.poll()
    eq({}, H.pending())
  end)

  it("brings the agent's change back as pending with u (Undo is undoable)", function()
    local agentdiff = scene({ ["z.lua"] = "a\nb\nc\n" }, { ["z.lua"] = "a\nB\nc\n" })
    local buf = H.edit("z.lua")
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    agentdiff.undo()
    eq({}, H.pending())
    vim.cmd("silent undo")
    vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf })
    eq({ "a", "B", "c" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    eq({ "modified z.lua +1 -1 #1" }, H.pending(), "pending again")
    H.save()
    H.poll()
    eq({ "modified z.lua +1 -1 #1" }, H.pending(), "and still pending after saving")
  end)

  it("asks before undoing all files", function()
    local agentdiff = scene(
      { ["a.lua"] = "a\n", ["b.lua"] = "b\n" },
      { ["a.lua"] = "A\n", ["b.lua"] = "B\n" }
    )
    local orig = vim.fn.confirm
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.fn.confirm = function()
      return 1
    end
    agentdiff.undo_all()
    vim.fn.confirm = orig
    eq("a\n", H.read("a.lua"))
    eq("b\n", H.read("b.lua"))
    H.poll()
    eq({}, H.pending())
  end)
end)

describe("created and deleted files", function()
  it("deletes a created file on undo (Undo a created file)", function()
    local agentdiff = scene({ ["keep.lua"] = "k\n" }, { ["new.lua"] = "fresh\nfile\n" })
    eq({ "created new.lua +2 -0 #1" }, H.pending())
    local buf = H.edit("new.lua")
    agentdiff.undo_file()
    eq(nil, H.read("new.lua"))
    ok(not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf), "no buffer remains")
    H.poll()
    eq({}, H.pending())
  end)

  it("restores a deleted file on undo (Undo a deleted file)", function()
    local agentdiff = scene({ ["old.lua"] = "old\ncontent\n" }, { ["old.lua"] = false })
    eq({ "deleted old.lua +0 -2 #1" }, H.pending())
    agentdiff.undo({ scope = "file", path = "old.lua" })
    eq("old\ncontent\n", H.read("old.lua"))
    H.poll()
    eq({}, H.pending())
  end)

  it("keeps a created file and a deletion", function()
    local agentdiff = scene({ ["gone.lua"] = "g\n" }, { ["made.lua"] = "m\n", ["gone.lua"] = false })
    agentdiff.keep({ scope = "file", path = "made.lua" })
    agentdiff.keep({ scope = "file", path = "gone.lua" })
    eq({}, H.pending())
    eq("m\n", H.read("made.lua"))
  end)

  it("reviews a rename as a deletion plus a creation", function()
    scene({ ["a.lua"] = "same\n" }, {})
    os.rename(H.path("a.lua"), H.path("b.lua"))
    H.poll()
    eq({ "deleted a.lua +0 -1 #1", "created b.lua +1 -0 #1" }, H.pending())
  end)
end)

describe("partial keep and undo", function()
  it("keeps only the selected lines of a change (Keep part of a change)", function()
    local base = H.numbered(9)
    local added = base:gsub("l9\n", "l9\nn10\nn11\nn12\nn13\nn14\n")
    local agentdiff = scene({ ["p.lua"] = base }, { ["p.lua"] = added })
    H.edit("p.lua")
    agentdiff.keep({ range = { 10, 11 } })
    eq({ "modified p.lua +3 -0 #1" }, H.pending())
    local f = agentdiff.files()[1]
    eq({ 11, 14 }, { f.hunks[1].b_lo, f.hunks[1].b_hi }, "lines 12-14 remain pending")
    eq(added, H.read("p.lua"))
  end)

  it("undoes only the selected lines of a change", function()
    local base = H.numbered(9)
    local added = base:gsub("l9\n", "l9\nn10\nn11\nn12\n")
    local agentdiff = scene({ ["q.lua"] = base }, { ["q.lua"] = added })
    H.edit("q.lua")
    agentdiff.undo({ range = { 11, 11 } })
    eq(base:gsub("l9\n", "l9\nn10\nn12\n"), H.read("q.lua"))
    H.poll()
    eq({ "modified q.lua +2 -0 #1" }, H.pending())
  end)

  it("includes removed lines when the selection starts at the change", function()
    local agentdiff = scene({ ["r.lua"] = "a\nold1\nold2\nz\n" }, { ["r.lua"] = "a\nnew1\nnew2\nz\n" })
    H.edit("r.lua")
    agentdiff.keep({ range = { 2, 2 } })
    -- old lines accepted as removed, new1 kept, new2 still pending as added
    eq({ "modified r.lua +1 -0 #1" }, H.pending())
  end)
end)

describe("undo with unsaved edits", function()
  it("leaves the result unsaved with the user's edits (Undo with unsaved edits)", function()
    local a = H.numbered(20)
    local agentdiff = scene({ ["v.lua"] = a }, { ["v.lua"] = a:gsub("l3\n", "A3\n") })
    local buf = H.edit("v.lua")
    H.change(15, 15, { "mine15" })
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    agentdiff.undo()
    eq({}, H.pending())
    ok(vim.bo[buf].modified, "still unsaved")
    eq("mine15", vim.api.nvim_buf_get_lines(buf, 14, 15, false)[1])
    eq(a:gsub("l3\n", "A3\n"), H.read("v.lua"), "nothing written yet")
    H.save()
    H.poll()
    eq({}, H.pending())
    eq(a:gsub("l15\n", "mine15\n"), H.read("v.lua"))
  end)
end)
