--
-- This file defines some of the LSP protocol elements as needed
-- for type hinting usage with the sumneko lua language server.
--
-- LSP Documentation:
-- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification

local protocol = {}

---@alias lsp.protocol.DocumentURI string
---@alias array table<integer,any>
---@alias object table<string,any>

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

---@class lsp.protocol.Location
---@field uri lsp.protocol.DocumentURI
---@field range lsp.protocol.Range

---@class lsp.protocol.Message
---The language server protocol always uses “2.0” as the jsonrpc version.
---@field jsonrpc string

---@class lsp.protocol.Message
---The language server protocol always uses “2.0” as the jsonrpc version.
---@field jsonrpc string

---@class lsp.protocol.RequestMessage
---@field id integer | string
---@field method string
---@field params array | object

---@class lsp.protocol.ResponseError
---@field code integer
---@field message string
---@field data? string | number | boolean | array | object | nil

---@class lsp.protocol.ResponseMessage : lsp.protocol.Message
---@field id integer | string | nil
---@field result? string | number | boolean | array | object | nil
---@field error? lsp.protocol.ResponseError

---@class lsp.protocol.NotificationMessage : lsp.protocol.Message
---@field method string
---@field params? array | object

---@enum lsp.protocol.SymbolTag
protocol.SymbolTag = {
  Deprecated = 1
}

---@enum lsp.protocol.SymbolKind
protocol.SymbolKind = {
  File = 1,
  Module = 2,
  Namespace = 3,
  Package = 4,
  Class = 5,
  Method = 6,
  Property = 7,
  Field = 8,
  Constructor = 9,
  Enum = 10,
  Interface = 11,
  Function = 12,
  Variable = 13,
  Constant = 14,
  String = 15,
  Number = 16,
  Boolean = 17,
  Array = 18,
  Object = 19,
  Key = 20,
  Null = 21,
  EnumMember = 22,
  Struct = 23,
  Event = 24,
  Operator = 25,
  TypeParameter = 26
}

---@class lsp.protocol.DocumentSymbol
---@field name string
---@field detail? string
---@field kind lsp.protocol.SymbolKind
---@field tags? lsp.protocol.SymbolTag[]
---@field deprecated? boolean
---@field range lsp.protocol.Range
---@field selectionRange lsp.protocol.Range
---@field children? lsp.protocol.DocumentSymbol[]

---@class lsp.protocol.SymbolInformation
---@field name string
---@field kind lsp.protocol.SymbolKind
---@field tags? lsp.protocol.SymbolTag[]
---@field deprecated? boolean
---@field location lsp.protocol.Location
---@field containerName? string

---LSP Docs: /#errorCodes
---@enum lsp.protocol.ErrorCodes
protocol.ErrorCodes = {
  ParseError                      = -32700,
  InvalidRequest                  = -32600,
  MethodNotFound                  = -32601,
  InvalidParams                   = -32602,
  InternalError                   = -32603,
  jsonrpcReservedErrorRangeStart  = -32099,
  serverErrorStart                = -32099,
  ServerNotInitialized            = -32002,
  UnknownErrorCode                = -32001,
  jsonrpcReservedErrorRangeEnd    = -32000,
  serverErrorEnd                  = -32000,
  lspReservedErrorRangeStart      = -32899,
  ContentModified                 = -32801,
  RequestCancelled                = -32800,
  lspReservedErrorRangeEnd        = -32800,
}

---LSP Docs: /#completionTriggerKind
---@enum lsp.protocol.CompletionTriggerKind
protocol.CompletionTriggerKind = {
  Invoked = 1,
  TriggerCharacter = 2,
  TriggerForIncompleteCompletions = 3
}

---LSP Docs: /#diagnosticSeverity
---@enum lsp.protocol.DiagnosticSeverity
protocol.DiagnosticSeverity = {
  Error = 1,
  Warning = 2,
  Information = 3,
  Hint = 4
}

---LSP Docs: /#textDocumentSyncKind
---@enum lsp.protocol.TextDocumentSyncKind
protocol.TextDocumentSyncKind = {
  None = 0,
  Full = 1,
  Incremental = 2
}

---LSP Docs: /#completionItemKind
---@enum lsp.protocol.CompletionItemKind
protocol.CompletionItemKind = {
  Text = 1,
  Method = 2,
  Function = 3,
  Constructor = 4,
  Field = 5,
  Variable = 6,
  Class = 7,
  Interface = 8,
  Module = 9,
  Property = 10,
  Unit = 11,
  Value = 12,
  Enum = 13,
  Keyword = 14,
  Snippet = 15,
  Color = 16,
  File = 17,
  Reference = 18,
  Folder = 19,
  EnumMember = 20,
  Constant = 21,
  Struct = 22,
  Event = 23,
  Operator = 24,
  TypeParameter = 25
}

---Used for easy integer to string matching
---@type table<integer,string>
---@see lsp.protocol.CompletionItemKind
protocol.CompletionItemKindString = {
  'Text', 'Method', 'Function', 'Constructor', 'Field', 'Variable', 'Class',
  'Interface', 'Module', 'Property', 'Unit', 'Value', 'Enum', 'Keyword',
  'Snippet', 'Color', 'File', 'Reference', 'Folder', 'EnumMember',
  'Constant', 'Struct', 'Event', 'Operator', 'TypeParameter'
}

---LSP Docs: /#symbolKind
---@enum lsp.protocol.SymbolKind
protocol.SymbolKind = {
  File = 1,
  Module = 2,
  Namespace = 3,
  Package = 4,
  Class = 5,
  Method = 6,
  Property = 7,
  Field = 8,
  Constructor = 9,
  Enum = 10,
  Interface = 11,
  Function = 12,
  Variable = 13,
  Constant = 14,
  String = 15,
  Number = 16,
  Boolean = 17,
  Array = 18,
  Object = 19,
  Key = 20,
  Null = 21,
  EnumMember = 22,
  Struct = 23,
  Event = 24,
  Operator = 25,
  TypeParameter = 26
}

---Used for easy integer to string matching
---@type table<integer,string>
---@see lsp.protocol.SymbolKind
protocol.SymbolKindString = {
  'File', 'Module', 'Namespace', 'Package', 'Class', 'Method', 'Property',
  'Field', 'Constructor', 'Enum', 'Interface', 'Function', 'Variable',
  'Constant', 'String', 'Number', 'Boolean', 'Array', 'Object', 'Key',
  'Null', 'EnumMember', 'Struct', 'Event', 'Operator', 'TypeParameter'
}

---LSP Docs: /#insertTextFormat
---@enum lsp.protocol.InsertTextFormat
protocol.InsertTextFormat = {
  PlainText = 1,
  Snippet = 2
}

---LSP Docs: /#messageType
---@enum lsp.protocol.MessageType
protocol.MessageType = {
	Error = 1,
	Warning = 2,
	Info = 3,
	Log = 4,
	---@since 3.18.0
	Debug = 5
}

---LSP Docs: /#positionEncodingKind
---@enum lsp.protocol.PositionEncodingKind
protocol.PositionEncodingKind = {
  UTF8  = 'utf-8',
  UTF16 = 'utf-16',
  UTF32 = 'utf-32'
}


return protocol
