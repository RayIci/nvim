---WCAG 2.x contrast ratio between two #RRGGBB colours.
local M = {}

---@param hex string
---@return number
local function luminance(hex)
  local function channel(i)
    local v = tonumber(hex:sub(i, i + 1), 16) / 255
    return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4
  end
  return 0.2126 * channel(2) + 0.7152 * channel(4) + 0.0722 * channel(6)
end

---@param a string
---@param b string
---@return number ratio from 1 to 21
function M.ratio(a, b)
  local la, lb = luminance(a), luminance(b)
  if la < lb then
    la, lb = lb, la
  end
  return (la + 0.05) / (lb + 0.05)
end

-- Minimum ratio for body text (WCAG AA).
M.TEXT_MIN = 4.5

return M
