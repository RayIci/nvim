---Plugin integrations: one module per installed UI plugin, merged in order.
---
---Coverage checklist (audited against each plugin's source: groups it defines
---or links by default). Plugins not listed either derive their colours from
---core groups on ColorScheme (bufferline, todo-comments, git-conflict) — those
---are still covered by a module that pins the derived groups where needed.
---
---  git        gitsigns diffview neogit git_conflict
---             (octo: plugins/octo.lua rebuilds its groups from standard
---             Diagnostic*/Function/Statement groups, so it follows vale)
---  pickers    telescope flash illuminate grug_far window_picker
---  shell      neotree bufferline navic which_key noice snacks trouble
---             todo_comments indent rainbow toggleterm ufo render_markdown mason
---  code       blink lspsaga lightbulb dap neotest overseer multicursor
---             copilot sidekick
---  lang packs dadbod easy_dotnet kulala
---
---Each module: function(r: ValeRoles, c: resolved palette) → { Group = spec }.

local modules = {
  "gitsigns",
  "diffview",
  "neogit",
  "git_conflict",
  "telescope",
  "flash",
  "illuminate",
  "grug_far",
  "window_picker",
  "neotree",
  "bufferline",
  "navic",
  "which_key",
  "noice",
  "snacks",
  "trouble",
  "todo_comments",
  "indent",
  "rainbow",
  "toggleterm",
  "ufo",
  "render_markdown",
  "mason",
  "blink",
  "lspsaga",
  "lightbulb",
  "dap",
  "neotest",
  "overseer",
  "multicursor",
  "copilot",
  "sidekick",
  "dadbod",
  "easy_dotnet",
  "kulala",
}

---@param r ValeRoles
---@param c table
---@return table<string, vim.api.keyset.highlight>
return function(r, c)
  local groups = {}
  for _, name in ipairs(modules) do
    for group, spec in pairs(require("vale.integrations." .. name)(r, c)) do
      groups[group] = spec
    end
  end
  return groups
end
