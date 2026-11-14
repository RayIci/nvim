---VS Code bridge, loaded by init.lua instead of the full config when Neovim runs
---inside VS Code through vscode-neovim (vim.g.vscode is set).
---
---The plugin/LSP/UI stack is skipped: VS Code provides those. What is left is
---split three ways so that each key lives where it works best:
---  * <leader> (Space): VS Code's which-key menu, NOT this file. keybindings.json
---    binds Space to `whichkey.show`, so Space never reaches Neovim; the menu is
---    `whichkey.bindings` in %APPDATA%\Code\User\settings.json (section
---    "which-key"; from WSL: /mnt/c/Users/<you>/AppData/Roaming/Code/User). It uses the keys of plugins/whichkey.lua's groups, trimmed to
---    what VS Code can do, and also works outside the editor (explorer, panels, lists).
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

-- Copilot <C-w> (accept word) and <C-t> (accept line) are VS Code keybindings
-- that only fire while a suggestion is visible; otherwise the key reaches
-- Neovim, whose built-ins would delete the word just accepted (i_CTRL-W) or
-- indent the line (i_CTRL-T). Same as plugins/copilot.lua: no fallback.
map("i", "<C-w>", "<Nop>", { desc = "Accept Copilot word (no fallback)" })
map("i", "<C-t>", "<Nop>", { desc = "Accept Copilot line (no fallback)" })

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

-- Window resize (<C-arrows>).
map("n", "<C-Up>", action("workbench.action.increaseViewHeight"), { desc = "Grow window height" })
map("n", "<C-Down>", action("workbench.action.decreaseViewHeight"), { desc = "Shrink window height" })
map("n", "<C-Left>", action("workbench.action.decreaseViewWidth"), { desc = "Shrink window width" })
map("n", "<C-Right>", action("workbench.action.increaseViewWidth"), { desc = "Grow window width" })

-- Multicursor (same keys as plugins/visual-multi.lua) --------------------------
-- VS Code holds the extra cursors, but Neovim only sees the main one, and any
-- edit Neovim makes collapses VS Code back to a single cursor. So every key that
-- adds cursors first switches to insert mode (vscode.with_insert keeps a visual
-- selection as a VS Code selection): typing there is VS Code's and goes to every
-- cursor. <Esc> returns to normal mode with one cursor.
-- Repeated <C-n>/<C-p>/<M-Up>/<M-Down> presses in insert mode are VS Code
-- keybindings (keybindings.json); <C-n>/<C-p>/<M-…> reach the maps below only
-- because keybindings.json sends them to Neovim. <leader>ma / <leader>ms call
-- M.* through the `vscode-neovim.lua` command (which-key in settings.json).
local M = {}

---@param name string VS Code command that adds cursors or selections
---@return fun()
local function in_insert(name)
  return function()
    vscode.with_insert(function()
      vscode.action(name)
    end)
  end
end

M.add_next_match = in_insert("editor.action.addSelectionToNextFindMatch")
M.add_prev_match = in_insert("editor.action.addSelectionToPreviousFindMatch")
M.add_all_matches = in_insert("editor.action.selectHighlights")
M.split_lines = in_insert("editor.action.insertCursorAtEndOfEachLineSelected")

