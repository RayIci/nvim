---vale studio: a browser page, served by Neovim, for creating and editing
---vale themes. `:Vale` opens the theme list, `:Vale new <name>` the creation
---form, `:Vale edit <name>` a theme's editor, `:Vale stop` shuts it down.
---Edits preview live in Neovim and in the page; nothing is written until Save.
local vale = require("vale")

local M = {}

local plugin_dir = vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))) -- lua/vale
local assets_dir = vim.fs.joinpath(plugin_dir, "studio", "assets")
local IDLE_MS = 30000

---@class ValeSession
---@field name string theme being edited
---@field variant ValeVariant variant shown in Neovim
---@field palette table<string, table<string, string>> variant → "block.key" → hex (unsaved)
---@field semantics table file-shaped semantics being edited
---@field prev string|nil colorscheme active before the editor opened
---@field watcher uv.uv_fs_event_t|nil
---@field quiet_until integer ignore file events until this hrtime (our own saves)

---@class ValeStudio
---@field server { port: integer, close: fun() }
---@field token string
---@field streams table<table, true>
---@field idle uv.uv_timer_t
---@field session ValeSession|nil

---@type ValeStudio|nil
local S = nil

local function broadcast(event, data)
  if not S then
    return
  end
  for stream in pairs(S.streams) do
    if not stream.send(event, data) then
      S.streams[stream] = nil
    end
  end
end

-- Idle shutdown: armed whenever no page is connected.
local function arm_idle()
  if S and next(S.streams) == nil then
    S.idle:stop()
    S.idle:start(
      IDLE_MS,
      0,
      vim.schedule_wrap(function()
        if S and next(S.streams) == nil then
          M.stop()
        end
      end)
    )
  end
end

---Apply the session's unsaved state to Neovim.
local function apply_session()
  local s = S and S.session
  if not s then
    return
  end
  vale.unload()
  vale.load(s.name, s.variant, { palette = s.palette[s.variant], semantics = s.semantics })
  vim.api.nvim_exec_autocmds("ColorScheme", { pattern = vim.g.colors_name, modeline = false })
end

local function stop_watch(s)
  if s and s.watcher and not s.watcher:is_closing() then
    s.watcher:close()
  end
end

---Drop unsaved edits and restore the colorscheme active before editing.
function M.discard()
  local s = S and S.session
  if not s then
    return
  end
  S.session = nil
  stop_watch(s)
  if s.prev then
    pcall(vim.cmd.colorscheme, s.prev)
  end
end

---@param name string
local function watch(s, name)
  local timer = assert(vim.uv.new_timer())
  local w = assert(vim.uv.new_fs_event())
  w:start(vale.theme_path(name), {}, function(_, fname)
    if not (fname and fname:match("%.lua$")) then
      return
    end
    timer:stop()
    timer:start(
      150,
      0,
      vim.schedule_wrap(function()
        if S and S.session == s and vim.uv.hrtime() > s.quiet_until then
          apply_session()
          broadcast("changed", { name = name })
        end
      end)
    )
  end)
  s.watcher = w
end

---Start (or switch) the editing session for a theme variant.
---@param name string
---@param variant ValeVariant
local function begin(name, variant)
  local s = S.session
  if s and s.name ~= name then
    M.discard()
    s = nil
  end
  if not s then
    s = {
      name = name,
      variant = variant,
      palette = { night = {}, day = {} },
      semantics = vale.read_semantics(name),
      prev = vim.g.colors_name,
      quiet_until = 0,
    }
    S.session = s
    watch(s, name)
  end
  s.variant = variant
  apply_session()
end

