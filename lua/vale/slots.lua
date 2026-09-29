-- Slot metadata for the vale studio: one entry per palette key, in display
-- order. Pure data.
--   slot   "block.key" in every theme palette
--   group  foundation | syntax | signals | ui | ansi
--   label  what the colour is used for
--   on     "block.key" the colour is measured against for contrast (text
--          slots: the background they sit on; background slots: the text on them)
--   text   true → mark contrast below 4.5:1
--   alias  true → by default names another colour instead of holding a hex

-- stylua: ignore start
return {

  -- foundation
  { slot = "base.bg", group = "foundation", label = "editor background", on = "base.fg" },
  { slot = "base.fg", group = "foundation", label = "main text", on = "base.bg", text = true },
  { slot = "base.chrome", group = "foundation", label = "statusline, tabline, sidebars", on = "base.fg" },
  { slot = "base.float", group = "foundation", label = "floating windows, popups", on = "base.fg" },
  { slot = "base.line", group = "foundation", label = "cursorline", on = "base.fg" },
  { slot = "base.surface", group = "foundation", label = "menus, inputs, selected list item", on = "base.fg" },
  { slot = "base.border", group = "foundation", label = "window separators", on = "base.bg" },
  { slot = "base.overlay", group = "foundation", label = "float borders", on = "base.float" },
  { slot = "base.linenr", group = "foundation", label = "line numbers", on = "base.bg" },
  { slot = "base.subtext", group = "foundation", label = "secondary text", on = "base.bg", text = true },
  { slot = "base.guide", group = "foundation", label = "indent guides", on = "base.bg" },
  { slot = "base.guide_active", group = "foundation", label = "active indent guide", on = "base.bg" },
  { slot = "base.bright", group = "foundation", label = "emphasised text", on = "base.bg", text = true },

  -- syntax
  { slot = "accent.green", group = "syntax", label = "comments", on = "base.bg", text = true },
  { slot = "base.text", group = "syntax", label = "operators, punctuation", on = "base.bg", text = true },
  { slot = "accent.blue", group = "syntax", label = "storage keywords, true/false, this", on = "base.bg", text = true },
  { slot = "accent.purple", group = "syntax", label = "control flow keywords", on = "base.bg", text = true },
  { slot = "accent.yellow", group = "syntax", label = "functions, methods", on = "base.bg", text = true },
  { slot = "accent.orange", group = "syntax", label = "strings", on = "base.bg", text = true },
  { slot = "accent.teal", group = "syntax", label = "types, classes, namespaces", on = "base.bg", text = true },
  { slot = "accent.cyan", group = "syntax", label = "constants, enum members", on = "base.bg", text = true },
  { slot = "accent.sage", group = "syntax", label = "numbers", on = "base.bg", text = true },
  { slot = "accent.light_blue", group = "syntax", label = "variables, parameters, properties", on = "base.bg", text = true },
  { slot = "accent.gold", group = "syntax", label = "escape sequences", on = "base.bg", text = true },
  { slot = "accent.red", group = "syntax", label = "regular expressions", on = "base.bg", text = true },

  -- signals
  { slot = "signal.error", group = "signals", label = "errors", on = "base.bg", text = true },
  { slot = "signal.warn", group = "signals", label = "warnings", on = "base.bg", text = true },
  { slot = "signal.info", group = "signals", label = "information", on = "base.bg", text = true },
  { slot = "signal.hint", group = "signals", label = "hints", on = "base.bg", text = true },
  { slot = "signal.add", group = "signals", label = "git added", on = "base.bg" },
  { slot = "signal.change", group = "signals", label = "git modified", on = "base.bg" },
  { slot = "signal.delete", group = "signals", label = "git deleted", on = "base.bg" },
  { slot = "ui.diff_add", group = "signals", label = "diff: added line", on = "base.fg" },
  { slot = "ui.diff_delete", group = "signals", label = "diff: deleted line", on = "base.fg" },
  { slot = "ui.diff_add_text", group = "signals", label = "diff: added characters", on = "base.fg" },
  { slot = "ui.diff_delete_text", group = "signals", label = "diff: deleted characters", on = "base.fg" },
  { slot = "ui.diff_change", group = "signals", label = "diff: changed line", on = "base.fg" },
  { slot = "ui.diff_text", group = "signals", label = "diff: changed characters", on = "base.fg" },

  -- ui
  { slot = "ui.bg", group = "ui", label = "terminal/editor background (follows base.bg)", on = "base.fg", alias = true },
  { slot = "ui.fg", group = "ui", label = "terminal/editor foreground (follows base.fg)", on = "base.bg", text = true, alias = true },
  { slot = "ui.border", group = "ui", label = "window borders (follows base.border)", on = "base.bg", alias = true },
  { slot = "ui.accent", group = "ui", label = "UI accent (follows accent.azure)", on = "ui.accent_fg", alias = true },
  { slot = "ui.linenr_active", group = "ui", label = "current line number", on = "base.line", text = true },
  { slot = "ui.whitespace", group = "ui", label = "invisible characters", on = "base.bg" },
  { slot = "ui.selection", group = "ui", label = "visual selection", on = "base.fg" },
  { slot = "ui.selection_inactive", group = "ui", label = "selection, unfocused", on = "base.fg" },
  { slot = "ui.word_highlight", group = "ui", label = "same word under cursor", on = "base.fg" },
  { slot = "ui.search", group = "ui", label = "search matches", on = "base.fg" },
  { slot = "ui.search_current", group = "ui", label = "current search match", on = "base.fg" },
  { slot = "ui.match_paren", group = "ui", label = "matching bracket", on = "base.fg" },
  { slot = "ui.cursor", group = "ui", label = "cursor", on = "base.bg" },
  { slot = "accent.azure", group = "ui", label = "UI accent: focus, mode badge", on = "ui.accent_fg" },
  { slot = "ui.accent_fg", group = "ui", label = "text on accent", on = "accent.azure", text = true },
  { slot = "accent.sky", group = "ui", label = "links, completion match", on = "base.bg", text = true },
  { slot = "accent.amber", group = "ui", label = "lightbulb", on = "base.bg" },
  { slot = "ui.ghost", group = "ui", label = "ghost text (AI)", on = "base.bg" },
  { slot = "ui.inlay_fg", group = "ui", label = "inlay hint text", on = "ui.inlay_bg" },
  { slot = "ui.inlay_bg", group = "ui", label = "inlay hint background", on = "ui.inlay_fg" },
  { slot = "ui.codelens", group = "ui", label = "code lens", on = "base.bg" },
  { slot = "ui.unnecessary", group = "ui", label = "unused code", on = "base.bg" },
  { slot = "ui.rainbow_1", group = "ui", label = "bracket pair 1", on = "base.bg" },
  { slot = "ui.rainbow_2", group = "ui", label = "bracket pair 2", on = "base.bg" },
  { slot = "ui.rainbow_3", group = "ui", label = "bracket pair 3", on = "base.bg" },

  -- ansi
  { slot = "ansi.black", group = "ansi", label = "ANSI 0 black", on = "base.bg" },
  { slot = "ansi.red", group = "ansi", label = "ANSI 1 red", on = "base.bg" },
  { slot = "ansi.green", group = "ansi", label = "ANSI 2 green", on = "base.bg" },
  { slot = "ansi.yellow", group = "ansi", label = "ANSI 3 yellow", on = "base.bg" },
  { slot = "ansi.blue", group = "ansi", label = "ANSI 4 blue", on = "base.bg" },
  { slot = "ansi.magenta", group = "ansi", label = "ANSI 5 magenta", on = "base.bg" },
  { slot = "ansi.cyan", group = "ansi", label = "ANSI 6 cyan", on = "base.bg" },
  { slot = "ansi.white", group = "ansi", label = "ANSI 7 white", on = "base.bg" },
  { slot = "ansi.bright_black", group = "ansi", label = "ANSI 8 bright black", on = "base.bg" },
  { slot = "ansi.bright_red", group = "ansi", label = "ANSI 9 bright red", on = "base.bg" },
  { slot = "ansi.bright_green", group = "ansi", label = "ANSI 10 bright green", on = "base.bg" },
  { slot = "ansi.bright_yellow", group = "ansi", label = "ANSI 11 bright yellow", on = "base.bg" },
  { slot = "ansi.bright_blue", group = "ansi", label = "ANSI 12 bright blue", on = "base.bg" },
  { slot = "ansi.bright_magenta", group = "ansi", label = "ANSI 13 bright magenta", on = "base.bg" },
  { slot = "ansi.bright_cyan", group = "ansi", label = "ANSI 14 bright cyan", on = "base.bg" },
  { slot = "ansi.bright_white", group = "ansi", label = "ANSI 15 bright white", on = "base.bg" },
}
-- stylua: ignore end
