-- vale palette TEMPLATE: every palette key once, with its role comment.
-- The studio fills values (and the {{…}} header) when creating a theme;
-- names kept in ansi/ui are used when they match the starting values.
--
-- {{name}} theme, {{variant}} variant.
--
-- FORMAT RULES (other tools and the vale studio rely on them):
--   * Pure data: no functions, no require, no computed values.
--   * One entry per line:  key = "#RRGGBB", -- role
--   * ansi/ui values may instead name a colour from base, accent or signal.
--   * Every palette of every theme has exactly the same keys.
--
-- Blocks:
--   base    backgrounds → foregrounds (UI shades)
--   accent  named hues (names describe the hue family, not the syntax role)
--   signal  diagnostic + git status colours
--   ansi    the 16 terminal colours (slot number in each comment)
--   ui      editor/terminal UI colours portable to other tools

return {
  base = {
    chrome = "#000000", -- statusline, tabline, sidebars
    bg = "#000000", -- editor background
    float = "#000000", -- floating windows, popups
    line = "#000000", -- cursorline
    border = "#000000", -- window separators, subtle borders
    surface = "#000000", -- menus, inputs, selected list item
    overlay = "#000000", -- float borders, stronger borders
    guide = "#000000", -- indent guides
    guide_active = "#000000", -- active indent guide
    linenr = "#000000", -- line numbers, fold column
    subtext = "#000000", -- secondary text: descriptions, inactive tabs
    fg = "#000000", -- main UI text, plain identifiers
    text = "#000000", -- code text: operators, punctuation
    bright = "#000000", -- emphasised text: active tab, selected item
  },

  accent = {
    blue = "#000000", -- storage keywords (class, public, def), true/false/null, this/self, tags
    purple = "#000000", -- control flow (if, return, import, try)
    yellow = "#000000", -- functions and methods
    orange = "#000000", -- strings
    teal = "#000000", -- types, classes, namespaces
    light_blue = "#000000", -- variables, parameters, properties
    cyan = "#000000", -- constants, enum members
    sage = "#000000", -- numbers
    green = "#000000", -- comments
    red = "#000000", -- regular expressions
    gold = "#000000", -- escape sequences
    azure = "#000000", -- UI accent: focus, active tab marker, mode badge
    sky = "#000000", -- links
    amber = "#000000", -- lightbulb / code-action marker
  },

  signal = {
    error = "#000000", -- errors
    warn = "#000000", -- warnings
    info = "#000000", -- information
    hint = "#000000", -- hints
    add = "#000000", -- git added
    change = "#000000", -- git modified
    delete = "#000000", -- git deleted
  },

  ansi = {
    black = "#000000", -- 0
    red = "#000000", -- 1
    green = "#000000", -- 2
    yellow = "#000000", -- 3
    blue = "#000000", -- 4
    magenta = "#000000", -- 5
    cyan = "#000000", -- 6
    white = "#000000", -- 7
    bright_black = "#000000", -- 8
    bright_red = "#000000", -- 9
    bright_green = "#000000", -- 10
    bright_yellow = "#000000", -- 11
    bright_blue = "#000000", -- 12
    bright_magenta = "#000000", -- 13
    bright_cyan = "#000000", -- 14
    bright_white = "#000000", -- 15
  },

  ui = {
    bg = "bg", -- terminal/editor background
    fg = "fg", -- terminal/editor foreground
    cursor = "#000000", -- cursor block
    selection = "#000000", -- visual selection
    selection_inactive = "#000000", -- selection in unfocused window
    border = "border", -- window borders
    accent = "azure", -- focus / active element
    accent_fg = "#000000", -- text on accent backgrounds (badges, prompt titles)
    linenr_active = "fg", -- current line number
    word_highlight = "#000000", -- other occurrences of word under cursor
    search = "#000000", -- search matches
    search_current = "#000000", -- current search match
    match_paren = "#000000", -- matching bracket background
    whitespace = "#000000", -- listchars, invisible characters
    ghost = "#000000", -- ghost text (AI suggestions)
    inlay_fg = "#000000", -- inlay hint text
    inlay_bg = "#000000", -- inlay hint background
    codelens = "#000000", -- code lens text
    unnecessary = "#000000", -- unused code (faded)
    diff_add = "#000000", -- added line background
    diff_delete = "#000000", -- deleted line background
    diff_add_text = "#000000", -- added characters within a line
    diff_delete_text = "#000000", -- deleted characters within a line
    diff_change = "#000000", -- changed line background
    diff_text = "#000000", -- changed characters within a changed line
    rainbow_1 = "#000000", -- bracket pair level 1
    rainbow_2 = "#000000", -- bracket pair level 2
    rainbow_3 = "#000000", -- bracket pair level 3
  },
}
