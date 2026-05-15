local core = require "core"
local Object = require "core.object"

---@class lsp.transport.stdio : lsp.transport, core.object
---@field public kind '"stdio"'
---@field public proc process | nil
---@field public startup_ok boolean
---@field public startup_error string | nil
---@field super core.object
local StdioTransport = Object:extend()

---@param options lsp.server.options
function StdioTransport:new(options)
  self.kind = "stdio"
  self.proc = nil
  self.startup_ok = false
  self.startup_error = nil

  if not options.command or #options.command == 0 then
    self.startup_error = "stdio transport requires a command"
    return
  end

  self.proc = process.start(options.command, {
    stderr = process.REDIRECT_PIPE,
    -- needed on some not fully implemented lsp servers like psalm
    cwd = core.root_project().path,
    env = options.env
  })

  if not self.proc then
    self.startup_error = "failed to start stdio transport process"
    return
  end

  self.startup_ok = true
end

function StdioTransport:update()
end

---@return boolean
function StdioTransport:is_starting()
  return false
end

---@param data string
---@return integer? written
---@return string? errmsg
function StdioTransport:write(data)
  if not self.proc then
    return nil, "stdio transport is not running"
  end
  return self.proc:write(data)
end

---@param amount integer
---@return string? data
---@return string? errmsg
function StdioTransport:read(amount)
  if not self.proc then
    return nil, "stdio transport is not running"
  end
  return self.proc:read_stdout(amount)
end

---@param amount integer
---@return string? data
---@return string? errmsg
function StdioTransport:read_stderr(amount)
  if not self.proc then
    return nil, "stdio transport is not running"
  end
  return self.proc:read_stderr(amount)
end

---@return boolean
function StdioTransport:is_running()
  return self.proc and self.proc:running() or false
end

function StdioTransport:stop()
  if self.proc then
    self.proc:kill()
  end
end

return StdioTransport