---Sections and notes of the shared default roles, read from semantics.lua so
---the page shows them in file order.
---@return { role: string, default: string, section: string, note: string|nil }[]
local function roles()
  local out, section = {}, ""
  for _, line in ipairs(vim.fn.readfile(vim.fs.joinpath(plugin_dir, "semantics.lua"))) do
    local header = line:match("^%s*%-%-%s*(%u[%w%s/]+)$")
    if header then
      section = header
    end
    local role, value, note = line:match('^%s*([%w_]+)%s*=%s*"([^"]+)",?%s*%-?%-?%s*(.*)$')
    if role then
      out[#out + 1] = { role = role, default = value, section = section, note = note ~= "" and note or nil }
    end
  end
  return out
end

---@param name string
---@return table|nil
local function theme_payload(name)
  local theme
  for _, t in ipairs(vale.list()) do
    if t.name == name then
      theme = t
    end
  end
  if not theme then
    return nil
  end
  local palettes, resolved = {}, {}
  for _, v in ipairs(theme.variants) do
    palettes[v] = vale.read_palette(name, v)
    local c = vale.resolve(palettes[v])
    resolved[v] = {}
    for _, block in ipairs(vale.blocks) do
      for key in pairs(palettes[v][block]) do
        resolved[v][block .. "." .. key] = (block == "ui" or block == "ansi") and c[block][key] or c[key]
      end
    end
  end
  return {
    name = name,
    variants = theme.variants,
    palettes = palettes,
    resolved = resolved,
    semantics = vale.read_semantics(name),
    roles = roles(),
    slots = dofile(vim.fs.joinpath(plugin_dir, "slots.lua")),
    reference = dofile(vim.fs.joinpath(plugin_dir, "reference", "vscode_modern.lua")),
  }
end

---@return table
local function preview_payload(file)
  local render = require("vale.studio.render")
  return {
    samples = render.samples,
    sample = render.sample(file or render.samples[1].file),
    ui = render.ui(),
    colors_name = vim.g.colors_name,
  }
end

local CONTENT_TYPES = { html = "text/html", js = "text/javascript", css = "text/css" }

---@param req ValeRequest
---@return string|nil reason when the request must be refused
local function refuse(req)
  local port = S.server.port
  local host = req.headers.host
  if host ~= "127.0.0.1:" .. port and host ~= "localhost:" .. port then
    return "bad host"
  end
  local token = req.headers["x-vale-token"] or req.query.t
  if token ~= S.token then
    return "bad token"
  end
  local origin = req.headers.origin
  if
    req.method == "POST"
    and origin
    and origin ~= "http://127.0.0.1:" .. port
    and origin ~= "http://localhost:" .. port
  then
    return "bad origin"
  end
end

---@param req ValeRequest
---@param res ValeResponse
local function handle(req, res)
  if not S then
    return res.send(404)
  end
  local why = refuse(req)
  if why then
    return res.json(403, { error = why })
  end

  -- static assets (the token is injected into the page so it can call back)
  local asset = req.path == "/" and "index.html" or req.path:match("^/([%w%-]+%.[%w]+)$")
  if req.method == "GET" and asset then
    local path = vim.fs.joinpath(assets_dir, asset)
    if not vim.uv.fs_stat(path) then
      return res.send(404)
    end
    local body = table.concat(vim.fn.readfile(path, "b"), "\n")
    if asset == "index.html" then
      body = body:gsub("{{TOKEN}}", S.token)
    end
    return res.send(
      200,
      body,
      { ["Content-Type"] = CONTENT_TYPES[asset:match("%.(%w+)$")] .. "; charset=utf-8" }
    )
  end

  local body = {}
  if req.method == "POST" then
    local ok, decoded =
      pcall(vim.json.decode, req.body ~= "" and req.body or "{}", { luanil = { object = true } })
    if not ok or type(decoded) ~= "table" then
      return res.json(400, { error = "invalid JSON" })
    end
    body = decoded
  end
  local route = req.method .. " " .. req.path

  if route == "GET /api/events" then
    local stream = res.stream()
    S.streams[stream] = true
    S.idle:stop()
    stream.on_close(function()
      if S then
        S.streams[stream] = nil
        arm_idle()
      end
    end)
    stream.send("hello", { colors_name = vim.g.colors_name })
    return
  elseif route == "GET /api/themes" then
    return res.json(200, { themes = vale.list(), editing = S.session and S.session.name })
  elseif req.method == "GET" and req.path:match("^/api/theme/") then
    local payload = theme_payload(req.path:match("^/api/theme/([%w%-]+)$") or "")
    return payload and res.json(200, payload) or res.json(404, { error = "no such theme" })
  elseif route == "POST /api/create" then
    local ok, err = require("vale.studio.generate").create(body.name, body.variants, body.from or "vscode")
    return ok and res.json(200, { name = body.name }) or res.json(409, { error = err })
  elseif route == "POST /api/session" then
    if not theme_payload(body.name or "") or not vim.list_contains(vale.variants, body.variant) then
      return res.json(404, { error = "no such theme variant" })
    end
    begin(body.name, body.variant)
    return res.json(200, preview_payload(body.sample))
  elseif route == "POST /api/preview" then
    local s = S.session
    if not s or s.name ~= body.name then
      return res.json(409, { error = "no editing session for this theme" })
    end
    for _, v in ipairs(vale.variants) do
      local edits = (body.palette or {})[v] or {}
      for slot, hex in pairs(edits) do
        if type(hex) ~= "string" or not hex:match("^#%x%x%x%x%x%x$") then
          return res.json(400, { error = ("invalid colour for %s"):format(slot) })
        end
      end
      s.palette[v] = edits
    end
    s.semantics = body.semantics or s.semantics
    if body.variant then
      s.variant = body.variant
    end
    local ok, err = pcall(apply_session)
    if not ok then
      return res.json(400, { error = tostring(err) })
    end
    return res.json(200, preview_payload(body.sample))
  elseif route == "POST /api/render" then
    return res.json(200, preview_payload(body.sample))
  elseif route == "POST /api/save" then
    local s = S.session
    if not s or s.name ~= body.name then
      return res.json(409, { error = "no editing session for this theme" })
    end
    s.quiet_until = vim.uv.hrtime() + 1e9
    local ok, err = require("vale.studio.writer").save(s.name, s.palette, s.semantics)
    if not ok then
      return res.json(409, { error = err })
    end
    s.palette = { night = {}, day = {} }
    s.semantics = vale.read_semantics(s.name)
    apply_session()
    return res.json(200, { saved = true })
  elseif route == "POST /api/close" then
    M.discard()
    return res.json(200, { closed = true })
  end
  return res.json(404, { error = "unknown route" })
end

---@return string
local function url(fragment)
  return ("http://127.0.0.1:%d/?t=%s%s"):format(S.server.port, S.token, fragment or "")
end

---Start the server if needed and open the page.
---@param fragment? string page route, e.g. "#/edit/vale"
function M.open(fragment)
  if not S then
    local token = vim.fn.sha256(vim.uv.random(16) --[[@as string]]):sub(1, 32)
    S = { token = token, streams = {}, idle = assert(vim.uv.new_timer()) } ---@diagnostic disable-line: missing-fields
    S.server = require("vale.studio.server").start(handle)
    arm_idle()
  end
  local link = url(fragment)
  vim.notify("vale studio: " .. link)
  local _, err = vim.ui.open(link)
  if err then
    vim.notify(
      "vale studio: could not open a browser (" .. err .. "); open the URL above",
      vim.log.levels.WARN
    )
  end
end

---Stop the server, discarding unsaved edits.
function M.stop()
  if not S then
    return
  end
  M.discard()
  broadcast("bye", {})
  local s = S
  S = nil
  s.idle:stop()
  s.idle:close()
  s.server.close()
end

---@return string|nil URL of the running studio (with its access token)
function M.url()
  return S and url()
end

function M.setup()
  vim.api.nvim_create_user_command("Vale", function(opts)
    local sub, arg = opts.fargs[1], opts.fargs[2]
    if not sub then
      M.open("#/")
    elseif sub == "new" then
      M.open("#/new" .. (arg and ("/" .. arg) or ""))
    elseif sub == "edit" and arg then
      M.open("#/edit/" .. arg)
    elseif sub == "stop" then
      M.stop()
    else
      vim.notify("usage: :Vale [new [name] | edit {name} | stop]", vim.log.levels.ERROR)
    end
  end, {
    nargs = "*",
    desc = "vale theme studio",
    complete = function(_, line)
      local words = vim.split(line, "%s+", { trimempty = true })
      if #words <= 1 or (#words == 2 and not line:match("%s$")) then
        return { "new", "edit", "stop" }
      end
      if words[2] == "edit" then
        return vim.tbl_map(function(t)
          return t.name
        end, vale.list())
      end
      return {}
    end,
  })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("vale.studio", { clear = true }),
    callback = function()
      if S then
        S.session = nil -- no colorscheme restore while exiting
        M.stop()
      end
    end,
  })
end

return M
