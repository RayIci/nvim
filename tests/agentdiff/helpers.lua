---Per-test fixtures: a temp project directory and a temp state directory.
local H = {}

---@type string?  project root of the running test
H.project = nil
---@type string?  XDG_STATE_HOME of the running test
H.state = nil

local function rmrf(path)
  if path and vim.uv.fs_stat(path) then
    vim.fn.delete(path, "rf")
  end
end

function H.begin_test()
  local base = vim.fn.tempname()
  H.project = base .. "-project"
  H.state = base .. "-state"
  vim.fn.mkdir(H.project, "p")
  vim.fn.mkdir(H.state, "p")
  -- Resolve symlinks once so paths compare equal to what the plugin computes.
  H.project = vim.uv.fs_realpath(H.project)
  vim.env.XDG_STATE_HOME = H.state
  vim.cmd.cd(H.project)
end

function H.end_test()
  local loaded = package.loaded["agentdiff"]
  if loaded and loaded._test and loaded._test.reset then
    loaded._test.reset()
  end
  vim.cmd("silent! %bwipeout!")
  vim.cmd.cd(vim.fn.stdpath("cache"))
  rmrf(H.project)
  rmrf(H.state)
  H.project, H.state = nil, nil
end

---Absolute path of a project-relative path.
---@param rel string
---@return string
function H.path(rel)
  return H.project .. "/" .. rel
end

---Write a file the way an agent does: straight to disk, bypassing Neovim.
---@param rel string
---@param text string
function H.write(rel, text)
  local p = H.path(rel)
  vim.fn.mkdir(vim.fn.fnamemodify(p, ":h"), "p")
  local f = assert(io.open(p, "wb"))
  f:write(text)
  f:close()
end

---@param rel string
---@return string?
function H.read(rel)
  local f = io.open(H.path(rel), "rb")
  if not f then
    return nil
  end
  local s = f:read("*a")
  f:close()
  return s
end

---@param rel string
function H.remove(rel)
  os.remove(H.path(rel))
end

---Run git in the test project (isolated from the user's git config).
---@param args string[]
---@return string stdout
function H.git(args)
  local cmd =
    { "git", "-c", "user.name=t", "-c", "user.email=t@t", "-c", "init.defaultBranch=main", "-C", H.project }
  vim.list_extend(cmd, args)
  local r = vim
    .system(cmd, {
      clear_env = true,
      env = {
        PATH = vim.env.PATH,
        HOME = H.state,
        GIT_CONFIG_NOSYSTEM = "1",
        GIT_CONFIG_GLOBAL = "/dev/null",
        -- `git status` would otherwise refresh .git/index opportunistically,
        -- which makes "the plugin never touches the project's index" flaky.
        GIT_OPTIONAL_LOCKS = "0",
      },
    })
    :wait()
  assert(r.code == 0, table.concat(args, " ") .. ": " .. (r.stderr or ""))
  return r.stdout or ""
end

---Make the project a git repository with one commit of its current files.
function H.git_repo()
  H.git({ "init", "-q" })
  H.git({ "add", "-A" })
  H.git({ "commit", "-q", "--allow-empty", "-m", "init" })
end

---Open the plugin's store for the test project and wait for its snapshot.
---@param opts table?
---@return AgentdiffStore
function H.store(opts)
  local config = require("agentdiff.config")
  config.resolve(vim.tbl_extend("force", { auto_start = false, root = H.project }, opts or {}))
  local store = require("agentdiff.store").open(H.project, config.options)
  local done
  store:snapshot(function(okk)
    done = okk
  end)
  assert(
    vim.wait(5000, function()
      return done ~= nil
    end),
    "snapshot timed out"
  )
  assert(done, "snapshot failed")
  return store
end

---@param abs string
---@return string?
function H.read_abs(abs)
  local f = io.open(abs, "rb")
  if not f then
    return nil
  end
  local s = f:read("*a")
  f:close()
  return s
end

---@param abs string
---@param text string
function H.write_abs(abs, text)
  local f = assert(io.open(abs, "wb"))
  f:write(text)
  f:close()
end

---Set up and start the plugin on the test project, waiting for the snapshot.
---No poll timer: tests drive detection with H.poll().
---@param opts table?
---@return table agentdiff
function H.start(opts)
  local agentdiff = require("agentdiff")
  agentdiff.setup(vim.tbl_extend("force", {
    root = H.project,
    state_dir = H.state .. "/agentdiff",
    poll_interval = 0,
    auto_start = false,
  }, opts or {}))
  agentdiff.start()
  assert(agentdiff._test.wait_ready(5000), "agentdiff did not become ready")
  return agentdiff
end

---Detect now (unclaimed changes confirmed at once unless settle = true).
---@param settle boolean?
function H.poll(settle)
  require("agentdiff")._test.poll_now(settle and {} or { settle = false })
end

---Pending files as "status path +a -r #hunks" strings.
---@return string[]
function H.pending()
  local agentdiff = require("agentdiff")
  agentdiff._test.flush()
  return vim.tbl_map(function(f)
    return ("%s %s +%d -%d #%d"):format(f.status, f.path, f.added, f.removed, #f.hunks)
  end, agentdiff.files())
end

---Open a project file in the current window; returns its buffer.
---@param rel string
---@return integer
function H.edit(rel)
  vim.cmd.edit(vim.fn.fnameescape(H.path(rel)))
  return vim.api.nvim_get_current_buf()
end

---Replace 1-based lines [first, last] of the current buffer (as typing would).
---@param first integer
---@param last integer
---@param lines string[]
function H.change(first, last, lines)
  vim.api.nvim_buf_set_lines(0, first - 1, last, false, lines)
  vim.api.nvim_exec_autocmds("TextChanged", { buffer = 0 })
  require("agentdiff")._test.flush()
end

function H.save()
  vim.cmd("silent write")
end

---@param n integer
---@return string text with lines "l1".."ln"
function H.numbered(n)
  local t = {}
  for i = 1, n do
    t[i] = "l" .. i
  end
  return table.concat(t, "\n") .. "\n"
end

return H
