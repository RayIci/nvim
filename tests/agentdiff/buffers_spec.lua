local H = require("helpers")

---Make Neovim notice the disk change the way focus/checktime does, then detect.
local function notice()
  vim.cmd("silent! checktime")
  vim.wait(50) -- let scheduled buffer updates run
  H.poll()
  require("agentdiff")._test.flush()
end

describe("unsaved buffers", function()
  it(
    "merges a non-overlapping agent write into a buffer with unsaved edits (Non-overlapping edits merge)",
    function()
      H.write("m.lua", H.numbered(60))
      H.start()
      local buf = H.edit("m.lua")
      H.change(5, 5, { "mine5" })
      local prompted = false
      local orig = vim.fn.confirm
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.fn.confirm = function(...)
        prompted = true
        return orig(...)
      end
      H.write("m.lua", (H.numbered(60):gsub("l50\n", "agent50\n")))
      notice()
      vim.fn.confirm = orig
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      eq("mine5", lines[5], "the user's unsaved edit is kept")
      eq("agent50", lines[50], "the agent's change is in the buffer")
      ok(vim.bo[buf].modified, "line 5 is still an unsaved edit")
      eq({ "modified m.lua +1 -1 #1" }, H.pending(), "only the agent's change is pending")
      eq(49, require("agentdiff").files()[1].hunks[1].b_lo)
      ok(not prompted, "no prompt")
      -- Saving keeps the agent's change pending and the user's edit out of it.
      H.save()
      H.poll()
      eq({ "modified m.lua +1 -1 #1" }, H.pending())
    end
  )

  it(
    "flags an overlapping agent write as a conflict and leaves the buffer alone (Conflict is flagged)",
    function()
      H.write("c.lua", H.numbered(10))
      H.start()
      local buf = H.edit("c.lua")
      H.change(5, 5, { "mine5" })
      H.write("c.lua", (H.numbered(10):gsub("l5\n", "agent5\n")))
      notice()
      eq("mine5", vim.api.nvim_buf_get_lines(buf, 4, 5, false)[1])
      eq({ "conflicted c.lua +1 -1 #1" }, H.pending())
    end
  )

  it("keeps the user's version and undoes the agent's on disk (Keep mine)", function()
    H.write("k.lua", H.numbered(10))
    local agentdiff = H.start()
    local buf = H.edit("k.lua")
    H.change(5, 5, { "mine5" })
    H.write("k.lua", (H.numbered(10):gsub("l5\n", "agent5\n")))
    notice()
    agentdiff.resolve("mine")
    notice()
    eq(H.numbered(10), H.read("k.lua"), "disk is back to the baseline")
    eq("mine5", vim.api.nvim_buf_get_lines(buf, 4, 5, false)[1], "unsaved edit kept")
    ok(vim.bo[buf].modified)
    eq({}, H.pending())
    H.save()
    H.poll()
    eq({}, H.pending(), "saving the user's version doesn't create a pending change")
  end)

  it("takes the agent's version, recoverable with undo", function()
    H.write("t.lua", H.numbered(10))
    local agentdiff = H.start()
    local buf = H.edit("t.lua")
    H.change(5, 5, { "mine5" })
    H.write("t.lua", (H.numbered(10):gsub("l5\n", "agent5\n")))
    notice()
    agentdiff.resolve("agent")
    notice()
    eq("agent5", vim.api.nvim_buf_get_lines(buf, 4, 5, false)[1])
    eq({ "modified t.lua +1 -1 #1" }, H.pending())
    vim.cmd("silent undo")
    eq("mine5", vim.api.nvim_buf_get_lines(buf, 4, 5, false)[1], "the discarded edit is back with u")
  end)

  it("reloads unmodified buffers silently", function()
    H.write("r.lua", "a\n")
    H.start()
    local buf = H.edit("r.lua")
    H.write("r.lua", "b\n")
    notice()
    eq({ "b" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    eq({ "modified r.lua +1 -1 #1" }, H.pending())
  end)
end)
