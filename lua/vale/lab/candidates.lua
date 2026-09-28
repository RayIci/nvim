-- :ValeLab slot order and candidate colours. Pure data; rewritten between
-- picking rounds and hot-reloaded by the lab when saved.
--
-- Per slot:
--   slot   palette entry "block.key" that <CR> writes to
--   label  what the colour is used for
--   on     "block.key" the colour is measured against for contrast
--          (text slots: the background it sits on; background slots: the
--          text drawn on top of it)
--   text   true → warn below 4.5:1
--   night/day  extra candidates. The lab always prepends the VS Code
--          reference value and the current palette value, so these are
--          only the alternatives.
--
-- Phases follow the agreed order: foundation → quiet → loud → signals → UI → ANSI.

-- stylua: ignore start
local bg_on = "base.fg" -- background slots are judged by the text on them
local text_on = "base.bg" -- text slots are judged against the editor background

return {
  -- 1. Foundation
  { phase = "foundation", slot = "base.bg", label = "editor background", on = bg_on,
    night = { "#1E1E1E", "#1B1B1B", "#212121", "#1B1D21" },
    day = { "#FAFAFA", "#FDFDFD", "#F7F7F5" } },
  { phase = "foundation", slot = "base.fg", label = "main text", on = text_on, text = true,
    night = { "#D4D4D4", "#C8C8C8", "#DADADA" },
    day = { "#1F1F1F", "#333333", "#444444" } },
  { phase = "foundation", slot = "base.chrome", label = "statusline, tabline, sidebars", on = bg_on,
    night = { "#252526", "#1B1B1B", "#151515" },
    day = { "#F3F3F3", "#F0F0F0", "#FFFFFF" } },
  { phase = "foundation", slot = "base.float", label = "floating windows, popups", on = bg_on,
    night = { "#252526", "#262626", "#1B1B1B" },
    day = { "#F3F3F3", "#FFFFFF", "#F0F0F0" } },
  { phase = "foundation", slot = "base.line", label = "cursorline", on = bg_on,
    night = { "#2A2D2E", "#262626", "#2C2C2C" },
    day = { "#F2F2F2", "#F0F0F0", "#E8F2FF" } },
  { phase = "foundation", slot = "base.surface", label = "menus, inputs, selected list item", on = bg_on,
    night = { "#37373D", "#2D2D30", "#3C3C3C" },
    day = { "#E4E6F1", "#EDEDED", "#E0E0E0" } },
  { phase = "foundation", slot = "base.border", label = "window separators", on = "base.bg",
    night = { "#333333", "#3C3C3C", "#252526" },
    day = { "#D4D4D4", "#DDDDDD", "#EEEEEE" } },
  { phase = "foundation", slot = "base.overlay", label = "float borders", on = "base.float",
    night = { "#454545", "#4B4B4B", "#333333" },
    day = { "#C8C8C8", "#B9B9B9", "#DDDDDD" } },

  -- 2. Quiet
  { phase = "quiet", slot = "accent.green", label = "comments", on = text_on, text = true, night = {}, day = {} },
  { phase = "quiet", slot = "base.linenr", label = "line numbers", on = text_on, night = {}, day = {} },
  { phase = "quiet", slot = "ui.linenr_active", label = "current line number", on = "base.line", text = true, night = {}, day = {} },
  { phase = "quiet", slot = "base.text", label = "operators, punctuation", on = text_on, text = true, night = {}, day = {} },
  { phase = "quiet", slot = "base.subtext", label = "secondary text", on = text_on, text = true, night = {}, day = {} },
  { phase = "quiet", slot = "base.guide", label = "indent guides", on = text_on, night = {}, day = {} },
  { phase = "quiet", slot = "base.guide_active", label = "active indent guide", on = text_on, night = {}, day = {} },
  { phase = "quiet", slot = "ui.whitespace", label = "invisible characters", on = text_on, night = {}, day = {} },
  { phase = "quiet", slot = "base.bright", label = "emphasised text", on = text_on, text = true, night = {}, day = {} },

  -- 3. Loud (most frequent first)
  { phase = "loud", slot = "accent.blue", label = "storage keywords, true/false, this", on = text_on, text = true, night = {}, day = {} },
  { phase = "loud", slot = "accent.purple", label = "control flow keywords", on = text_on, text = true, night = {}, day = {} },
  { phase = "loud", slot = "accent.yellow", label = "functions, methods", on = text_on, text = true, night = {}, day = {} },
  { phase = "loud", slot = "accent.orange", label = "strings", on = text_on, text = true, night = {}, day = {} },
  { phase = "loud", slot = "accent.teal", label = "types, classes, namespaces", on = text_on, text = true, night = {}, day = {} },
  { phase = "loud", slot = "accent.cyan", label = "constants, enum members", on = text_on, text = true, night = {}, day = {} },
  { phase = "loud", slot = "accent.sage", label = "numbers", on = text_on, text = true, night = {}, day = {} },
  { phase = "loud", slot = "accent.light_blue", label = "variables, parameters, properties", on = text_on, text = true, night = {}, day = {} },
  { phase = "loud", slot = "accent.gold", label = "escape sequences", on = text_on, text = true, night = {}, day = {} },
  { phase = "loud", slot = "accent.red", label = "regular expressions", on = text_on, text = true, night = {}, day = {} },

  -- 4. Signals
  { phase = "signals", slot = "signal.error", label = "errors", on = text_on, text = true, night = {}, day = {} },
  { phase = "signals", slot = "signal.warn", label = "warnings", on = text_on, text = true, night = {}, day = {} },
  { phase = "signals", slot = "signal.info", label = "information", on = text_on, text = true, night = {}, day = {} },
  { phase = "signals", slot = "signal.hint", label = "hints", on = text_on, text = true, night = {}, day = {} },
  { phase = "signals", slot = "signal.add", label = "git added", on = text_on, night = {}, day = {} },
  { phase = "signals", slot = "signal.change", label = "git modified", on = text_on, night = {}, day = {} },
  { phase = "signals", slot = "signal.delete", label = "git deleted", on = text_on, night = {}, day = {} },
  { phase = "signals", slot = "ui.diff_add", label = "diff: added line", on = bg_on, night = {}, day = {} },
  { phase = "signals", slot = "ui.diff_delete", label = "diff: deleted line", on = bg_on, night = {}, day = {} },
  { phase = "signals", slot = "ui.diff_add_text", label = "diff: added characters", on = bg_on, night = {}, day = {} },
  { phase = "signals", slot = "ui.diff_delete_text", label = "diff: deleted characters", on = bg_on, night = {}, day = {} },
  { phase = "signals", slot = "ui.diff_change", label = "diff: changed line", on = bg_on, night = {}, day = {} },
  { phase = "signals", slot = "ui.diff_text", label = "diff: changed characters", on = bg_on, night = {}, day = {} },

  -- 5. UI
  { phase = "ui", slot = "ui.selection", label = "visual selection", on = bg_on, night = {}, day = {} },
  { phase = "ui", slot = "ui.selection_inactive", label = "selection, unfocused", on = bg_on, night = {}, day = {} },
  { phase = "ui", slot = "ui.word_highlight", label = "same word under cursor", on = bg_on, night = {}, day = {} },
  { phase = "ui", slot = "ui.search", label = "search matches", on = bg_on, night = {}, day = {} },
  { phase = "ui", slot = "ui.search_current", label = "current search match", on = bg_on, night = {}, day = {} },
  { phase = "ui", slot = "ui.match_paren", label = "matching bracket", on = bg_on, night = {}, day = {} },
  { phase = "ui", slot = "ui.cursor", label = "cursor", on = text_on, night = {}, day = {} },
  { phase = "ui", slot = "accent.azure", label = "UI accent: focus, mode badge", on = "ui.accent_fg", night = {}, day = {} },
  { phase = "ui", slot = "ui.accent_fg", label = "text on accent", on = "accent.azure", text = true, night = {}, day = {} },
  { phase = "ui", slot = "accent.sky", label = "links, completion match", on = text_on, text = true, night = {}, day = {} },
  { phase = "ui", slot = "accent.amber", label = "lightbulb", on = text_on, night = {}, day = {} },
  { phase = "ui", slot = "ui.ghost", label = "ghost text (AI)", on = text_on, night = {}, day = {} },
  { phase = "ui", slot = "ui.inlay_fg", label = "inlay hint text", on = "ui.inlay_bg", night = {}, day = {} },
  { phase = "ui", slot = "ui.inlay_bg", label = "inlay hint background", on = "ui.inlay_fg", night = {}, day = {} },
  { phase = "ui", slot = "ui.codelens", label = "code lens", on = text_on, night = {}, day = {} },
  { phase = "ui", slot = "ui.unnecessary", label = "unused code", on = text_on, night = {}, day = {} },
  { phase = "ui", slot = "ui.rainbow_1", label = "bracket pair 1", on = text_on, night = {}, day = {} },
  { phase = "ui", slot = "ui.rainbow_2", label = "bracket pair 2", on = text_on, night = {}, day = {} },
  { phase = "ui", slot = "ui.rainbow_3", label = "bracket pair 3", on = text_on, night = {}, day = {} },

  -- 6. ANSI (terminal)
  { phase = "ansi", slot = "ansi.black", label = "ANSI 0 black", on = text_on, night = {}, day = {} },
  { phase = "ansi", slot = "ansi.red", label = "ANSI 1 red", on = text_on, night = {}, day = {} },
  { phase = "ansi", slot = "ansi.green", label = "ANSI 2 green", on = text_on, night = {}, day = {} },
  { phase = "ansi", slot = "ansi.yellow", label = "ANSI 3 yellow", on = text_on, night = {}, day = {} },
  { phase = "ansi", slot = "ansi.blue", label = "ANSI 4 blue", on = text_on, night = {}, day = {} },
  { phase = "ansi", slot = "ansi.magenta", label = "ANSI 5 magenta", on = text_on, night = {}, day = {} },
  { phase = "ansi", slot = "ansi.cyan", label = "ANSI 6 cyan", on = text_on, night = {}, day = {} },
  { phase = "ansi", slot = "ansi.white", label = "ANSI 7 white", on = text_on, night = {}, day = {} },
  { phase = "ansi", slot = "ansi.bright_black", label = "ANSI 8 bright black", on = text_on, night = {}, day = {} },
  { phase = "ansi", slot = "ansi.bright_red", label = "ANSI 9 bright red", on = text_on, night = {}, day = {} },
  { phase = "ansi", slot = "ansi.bright_green", label = "ANSI 10 bright green", on = text_on, night = {}, day = {} },
  { phase = "ansi", slot = "ansi.bright_yellow", label = "ANSI 11 bright yellow", on = text_on, night = {}, day = {} },
  { phase = "ansi", slot = "ansi.bright_blue", label = "ANSI 12 bright blue", on = text_on, night = {}, day = {} },
  { phase = "ansi", slot = "ansi.bright_magenta", label = "ANSI 13 bright magenta", on = text_on, night = {}, day = {} },
  { phase = "ansi", slot = "ansi.bright_cyan", label = "ANSI 14 bright cyan", on = text_on, night = {}, day = {} },
  { phase = "ansi", slot = "ansi.bright_white", label = "ANSI 15 bright white", on = text_on, night = {}, day = {} },
}
-- stylua: ignore end
