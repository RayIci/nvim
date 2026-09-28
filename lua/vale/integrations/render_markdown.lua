---render-markdown.nvim
---@param r ValeRoles
return function(r)
  local g = {
    RenderMarkdownCode = { bg = r.bg_float },
    RenderMarkdownCodeInline = { fg = r.markup_code, bg = r.bg_surface },
    RenderMarkdownCodeBorder = { bg = r.bg_surface },
    RenderMarkdownCodeInfo = { fg = r.fg_muted },
    RenderMarkdownBullet = { fg = r.markup_list },
    RenderMarkdownQuote = { fg = r.markup_quote },
    RenderMarkdownDash = { fg = r.guide_active },
    RenderMarkdownLink = { fg = r.markup_link },
    RenderMarkdownWikiLink = { fg = r.markup_link },
    RenderMarkdownChecked = { fg = r.ok },
    RenderMarkdownUnchecked = { fg = r.fg_muted },
    RenderMarkdownTodo = { fg = r.info },
    RenderMarkdownTableHead = { fg = r.border_float },
    RenderMarkdownTableRow = { fg = r.border_float },
    RenderMarkdownMath = { fg = r.number },
    RenderMarkdownSign = { fg = r.fg_muted },
    RenderMarkdownSuccess = { fg = r.ok },
    RenderMarkdownInfo = { fg = r.info },
    RenderMarkdownHint = { fg = r.hint },
    RenderMarkdownWarn = { fg = r.warn },
    RenderMarkdownError = { fg = r.error },
    RenderMarkdownInlineHighlight = { bg = r.search },
    RenderMarkdownHtmlComment = { fg = r.comment },
  }
  -- VS Code colours every heading level with markup.heading.
  for i = 1, 6 do
    g["RenderMarkdownH" .. i] = { fg = r.heading, bold = true }
    g["RenderMarkdownH" .. i .. "Bg"] = { bg = r.bg_line }
  end
  return g
end
