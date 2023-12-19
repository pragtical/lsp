--
-- This file will define some of the LSP protocol elements as needed
-- for type hinting usage with the sumneko lua language server.
--

---@alias lsp.protocol.DocumentURI string

---@class lsp.protocol.Position
---@field line integer
---@field character integer

---@class lsp.protocol.Range
---@field start lsp.protocol.Position
---@field end lsp.protocol.Position

---@class lsp.protocol.TextEdit
---@field newText string
---@field range lsp.protocol.Range

---@class lsp.protocol.WorkspaceEdit
---@field changes table<lsp.protocol.DocumentURI,lsp.protocol.TextEdit[]>
