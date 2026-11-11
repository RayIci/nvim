---Shared persistence helpers for state files under stdpath("state").
---
---  path(kind, cwd)   per-project JSON file: <state>/<kind>/<cwd-key>.json
---  read / write      JSON files; a missing file is distinct from an empty one
---  saver(opts)       debounced, transition-aware writer (see ConfigStateSaver)
---
---The cwd key is the one these files have always used, so existing files keep
---being found.
---@class ConfigState
local M = {}

---Filesystem-safe key for a project directory.
---@param cwd? string defaults to the current directory
---@return string
function M.key(cwd)
  return ((cwd or vim.fn.getcwd()):gsub("[/\\:]", "%%"))
end

---Per-project state file.
---@param kind string subdirectory of stdpath("state"), e.g. "workspaces"
---@param cwd? string defaults to the current directory
---@return string
function M.path(kind, cwd)
  return vim.fs.joinpath(vim.fn.stdpath("state") --[[@as string]], kind, M.key(cwd) .. ".json")
end

---Read a JSON file. A missing file returns `default` and false; an existing
---file that is not valid JSON raises, so callers never mistake a damaged
---snapshot for an empty one.
---@param path string
---@param default any returned when the file does not exist
---@return any value
---@return boolean exists
function M.read(path, default)
  if not vim.uv.fs_lstat(path) then
    return default, false
  end
  return vim.json.decode(table.concat(vim.fn.readfile(path), "\n")), true
end

---Write a value as JSON, creating the parent directory when needed.
---@param path string
---@param value any
function M.write(path, value)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile({ vim.json.encode(value) }, path)
end

---A debounced writer that never writes the wrong project. Every scheduled
---write remembers the cwd and a generation token; it is dropped when the cwd
---changed, the saver was paused or exiting, or the generation moved on
---(pause, flush, invalidate, exit all bump it).
---@class ConfigStateSaver
---@field touch fun() schedule a write for the current cwd (ignored while paused or exiting)
---@field flush fun() write now for the current cwd; errors propagate to the caller
---@field pause fun() drop pending writes and ignore touches until resume()
---@field resume fun()
---@field invalidate fun() drop pending writes and deferred callbacks without pausing
---@field exit fun() last write on VimLeavePre (unless paused); later touches are ignored
---@field active fun(): boolean neither paused nor exiting
---@field token fun(): integer current generation
---@field defer fun(fn: fun(), delay: integer) run fn later unless the cwd or generation changed meanwhile

---@class ConfigStateSaverOpts
---@field save fun(cwd: string) writes the state for `cwd`
---@field label string prefix for error notifications, e.g. "Workspace save"
---@field delay? integer debounce in ms (default 500)

---@param opts ConfigStateSaverOpts
---@return ConfigStateSaver
function M.saver(opts)
  local delay = opts.delay or 500
  local timer = assert(vim.uv.new_timer())
  local paused, exiting, generation = false, false, 0

  ---@param fn fun()
  local function report(fn)
    local ok, err = pcall(fn)
    if not ok then
      vim.notify(opts.label .. ": " .. tostring(err), vim.log.levels.ERROR)
    end
  end

  ---@type ConfigStateSaver
  local saver = {} ---@diagnostic disable-line: missing-fields

  function saver.active()
    return not paused and not exiting
  end

  function saver.token()
    return generation
  end

  function saver.invalidate()
    generation = generation + 1
    timer:stop()
  end

  function saver.pause()
    paused = true
    saver.invalidate()
  end

  function saver.resume()
    paused = false
  end

  function saver.flush()
    saver.invalidate()
    opts.save(vim.fn.getcwd())
  end

  function saver.touch()
    if not saver.active() then
      return
    end
    local cwd, token = vim.fn.getcwd(), generation
    timer:stop()
    timer:start(
      delay,
      0,
      vim.schedule_wrap(function()
        if saver.active() and token == generation and cwd == vim.fn.getcwd() then
          report(function()
            opts.save(cwd)
          end)
        end
      end)
    )
  end

  function saver.defer(fn, ms)
    local cwd, token = vim.fn.getcwd(), generation
    vim.defer_fn(function()
      if saver.active() and token == generation and cwd == vim.fn.getcwd() then
        report(fn)
      end
    end, ms)
  end

  function saver.exit()
    exiting = true
    saver.invalidate()
    if not paused then
      report(function()
        opts.save(vim.fn.getcwd())
      end)
    end
  end

  return saver
end

return M
