local H = require("helpers")

describe("session startup", function()
  it(
    "returns from setup before the snapshot finishes, then becomes active (Large project startup)",
    function()
      for i = 1, 1500 do
        H.write(("src/m%d/f%d.lua"):format(i % 30, i), "return " .. i .. "\n")
      end
      local agentdiff = require("agentdiff")
      agentdiff.setup({
        root = H.project,
        state_dir = H.state .. "/agentdiff",
        poll_interval = 0,
        auto_start = false,
      })
      local t0 = vim.uv.hrtime()
      agentdiff.start()
      local elapsed_ms = (vim.uv.hrtime() - t0) / 1e6
      local s = agentdiff._test.session()
      eq(false, s.ready, "review is inactive until the snapshot completes")
      ok(elapsed_ms < 500, ("start() returned in %.0f ms"):format(elapsed_ms))
      -- A change made before the snapshot exists is not reported.
      ok(agentdiff._test.wait_ready(10000), "snapshot completed")
      eq({}, H.pending())
      H.write("src/m1/f1.lua", "return 'agent'\n")
      H.poll()
      eq({ "modified src/m1/f1.lua +1 -1 #1" }, H.pending())
    end
  )

  it("reviews a directory that is not a git repository (Not a git repository)", function()
    H.write("notes.txt", "one\ntwo\n")
    H.start()
    H.write("notes.txt", "one\nTWO\n")
    H.poll()
    eq({ "modified notes.txt +1 -1 #1" }, H.pending())
  end)

  it("is immediately active when a baseline already exists", function()
    H.write("a.txt", "a\n")
    local agentdiff = H.start()
    agentdiff.stop()
    agentdiff.start()
    eq(true, agentdiff._test.session().ready)
  end)
end)

describe("store reset", function()
  it("rebuilds a deleted store from the current disk state", function()
    H.write("r.lua", "base\n")
    local agentdiff = H.start()
    H.write("r.lua", "agent\n")
    H.poll()
    eq({ "modified r.lua +1 -1 #1" }, H.pending())
    local s = agentdiff._test.session()
    agentdiff._test.reset()
    require("agentdiff.store").destroy(s.store)
    ok(vim.uv.fs_stat(s.store.dir) == nil, "store deleted")
    H.start()
    eq({}, H.pending(), "nothing pending after the rebuild")
    eq({ ["r.lua"] = "agent\n" }, agentdiff._test.session().store:read("baseline", { "r.lua" }))
  end)
end)

describe("startup guards", function()
  it("doesn't treat the home directory as a project unless asked to", function()
    local home = vim.env.HOME
    vim.env.HOME = H.project
    local agentdiff = require("agentdiff")
    agentdiff.setup({ state_dir = H.state .. "/agentdiff", poll_interval = 0, auto_start = false })
    agentdiff.start()
    vim.env.HOME = home
    eq(nil, agentdiff._test.session())
  end)

  it("skips projects with more files than max_files, with a notice", function()
    for i = 1, 5 do
      H.write("f" .. i .. ".txt", "x\n")
    end
    local got = {}
    local orig = vim.notify
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.notify = function(msg)
      got[#got + 1] = msg
    end
    local agentdiff = require("agentdiff")
    agentdiff.setup({
      root = H.project,
      state_dir = H.state .. "/agentdiff",
      poll_interval = 0,
      auto_start = false,
      max_files = 3,
    })
    agentdiff.start()
    vim.wait(3000, function()
      return #got > 0
    end)
    vim.notify = orig
    ok(got[1] and got[1]:find("max_files", 1, true), vim.inspect(got))
    eq(nil, agentdiff._test.session(), "stopped")
  end)
end)