map({ "n", "x" }, "<C-n>", M.add_next_match, { desc = "Multicursor: add next match" })
map({ "n", "x" }, "<C-p>", M.add_prev_match, { desc = "Multicursor: add prev match" })
map({ "n", "x" }, "<M-Up>", in_insert("editor.action.insertCursorAbove"), {
  desc = "Multicursor: add cursor above",
})
map({ "n", "x" }, "<M-Down>", in_insert("editor.action.insertCursorBelow"), {
  desc = "Multicursor: add cursor below",
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
map("n", "]x", action("merge-conflict.next"), { desc = "Next conflict" })
map("n", "[x", action("merge-conflict.previous"), { desc = "Previous conflict" })

-- Folds (config/folds.lua) ---------------------------------------------------
map("n", "zR", action("editor.unfoldAll"), { desc = "Open all folds" })
map("n", "zM", action("editor.foldAll"), { desc = "Close all folds" })
map("n", "za", action("editor.toggleFold"), { desc = "Toggle fold" })
map("n", "zc", action("editor.fold"), { desc = "Close fold" })
map("n", "zo", action("editor.unfold"), { desc = "Open fold" })
map("n", "zC", action("editor.foldRecursively"), { desc = "Close folds recursively" })
map("n", "zO", action("editor.unfoldRecursively"), { desc = "Open folds recursively" })

-- Open from a list in normal mode ---------------------------------------------
-- Problems, search results, references, ... open the file with the problem/match
-- range selected, and vscode-neovim turns any non-empty VS Code selection into
-- visual mode. Moving through those lists previews the item the same way. So
-- keybindings.json runs M.normal_after_jump after every open/move in Problems,
-- Search, the References view and the peek widget (grr). The JS collapses that
-- selection to its start; vscode-neovim then sees an empty selection and stays
-- in (or returns to) normal mode.
--   * The editor may not be open yet when this runs: wait up to 2 s for the
--     selection (the first file after a window reload is slow to open).
--   * vscode-neovim re-applies the old selection 20-450 ms after the first
--     collapse, once or twice: keep collapsing until it's quiet for 0.8 s.
--   * Opens report no selection kind (undefined), previews report Command: only
--     clicks and typing are left alone.
--   * Each call cancels the previous wait, so fast j/k don't pile up.
local COLLAPSE_JUMP_SELECTION_JS = [[
globalThis.__nvimCancelJumpWait?.();
const K = vscode.TextEditorSelectionChangeKind;
const collapse = (editor) => {
  if (editor.selection.isEmpty && editor.selections.length === 1) { return false; }
  const start = editor.selection.start;
  editor.selection = new vscode.Selection(start, start);
  return true;
};
await new Promise((resolve) => {
  let timer = setTimeout(done, 2000);
  const quiet = () => { clearTimeout(timer); timer = setTimeout(done, 800); };
  const sub = vscode.window.onDidChangeTextEditorSelection((e) => {
    if (e.kind !== K.Mouse && e.kind !== K.Keyboard && collapse(e.textEditor)) { quiet(); }
  });
  function done() {
    clearTimeout(timer);
    sub.dispose();
    if (globalThis.__nvimCancelJumpWait === done) { globalThis.__nvimCancelJumpWait = undefined; }
    resolve();
  }
  globalThis.__nvimCancelJumpWait = done;
  const now = vscode.window.activeTextEditor;
  if (now && collapse(now)) { quiet(); }
});
]]

function M.normal_after_jump()
  vscode.eval_async(COLLAPSE_JUMP_SELECTION_JS)
end

-- Merge editor <C-h>/<C-l> ---------------------------------------------------
-- The merge editor (mixed layout: Incoming | Current on top, Result below) is
-- one editor in one group, so navigateLeft/Right jump straight out of it, and
-- no context key tells Incoming from Current. keybindings.json calls
-- M.merge_nav through the `vscode-neovim.lua` command; the JS finds the focused
-- pane by comparing the active text editor with the URIs of the active merge
-- tab (TabInputTextMerge), which works for any merge, not just Git's.
--   Incoming: <C-h> sidebar,  <C-l> Current
--   Current:  <C-h> Incoming, <C-l> Copilot bar (auxiliary bar)
--   Base:     <C-h> Incoming, <C-l> Current
--   Result:   <C-h> sidebar,  <C-l> Copilot bar
-- mergeEditor.toggleBetweenInputs focuses Incoming, or Current when Incoming
-- already has focus; there is no command to focus a given pane. Leaving uses
-- focusSideBar / focusAuxiliaryBar: navigateLeft/Right didn't get out of
-- Result. <C-j>/<C-k> between the top panes and Result are plain keybindings.
local MERGE_NAV_JS = [[
const run = async (...ids) => { for (const id of ids) { await vscode.commands.executeCommand(id); } };
const left = args.dir === 'left';
const merge = vscode.window.tabGroups.activeTabGroup.activeTab?.input;
const doc = vscode.window.activeTextEditor?.document.uri.toString();
if (!(merge instanceof vscode.TabInputTextMerge) || !doc) {
  return run(left ? 'workbench.action.navigateLeft' : 'workbench.action.navigateRight');
}
const TOGGLE = 'mergeEditor.toggleBetweenInputs';
const OUT = left ? 'workbench.action.focusSideBar' : 'workbench.action.focusAuxiliaryBar';
const focused = (uri) => uri !== undefined && uri.toString() === doc;
if (focused(merge.input1)) { return left ? run(OUT) : run(TOGGLE); }
if (focused(merge.input2)) { return left ? run(TOGGLE) : run(OUT); }
if (focused(merge.base)) { return left ? run(TOGGLE) : run(TOGGLE, TOGGLE); }
return run(OUT);
]]

---@param dir "left"|"right"
function M.merge_nav(dir)
  vscode.eval_async(MERGE_NAV_JS, { args = { dir = dir } })
end

-- SCM commit box <C-j> ---------------------------------------------------------
-- keybindings.json: <C-j> in the commit box goes down to the changes list
-- (workbench.scm.action.focusNextResourceGroup). In a clean repo there is no
-- resource group, so that command silently does nothing, and no context key
-- says whether a repo has changes. With changes, focus the list; clean, go on
-- to the Graph (`graph`: keybindings.json passes whether it's expanded,
-- view.workbench.scm.history.visible) or down to the panel.
-- The check is `git status` run here, not the Git extension API: with
-- vscode-neovim.useWSL, vscode-neovim (and eval'd JS) runs in the Windows
-- extension host while the Git extension runs in WSL, out of reach. Neovim
-- itself runs in WSL, next to git and the repo. Only the workspace folder
-- paths come from VS Code. Anything that isn't a clean Git repo (error, not a
-- repo, Windows path) counts as "has changes": the plain command, as before.
local SCM_FOCUS_CHANGES = "workbench.scm.action.focusNextResourceGroup"

---@param graph boolean the Graph section is expanded
function M.scm_down(graph)
  local folders = vscode.eval("return (vscode.workspace.workspaceFolders ?? []).map((f) => f.uri.path)") or {}
  if #folders == 0 then
    return vscode.action(SCM_FOCUS_CHANGES)
  end
  local pending, dirty = #folders, false
  local function done(has_changes)
    dirty = dirty or has_changes
    pending = pending - 1
    if pending == 0 then
      vim.schedule(function()
        local clean_target = graph and "workbench.scm.history.focus" or "workbench.action.navigateDown"
        vscode.action(dirty and SCM_FOCUS_CHANGES or clean_target)
      end)
    end
  end
  for _, path in ipairs(folders) do
    local ok = pcall(vim.system, { "git", "-C", path, "status", "--porcelain", "--ignore-submodules" }, { text = true }, function(r)
      done(r.code ~= 0 or (r.stdout or "") ~= "")
    end)
    if not ok then
      done(true)
    end
  end
end

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

return M
