---Minimal HTTP/1.1 server on vim.uv for the vale studio. It only has to serve
---its own page: requests are parsed strictly (request line, headers,
---Content-Length bodies) and anything unexpected is answered with 400/413.
---Handlers run via vim.schedule, so they may use any Neovim API.
local M = {}

local MAX_BODY = 1024 * 1024
local MAX_HEADER = 16 * 1024

local REASONS = {
  [200] = "OK",
  [204] = "No Content",
  [400] = "Bad Request",
  [403] = "Forbidden",
  [404] = "Not Found",
  [405] = "Method Not Allowed",
  [409] = "Conflict",
  [413] = "Payload Too Large",
  [500] = "Internal Server Error",
}

---@class ValeRequest
---@field method string
---@field path string
---@field query table<string, string>
---@field headers table<string, string> lower-case names
---@field body string

---@class ValeResponse
---@field send fun(status: integer, body?: string, headers?: table<string, string>)
---@field json fun(status: integer, value: any)
---@field stream fun(): ValeStream switch to a server-sent-events stream

---@class ValeStream
---@field send fun(event: string, data: any): boolean false once the client is gone
---@field comment fun(text: string): boolean
---@field on_close fun(cb: fun())

---@param s string
---@return string
local function url_decode(s)
  s = s:gsub("+", " ")
  return (s:gsub("%%(%x%x)", function(h)
    return string.char(tonumber(h, 16))
  end))
end

---@param head string
---@return ValeRequest|nil
local function parse_head(head)
  local lines = vim.split(head, "\r\n", { plain = true })
  local method, target = lines[1]:match("^(%u+) (%S+) HTTP/1%.[01]$")
  if not method then
    return nil
  end
  local path, qs = target:match("^([^?]*)%??(.*)$")
  local query = {}
  for pair in qs:gmatch("[^&]+") do
    local k, v = pair:match("^([^=]*)=?(.*)$")
    query[url_decode(k)] = url_decode(v)
  end
  local headers = {}
  for i = 2, #lines do
    local k, v = lines[i]:match("^([^:]+):%s*(.-)%s*$")
    if not k then
      return nil
    end
    headers[k:lower()] = v
  end
  return { method = method, path = url_decode(path), query = query, headers = headers, body = "" }
end

---@param client uv.uv_tcp_t
---@param status integer
---@param body string
---@param headers? table<string, string>
local function write_response(client, status, body, headers)
  local out = { ("HTTP/1.1 %d %s"):format(status, REASONS[status] or "Status") }
  headers = vim.tbl_extend("keep", headers or {}, {
    ["Content-Length"] = tostring(#body),
    ["Connection"] = "close",
    ["Cache-Control"] = "no-store",
    ["X-Content-Type-Options"] = "nosniff",
  })
  for k, v in pairs(headers) do
    out[#out + 1] = k .. ": " .. v
  end
  out[#out + 1] = ""
  out[#out + 1] = body
  if not client:is_closing() then
    client:write(table.concat(out, "\r\n"), function()
      if not client:is_closing() then
        client:close()
      end
    end)
  end
end

---@param client uv.uv_tcp_t
---@return ValeResponse
local function response(client)
  local done = false
  local res = {}
  function res.send(status, body, headers)
    if done then
      return
    end
    done = true
    write_response(client, status, body or "", headers)
  end
  function res.json(status, value)
    res.send(status, vim.json.encode(value), { ["Content-Type"] = "application/json; charset=utf-8" })
  end
  function res.stream()
    done = true
    local closers = {}
    local open = true
    client:write(table.concat({
      "HTTP/1.1 200 OK",
      "Content-Type: text/event-stream; charset=utf-8",
      "Cache-Control: no-store",
      "Connection: keep-alive",
      "",
      "",
    }, "\r\n"))
    local function close()
      if not open then
        return
      end
      open = false
      if not client:is_closing() then
        client:close()
      end
      for _, cb in ipairs(closers) do
        vim.schedule(cb)
      end
    end
    -- A read returning EOF/error is how we learn the page went away.
    client:read_start(function(err, chunk)
      if err or not chunk then
        close()
      end
    end)
    local function write(text)
      if not open or client:is_closing() then
        return false
      end
      client:write(text, function(err)
        if err then
          close()
        end
      end)
      return true
    end
    ---@type ValeStream
    return {
      send = function(event, data)
        return write(("event: %s\ndata: %s\n\n"):format(event, vim.json.encode(data)))
      end,
      comment = function(text)
        return write(": " .. text .. "\n\n")
      end,
      on_close = function(cb)
        closers[#closers + 1] = cb
      end,
    }
  end
  return res
end

---Start listening on 127.0.0.1 with a free port.
---@param handler fun(req: ValeRequest, res: ValeResponse)
---@return { port: integer, close: fun() }
function M.start(handler)
  local server = assert(vim.uv.new_tcp())
  assert(server:bind("127.0.0.1", 0))
  server:listen(64, function(err)
    if err then
      return
    end
    local client = assert(vim.uv.new_tcp())
    server:accept(client)
    local buf = ""
    local req ---@type ValeRequest|nil
    local need ---@type integer|nil
    client:read_start(function(rerr, chunk)
      if rerr or not chunk then
        if not client:is_closing() then
          client:close()
        end
        return
      end
      buf = buf .. chunk
      if not req then
        local head_end = buf:find("\r\n\r\n", 1, true)
        if not head_end then
          if #buf > MAX_HEADER then
            client:read_stop()
            write_response(client, 413, "")
          end
          return
        end
        req = parse_head(buf:sub(1, head_end - 1))
        buf = buf:sub(head_end + 4)
        if not req then
          client:read_stop()
          write_response(client, 400, "")
          return
        end
        need = tonumber(req.headers["content-length"] or "0")
        if not need or need < 0 or (req.method == "POST" and not req.headers["content-length"]) then
          client:read_stop()
          write_response(client, 400, "")
          return
        end
        if need > MAX_BODY then
          client:read_stop()
          write_response(client, 413, "")
          return
        end
      end
      if #buf >= need then
        client:read_stop()
        req.body = buf:sub(1, need)
        local r = req
        vim.schedule(function()
          local res = response(client)
          local ok, e = pcall(handler, r, res)
          if not ok then
            res.json(500, { error = tostring(e) })
          end
        end)
      end
    end)
  end)
  local port = server:getsockname().port
  return {
    port = port,
    close = function()
      if not server:is_closing() then
        server:close()
      end
    end,
  }
end

return M
