local H = require("helpers")

local function marks(buf, ns)
  return vim.api.nvim_buf_get_extmarks(buf, ns or require("agentdiff.render").ns, 0, -1, { details = true })
end

---@return { row: integer, added: boolean, virt: string[]?, above: boolean? }[]
local function overlay(buf)
  local out = {}
  for _, m in ipairs(marks(buf)) do
    local d = m[4]
    local e = { row = m[2], added = d.line_hl_group == "AgentdiffAdd" }
    if d.virt_lines then
      e.virt = vim.tbl_map(function(l)
        return vim.trim(l[1][1])
      end, d.virt_lines)
      e.above = d.virt_lines_above
    end
    out[#out + 1] = e
  end
  table.sort(out, function(a, b)
    return a.row < b.row or (a.row == b.row and (a.virt == nil) and b.virt ~= nil)
  end)
  return out
end

local function open_changed(rel, before, after)
  H.write(rel, before)
  local agentdiff = H.start({ keymaps = { keep = "<leader>rk", undo = "<leader>ru" } })
  local buf = H.edit(rel)
  H.write(rel, after)
  vim.cmd("silent! checktime")
  H.poll()
  agentdiff._test.flush()
  return agentdiff, buf
end

describe("overlay", function()
  it("shows the old line as a removed virtual line above the new highlighted line (Modified line)", function()
    local _, buf = open_changed("m.lua", "a\nold\nc\n", "a\nnew\nc\n")
    eq({
      { row = 1, added = true },
      { row = 1, added = false, virt = { "old" }, above = true },
    }, overlay(buf))
  end)

  it("never changes the buffer text (Buffer text untouched)", function()
    local _, buf = open_changed("t.lua", "a\nold\nc\n", "a\nnew\nextra\nc\n")
    eq({ "a", "new", "extra", "c" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    eq("a\nnew\nextra\nc\n", H.read("t.lua"))
    ok(not vim.bo[buf].modified)
    -- removed lines are virtual: yanking the buffer yields only real lines
    vim.cmd("silent %yank z")
    eq("a\nnew\nextra\nc\n", vim.fn.getreg("z"))
  end)

  it("draws a deletion at the end of the file below the last line", function()
    local _, buf = open_changed("e.lua", "a\nb\ngone\n", "a\nb\n")
    eq({ { row = 1, added = false, virt = { "gone" }, above = false } }, overlay(buf))
  end)

  it("uses highlight groups that link to DiffAdd and DiffDelete by default", function()
    require("agentdiff.render").define_highlights()
    eq("DiffAdd", vim.api.nvim_get_hl(0, { name = "AgentdiffAdd" }).link)
    eq("DiffDelete", vim.api.nvim_get_hl(0, { name = "AgentdiffDelete" }).link)
  end)

  it("draws the overlay in every window showing the buffer", function()
    local _, buf = open_changed("w.lua", "a\nb\n", "a\nB\n")
    vim.cmd("vsplit")
    eq(2, #vim.fn.win_findbuf(buf))
    ok(#marks(buf) > 0, "extmarks are per buffer, so both windows show them")
  end)
end)

describe("hint", function()
  local function hint_text(buf)
    local m = marks(buf, require("agentdiff.render").ns_hint)
    return m[1] and m[1][4].virt_text[1][1] or nil
  end

  it("shows the position among all pending changes and the keys (Hint position)", function()
    local before = H.numbered(40)
    local after = before:gsub("l5\n", "A5\n"):gsub("l15\n", "A15\n"):gsub("l25\n", "A25\n")
    H.write("z.lua", "z\n")
    local agentdiff, buf = open_changed("a.lua", before, after)
    H.write("z.lua", "Z\nZ2\n")
    H.poll()
    agentdiff._test.flush()
    -- 3 changes in a.lua + 1 in z.lua = 4 (z.lua: one hunk)
    vim.api.nvim_win_set_cursor(0, { 15, 0 })
    require("agentdiff.render").hint(agentdiff._test.session())
    eq("agent 2/4 · <leader>rk keep · <leader>ru undo", hint_text(buf))
  end)

  it("follows the cursor to the nearest change", function()
    local before = H.numbered(40)
    local after = before:gsub("l5\n", "A5\n"):gsub("l30\n", "A30\n")
    local agentdiff, buf = open_changed("n.lua", before, after)
    vim.api.nvim_win_set_cursor(0, { 28, 0 })
    vim.api.nvim_exec_autocmds("CursorMoved", {})
    eq("agent 2/2 · <leader>rk keep · <leader>ru undo", hint_text(buf))
    local m = marks(buf, require("agentdiff.render").ns_hint)
    eq(29, m[1][2], "placed on the change's line")
    local _ = agentdiff
  end)
end)

describe("hide and show", function()
  it("hides the overlay without touching pending changes (Hide and restore)", function()
    local agentdiff, buf = open_changed("h.lua", "a\nb\n", "a\nB\n")
    local shown = #marks(buf)
    ok(shown > 0)
    agentdiff.toggle_overlay()
    eq(0, #marks(buf))
    eq({ "modified h.lua +1 -1 #1" }, H.pending(), "still pending while hidden")
    agentdiff.toggle_overlay()
    eq(shown, #marks(buf))
    eq({ "modified h.lua +1 -1 #1" }, H.pending())
  end)
end)
