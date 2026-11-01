local H = require("helpers")

---Fingerprint of the project's own repository state.
local function project_git_state()
  return {
    status = H.git({ "status", "--porcelain=v1", "--untracked-files=all" }),
    refs = H.git({ "for-each-ref" }),
    index = vim.fn.sha256(H.read(".git/index") or ""),
    head = H.read(".git/HEAD"),
  }
end

local function paths(changes)
  return vim.tbl_map(function(c)
    return c.status .. " " .. c.path
  end, changes)
end

describe("store", function()
  it("lives outside the project, keyed by its root", function()
    H.write("a.txt", "a\n")
    local store = H.store()
    ok(store.dir:sub(1, #H.state) == H.state, "store under the state dir")
    ok(store.dir:find(H.project, 1, true) == nil, "store not inside the project")
    eq(H.project .. "\n", H.read_abs(store.dir .. "/root"))
  end)

  it("never modifies the project's own git repository (Project git untouched)", function()
    H.write("a.txt", "a\n")
    H.write("b.txt", "b\n")
    H.git_repo()
    H.write("b.txt", "b changed\n") -- an unstaged change in the project
    local before = project_git_state()
    local store = H.store()
    H.write("a.txt", "agent\n")
    H.write("c.txt", "new\n")
    store:changes("observed")
    store:adopt("observed", { "a.txt", "c.txt" })
    store:write("baseline", { { path = "a.txt", text = "kept\n" } })
    store:refresh("baseline")
    store:changes("baseline")
    -- Restore the project's worktree to its pre-test state and compare.
    H.write("a.txt", "a\n")
    H.remove("c.txt")
    eq(before, project_git_state())
  end)

  it("works in a directory that is not a git repository", function()
    H.write("a.txt", "a\n")
    local store = H.store()
    H.write("a.txt", "b\n")
    eq({ "M a.txt" }, paths(store:changes("baseline")))
  end)

  it("lists modified, deleted and new files against an index", function()
    H.write("m.txt", "m\n")
    H.write("d.txt", "d\n")
    local store = H.store()
    H.write("m.txt", "m2\n")
    H.remove("d.txt")
    H.write("dir/new.txt", "n\n")
    eq({ "D d.txt", "A dir/new.txt", "M m.txt" }, paths(store:changes("baseline")))
  end)

  it("lists changes asynchronously too", function()
    H.write("a.txt", "a\n")
    local store = H.store()
    H.write("a.txt", "b\n")
    local got
    store:changes("baseline", function(c)
      got = c
    end)
    ok(vim.wait(5000, function()
      return got ~= nil
    end))
    eq({ "M a.txt" }, paths(got))
  end)

  it("ignores paths ignored by .gitignore and the default excludes (Ignored paths)", function()
    H.write(".gitignore", "generated/\n")
    local store = H.store()
    H.write("generated/out.txt", "x\n")
    H.write("node_modules/pkg/index.js", "x\n")
    eq({}, store:changes("baseline"))
  end)

  it("skips nested git repositories instead of failing", function()
    H.write("a.txt", "a\n")
    vim.fn.mkdir(H.path("vendor/lib"), "p")
    H.write("vendor/lib/x.txt", "x\n")
    H.git({ "-C", H.path("vendor/lib"), "init", "-q" })
    local store = H.store()
    eq({}, store:changes("baseline"))
  end)

  it("stores raw bytes regardless of the project's attributes", function()
    H.write(".gitattributes", "* text=auto eol=crlf\n")
    H.write("w.txt", "a\r\nb\r\n")
    local store = H.store()
    eq({ ["w.txt"] = "a\r\nb\r\n" }, store:read("baseline", { "w.txt" }))
  end)

  it("reads, writes and removes entries", function()
    H.write("a.txt", "a\n")
    local store = H.store()
    eq({ ["a.txt"] = "a\n", ["nope.txt"] = false }, store:read("baseline", { "a.txt", "nope.txt" }))
    store:write("baseline", { { path = "a.txt", text = "B\n" }, { path = "n.txt", text = "N" } })
    eq({ ["a.txt"] = "B\n", ["n.txt"] = "N" }, store:read("baseline", { "a.txt", "n.txt" }))
    store:write("baseline", { { path = "n.txt", text = nil } })
    eq({ ["n.txt"] = false }, store:read("baseline", { "n.txt" }))
    -- observed is a separate index
    eq({ ["a.txt"] = "a\n" }, store:read("observed", { "a.txt" }))
  end)

  it("adopts disk content, removing paths that no longer exist", function()
    H.write("a.txt", "a\n")
    H.write("b.txt", "b\n")
    local store = H.store()
    H.write("a.txt", "a2\n")
    H.remove("b.txt")
    store:adopt("observed", { "a.txt", "b.txt" })
    eq({ ["a.txt"] = "a2\n", ["b.txt"] = false }, store:read("observed", { "a.txt", "b.txt" }))
    eq({}, store:changes("observed"))
  end)

  it("retries while another process holds the index lock", function()
    H.write("a.txt", "a\n")
    local store = H.store()
    local lock = store:index_path("baseline") .. ".lock"
    H.write_abs(lock, "")
    local t = vim.uv.new_timer()
    t:start(200, 0, function()
      os.remove(lock)
    end)
    store:write("baseline", { { path = "a.txt", text = "z\n" } })
    t:close()
    eq({ ["a.txt"] = "z\n" }, store:read("baseline", { "a.txt" }))
  end)

  it("serializes read-modify-write through the store lock", function()
    local store = H.store()
    local inner = store:locked(function()
      return vim.uv.fs_stat(store.dir .. "/lock") ~= nil
    end)
    ok(inner, "lock held inside")
    ok(vim.uv.fs_stat(store.dir .. "/lock") == nil, "lock released after")
  end)
end)
