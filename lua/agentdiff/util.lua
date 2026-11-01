---Small filesystem and time helpers.
---@class AgentdiffUtil
local M = {}

local uv = vim.uv

---Whole file as a string, or nil when it does not exist or is not a file.
---@param path string
---@return string?
function M.read_file(path)
  local st = uv.fs_stat(path)
  if not st or st.type ~= "file" then
    return nil
  end
  local fd = uv.fs_open(path, "r", 438)
  if not fd then
    return nil
  end
  local data = uv.fs_read(fd, st.size, 0) or ""
  uv.fs_close(fd)
  return data
end

---Write a file, creating parent directories. Keeps the existing permission bits.
---@param path string
---@param data string
---@return boolean ok
function M.write_file(path, data)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local st = uv.fs_stat(path)
  local fd = uv.fs_open(path, "w", st and st.mode or 420)
  if not fd then
    return false
  end
  uv.fs_write(fd, data, 0)
  uv.fs_close(fd)
  return true
end

---Wall-clock milliseconds; comparable across processes.
---@return integer
function M.now_ms()
  local sec, usec = uv.gettimeofday()
  return sec * 1000 + math.floor(usec / 1000)
end

---Path relative to root, or nil when outside it.
---@param root string
---@param abs string
---@return string?
function M.relative(root, abs)
  if abs == "" then
    return nil
  end
  abs = vim.fs.normalize(abs)
  local prefix = root:sub(-1) == "/" and root or (root .. "/")
  if abs:sub(1, #prefix) == prefix then
    return abs:sub(#prefix + 1)
  end
  return nil
end

---@param msg string
---@param level integer?
function M.notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "agentdiff" })
end

return M
