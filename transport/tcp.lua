local core = require "core"
local net = require "net"
local Object = require "core.object"

local CONNECT_TIMEOUT_MS = 10000
local CONNECT_RETRY_DELAY = 0.05

---@class lsp.transport.tcp : lsp.transport, core.object
---@field public kind '"tcp"'
---@field public proc process | nil
---@field public socket net.tcp | nil
---@field public startup_ok boolean
---@field public startup_error string | nil
---@field public host string | nil
---@field public port integer | nil
---@field public address net.address | nil
---@field public deadline number
---@field public next_attempt number
---@field public last_error string | nil
---@field public state '"resolving"' | '"connecting"' | '"ready"' | '"failed"'
---@field super core.object
local TcpTransport = Object:extend()

---@return string
local function join_error(...)
  local parts = {}
  for _, value in ipairs({ ... }) do
    if value and value ~= "" then
      table.insert(parts, value)
    end
  end
  return table.concat(parts, "\n")
end

---@param proc process?
---@return string
local function get_process_stderr(proc)
  if not proc then
    return ""
  end

  local output = proc:read_stderr(4096) or ""
  local chunk = output
  while chunk and chunk ~= "" do
    chunk = proc:read_stderr(4096)
    if chunk and chunk ~= "" then
      output = output .. chunk
    end
  end

  return output
end

---@param options lsp.server.options
function TcpTransport:new(options)
  self.kind = "tcp"
  self.proc = nil
  self.socket = nil
  self.startup_ok = false
  self.startup_error = nil
  self.host = options.host
  self.port = options.port
  self.address = nil
  self.deadline = system.get_time() + (CONNECT_TIMEOUT_MS / 1000)
  self.next_attempt = system.get_time()
  self.last_error = nil
  self.state = "resolving"

  if not self.host or self.host == "" then
    self.startup_error = "tcp transport requires a host"
    self:stop()
    return
  end

  if not self.port then
    self.startup_error = "tcp transport requires a port"
    self:stop()
    return
  end

  if options.command and #options.command > 0 then
    self.proc = process.start(options.command, {
      stderr = process.REDIRECT_PIPE,
      cwd = core.root_project().path,
      env = options.env
    })
  end

  local address, errmsg = net.resolve_address(self.host)
  if not address then
    self.startup_error = errmsg or ("failed to resolve tcp host: " .. self.host)
    self.state = "failed"
    self:stop()
    return
  end
  self.address = address
end

function TcpTransport:update()
  if self.startup_ok or self.startup_error then
    return
  end

  local now = system.get_time()
  if now >= self.deadline then
    self.startup_error = self.last_error or string.format(
      "timed out connecting to tcp server %s:%d",
      self.host,
      self.port
    )
    self.state = "failed"
    self:stop()
    return
  end

  if self.proc and not self.proc:running() then
    local stderr = get_process_stderr(self.proc)
    self.startup_error = join_error(
      "tcp lsp helper process exited before accepting connections",
      stderr ~= "" and stderr or nil,
      self.last_error
    )
    self.state = "failed"
    self:stop()
    return
  end

  if self.state == "resolving" and self.address then
    local status, errmsg = self.address:wait_until_resolved(0)
    if status == "success" then
      self.state = "connecting"
    elseif status == "failure" then
      self.startup_error = errmsg or ("failed to resolve tcp host: " .. self.host)
      self.state = "failed"
      self:stop()
      return
    else
      return
    end
  end

  if self.state ~= "connecting" then
    return
  end

  if self.socket then
    local status, errmsg = self.socket:wait_until_connected(0)
    if status == "success" then
      self.startup_ok = true
      self.state = "ready"
      return
    elseif status == "failure" then
      self.last_error = errmsg or string.format(
        "failed to connect to tcp server %s:%d",
        self.host,
        self.port
      )
      self.socket:close()
      self.socket = nil
      self.next_attempt = now + CONNECT_RETRY_DELAY
    end
    return
  end

  if now < self.next_attempt or not self.address then
    return
  end

  self.socket, self.last_error = net.open_tcp(self.address, self.port)
  if not self.socket then
    self.last_error = self.last_error or string.format(
      "failed to open tcp connection to %s:%d",
      self.host,
      self.port
    )
    self.next_attempt = now + CONNECT_RETRY_DELAY
    return
  end

  local status, errmsg = self.socket:wait_until_connected(0)
  if status == "success" then
    self.startup_ok = true
    self.state = "ready"
  elseif status == "failure" then
    self.last_error = errmsg or string.format(
      "failed to connect to tcp server %s:%d",
      self.host,
      self.port
    )
    self.socket:close()
    self.socket = nil
    self.next_attempt = now + CONNECT_RETRY_DELAY
  end
end

---@return boolean
function TcpTransport:is_starting()
  self:update()
  return not self.startup_ok and not self.startup_error
end

---@param data string
---@return integer? written
---@return string? errmsg
function TcpTransport:write(data)
  self:update()
  if not self.socket then
    return nil, self.startup_error or "tcp transport is still starting"
  end

  local written, errmsg = self.socket:write(data)
  if written then
    return #data
  end
  return nil, errmsg
end

---@param amount integer
---@return string? data
---@return string? errmsg
function TcpTransport:read(amount)
  self:update()
  if not self.socket then
    return nil, self.startup_error or "tcp transport is still starting"
  end
  return self.socket:read(amount)
end

---@param amount integer
---@return string? data
---@return string? errmsg
function TcpTransport:read_stderr(amount)
  if not self.proc then
    return ""
  end
  return self.proc:read_stderr(amount)
end

---@return boolean
function TcpTransport:is_running()
  self:update()
  local socket_running = false
  if self.socket then
    socket_running = self.socket:get_status() == "success"
  end

  if self.proc then
    return socket_running and self.proc:running()
  end

  return socket_running
end

function TcpTransport:stop()
  if self.socket then
    self.socket:close()
    self.socket = nil
  end
  if self.proc then
    self.proc:kill()
    self.proc = nil
  end
end

return TcpTransport
