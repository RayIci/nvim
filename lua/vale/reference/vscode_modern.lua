-- VS Code Dark Modern / Light Modern reference values for every vale slot.
--
-- Pure data. Same shape as palettes/*.lua (every value is hex here, never a
-- name), so the lab can offer reference[variant][block][key] as candidate 1.
--
-- Sources (microsoft/vscode, main):
--   theme JSON  extensions/theme-defaults/themes/{dark,light}_{modern,plus,vs}.json
--               (modern includes plus, plus includes vs; the last one wins)
--   registry    src/vs/platform/theme/common/colors/editorColors.ts
--               src/vs/editor/common/core/editorColorRegistry.ts
--               src/vs/workbench/contrib/terminal/common/terminalColorRegistry.ts
--               (defaults for keys the theme JSON doesn't set)
-- "blend X over bg" = VS Code's RGBA value composited onto editor.background,
-- because Neovim cannot render alpha.
-- "derived" = VS Code has no equivalent; value chosen to fit, not copied.

return {
  night = {
    base = {
      chrome = "#181818", -- dark_modern: sideBar/statusBar/titleBar/panel.background
      bg = "#1F1F1F", -- dark_modern: editor.background
      float = "#202020", -- dark_modern: editorWidget.background
      line = "#282828", -- registry: editor.lineHighlightBorder (dark)
      border = "#2B2B2B", -- dark_modern: sideBar.border, panel.border, tab.border
      surface = "#313131", -- dark_modern: input.background, dropdown.background
      overlay = "#3C3C3C", -- dark_modern: input.border, dropdown.border
      guide = "#404040", -- dark_vs: editorIndentGuide.background1
      guide_active = "#707070", -- dark_vs: editorIndentGuide.activeBackground1
      linenr = "#6E7681", -- dark_modern: editorLineNumber.foreground
      subtext = "#9D9D9D", -- dark_modern: descriptionForeground, tab.inactiveForeground
      fg = "#CCCCCC", -- dark_modern: editor.foreground
      text = "#D4D4D4", -- dark_vs: editor.foreground; tokens keyword.operator, meta.embedded
      bright = "#FFFFFF", -- dark_modern: tab.activeForeground
    },
    accent = {
      blue = "#569CD6", -- dark_vs: storage, storage.type, keyword, constant.language, variable.language, entity.name.tag, markup.heading
      purple = "#C586C0", -- dark_plus: keyword.control, keyword.operator.new/delete, keyword.other.using
      yellow = "#DCDCAA", -- dark_plus: entity.name.function, support.function
      orange = "#CE9178", -- dark_vs: string; semanticTokenColors.stringLiteral
      teal = "#4EC9B0", -- dark_plus: entity.name.type/class/namespace, support.type/class, storage.type.<lang>
      light_blue = "#9CDCFE", -- dark_plus: variable, meta.object-literal.key; dark_vs: entity.other.attribute-name, support.type.property-name
      cyan = "#4FC1FF", -- dark_plus: variable.other.constant, variable.other.enummember
      sage = "#B5CEA8", -- dark_vs: constant.numeric, markup.inserted; semanticTokenColors.numberLiteral
      green = "#6A9955", -- dark_vs: comment
      red = "#D16969", -- dark_vs: string.regexp
      gold = "#D7BA7D", -- dark_plus: constant.character.escape; dark_vs: entity.name.tag.css
      azure = "#0078D4", -- dark_modern: focusBorder, button.background, statusBar.focusBorder
      sky = "#4DAAFC", -- dark_modern: textLink.foreground
      amber = "#FFCC00", -- registry: editorLightBulb.foreground (dark)
    },
    signal = {
      error = "#F14C4C", -- registry: editorError.foreground (dark)
      warn = "#CCA700", -- registry: editorWarning.foreground (dark)
      info = "#59A4F9", -- registry: editorInfo.foreground (dark)
      hint = "#B0B0B0", -- registry: editorHint.foreground #EEEEEEB3, blend over bg
      add = "#2EA043", -- dark_modern: editorGutter.addedBackground
      change = "#0078D4", -- dark_modern: editorGutter.modifiedBackground
      delete = "#F85149", -- dark_modern: editorGutter.deletedBackground, errorForeground
    },
    ansi = {
      black = "#000000", -- 0  registry: terminal.ansiBlack
      red = "#CD3131", -- 1  registry: terminal.ansiRed
      green = "#0DBC79", -- 2  registry: terminal.ansiGreen
      yellow = "#E5E510", -- 3  registry: terminal.ansiYellow
      blue = "#2472C8", -- 4  registry: terminal.ansiBlue
      magenta = "#BC3FBC", -- 5  registry: terminal.ansiMagenta
      cyan = "#11A8CD", -- 6  registry: terminal.ansiCyan
      white = "#E5E5E5", -- 7  registry: terminal.ansiWhite
      bright_black = "#666666", -- 8  registry: terminal.ansiBrightBlack
      bright_red = "#F14C4C", -- 9  registry: terminal.ansiBrightRed
      bright_green = "#23D18B", -- 10 registry: terminal.ansiBrightGreen
      bright_yellow = "#F5F543", -- 11 registry: terminal.ansiBrightYellow
      bright_blue = "#3B8EEA", -- 12 registry: terminal.ansiBrightBlue
      bright_magenta = "#D670D6", -- 13 registry: terminal.ansiBrightMagenta
      bright_cyan = "#29B8DB", -- 14 registry: terminal.ansiBrightCyan
      bright_white = "#E5E5E5", -- 15 registry: terminal.ansiBrightWhite
    },
    ui = {
      bg = "#1F1F1F", -- dark_modern: editor.background
      fg = "#CCCCCC", -- dark_modern: editor.foreground
      cursor = "#AEAFAD", -- registry: editorCursor.foreground (dark)
      selection = "#264F78", -- registry: editor.selectionBackground (dark)
      selection_inactive = "#3A3D41", -- dark_vs: editor.inactiveSelectionBackground
      border = "#2B2B2B", -- dark_modern: sideBar.border
      accent = "#0078D4", -- dark_modern: focusBorder
      accent_fg = "#FFFFFF", -- dark_modern: button.foreground, activityBarBadge.foreground
      linenr_active = "#CCCCCC", -- dark_modern: editorLineNumber.activeForeground
      word_highlight = "#343A40", -- dark_vs: editor.selectionHighlightBackground #ADD6FF26, blend over bg
      search = "#633315", -- registry: editor.findMatchHighlightBackground #EA5C0055, blend over bg
      search_current = "#9E6A03", -- dark_modern: editor.findMatchBackground
      match_paren = "#1C261C", -- registry: editorBracketMatch.background #0064001A, blend over bg
      whitespace = "#3F3F3E", -- registry: editorWhitespace.foreground #E3E4E229, blend over bg
      ghost = "#6B6B6B", -- registry: editorGhostText.foreground #FFFFFF56, blend over bg
      inlay_fg = "#969696", -- registry: editorInlayHint.foreground
      inlay_bg = "#262626", -- registry: editorInlayHint.background = badge.background #616161 @10%, blend over bg
      codelens = "#999999", -- registry: editorCodeLens.foreground (dark)
      unnecessary = "#929292", -- registry: editorUnnecessaryCode.opacity #000A (fg at 67%), blend over bg
      diff_add = "#383E2A", -- registry: diffEditor.insertedLineBackground rgba(155,185,85,.2), blend over bg
      diff_delete = "#4C1919", -- registry: diffEditor.removedLineBackground rgba(255,0,0,.2), blend over bg
      diff_add_text = "#4C5A2A", -- registry: diffEditor.insertedTextBackground #9CCC2C33, blend over diff_add
      diff_delete_text = "#701414", -- registry: diffEditor.removedTextBackground #FF000033, blend over diff_delete
      diff_change = "#1A2C3A", -- derived: azure @15% over bg (VS Code has no changed-line background)
      diff_text = "#163A55", -- derived: azure @30% over bg
      rainbow_1 = "#FFD700", -- registry: editorBracketHighlight.foreground1 (dark)
      rainbow_2 = "#DA70D6", -- registry: editorBracketHighlight.foreground2 (dark)
      rainbow_3 = "#179FFF", -- registry: editorBracketHighlight.foreground3 (dark)
    },
  },

  day = {
    base = {
      chrome = "#F8F8F8", -- light_modern: sideBar/statusBar/titleBar/panel.background
      bg = "#FFFFFF", -- light_modern: editor.background
      float = "#F8F8F8", -- light_modern: editorWidget.background, editorSuggestWidget.background
      line = "#EEEEEE", -- registry: editor.lineHighlightBorder (light)
      border = "#E5E5E5", -- light_modern: sideBar.border, panel.border, tab.border
      surface = "#E8E8E8", -- light_modern: list.activeSelectionBackground
      overlay = "#CECECE", -- light_modern: input.border, dropdown.border
      guide = "#D3D3D3", -- light_modern: editorIndentGuide.background1
      guide_active = "#939393", -- light_vs: editorIndentGuide.activeBackground1
      linenr = "#6E7681", -- light_modern: editorLineNumber.foreground
      subtext = "#616161", -- light_modern: tab.inactiveForeground
      fg = "#3B3B3B", -- light_modern: editor.foreground
      text = "#000000", -- light_vs: keyword.operator, meta.embedded
      bright = "#000000", -- light_modern: list.activeSelectionForeground
    },
    accent = {
      blue = "#0000FF", -- light_vs: storage, storage.type, keyword, constant.language, variable.language
      purple = "#AF00DB", -- light_plus: keyword.control, keyword.operator.new/delete, keyword.other.using
      yellow = "#795E26", -- light_plus: entity.name.function, support.function
      orange = "#A31515", -- light_vs: string; semanticTokenColors.stringLiteral
      teal = "#267F99", -- light_plus: entity.name.type/class/namespace, support.type/class
      light_blue = "#001080", -- light_plus: variable, meta.object-literal.key
      cyan = "#0070C1", -- light_plus: variable.other.constant, variable.other.enummember
      sage = "#098658", -- light_vs: constant.numeric, markup.inserted; semanticTokenColors.numberLiteral
      green = "#008000", -- light_vs: comment
      red = "#811F3F", -- light_vs: string.regexp
      gold = "#EE0000", -- light_plus: constant.character.escape
      azure = "#005FB8", -- light_modern: focusBorder, button.background
      sky = "#005FB8", -- light_modern: textLink.foreground
      amber = "#DDB100", -- registry: editorLightBulb.foreground (light)
    },
    signal = {
      error = "#E51400", -- registry: editorError.foreground (light)
      warn = "#BF8803", -- registry: editorWarning.foreground (light)
      info = "#0063D3", -- registry: editorInfo.foreground (light)
      hint = "#6C6C6C", -- registry: editorHint.foreground (light)
      add = "#2EA043", -- light_modern: editorGutter.addedBackground
      change = "#005FB8", -- light_modern: editorGutter.modifiedBackground
      delete = "#F85149", -- light_modern: editorGutter.deletedBackground, errorForeground
    },
    ansi = {
      black = "#000000", -- 0  registry: terminal.ansiBlack
      red = "#CD3131", -- 1  registry: terminal.ansiRed
      green = "#107C10", -- 2  registry: terminal.ansiGreen (light)
      yellow = "#949800", -- 3  registry: terminal.ansiYellow (light)
      blue = "#0451A5", -- 4  registry: terminal.ansiBlue (light)
      magenta = "#BC05BC", -- 5  registry: terminal.ansiMagenta (light)
      cyan = "#0598BC", -- 6  registry: terminal.ansiCyan (light)
      white = "#555555", -- 7  registry: terminal.ansiWhite (light)
      bright_black = "#666666", -- 8  registry: terminal.ansiBrightBlack
      bright_red = "#F14C4C", -- 9  registry: terminal.ansiBrightRed
      bright_green = "#14CE14", -- 10 registry: terminal.ansiBrightGreen (light)
      bright_yellow = "#B5BA00", -- 11 registry: terminal.ansiBrightYellow (light)
      bright_blue = "#3B8EEA", -- 12 registry: terminal.ansiBrightBlue
      bright_magenta = "#D670D6", -- 13 registry: terminal.ansiBrightMagenta
      bright_cyan = "#29B8DB", -- 14 registry: terminal.ansiBrightCyan
      bright_white = "#A5A5A5", -- 15 registry: terminal.ansiBrightWhite (light)
    },
    ui = {
      bg = "#FFFFFF", -- light_modern: editor.background
      fg = "#3B3B3B", -- light_modern: editor.foreground
      cursor = "#000000", -- registry: editorCursor.foreground (light)
      selection = "#ADD6FF", -- registry: editor.selectionBackground (light)
      selection_inactive = "#E5EBF1", -- light_modern: editor.inactiveSelectionBackground
      border = "#E5E5E5", -- light_modern: sideBar.border
      accent = "#005FB8", -- light_modern: focusBorder
      accent_fg = "#FFFFFF", -- light_modern: button.foreground
      linenr_active = "#171184", -- light_modern: editorLineNumber.activeForeground
      word_highlight = "#D6EAFF", -- light_modern: editor.selectionHighlightBackground #ADD6FF80, blend over bg
      search = "#F8C9AA", -- registry: editor.findMatchHighlightBackground #EA5C0055, blend over bg
      search_current = "#A8AC94", -- registry: editor.findMatchBackground (light)
      match_paren = "#E5EFE5", -- registry: editorBracketMatch.background #0064001A, blend over bg
      whitespace = "#D6D6D6", -- registry: editorWhitespace.foreground #33333333, blend over bg
      ghost = "#888888", -- registry: editorGhostText.foreground #00000077, blend over bg
      inlay_fg = "#969696", -- registry: editorInlayHint.foreground
      inlay_bg = "#FAFAFA", -- registry: editorInlayHint.background = badge.background #CCCCCC @10%, blend over bg
      codelens = "#919191", -- registry: editorCodeLens.foreground (light)
      unnecessary = "#A4A4A4", -- registry: editorUnnecessaryCode.opacity #0007 (fg at 47%), blend over bg
      diff_add = "#EBF1DD", -- registry: diffEditor.insertedLineBackground rgba(155,185,85,.2), blend over bg
      diff_delete = "#FFCCCC", -- registry: diffEditor.removedLineBackground rgba(255,0,0,.2), blend over bg
      diff_add_text = "#D7E8B1", -- registry: diffEditor.insertedTextBackground #9CCC2C40, blend over diff_add
      diff_delete_text = "#FFA3A3", -- registry: diffEditor.removedTextBackground #FF000033, blend over diff_delete
      diff_change = "#E0ECF6", -- derived: azure @12% over bg (VS Code has no changed-line background)
      diff_text = "#BFD7ED", -- derived: azure @25% over bg
      rainbow_1 = "#0431FA", -- registry: editorBracketHighlight.foreground1 (light)
      rainbow_2 = "#319331", -- registry: editorBracketHighlight.foreground2 (light)
      rainbow_3 = "#7B3814", -- registry: editorBracketHighlight.foreground3 (light)
    },
  },
}
