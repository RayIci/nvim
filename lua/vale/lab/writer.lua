---Writes one palette value in place: finds the `key = "…"` line inside its
---block and swaps only the quoted value, so comments, order and every other
---byte of the file stay untouched (never re-serialises the table).
local M = {}

---@param variant ValeVariant
---@param slot string "block.key"
---@param hex string "#RRGGBB"
---@return boolean ok, string? err
function M.write(variant, slot, hex)
  local block, key = slot:match("^(%w+)%.([%w_]+)$")
  if not block then
    return false, "bad slot " .. slot
  end
  local path = require("vale").palette_path(variant)

  local bufnr = vim.fn.bufnr(path)
  if bufnr ~= -1 and vim.bo[bufnr].modified then
    return false, vim.fs.basename(path) .. " has unsaved changes; save or discard them first"
  end

  local lines = vim.fn.readfile(path)
  local start
  for i, line in ipairs(lines) do
    if line:match("^%s*" .. block .. "%s*=%s*{%s*$") then
      start = i
      break
    end
  end
  if not start then
    return false, ("block %q not found in %s"):format(block, path)
  end

  local matches = {}
  for i = start + 1, #lines do
    local line = lines[i]
    if line:match("^%s*},?%s*$") then
      break
    end
    if line:match("^%s*" .. key .. '%s*=%s*"[^"]*"') then
      matches[#matches + 1] = i
    end
  end
  if #matches ~= 1 then
    return false, ("expected one %q line in %s, found %d"):format(slot, vim.fs.basename(path), #matches)
  end

  local i = matches[1]
  lines[i] = lines[i]:gsub("^(%s*" .. key .. '%s*=%s*")[^"]*(")', "%1" .. hex .. "%2", 1)
  if vim.fn.writefile(lines, path) ~= 0 then
    return false, "could not write " .. path
  end
  if bufnr ~= -1 then
    vim.api.nvim_buf_call(bufnr, function()
      vim.cmd("checktime")
    end)
  end
  return true
end

return M
