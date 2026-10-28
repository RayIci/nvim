---VS Code bridge, loaded by init.lua instead of the full config when Neovim runs
---inside VS Code through vscode-neovim (vim.g.vscode is set).
---
---The plugin/LSP/UI stack is skipped: VS Code provides those. What is left is
---split three ways so that each key lives where it works best:
---  * <leader> (Space): VS Code's which-key menu (`whichkey.bindings` in the
---    VS Code settings.json). It mirrors the groups of plugins/whichkey.lua and
---    also works outside the editor (explorer, panels, lists).
---  * <C-…> workbench keys (<C-h/j/k/l>, <C-t>, <C-s>, Copilot): VS Code's
---    keybindings.json, for the same reason.
---  * Printable-key mappings (this file): they must go through Neovim so counts,
---    pending operators and f/t/r targets keep working.
local vscode = require("vscode")

local map = vim.keymap.set

---@param name string VS Code command id
---@param opts? table forwarded to vscode.action (args, range, ...)
---@return fun()
local function action(name, opts)
  return function()
    vscode.action(name, opts)
  end
end

-- vscode-neovim ships its own clipboard provider; config.clipboard (WSL
-- provider selection) is not needed here.
vim.opt.clipboard = "unnamedplus"

-- Editing (config.keymaps) ---------------------------------------------------

-- J/K move lines; VS Code's command keeps the indentation right without `==`.
map("n", "J", action("editor.action.moveLinesDownAction"), { desc = "Move line down" })
map("n", "K", action("editor.action.moveLinesUpAction"), { desc = "Move line up" })
map("x", "J", ":m '>+1<cr>gv", { silent = true, desc = "Move selection down" })
map("x", "K", ":m '<-2<cr>gv", { silent = true, desc = "Move selection up" })

map("x", "<", "<gv", { desc = "Dedent selection" })
map("x", ">", ">gv", { desc = "Indent selection" })

