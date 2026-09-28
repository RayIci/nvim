-- vale-night palette (dark). Seeded from VS Code Dark Modern.
--
-- FORMAT RULES (other tools and :ValeLab rely on them):
--   * Pure data: no functions, no require, no computed values.
--   * One entry per line:  key = "#RRGGBB", -- role
--   * ansi/ui values may instead name a colour from base, accent or signal.
--   * day.lua has exactly the same keys.
--
-- Blocks:
--   base    backgrounds → foregrounds (UI shades)
--   accent  named hues (names describe the hue family, not the syntax role)
--   signal  diagnostic + git status colours
--   ansi    the 16 terminal colours (slot number in each comment)
--   ui      editor/terminal UI colours portable to other tools

return {
  base = {
    chrome = "#181818", -- statusline, tabline, sidebars
    bg = "#1B1B1B", -- editor background
    float = "#202020", -- floating windows, popups
    line = "#282828", -- cursorline
    border = "#2B2B2B", -- window separators, subtle borders
    surface = "#313131", -- menus, inputs, selected list item
    overlay = "#3C3C3C", -- float borders, stronger borders
    guide = "#404040", -- indent guides
    guide_active = "#707070", -- active indent guide
    linenr = "#6E7681", -- line numbers, fold column
    subtext = "#9D9D9D", -- secondary text: descriptions, inactive tabs
    fg = "#CCCCCC", -- main UI text, plain identifiers
    text = "#D4D4D4", -- code text: operators, punctuation
    bright = "#FFFFFF", -- emphasised text: active tab, selected item
  },

  accent = {
    blue = "#569CD6", -- storage keywords (class, public, def), true/false/null, this/self, tags
    purple = "#C586C0", -- control flow (if, return, import, try)
    yellow = "#DCDCAA", -- functions and methods
    orange = "#CE9178", -- strings
    teal = "#4EC9B0", -- types, classes, namespaces
    light_blue = "#9CDCFE", -- variables, parameters, properties
    cyan = "#4FC1FF", -- constants, enum members
    sage = "#B5CEA8", -- numbers
    green = "#6A9955", -- comments
    red = "#D16969", -- regular expressions
    gold = "#D7BA7D", -- escape sequences
    azure = "#0078D4", -- UI accent: focus, active tab marker, mode badge
    sky = "#4DAAFC", -- links
    amber = "#FFCC00", -- lightbulb / code-action marker
  },

  signal = {
    error = "#F14C4C", -- errors
    warn = "#CCA700", -- warnings
    info = "#59A4F9", -- information
    hint = "#B0B0B0", -- hints
    add = "#2EA043", -- git added
    change = "#0078D4", -- git modified
    delete = "#F85149", -- git deleted
  },

  ansi = {
    black = "#000000", -- 0
    red = "#CD3131", -- 1
    green = "#0DBC79", -- 2
    yellow = "#E5E510", -- 3
    blue = "#2472C8", -- 4
    magenta = "#BC3FBC", -- 5
    cyan = "#11A8CD", -- 6
    white = "#E5E5E5", -- 7
    bright_black = "#666666", -- 8
    bright_red = "#F14C4C", -- 9
    bright_green = "#23D18B", -- 10
    bright_yellow = "#F5F543", -- 11
    bright_blue = "#3B8EEA", -- 12
    bright_magenta = "#D670D6", -- 13
    bright_cyan = "#29B8DB", -- 14
    bright_white = "#E5E5E5", -- 15
  },

  ui = {
    bg = "bg", -- terminal/editor background
    fg = "fg", -- terminal/editor foreground
    cursor = "#AEAFAD", -- cursor block
    selection = "#264F78", -- visual selection
    selection_inactive = "#3A3D41", -- selection in unfocused window
    border = "border", -- window borders
    accent = "azure", -- focus / active element
    accent_fg = "#FFFFFF", -- text on accent backgrounds (badges, prompt titles)
    linenr_active = "fg", -- current line number
    word_highlight = "#343A40", -- other occurrences of word under cursor
    search = "#633315", -- search matches
    search_current = "#9E6A03", -- current search match
    match_paren = "#1C261C", -- matching bracket background
    whitespace = "#3F3F3E", -- listchars, invisible characters
    ghost = "#6B6B6B", -- ghost text (AI suggestions)
    inlay_fg = "#969696", -- inlay hint text
    inlay_bg = "#262626", -- inlay hint background
    codelens = "#999999", -- code lens text
    unnecessary = "#929292", -- unused code (faded)
    diff_add = "#383E2A", -- added line background
    diff_delete = "#4C1919", -- deleted line background
    diff_add_text = "#4C5A2A", -- added characters within a line
    diff_delete_text = "#701414", -- deleted characters within a line
    diff_change = "#1A2C3A", -- changed line background
    diff_text = "#163A55", -- changed characters within a changed line
    rainbow_1 = "#FFD700", -- bracket pair level 1
    rainbow_2 = "#DA70D6", -- bracket pair level 2
    rainbow_3 = "#179FFF", -- bracket pair level 3
  },
}
