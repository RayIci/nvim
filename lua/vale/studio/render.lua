---Renders vale's sample files for the studio page with the colours Neovim
---currently uses, so the page shows exactly what Neovim would draw. Treesitter
---captures are collected once per sample; each render only resolves the
---highlight groups again (cheap), after the studio has applied its overrides.
local M = {}

local samples_dir =
  vim.fs.joinpath(vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))), "samples")

---Samples shown as tabs, in order.
M.samples = {
  { file = "sample.py", label = "Python" },
  { file = "csharp/Sample.cs", label = "C#" },
  { file = "java/src/main/java/sample/Sample.java", label = "Java" },
  { file = "rust/src/main.rs", label = "Rust" },
  { file = "sample.ts", label = "TypeScript" },
  { file = "sample.lua", label = "Lua" },
  { file = "sample.kt", label = "Kotlin" },
  { file = "sample.sql", label = "SQL" },
  { file = "sample.sh", label = "Bash" },
  { file = "sample.json", label = "JSON" },
  { file = "sample.yaml", label = "YAML" },
  { file = "sample.md", label = "Markdown" },
  { file = "Dockerfile", label = "Dockerfile" },
}

---@class ValeCapture
---@field row integer
---@field s integer byte column (inclusive)
---@field e integer byte column (exclusive)
---@field group string e.g. "@keyword.function.python"
---@field prio integer
---@field order integer

---@type table<string, { lines: string[], captures: ValeCapture[] }>
local cache = {}

---@param file string
---@return { lines: string[], captures: ValeCapture[] }
local function load(file)
  if cache[file] then
    return cache[file]
  end
  local path = vim.fs.joinpath(samples_dir, file)
  local lines = vim.fn.readfile(path)
  local captures = {}
  local ft = vim.filetype.match({ filename = path, contents = lines })
  local lang = ft and (vim.treesitter.language.get_lang(ft) or ft)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, lang)
  if ok and parser then
    parser:parse(true)
    local order = 0
    parser:for_each_tree(function(tree, ltree)
      local tlang = ltree:lang()
      local query = vim.treesitter.query.get(tlang, "highlights")
      if not query then
        return
      end
      for id, node, metadata in query:iter_captures(tree:root(), buf, 0, -1) do
        local name = query.captures[id]
        if not (name:match("^_") or name == "spell" or name == "nospell" or name == "conceal") then
          local sr, sc, er, ec = node:range()
          local prio = tonumber(metadata.priority or (metadata[id] or {}).priority) or 100
          order = order + 1
          for row = sr, er do
            local s = row == sr and sc or 0
            local e = row == er and ec or #(lines[row + 1] or "")
            if e > s then
              captures[#captures + 1] =
                { row = row, s = s, e = e, group = "@" .. name .. "." .. tlang, prio = prio, order = order }
            end
          end
        end
      end
    end)
  end
  vim.api.nvim_buf_delete(buf, { force = true })
  table.sort(captures, function(a, b)
    if a.prio ~= b.prio then
      return a.prio < b.prio
    end
    return a.order < b.order
  end)
  cache[file] = { lines = lines, captures = captures }
  return cache[file]
end

---Highlight attributes for a capture group, falling back through its dotted
---parents the way Neovim does (@keyword.function.python → @keyword.function → @keyword).
---@param group string
---@param memo table<string, table|false>
---@return table|false
local function resolve(group, memo)
  if memo[group] ~= nil then
    return memo[group]
  end
  local name = group
  local found = false
  while name do
    local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
    if hl.fg or hl.bg or hl.bold or hl.italic or hl.underline or hl.undercurl or hl.strikethrough then
      found = hl
      break
    end
    name = name:match("^(.+)%.[^.]+$")
  end
  memo[group] = found
  return found
end

---@param n integer|nil
---@return string|nil
local function hex(n)
  return n and string.format("#%06x", n) or nil
end

---Render one sample with the current highlight groups.
---@param file string
---@return { file: string, lines: string[], runs: table[] }
function M.sample(file)
  local data = load(file)
  local memo = {}
  local per_line = {} ---@type table<integer, table[]> row → byte → attrs
  for _, cap in ipairs(data.captures) do
    local hl = resolve(cap.group, memo)
    if hl then
      local cells = per_line[cap.row] or {}
      per_line[cap.row] = cells
      for col = cap.s, cap.e - 1 do
        local cell = cells[col] or {}
        cells[col] = cell
        cell.fg = hl.fg or cell.fg
        cell.bg = hl.bg or cell.bg
        cell.b = hl.bold or cell.b
        cell.i = hl.italic or cell.i
        cell.u = (hl.underline or hl.undercurl) or cell.u
        cell.st = hl.strikethrough or cell.st
      end
    end
  end
  local runs = {}
  for row, cells in pairs(per_line) do
    local line = data.lines[row + 1] or ""
    local run
    local function key(c)
      return c
        and table.concat(
          { c.fg or "", c.bg or "", c.b and 1 or 0, c.i and 1 or 0, c.u and 1 or 0, c.st and 1 or 0 },
          ","
        )
    end
    local function flush(end_byte)
      if run then
        run.e = vim.str_utfindex(line, "utf-16", end_byte, false)
        runs[#runs + 1] = run
        run = nil
      end
    end
    for col = 0, #line do
      local c = cells[col]
      local k = key(c)
      if not run or run.k ~= k then
        flush(col)
        if c then
          run = {
            row = row,
            s = vim.str_utfindex(line, "utf-16", col, false),
            k = k,
            fg = hex(c.fg),
            bg = hex(c.bg),
            b = c.b or nil,
            i = c.i or nil,
            u = c.u or nil,
            st = c.st or nil,
          }
        end
      end
    end
    flush(#line)
  end
  for _, r in ipairs(runs) do
    r.k = nil
  end
  return { file = file, lines = data.lines, runs = runs }
end

---Editor chrome colours for the preview frame.
---@return table
function M.ui()
  local function get(name)
    return vim.api.nvim_get_hl(0, { name = name, link = false })
  end
  local normal, linenr, cur = get("Normal"), get("LineNr"), get("CursorLine")
  return { fg = hex(normal.fg), bg = hex(normal.bg), linenr = hex(linenr.fg), cursorline = hex(cur.bg) }
end

return M