-- Clear search highlight (<Esc> and <C-x>, as in config.keymaps). Without the
-- map, <C-x> fell through to Vim's default and decremented the number under cursor.
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })
map("n", "<C-x>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })

-- Keep the cursor centered on search hits and half-page jumps (`nzzzv`, `<C-d>zz`).
-- The viewport belongs to VS Code: Neovim's built-in zz only scrolls Neovim's
-- hidden window, so `remap = true` lets `zz` resolve to vscode-neovim's own zz
-- mapping, which asks VS Code to reveal the line in the center.
map("n", "n", "nzz", { remap = true, desc = "Next match (centered)" })
map("n", "N", "Nzz", { remap = true, desc = "Previous match (centered)" })

-- <C-d>zz / <C-u>zz. Doing it as `{n}j` + `zz` in Neovim races: vscode-neovim's
-- zz centers on VS Code's cursor, which hasn't caught up with the jump yet, and
-- Neovim's own window scroll fights VS Code's. So the whole move runs inside
-- VS Code in one step: move the cursor half a visible page and reveal it in
-- the center; vscode-neovim then syncs Neovim's cursor from the new selection.
local HALF_PAGE_JS = [[
const editor = vscode.window.activeTextEditor;
if (!editor) { return; }
const visible = editor.visibleRanges[0];
const half = Math.max(1, Math.floor((visible.end.line - visible.start.line) / 2));
const step = (args.count > 0 ? args.count : half) * args.dir;
const cursor = editor.selection.active;
const line = Math.min(Math.max(cursor.line + step, 0), editor.document.lineCount - 1);
const target = editor.document.validatePosition(new vscode.Position(line, cursor.character));
editor.selection = new vscode.Selection(target, target);
editor.revealRange(new vscode.Range(target, target), vscode.TextEditorRevealType.InCenter);
]]

---@param dir 1|-1
---@return fun()
local function half_page(dir)
  return function()
    -- A count before <C-d>/<C-u> is taken as the number of lines.
    vscode.eval_async(HALF_PAGE_JS, { args = { dir = dir, count = vim.v.count } })
  end
end

-- keybindings.json sends <C-d>/<C-u> to Neovim (instead of vscode-neovim's own
-- scroll command) so these mappings run.
map("n", "<C-d>", half_page(1), { desc = "Half page down (centered)" })
map("n", "<C-u>", half_page(-1), { desc = "Half page up (centered)" })
-- Visual mode keeps vscode-neovim's scroll, which extends the selection correctly.
map("x", "<C-d>", action("vscode-neovim.ctrl-d"), { desc = "Half page down" })
map("x", "<C-u>", action("vscode-neovim.ctrl-u"), { desc = "Half page up" })

-- Window resize (<C-arrows>); in visual mode they add cursors, as multicursor.nvim does.
map("n", "<C-Up>", action("workbench.action.increaseViewHeight"), { desc = "Grow window height" })
map("n", "<C-Down>", action("workbench.action.decreaseViewHeight"), { desc = "Shrink window height" })
map("n", "<C-Left>", action("workbench.action.decreaseViewWidth"), { desc = "Shrink window width" })
map("n", "<C-Right>", action("workbench.action.increaseViewWidth"), { desc = "Grow window width" })
map("x", "<C-Up>", action("editor.action.insertCursorAbove"), { desc = "Multicursor: add above" })
map("x", "<C-Down>", action("editor.action.insertCursorBelow"), { desc = "Multicursor: add below" })

-- Multicursor (plugins/visual-multi.lua): <C-n>/<C-p> add the next/previous match.
map({ "n", "x" }, "<C-n>", action("editor.action.addSelectionToNextFindMatch"), {
  desc = "Multicursor: add next match",
})
map({ "n", "x" }, "<C-p>", action("editor.action.addSelectionToPreviousFindMatch"), {
  desc = "Multicursor: add prev match",
})

-- Buffers (bufferline) -------------------------------------------------------
-- In LSP buffers the old config shadows <S-h> with hover (plugins/lsp.lua), and
-- every buffer is an "LSP buffer" in VS Code: H is hover, <S-Tab> goes back.
map("n", "L", action("workbench.action.nextEditorInGroup"), { desc = "Next buffer" })
map("n", "<Tab>", action("workbench.action.nextEditorInGroup"), { desc = "Next buffer" })
map("n", "<S-Tab>", action("workbench.action.previousEditorInGroup"), { desc = "Previous buffer" })
map("n", "[b", action("workbench.action.moveEditorLeftInGroup"), { desc = "Move buffer left" })
map("n", "]b", action("workbench.action.moveEditorRightInGroup"), { desc = "Move buffer right" })

-- LSP (plugins/lsp.lua). gd and gO are already vscode-neovim defaults.
map("n", "H", action("editor.action.showHover"), { desc = "Hover docs" })
map("n", "gD", action("editor.action.revealDeclaration"), { desc = "Goto declaration" })
map("n", "grr", action("editor.action.referenceSearch.trigger"), { desc = "References" })
map("n", "gri", action("editor.action.goToImplementation"), { desc = "Goto implementation" })
map("n", "grt", action("editor.action.goToTypeDefinition"), { desc = "Goto type definition" })
map("n", "grn", action("editor.action.rename"), { desc = "Rename symbol" })
map({ "n", "x" }, "gra", action("editor.action.quickFix"), { desc = "Code action" })

-- Bracket motions --------------------------------------------------------------
map("n", "]d", action("editor.action.marker.next"), { desc = "Next diagnostic" })
map("n", "[d", action("editor.action.marker.prev"), { desc = "Previous diagnostic" })
map("n", "]h", action("workbench.action.editor.nextChange"), { desc = "Next hunk" })
map("n", "[h", action("workbench.action.editor.previousChange"), { desc = "Previous hunk" })
map("n", "]]", action("editor.action.wordHighlight.next"), { desc = "Next reference" })
map("n", "[[", action("editor.action.wordHighlight.prev"), { desc = "Previous reference" })
-- ]t/[t: todo-comments is set up after neotest in plugins/init.lua, so TODOs win.
map("n", "]t", action("todo-tree.goToNext"), { desc = "Next TODO" })
map("n", "[t", action("todo-tree.goToPrevious"), { desc = "Previous TODO" })

-- Folds (plugins/folding.lua) ------------------------------------------------
map("n", "zR", action("editor.unfoldAll"), { desc = "Open all folds" })
map("n", "zM", action("editor.foldAll"), { desc = "Close all folds" })
map("n", "za", action("editor.toggleFold"), { desc = "Toggle fold" })
map("n", "zc", action("editor.fold"), { desc = "Close fold" })
map("n", "zo", action("editor.unfold"), { desc = "Open fold" })
map("n", "zC", action("editor.foldRecursively"), { desc = "Close folds recursively" })
map("n", "zO", action("editor.unfoldRecursively"), { desc = "Open folds recursively" })

-- Text-only plugins that work under vscode-neovim ---------------------------
-- Same modules as the full config, so their keymaps stay defined in one place.
-- packadd finds them where vim.pack installed them (site/pack/core/opt).
for _, plugin in ipairs({
  { pack = "flash.nvim", module = "plugins.flash" }, -- s / S / R
  { pack = "nvim-surround", module = "plugins.surround" }, -- ys / cs / ds
}) do
  local ok, err = pcall(function()
    vim.cmd.packadd(plugin.pack)
    require(plugin.module).setup()
  end)
  if not ok then
    vim.notify(("vscode: %s not loaded: %s"):format(plugin.pack, err), vim.log.levels.WARN)
  end
end
