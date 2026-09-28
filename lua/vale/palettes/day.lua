-- vale-day palette (light). Seeded from VS Code Light Modern.
--
-- FORMAT RULES (other tools and :ValeLab rely on them):
--   * Pure data: no functions, no require, no computed values.
--   * One entry per line:  key = "#RRGGBB", -- role
--   * ansi/ui values may instead name a colour from base, accent or signal.
--   * night.lua has exactly the same keys.
--
-- Blocks:
--   base    backgrounds → foregrounds (UI shades)
--   accent  named hues (names describe the hue family, not the syntax role;
--           on white the family goes darker — yellow is brown, orange is brick)
--   signal  diagnostic + git status colours
--   ansi    the 16 terminal colours (slot number in each comment)
--   ui      editor/terminal UI colours portable to other tools

return {
  base = {
    chrome = "#F8F8F8", -- statusline, tabline, sidebars
    bg = "#FFFFFF", -- editor background
    float = "#F8F8F8", -- floating windows, popups
    line = "#EEEEEE", -- cursorline
    border = "#E5E5E5", -- window separators, subtle borders
    surface = "#E8E8E8", -- menus, inputs, selected list item
    overlay = "#CECECE", -- float borders, stronger borders
    guide = "#D3D3D3", -- indent guides
    guide_active = "#939393", -- active indent guide
    linenr = "#6E7681", -- line numbers, fold column
    subtext = "#616161", -- secondary text: descriptions, inactive tabs
    fg = "#3B3B3B", -- main UI text, plain identifiers
    text = "#000000", -- code text: operators, punctuation
    bright = "#000000", -- emphasised text: active tab, selected item
  },

  accent = {
    blue = "#0000FF", -- storage keywords (class, public, def), true/false/null, this/self, tags
    purple = "#AF00DB", -- control flow (if, return, import, try)
    yellow = "#795E26", -- functions and methods
    orange = "#A31515", -- strings
    teal = "#267F99", -- types, classes, namespaces
    light_blue = "#001080", -- variables, parameters, properties
    cyan = "#0070C1", -- constants, enum members
    sage = "#098658", -- numbers
    green = "#008000", -- comments
    red = "#811F3F", -- regular expressions
    gold = "#EE0000", -- escape sequences
    azure = "#005FB8", -- UI accent: focus, active tab marker, mode badge
    sky = "#005FB8", -- links
    amber = "#DDB100", -- lightbulb / code-action marker
  },

  signal = {
    error = "#E51400", -- errors
    warn = "#BF8803", -- warnings
    info = "#0063D3", -- information
    hint = "#6C6C6C", -- hints
    add = "#2EA043", -- git added
    change = "#005FB8", -- git modified
    delete = "#F85149", -- git deleted
  },

  ansi = {
    black = "#000000", -- 0
    red = "#CD3131", -- 1
    green = "#107C10", -- 2
    yellow = "#949800", -- 3
    blue = "#0451A5", -- 4
    magenta = "#BC05BC", -- 5
    cyan = "#0598BC", -- 6
    white = "#555555", -- 7
    bright_black = "#666666", -- 8
    bright_red = "#F14C4C", -- 9
    bright_green = "#14CE14", -- 10
    bright_yellow = "#B5BA00", -- 11
    bright_blue = "#3B8EEA", -- 12
    bright_magenta = "#D670D6", -- 13
    bright_cyan = "#29B8DB", -- 14
    bright_white = "#A5A5A5", -- 15
  },

  ui = {
    bg = "bg", -- terminal/editor background
    fg = "fg", -- terminal/editor foreground
    cursor = "#000000", -- cursor block
    selection = "#ADD6FF", -- visual selection
    selection_inactive = "#E5EBF1", -- selection in unfocused window
    border = "border", -- window borders
    accent = "azure", -- focus / active element
    accent_fg = "#FFFFFF", -- text on accent backgrounds (badges, prompt titles)
    linenr_active = "#171184", -- current line number
    word_highlight = "#D6EAFF", -- other occurrences of word under cursor
    search = "#F8C9AA", -- search matches
    search_current = "#A8AC94", -- current search match
    match_paren = "#E5EFE5", -- matching bracket background
    whitespace = "#D6D6D6", -- listchars, invisible characters
    ghost = "#888888", -- ghost text (AI suggestions)
    inlay_fg = "#969696", -- inlay hint text
    inlay_bg = "#FAFAFA", -- inlay hint background
    codelens = "#919191", -- code lens text
    unnecessary = "#A4A4A4", -- unused code (faded)
    diff_add = "#EBF1DD", -- added line background
    diff_delete = "#FFCCCC", -- deleted line background
    diff_add_text = "#D7E8B1", -- added characters within a line
    diff_delete_text = "#FFA3A3", -- deleted characters within a line
    diff_change = "#E0ECF6", -- changed line background
    diff_text = "#BFD7ED", -- changed characters within a changed line
    rainbow_1 = "#0431FA", -- bracket pair level 1
    rainbow_2 = "#319331", -- bracket pair level 2
    rainbow_3 = "#7B3814", -- bracket pair level 3
  },
}
