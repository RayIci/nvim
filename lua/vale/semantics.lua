-- Shared default: semantic roles → palette names, mirroring VS Code's TextMate
-- scopes (see reference/). Highlight groups only ever use these roles, so
-- re-pointing a role recolours every group that means that thing.
--
-- Values are palette names: "blue" (from base/accent/signal) or "ui.<key>";
-- "fg" means plain text. A theme overrides roles in themes/<name>/semantics.lua
-- (top-level for all its variants, or inside `night = {}` / `day = {}`).

return {
  -- Editor surfaces
  bg = "bg",
  bg_chrome = "chrome",
  bg_float = "float",
  bg_line = "line",
  bg_surface = "surface",
  border = "border",
  border_float = "overlay",
  fg = "fg",
  fg_text = "text",
  fg_bright = "bright",
  fg_muted = "subtext",
  linenr = "linenr",
  linenr_active = "ui.linenr_active",
  guide = "guide",
  guide_active = "guide_active",
  whitespace = "ui.whitespace",
  cursor = "ui.cursor",
  selection = "ui.selection",
  selection_inactive = "ui.selection_inactive",
  word_highlight = "ui.word_highlight",
  search = "ui.search",
  search_current = "ui.search_current",
  match_paren = "ui.match_paren",
  ghost = "ui.ghost",
  inlay_fg = "ui.inlay_fg",
  inlay_bg = "ui.inlay_bg",
  codelens = "ui.codelens",
  unnecessary = "ui.unnecessary",
  accent = "ui.accent",
  fg_on_accent = "ui.accent_fg",
  link = "sky",
  lightbulb = "amber",
  folder = "gold",

  -- Syntax
  comment = "green",
  keyword = "blue", -- storage/declaration keywords: class, public, def, let
  keyword_control = "purple", -- control flow: if, for, return, import, try
  func = "yellow",
  string = "orange",
  escape = "gold",
  regex = "red",
  type = "teal",
  type_builtin = "blue", -- int, bool, string (VS Code: storage.type → keyword blue)
  namespace = "teal",
  decorator = "teal", -- @Annotation, [Attribute], @decorator
  variable = "light_blue",
  parameter = "light_blue",
  property = "light_blue",
  constant = "cyan",
  number = "sage",
  boolean = "blue", -- true/false/null (VS Code: constant.language)
  builtin = "blue", -- this/self/super (VS Code: variable.language)
  operator = "text",
  punctuation = "text",
  tag = "blue",
  attribute = "light_blue",
  label = "fg",

  -- Markup
  heading = "blue",
  markup_link = "sky",
  markup_code = "orange",
  markup_list = "sky",
  markup_quote = "green",

  -- Diagnostics
  error = "error",
  warn = "warn",
  info = "info",
  hint = "hint",
  ok = "add",

  -- Git and diff
  git_add = "add",
  git_change = "change",
  git_delete = "delete",
  diff_add = "ui.diff_add",
  diff_delete = "ui.diff_delete",
  diff_add_text = "ui.diff_add_text",
  diff_delete_text = "ui.diff_delete_text",
  diff_change = "ui.diff_change",
  diff_text = "ui.diff_text",

  -- Bracket pairs
  rainbow_1 = "ui.rainbow_1",
  rainbow_2 = "ui.rainbow_2",
  rainbow_3 = "ui.rainbow_3",
}
