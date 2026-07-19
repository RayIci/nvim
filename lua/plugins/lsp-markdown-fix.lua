---Normalize LSP markdown before rendering. Some servers (pyright/basedpyright)
---emit escaped markdown (`\\*\\*` for `**`) and HTML entities (`&nbsp;`), which
---show up literally in hover and completion docs. Hooks
---vim.lsp.util.convert_input_to_markdown_lines (in-place: callers like blink
---pass a table and reuse it) plus blink's docs renderer, which may bypass it.
---Ported from ~/dotfiles/.config/nvim/lua/fixes/lsp-markdown-unescape.lua.
---@class PluginLspMarkdownFix
local M = {}

---@type table<string, string>
local html_entities = {
  ["&nbsp;"] = " ",
  ["&lt;"] = "<",
  ["&gt;"] = ">",
  ["&amp;"] = "&",
  ["&quot;"] = '"',
  ["&apos;"] = "'",
  ["&le;"] = "\u{2264}",
  ["&ge;"] = "\u{2265}",
  ["&ne;"] = "\u{2260}",
  ["&mdash;"] = "\u{2014}",
  ["&ndash;"] = "\u{2013}",
  ["&hellip;"] = "\u{2026}",
  ["&rarr;"] = "\u{2192}",
  ["&larr;"] = "\u{2190}",
  ["&bull;"] = "\u{2022}",
}

---Unescape backslash-escaped markdown; double-escapes survive as single escapes.
---@param text string
---@return string
local function unescape_markdown(text)
  return (
    text
      :gsub("\\\\%*", "\1"):gsub("\\\\_", "\2"):gsub("\\\\`", "\3")
      :gsub("\\%*", "*"):gsub("\\_", "_"):gsub("\\`", "`")
      :gsub("\\%[", "["):gsub("\\%]", "]")
      :gsub("\\%(", "("):gsub("\\%)", ")")
      :gsub("\\#", "#"):gsub("\\%+", "+"):gsub("\\%-", "-")
      :gsub("\\%.", "."):gsub("\\!", "!"):gsub("\\|", "|")
      :gsub("\\{", "{"):gsub("\\}", "}")
      :gsub("\1", "\\*"):gsub("\2", "\\_"):gsub("\3", "\\`")
  )
end

---@param text string
---@return string
local function decode_html_entities(text)
  local result = text
  for entity, char in pairs(html_entities) do
    result = result:gsub(entity, char)
  end
  result = result:gsub("&#(%d+);", function(n)
    local num = tonumber(n)
    return (num and num < 0x10FFFF) and vim.fn.nr2char(num) or ("&#" .. n .. ";")
  end)
  result = result:gsub("&#[xX](%x+);", function(n)
    local num = tonumber(n, 16)
    return (num and num < 0x10FFFF) and vim.fn.nr2char(num) or ("&#x" .. n .. ";")
  end)
  return result
end

---@param line string
---@return string
local function process_line(line)
  return decode_html_entities(unescape_markdown(line))
end

---@param contents string|string[]
---@return string|string[]
local function process(contents)
  if type(contents) == "string" then
    return process_line(contents)
  end
  if type(contents) == "table" then
    for i, line in ipairs(contents) do
      if type(line) == "string" then
        contents[i] = process_line(line)
      end
    end
  end
  return contents
end

---blink caches its own reference to the docs renderer, so hook it too.
local function hook_blink()
  local ok, blink_docs = pcall(require, "blink.cmp.lib.window.docs")
  if not ok or not blink_docs.render_detail_and_documentation then
    return
  end
  local orig_render = blink_docs.render_detail_and_documentation
  blink_docs.render_detail_and_documentation = function(opts)
    if type(opts.documentation) == "table" and opts.documentation.value then
      opts.documentation.value = process(opts.documentation.value)
    else
      opts.documentation = process(opts.documentation)
    end
    opts.detail = process(opts.detail)
    return orig_render(opts)
  end
end

function M.setup()
  local orig_convert = vim.lsp.util.convert_input_to_markdown_lines
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.lsp.util.convert_input_to_markdown_lines = function(input, contents)
    local result = orig_convert(input, contents)
    -- Process in-place: when `contents` is given the caller keeps that reference.
    if type(contents) == "table" then
      process(contents)
    end
    if result ~= contents then
      process(result)
    end
    return result
  end

  hook_blink()
end

return M
