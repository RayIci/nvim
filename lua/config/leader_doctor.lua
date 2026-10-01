---Leader doctor: diagnose + repair a dead <leader> (Space swallowed, no
---which-key popup, leader mappings not firing) without restarting.
---
---which-key v3 owns Space through buffer-local "which-key-trigger" mappings
---it tracks in an internal table, removes after every executed mapping and
---re-adds on the next tick. If that table and the real buffer mappings drift
---apart — or another mapping/state shadows Space — the leader goes dead in
---that buffer. Each :LeaderDoctor run (a command, so it works while the
---leader is broken) appends a snapshot of the culprit candidates to
---stdpath("state")/leader-doctor.log, then rebuilds which-key's state.
---@class LeaderDoctor
local M = {}

local log_path = vim.fs.joinpath(vim.fn.stdpath("state") --[[@as string]], "leader-doctor.log")

---Where a mapping came from: Lua callback location or Vimscript script.
---@param map table maparg()/nvim_get_keymap() dict
---@return string
local function map_source(map)
  if map.callback then
    local info = debug.getinfo(map.callback, "S")
    return ("lua %s:%d"):format(info.short_src, info.linedefined)
  end
  if map.sid and map.sid > 0 then
    local ok, scripts = pcall(vim.fn.getscriptinfo, { sid = map.sid })
    if ok and scripts[1] then
      return ("script %s:%d"):format(scripts[1].name, map.lnum or 0)
    end
  end
  return "unknown"
end

---@param map table
---@return string
local function describe_map(map)
  return ("lhs=%q rhs=%q desc=%q buffer=%s nowait=%s from %s"):format(
    map.lhs or "",
    map.rhs or (map.callback and "<lua>" or ""),
    map.desc or "",
    tostring(map.buffer),
    tostring(map.nowait),
    map_source(map)
  )
end

---Snapshot everything that can make Space dead in the current buffer.
---@return string[] lines
local function diagnose()
  local buf = vim.api.nvim_get_current_buf()
  local lines = {
    ("buffer %d %q ft=%q bt=%q mode=%q"):format(
      buf,
      vim.fn.bufname(buf),
      vim.bo[buf].filetype,
      vim.bo[buf].buftype,
      vim.api.nvim_get_mode().mode
    ),
    ("mapleader=%q recording=%q executing=%q"):format(
      vim.g.mapleader or "\\",
      vim.fn.reg_recording(),
      vim.fn.reg_executing()
    ),
  }

  -- What Space resolves to right now (buffer-local wins over global).
  local space = vim.fn.maparg(" ", "n", false, true)
  table.insert(lines, "Space resolves to: " .. (vim.tbl_isempty(space) and "nothing (native leader)" or describe_map(space)))

  -- A bare buffer-local Space mapping that isn't which-key's eats the leader.
  for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
    if map.lhs == " " and not (map.desc or ""):find("which-key-trigger", 1, true) then
      table.insert(lines, "buffer-local Space map: " .. describe_map(map))
    end
  end

  local ok, err = pcall(function()
    local Triggers = require("which-key.triggers")
    local State = require("which-key.state")
    local Buf = require("which-key.buf")
    local Config = require("which-key.config")

    table.insert(lines, "which-key state active: " .. tostring(State.state ~= nil))
    -- Keys are wk.Mode objects; their __tostring gives "Mode(n:<buf>)".
    local suspended = vim.tbl_map(tostring, vim.tbl_keys(Triggers.suspended))
    table.insert(lines, "which-key suspended modes: " .. (#suspended > 0 and table.concat(suspended, ", ") or "none"))
    table.insert(lines, ("which-key disabled here: ft=%s bt=%s"):format(
      tostring(vim.tbl_contains(Config.disable.ft or {}, vim.bo[buf].filetype)),
      tostring(vim.tbl_contains(Config.disable.bt or {}, vim.bo[buf].buftype))
    ))

    -- Triggers which-key believes it has here vs. what's really mapped.
    local tracked = 0
    for id, trigger in pairs(Triggers._triggers) do
      if trigger.buf == buf then
        tracked = tracked + 1
        local real = vim.fn.maparg(trigger.keys, trigger.mode, false, true)
        local present = not vim.tbl_isempty(real) and real.buffer == 1
          and (real.desc or ""):find("which-key-trigger", 1, true) ~= nil
        if not present then
          table.insert(lines, ("STALE trigger %s: tracked but not mapped (now: %s)"):format(
            id, vim.tbl_isempty(real) and "nothing" or describe_map(real)))
        end
      end
    end
    table.insert(lines, "which-key triggers tracked for this buffer: " .. tracked)

    local mode = Buf.get({ buf = buf, mode = "n" })
    if not mode then
      table.insert(lines, "which-key has NO mode for this buffer (start() bails: 'no mode')")
    elseif not mode.tree:find(" ") then
      table.insert(lines, "which-key tree has NO Space node (start() bails: 'no node')")
    end
  end)
  if not ok then
    table.insert(lines, "which-key inspection failed (internals changed?): " .. tostring(err))
  end
  return lines
end

---Reset which-key's trigger bookkeeping and rebuild the current buffer.
local function repair()
  local Triggers = require("which-key.triggers")
  local State = require("which-key.state")
  local Buf = require("which-key.buf")

  State.state = nil
  Triggers.suspended = {}
  -- Forget triggers whose real mapping is gone so update() re-adds them.
  for id, trigger in pairs(Triggers._triggers) do
    local valid = vim.api.nvim_buf_is_valid(trigger.buf)
    local real = valid
        and vim.api.nvim_buf_call(trigger.buf, function()
          return vim.fn.maparg(trigger.keys, trigger.mode, false, true)
        end)
      or {}
    if not valid or not (real.desc or ""):find("which-key-trigger", 1, true) then
      Triggers._triggers[id] = nil
    end
  end
  Buf.clear()
  Buf.get({ update = true })
end

---Diagnose, log, repair, and report whether Space is a which-key trigger again.
function M.run()
  local report = diagnose()
  local ok, err = pcall(repair)
  table.insert(report, ok and "repair: done" or ("repair FAILED: " .. tostring(err)))

  local file = io.open(log_path, "a")
  if file then
    file:write(("== %s\n%s\n"):format(os.date("%Y-%m-%d %H:%M:%S"), table.concat(report, "\n")))
    file:close()
  end

  -- Triggers re-attach on the next tick; verify once they had the chance.
  vim.defer_fn(function()
    local space = vim.fn.maparg(" ", "n", false, true)
    local healthy = (space.desc or ""):find("which-key-trigger", 1, true) ~= nil
    vim.notify(
      table.concat(report, "\n")
        .. "\n\nSpace is "
        .. (healthy and "a which-key trigger again." or "still not a which-key trigger.")
        .. "\nLogged to "
        .. log_path,
      healthy and vim.log.levels.INFO or vim.log.levels.WARN,
      { title = "Leader doctor" }
    )
  end, 100)
end

function M.setup()
  vim.api.nvim_create_user_command("LeaderDoctor", M.run, { desc = "Diagnose and repair a dead <leader>" })end

return M
