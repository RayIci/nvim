local repo = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")

---Function names in the first column of a README table that follows `heading`.
local function documented(heading)
  local readme = table.concat(vim.fn.readfile(repo .. "/lua/agentdiff/README.md"), "\n")
  local section = readme:match(heading .. "\n(.-)\n## ")
  assert(section, "README section " .. heading)
  local names = {}
  for row in section:gmatch("\n| `[^|]+|") do
    for name in row:gmatch("`([%w_]+)%(") do
      names[#names + 1] = name
    end
  end
  return names
end

describe("documented API", function()
  it("exists for every function in the README", function()
    local agentdiff = require("agentdiff")
    local names = documented("## Lua API")
    ok(#names >= 20, "found the API table (" .. #names .. " names)")
    for _, n in ipairs(names) do
      eq("function", type(agentdiff[n]), "agentdiff." .. n)
    end
  end)
end)

describe("documented command", function()
  it("lists exactly the real subcommands", function()
    local readme = table.concat(vim.fn.readfile(repo .. "/lua/agentdiff/README.md"), "\n")
    local section = assert(readme:match("## Command\n(.-)\n## "))
    local names = {}
    for row in section:gmatch("\n| `[^\n]+") do
      local first = row:match("^\n| ([^|]+)|")
      for name in (first or ""):gmatch("`([%w_]+)`") do
        names[#names + 1] = name
      end
    end
    table.sort(names)
    local real = vim.tbl_keys(require("agentdiff").subcommands)
    table.sort(real)
    eq(real, names)
  end)
end)
