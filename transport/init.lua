local StdioTransport = require "plugins.lsp.transport.stdio"
local TcpTransport = require "plugins.lsp.transport.tcp"

---@alias lsp.transport.kind
---| '"stdio"'
---| '"tcp"'

---Abstract transport used by `lsp.server` to communicate with language
---servers over either stdio or tcp.
---@class lsp.transport
---Selected backend kind.
---@field public kind lsp.transport.kind
---True once the transport has completed startup and is ready to exchange LSP
---messages.
---@field public startup_ok boolean
---Set when transport startup fails permanently. Once this is non-nil the
---server should stop retrying and treat startup as failed.
---@field public startup_error string | nil
local Transport = {}

---Advance transport startup and connection state without blocking the editor.
---Implementations may use this to poll async connection progress, retry tcp
---connect attempts, or detect early helper-process exits.
function Transport:update() end

---Returns true while the transport is still trying to become ready and has not
---yet either succeeded or failed permanently.
---@return boolean
function Transport:is_starting() end

---Read up to `amount` bytes from the main LSP channel.
---Returns `nil` when the underlying channel closes or when a transport error
---occurs. For nonblocking transports, an empty string means no data is
---available yet.
---@param amount integer
---@return string? data
---@return string? errmsg
function Transport:read(amount) end

---Read up to `amount` bytes from the helper process stderr stream when one
---exists. Transports without stderr support should return an empty string.
---@param amount integer
---@return string? data
---@return string? errmsg
function Transport:read_stderr(amount) end

---Write raw bytes to the main LSP channel.
---Returns the amount of bytes written, or `nil` plus an error message on
---failure. Implementations may return partial writes.
---@param data string
---@return integer? written
---@return string? errmsg
function Transport:write(data) end

---Returns true once the transport is fully connected and able to exchange LSP
---messages.
---@return boolean
function Transport:is_running() end

---Release all owned resources for the transport.
---For stdio this kills the spawned process. For tcp this closes the socket and
---kills any owned helper process.
function Transport:stop() end

---Instantiate the configured transport implementation.
---@param options lsp.server.options
---@return lsp.transport
function Transport.new(options)
  if (options.transport or "stdio") == "tcp" then
    return TcpTransport(options)
  end
  return StdioTransport(options)
end

return Transport
