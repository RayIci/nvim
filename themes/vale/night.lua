-- vale theme, night variant (dark). Seeded from VS Code Dark Modern.
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
    chrome = "#0D0D0D", -- statusline, tabline, sidebars
    bg = "#101010", -- editor background
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
    blue = "#2A9CEE", -- storage keywords (class, public, def), true/false/null, this/self, tags
    purple = "#D27ACC", -- control flow (if, return, import, try)
    yellow = "#DEDD93", -- functions and methods
    orange = "#DF8864", -- strings
    teal = "#00CEB0", -- types, classes, namespaces
    light_blue = "#9BDCFF", -- variables, parameters, properties
    cyan = "#77BEE9", -- constants, enum members
    sage = "#ADD299", -- numbers
    green = "#5B9E38", -- comments
    red = "#E6545A", -- regular expressions
    gold = "#E1B75A", -- escape sequences
    azure = "#3D7AB9", -- UI accent: focus, active tab marker, mode badge
    sky = "#48AAFF", -- links
    amber = "#F2CF6D", -- lightbulb / code-action marker
  },

  signal = {
    error = "#FF323D", -- errors
    warn = "#C2A957", -- warnings
    info = "#52A4FF", -- information
    hint = "#B3B0A9", -- hints
    add = "#00A335", -- git added
    change = "#3D7AB9", -- git modified
    delete = "#FF4641", -- git deleted
  },

  ansi = {
    black = "#000000", -- 0
    red = "#DA001D", -- 1
    green = "#00BC78", -- 2
    yellow = "#E5E500", -- 3
    blue = "#0070D5", -- 4
    magenta = "#CB00CC", -- 5
    cyan = "#00A8CE", -- 6
    white = "#E8E5DE", -- 7
    bright_black = "#686660", -- 8
    bright_red = "#FF323D", -- 9
    bright_green = "#00D289", -- 10
    bright_yellow = "#F6F500", -- 11
    bright_blue = "#0D8CFF", -- 12
    bright_magenta = "#E756E9", -- 13
    bright_cyan = "#00B9DE", -- 14
    bright_white = "#E8E5DE", -- 15
  },

  ui = {
    bg = "#1D1B16", -- terminal/editor background
    fg = "#CFCCC5", -- terminal/editor foreground
    cursor = "#ACB1A7", -- cursor block
    selection = "#034E8A", -- visual selection
    selection_inactive = "#363D48", -- selection in unfocused window
    border = "#2D2B26", -- window borders
    accent = "#3D7AB9", -- focus / active element
    accent_fg = "#EEEEEE", -- text on accent backgrounds (badges, prompt titles)
    linenr_active = "#CFCCC5", -- current line number
    word_highlight = "#2E3B47", -- other occurrences of word under cursor
    search = "#6A2E00", -- search matches
    search_current = "#9E6A00", -- current search match
    match_paren = "#162817", -- matching bracket background
    whitespace = "#404038", -- listchars, invisible characters
    ghost = "#6D6B65", -- ghost text (AI suggestions)
    inlay_fg = "#98968F", -- inlay hint text
    inlay_bg = "#282621", -- inlay hint background
    codelens = "#9B9992", -- code lens text
    unnecessary = "#94928B", -- unused code (faded)
    diff_add = "#363F1E", -- added line background
    diff_delete = "#57060F", -- deleted line background
    diff_add_text = "#495C07", -- added characters within a line
    diff_delete_text = "#770009", -- deleted characters within a line
    diff_change = "#0C2D43", -- changed line background
    diff_text = "#003A5E", -- changed characters within a changed line
    rainbow_1 = "#F4D971", -- bracket pair level 1
    rainbow_2 = "#EC55E8", -- bracket pair level 2
    rainbow_3 = "#559FE1", -- bracket pair level 3
  },
}
