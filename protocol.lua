--
-- This file defines some of the LSP protocol elements as needed
-- for type hinting usage with the sumneko lua language server.
--
-- LSP Documentation:
-- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification

local protocol = {}

---Generic array type for lsp.
---@alias array table<integer,any>

---Generic object type for lsp.
---@alias object table<string,any>

---Defines an unsigned integer number in the range of 0 to 2^31 - 1.
---@alias uinteger integer

---Defines a decimal number. Since decimal numbers are very
---rare in the language server specification we denote the
---exact range with every decimal using the mathematics
---interval notation (e.g. [0, 1] denotes all decimals d with
---0 <= d <= 1.
---@alias decimal integer

---URI’s are transferred as strings. The URI’s format is defined in https://tools.ietf.org/html/rfc3986
---@alias lsp.protocol.DocumentURI string

---URI's are transferred as strings. DocumentUri is an alias kept by the
---upstream specification for generated protocol definitions.
---@alias lsp.protocol.DocumentUri lsp.protocol.DocumentURI

---LSP object definition.
---
---since 3.17.0
---@alias lsp.protocol.LSPObject table<string,lsp.protocol.LSPAny>

---LSP arrays.
---
---since 3.17.0
---@alias lsp.protocol.LSPArray lsp.protocol.LSPAny[]

---The LSP any type
---
---since 3.17.0
---@alias lsp.protocol.LSPAny lsp.protocol.LSPObject | lsp.protocol.LSPArray | string | integer | uinteger | decimal | boolean | nil

---An identifier referring to a change annotation managed by a workspace edit.
---
---since 3.16.0.
---@alias lsp.protocol.ChangeAnnotationIdentifier string


---Position in a text document expressed as zero-based line and zero-based
---character offset. A position is between two characters like an ‘insert’
---cursor in an editor. Special values like for example -1 to denote the end
---of a line are not supported.
---@class lsp.protocol.Position
---Line position in a document (zero-based).
---@field line integer
---Character offset on a line in a document (zero-based). The meaning of this
---offset is determined by the negotiated `PositionEncodingKind`.
---
---If the character value is greater than the line length it defaults back
---to the line length.
---@field character integer


---A range in a text document expressed as (zero-based) start and end
---positions. A range is comparable to a selection in an editor. Therefore,
---the end position is exclusive. If you want to specify a range that contains
---a line including the line ending character(s) then use an end position
---denoting the start of the next line. For example:
---@class lsp.protocol.Range
---The range's start position.
---@field start lsp.protocol.Position
---The range's end position.
---@field end lsp.protocol.Position


---A textual edit applicable to a text document.
---@class lsp.protocol.TextEdit
---The range of the text document to be manipulated. To insert
---text into a document create a range where start === end.
---@field newText string
---The string to be inserted. For delete operations use an
---empty string.
---@field range lsp.protocol.Range

---@class lsp.protocol.AnnotatedTextEdit : lsp.protocol.TextEdit
---The actual annotation identifier.
---@field annotationId lsp.protocol.ChangeAnnotationIdentifier


---A special text edit to provide an insert and a replace operation.
---since 3.16.0
---@class lsp.protocol.InsertReplaceEdit
---The string to be inserted.
---@field newText string
---The range if the insert is requested
---@field insert lsp.protocol.Range
---The range if the replace is requested.
---@field replace lsp.protocol.Range


---Text documents are identified using a URI. On the protocol level, URIs are
---passed as strings. The corresponding JSON structure looks like this:
---@class lsp.protocol.TextDocumentIdentifier
---The text document's URI.
---@field uri lsp.protocol.DocumentURI


---An identifier which optionally denotes a specific version of a text
---document. This information usually flows from the server to the client.
---@class lsp.protocol.OptionalVersionedTextDocumentIdentifier : lsp.protocol.TextDocumentIdentifier
---The version number of this document. If an optional versioned text document
---identifier is sent from the server to the client and the file is not
---open in the editor (the server has not received an open notification
---before) the server can send `null` to indicate that the version is
---known and the content on disk is the master (as specified with document
---content ownership).
---
---The version number of a document will increase after each change,
---including undo/redo. The number doesn't need to be consecutive.
---@field version? integer


---New in version 3.16: support for AnnotatedTextEdit. The support is guarded
---by the client capability workspace.workspaceEdit.changeAnnotationSupport.
---If a client doesn’t signal the capability, servers shouldn’t send
---AnnotatedTextEdit literals back to the client.
---
---Describes textual changes on a single text document. The text document is
---referred to as a OptionalVersionedTextDocumentIdentifier to allow clients
---to check the text document version before an edit is applied. A
---TextDocumentEdit describes all changes on a version Si and after they are
---applied move the document to version Si+1. So the creator of a
---TextDocumentEdit doesn’t need to sort the array of edits or do any kind of
---ordering. However the edits must be non overlapping.
---@class lsp.protocol.TextDocumentEdit
---The text document to change.
---@field textDocument lsp.protocol.OptionalVersionedTextDocumentIdentifier
---The edits to be applied.
---
---since 3.16.0 - support for AnnotatedTextEdit. This is guarded by the
---client capability `workspace.workspaceEdit.changeAnnotationSupport`
---@field edits lsp.protocol.TextEdit[] | lsp.protocol.AnnotatedTextEdit[]


---Options to create a file.
---@class lsp.protocol.CreateFileOptions
---Overwrite existing file. Overwrite wins over `ignoreIfExists`
---@field overwrite? boolean
---Ignore if exists.
---@field ignoreIfExists? boolean


---Create file operation
---@class lsp.protocol.CreateFile
---A create
---@field kind 'create'
---The resource to create.
---@field uri lsp.protocol.DocumentURI
---Additional options
---@field options? lsp.protocol.CreateFileOptions
---An optional annotation identifier describing the operation.
---
---since 3.16.0
---@field annotationId? lsp.protocol.ChangeAnnotationIdentifier


---Rename file options
---@class lsp.protocol.RenameFileOptions
---Overwrite target if existing. Overwrite wins over `ignoreIfExists`
---@field overwrite? boolean
---Ignores if target exists.
---@field ignoreIfExists? boolean


---Rename file operation
---@class lsp.protocol.RenameFile
---A rename
---@field kind 'rename'
---The old (existing) location.
---@field oldUri lsp.protocol.DocumentURI
---The new location.
---@field newUri lsp.protocol.DocumentURI
---Rename options.
---@field options? lsp.protocol.RenameFileOptions
---An optional annotation identifier describing the operation.
---
---since 3.16.0
---@field annotationId? lsp.protocol.ChangeAnnotationIdentifier


---Delete file options
---@class lsp.protocol.DeleteFileOptions
---Delete the content recursively if a folder is denoted.
---@field recursive? boolean
---Ignore the operation if the file doesn't exist.
---@field ignoreIfNotExists? boolean


---Delete file operation
---@class lsp.protocol.DeleteFile
---A delete
---@field kind 'delete'
---The file to delete.
---@field uri lsp.protocol.DocumentURI
---Delete options
---@field options? lsp.protocol.DeleteFileOptions
---An optional annotation identifier describing the operation.
---
---since 3.16.0
---@field annotationId? lsp.protocol.ChangeAnnotationIdentifier


---Additional information that describes document changes.
---
---since 3.16.0
---@class lsp.protocol.ChangeAnnotation
---A human-readable string describing the actual change. The string
---is rendered prominent in the user interface.
---@field label string
---A flag which indicates that user confirmation is needed
---before applying the change.
---@field needsConfirmation? boolean
---A human-readable string which is rendered less prominent in
---the user interface.
---@field description? string


---Alias for the WorkspaceEdit documentChanges field type.
---@alias lsp.protocol.WorkspaceEditDocumentChange lsp.protocol.TextDocumentEdit | lsp.protocol.CreateFile | lsp.protocol.RenameFile | lsp.protocol.DeleteFile

---A workspace edit represents changes to many resources managed in the
---workspace. The edit should either provide changes or documentChanges. If the
---client can handle versioned document edits and if documentChanges are
---present, the latter are preferred over changes.
---
---Since version 3.13.0 a workspace edit can contain resource operations
---(create, delete or rename files and folders) as well. If resource operations
---are present clients need to execute the operations in the order in which
---they are provided. So a workspace edit for example can consist of the
---following two changes: (1) create file a.txt and (2) a text document edit
---which insert text into file a.txt. An invalid sequence (e.g. (1) delete
---file a.txt and (2) insert text into file a.txt) will cause failure of the
---operation. How the client recovers from the failure is described by the
---client capability: workspace.workspaceEdit.failureHandling
---@class lsp.protocol.WorkspaceEdit
---Holds changes to existing resources.
---@field changes? table<lsp.protocol.DocumentURI,lsp.protocol.TextEdit[]>
---Depending on the client capability
---`workspace.workspaceEdit.resourceOperations` document changes are either
---an array of `TextDocumentEdit`s to express changes to n different text
---documents where each text document edit addresses a specific version of
---a text document. Or it can contain above `TextDocumentEdit`s mixed with
---create, rename and delete file / folder operations.
---
---Whether a client supports versioned document edits is expressed via
---`workspace.workspaceEdit.documentChanges` client capability.
---
---If a client neither supports `documentChanges` nor
---`workspace.workspaceEdit.resourceOperations` then only plain `TextEdit`s
---using the `changes` property are supported.
---
---@field documentChanges? lsp.protocol.TextDocumentEdit[] | lsp.protocol.WorkspaceEditDocumentChange[]
---A map of change annotations that can be referenced in
---`AnnotatedTextEdit`s or create, rename and delete file / folder
---operations.
---
---Whether clients honor this property depends on the client capability
---`workspace.changeAnnotationSupport`.
---
---since 3.16.0
---@field changeAnnotations? table<string,lsp.protocol.ChangeAnnotation>


---Represents a location inside a resource, such as a line inside a text file.
---@class lsp.protocol.Location
---@field uri lsp.protocol.DocumentURI
---@field range lsp.protocol.Range


---Represents the connection of two locations. Provides additional metadata
---over normal locations, including origin and target selection ranges.
---@class lsp.protocol.LocationLink
---@field originSelectionRange? lsp.protocol.Range
---@field targetUri lsp.protocol.DocumentURI
---@field targetRange lsp.protocol.Range
---@field targetSelectionRange lsp.protocol.Range


---An item to transfer a text document from the client to the server.
---@class lsp.protocol.TextDocumentItem
---@field uri lsp.protocol.DocumentURI
---@field languageId string
---@field version integer
---@field text string


---An identifier to denote a specific version of a text document.
---@class lsp.protocol.VersionedTextDocumentIdentifier : lsp.protocol.TextDocumentIdentifier
---@field version integer


---A parameter literal used in requests to pass a text document and a position
---inside that document.
---@class lsp.protocol.TextDocumentPositionParams
---@field textDocument lsp.protocol.TextDocumentIdentifier
---@field position lsp.protocol.Position


---A document filter describes a top level text document or notebook cell
---document by language, scheme, or glob pattern.
---@class lsp.protocol.DocumentFilter
---@field language? string
---@field scheme? string
---@field pattern? string


---A document selector is the combination of one or more document filters.
---@alias lsp.protocol.DocumentSelector lsp.protocol.DocumentFilter[]


---Text document save options.
---@class lsp.protocol.SaveOptions
---The client is supposed to include the content on save.
---@field includeText? boolean


---Defines how text documents are synced.
---@class lsp.protocol.TextDocumentSyncOptions
---@field openClose? boolean
---@field change? lsp.protocol.TextDocumentSyncKind
---@field willSave? boolean
---@field willSaveWaitUntil? boolean
---@field save? boolean | lsp.protocol.SaveOptions


---A general message as defined by JSON-RPC. The language server protocol
---always uses “2.0” as the jsonrpc version.
---@class lsp.protocol.Message
---The language server protocol always uses “2.0” as the jsonrpc version.
---@field jsonrpc string


---A request message to describe a request between the client and the server.
---Every processed request must send a response back to the sender of the request.
---@class lsp.protocol.RequestMessage
---The request id.
---@field id integer | string
---The method to be invoked.
---@field method string
---The method's params.
---@field params array | object


---@class lsp.protocol.ResponseError
---A number indicating the error type that occurred.
---@field code integer
---A string providing a short description of the error.
---@field message string
---A primitive or structured value that contains additional
---information about the error. Can be omitted.
---@field data? string | number | boolean | array | object | nil


---A Response Message sent as a result of a request. If a request doesn’t
---provide a result value the receiver of a request still needs to return a
---response message to conform to the JSON-RPC specification. The result
---property of the ResponseMessage should be set to null in this case to signal
---a successful request.
---@class lsp.protocol.ResponseMessage : lsp.protocol.Message
---The request id.
---@field id integer | string | nil
---The result of a request. This member is REQUIRED on success.
---This member MUST NOT exist if there was an error invoking the method.
---@field result? string | number | boolean | array | object
---The error object in case a request fails.
---@field error? lsp.protocol.ResponseError


---A notification message. A processed notification message must not send a
---response back. They work like events.
---@class lsp.protocol.NotificationMessage : lsp.protocol.Message
---The method to be invoked.
---@field method string
---The notification's params.
---@field params? array | object


---Symbol tags are extra annotations that tweak the rendering of a symbol.
---
---since 3.16
---@enum lsp.protocol.SymbolTag
protocol.SymbolTag = {
  ---Render a symbol as obsolete, usually using a strike-out.
  Deprecated = 1
}


---A symbol kind.
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


---Represents programming constructs like variables, classes, interfaces etc.
---that appear in a document. Document symbols can be hierarchical and they
---have two ranges: one that encloses its definition and one that points to its
---most interesting range, e.g. the range of an identifier.
---@class lsp.protocol.DocumentSymbol
---The name of this symbol. Will be displayed in the user interface and
---therefore must not be an empty string or a string only consisting of
---white spaces.
---@field name string
---More detail for this symbol, e.g the signature of a function.
---@field detail? string
---The kind of this symbol.
---@field kind lsp.protocol.SymbolKind
---Tags for this document symbol.
---
---since 3.16.0
---@field tags? lsp.protocol.SymbolTag[]
---Indicates if this symbol is deprecated.
---
---deprecated Use tags instead
---@field deprecated? boolean
---The range enclosing this symbol not including leading/trailing whitespace
---but everything else like comments. This information is typically used to
---determine if the clients cursor is inside the symbol to reveal in the
---symbol in the UI.
---@field range lsp.protocol.Range
---The range that should be selected and revealed when this symbol is being
---picked, e.g. the name of a function. Must be contained by the `range`.
---@field selectionRange lsp.protocol.Range
---Children of this symbol, e.g. properties of a class.
---@field children? lsp.protocol.DocumentSymbol[]


---Represents information about programming constructs like variables, classes,
---interfaces etc.
---
---deprecated use DocumentSymbol or WorkspaceSymbol instead.
---@class lsp.protocol.SymbolInformation
---The name of this symbol.
---@field name string
---The kind of this symbol.
---@field kind lsp.protocol.SymbolKind
---Tags for this symbol.
---
---since 3.16.0
---@field tags? lsp.protocol.SymbolTag[]
---Indicates if this symbol is deprecated.
---
---deprecated Use tags instead
---@field deprecated? boolean
---The location of this symbol. The location's range is used by a tool
---to reveal the location in the editor. If the symbol is selected in the
---tool the range's start information is used to position the cursor. So
---the range usually spans more then the actual symbol's name and does
---normally include things like visibility modifiers.
---
---The range doesn't have to denote a node range in the sense of an abstract
---syntax tree. It can therefore not be used to re-construct a hierarchy of
---the symbols.
---@field location lsp.protocol.Location
---The name of the symbol containing this symbol. This information is for
---user interface purposes (e.g. to render a qualifier in the user interface
---if necessary). It can't be used to re-infer a hierarchy for the document
---symbols.
---@field containerName? string


---List of codes returned on response error messages.
---@enum lsp.protocol.ErrorCodes
protocol.ErrorCodes = {
  ParseError                      = -32700,
  InvalidRequest                  = -32600,
  MethodNotFound                  = -32601,
  InvalidParams                   = -32602,
  InternalError                   = -32603,
	---This is the start range of JSON-RPC reserved error codes.
	---It doesn't denote a real error code. No LSP error codes should
	---be defined between the start and end range. For backwards
	---compatibility the `ServerNotInitialized` and the `UnknownErrorCode`
	---are left in the range.
	---
	---since 3.16.0
  jsonrpcReservedErrorRangeStart  = -32099,
  ---deprecated use jsonrpcReservedErrorRangeStart
  serverErrorStart                = -32099,
  ---Error code indicating that a server received a notification or
	---request before the server has received the `initialize` request.
  ServerNotInitialized            = -32002,
  UnknownErrorCode                = -32001,
  ---This is the end range of JSON-RPC reserved error codes.
	---It doesn't denote a real error code.
	---
	---since 3.16.0
  jsonrpcReservedErrorRangeEnd    = -32000,
  ---deprecated use jsonrpcReservedErrorRangeEnd
  serverErrorEnd                  = -32000,
  ---This is the start range of LSP reserved error codes.
	---It doesn't denote a real error code.
	---
	---since 3.16.0
  lspReservedErrorRangeStart      = -32899,
  ---A request failed but it was syntactically correct, e.g the
	---method name was known and the parameters were valid. The error
	---message should contain human readable information about why
	---the request failed.
  ---
	---since 3.17.0
  RequestFailed                   = -32803,
  ---The server cancelled the request. This error code should
	---only be used for requests that explicitly support being
	---server cancellable.
	---
	---since 3.17.0
  ServerCancelled                 = -32802,
  ---The server detected that the content of a document got
	---modified outside normal conditions. A server should
	---NOT send this error code if it detects a content change
	---in it unprocessed messages. The result even computed
	---on an older state might still be useful for the client.
	---
	---If a client decides that a result is not of any use anymore
	---the client should cancel the request.
  ContentModified                 = -32801,
  ---The client has canceled a request and a server as detected
	---the cancel.
  RequestCancelled                = -32800,
  ---This is the end range of LSP reserved error codes.
	---It doesn't denote a real error code.
	---
	---since 3.16.0
  lspReservedErrorRangeEnd        = -32800,
}


---How a completion was triggered
---@enum lsp.protocol.CompletionTriggerKind
protocol.CompletionTriggerKind = {
  ---Completion was triggered by typing an identifier (24x7 code
	---complete), manual invocation (e.g Ctrl+Space) or via API.
  Invoked = 1,
  ---Completion was triggered by a trigger character specified by
	--the `triggerCharacters` properties of the
	---`CompletionRegistrationOptions`.
  TriggerCharacter = 2,
  ---Completion was re-triggered as the current completion list is incomplete.
  TriggerForIncompleteCompletions = 3
}


---The protocol currently supports the following diagnostic severities and tags:
---@enum lsp.protocol.DiagnosticSeverity
protocol.DiagnosticSeverity = {
  ---Reports an error.
  Error = 1,
  ---Reports a warning.
  Warning = 2,
  ---Reports an information.
  Information = 3,
  ---Reports a hint.
  Hint = 4
}


---Defines how the host (editor) should sync document changes to the language
---server.
---@enum lsp.protocol.TextDocumentSyncKind
protocol.TextDocumentSyncKind = {
  ---Documents should not be synced at all.
  None = 0,
  ---Documents are synced by always sending the full content
	---of the document.
  Full = 1,
  ---Documents are synced by sending the full content on open.
	---After that only incremental updates to the document are
	---sent.
  Incremental = 2
}


---The kind of a completion entry.
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


---A symbol kind.
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


---Defines whether the insert text in a completion item should be interpreted as
---plain text or a snippet.
---@enum lsp.protocol.InsertTextFormat
protocol.InsertTextFormat = {
  ---The primary text to be inserted is treated as a plain string.
  PlainText = 1,
  ---The primary text to be inserted is treated as a snippet.
	---
	---A snippet can define tab stops and placeholders with `$1`, `$2`
	---and `${3:foo}`. `$0` defines the final tab stop, it defaults to
	---the end of the snippet. Placeholders with equal identifiers are linked,
	---that is typing in one will update others too.
  Snippet = 2
}


---How whitespace and indentation is handled during completion
---item insertion.
---
---since 3.16.0
---@enum lsp.protocol.InsertTextMode
protocol.InsertTextMode = {
  ---The insertion or replace strings is taken as it is. If the
  ---value is multi line the lines below the cursor will be
  ---inserted using the indentation defined in the string value.
  ---The client will not apply any kind of adjustments to the
  ---string.
	asIs = 1,
	---The editor adjusts leading whitespace of new lines so that
	---they match the indentation up to the cursor of the line for
	---which the item is accepted.
	---
	---Consider a line like this: <2tabs><cursor><3tabs>foo. Accepting a
	---multi line completion item is indented using 2 tabs and all
	---following lines inserted will be indented using 2 tabs as well.
	adjustIndentation = 2
}


---A message type.
---@enum lsp.protocol.MessageType
protocol.MessageType = {
  ---An error message.
	Error = 1,
	---A warning message.
	Warning = 2,
	---An information message.
	Info = 3,
	---A log message.
	Log = 4,
	---A debug message.
	---
	---since 3.18.0
	Debug = 5
}


---A set of predefined position encoding kinds.
---
---since 3.17.0
---@enum lsp.protocol.PositionEncodingKind
protocol.PositionEncodingKind = {
  ---Character offsets count UTF-8 code units (e.g bytes).
  UTF8  = 'utf-8',
  ---Character offsets count UTF-16 code units.
	---
	---This is the default and must always be supported
	---by servers
  UTF16 = 'utf-16',
  ---Character offsets count UTF-32 code units.
	---
	---Implementation note: these are the same as Unicode code points,
	---so this `PositionEncodingKind` may also be used for an
	---encoding-agnostic representation of character offsets.
  UTF32 = 'utf-32'
}


---Describes the content type that a client supports in various
---result literals like `Hover`, `ParameterInfo` or `CompletionItem`.
---
---Please note that `MarkupKinds` must not start with a `$`. This kinds
---are reserved for internal usage.
---@enum lsp.protocol.MarkupKind
protocol.MarkupKind = {
  ---Plain text is supported as a content format
  PlainText = 'plaintext',
  ---Markdown is supported as a content format
  Markdown = 'markdown'
}


---A `MarkupContent` literal represents a string value which content is
---interpreted base on its kind flag. Currently the protocol supports
---`plaintext` and `markdown` as markup kinds.
---
---If the kind is `markdown` then the value can contain fenced code blocks like
---in GitHub issues.
---
---Here is an example how such a string can be constructed using
---JavaScript / TypeScript:
---```typescript
---let markdown: MarkdownContent = {
---	kind: MarkupKind.Markdown,
---	value: [
---		'# Header',
---		'Some text',
---		'```typescript',
---		'someCode();',
---		'```'
---	].join('\n')
---};
---```
---
---*Please Note* that clients might sanitize the return markdown. A client could
---decide to remove HTML from the markdown to avoid script execution.
---@class lsp.protocol.MarkupContent
---The type of the Markup
---@field kind lsp.protocol.MarkupKind
---The content itself
---@field value string


---A set of predefined code action kinds.
---@enum lsp.protocol.CodeActionKind
protocol.CodeActionKind = {
  ---Empty kind.
  Empty = '',
  ---Base kind for quickfix actions: 'quickfix'.
  QuickFix = 'quickfix',
  ---Base kind for refactoring actions: 'refactor'.
  Refactor = 'refactor',
  ---Base kind for refactoring extraction actions: 'refactor.extract'.
  ---
  ---Example extract actions:
  ---
  --- Extract method
  --- Extract function
  --- Extract variable
  --- Extract interface from class
  --- ...
  RefactorExtract = 'refactor.extract',
  ---Base kind for refactoring inline actions: 'refactor.inline'.
  ---
  ---Example inline actions:
  ---
  --- Inline function
  --- Inline variable
  --- Inline constant
  --- ...
  RefactorInline = 'refactor.inline',
  ---Base kind for refactoring rewrite actions: 'refactor.rewrite'.
  ---
  ---Example rewrite actions:
  ---
  --- Convert JavaScript function to class
  --- Add or remove parameter
  --- Encapsulate field
  --- Make method static
  --- Move method to base class
  --- ...
  RefactorRewrite = 'refactor.rewrite',
  ---Base kind for source actions: `source`.
  ---
  ---Source code actions apply to the entire file.
  Source = 'source',
  ---Base kind for an organize imports source action:
  ---`source.organizeImports`.
  SourceOrganizeImports = 'source.organizeImports',
  ---Base kind for a 'fix all' source action: `source.fixAll`.
  ---
  ---'Fix all' actions automatically fix errors that have a clear fix that
  ---do not require user input. They should not suppress errors or perform
  ---unsafe fixes such as generating new types or classes.
  ---
  ---since 3.17.0
  SourceFixAll = 'source.fixAll'
}


---@enum lsp.protocol.PrepareSupportDefaultBehavior
protocol.PrepareSupportDefaultBehavior = {
  ---The client's default behavior is to select the identifier
  ---according to the language's syntax rule.
  Identifier = 1
}


---The diagnostic tags.
---
---since 3.15.0
---@enum lsp.protocol.DiagnosticTag
protocol.DiagnosticTag = {
  --- Unused or unnecessary code.
  ---
  --- Clients are allowed to render diagnostics with this tag faded out
  --- instead of having an error squiggle.
  Unnecessary = 1,
  --- Deprecated or obsolete code.
  ---
  --- Clients are allowed to rendered diagnostics with this tag strike through.
  Deprecated = 2
}


---A set of predefined range kinds.
---@enum lsp.protocol.FoldingRangeKind
protocol.FoldingRangeKind = {
  ---Folding range for a comment
  Comment = 'comment',
  ---Folding range for imports or includes
  Imports = 'imports',
  ---Folding range for a region (e.g. `#region`)
  Region = 'region'
}


---The protocol defines an additional token format capability to allow future
---extensions of the format. The only format that is currently specified is
---relative expressing that the tokens are described using relative positions.
---@enum lsp.protocol.TokenFormat
protocol.TokenFormat = {
	Relative = 'relative'
}


---A document highlight kind.
---@enum lsp.protocol.DocumentHighlightKind
protocol.DocumentHighlightKind = {
	Text = 1,
	Read = 2,
	Write = 3
}


---A code action trigger kind.
---@enum lsp.protocol.CodeActionTriggerKind
protocol.CodeActionTriggerKind = {
	Invoked = 1,
	Automatic = 2
}


---Moniker uniqueness level.
---@enum lsp.protocol.UniquenessLevel
protocol.UniquenessLevel = {
	document = 'document',
	project = 'project',
	group = 'group',
	scheme = 'scheme',
	global = 'global'
}


---Moniker kind.
---@enum lsp.protocol.MonikerKind
protocol.MonikerKind = {
	Import = 'import',
	Export = 'export',
	Local = 'local'
}


---Inlay hint kind.
---
---since 3.17.0
---@enum lsp.protocol.InlayHintKind
protocol.InlayHintKind = {
	Type = 1,
	Parameter = 2
}


---The document diagnostic report kind.
---
---since 3.17.0
---@enum lsp.protocol.DocumentDiagnosticReportKind
protocol.DocumentDiagnosticReportKind = {
	Full = 'full',
	Unchanged = 'unchanged'
}


---Completion item tags are extra annotations that tweak the rendering of a
---completion item.
---
---since 3.15.0
---@enum lsp.protocol.CompletionItemTag
protocol.CompletionItemTag = {
  ---Render a completion as obsolete, usually using a strike-out.
	Deprecated = 1
}


---Represents a reference to a command. Provides a title which will be used
---to represent a command in the UI. Commands are identified by a string
---identifier. The recommended way to handle commands is to implement their
---execution on the server side if the client and server provides the
---corresponding capabilities. Alternatively the tool extension code could
---handle the command. The protocol currently doesn’t specify a set of
---well-known commands.
---@class lsp.protocol.Command
---Title of the command, like `save`.
---@field title string
---The identifier of the actual command handler.
---@field command string
---Arguments that the command handler should be
---invoked with.
---@field arguments? lsp.protocol.LSPAny[]


---Additional details for a completion item label.
---
---since 3.17.0
---@class lsp.protocol.CompletionItemLabelDetails
---An optional string which is rendered less prominently directly after
---{@link CompletionItem.label label}, without any spacing. Should be
---used for function signatures or type annotations.
---@field detail? string
---An optional string which is rendered less prominently after
---{@link CompletionItemLabelDetails.detail}. Should be used for fully qualified
---names or file path.
---@field description? string


---A completion item.
---@class lsp.protocol.CompletionItem
---The label of this completion item.
---
---The label property is also by default the text that
---is inserted when selecting this completion.
---
---If label details are provided the label itself should
---be an unqualified name of the completion item.
---@field label string
---since 3.17.0
---@field labelDetails? lsp.protocol.CompletionItemLabelDetails
---@field kind? lsp.protocol.CompletionItemKind
---@field tags? lsp.protocol.CompletionItemTag[]
---A human-readable string with additional information
---about this item, like type or symbol information.
---@field detail? string
---A human-readable string that represents a doc-comment.
---@field documentation? string | lsp.protocol.MarkupContent
---Indicates if this item is deprecated.
---
---deprecated Use `tags` instead if supported.
---@field deprecated? boolean
---Select this item when showing.
---
---*Note* that only one completion item can be selected and that the
---tool / client decides which item that is. The rule is that the *first*
---item of those that match best is selected.
---@field preselect? boolean
---A string that should be used when comparing this item
---with other items. When omitted the label is used
---as the sort text for this item.
---@field sortText? string
---A string that should be used when filtering a set of
---completion items. When omitted the label is used as the
---filter text for this item.
---@field filterText? string
---A string that should be inserted into a document when selecting
---this completion. When omitted the label is used as the insert text
---for this item.
---
---The `insertText` is subject to interpretation by the client side.
---Some tools might not take the string literally. For example
---VS Code when code complete is requested in this example
---`con<cursor position>` and a completion item with an `insertText` of
---`console` is provided it will only insert `sole`. Therefore it is
---recommended to use `textEdit` instead since it avoids additional client
---side interpretation.
---@field insertText? string
---The format of the insert text. The format applies to both the
---`insertText` property and the `newText` property of a provided
---`textEdit`. If omitted defaults to `InsertTextFormat.PlainText`.
---
---Please note that the insertTextFormat doesn't apply to
---`additionalTextEdits`.
---@field insertTextFormat? lsp.protocol.InsertTextFormat
---How whitespace and indentation is handled during completion
---item insertion. If not provided the client's default value depends on
---the `textDocument.completion.insertTextMode` client capability.
---
---since 3.16.0
---since 3.17.0 - support for `textDocument.completion.insertTextMode`
---@field insertTextMode? lsp.protocol.InsertTextMode
---An edit which is applied to a document when selecting this completion.
---When an edit is provided the value of `insertText` is ignored.
---
---*Note:* The range of the edit must be a single line range and it must
---contain the position at which completion has been requested.
---
---Most editors support two different operations when accepting a completion
---item. One is to insert a completion text and the other is to replace an
---existing text with a completion text. Since this can usually not be
---predetermined by a server it can report both ranges. Clients need to
---signal support for `InsertReplaceEdit`s via the
---`textDocument.completion.completionItem.insertReplaceSupport` client
---capability property.
---
---*Note 1:* The text edit's range as well as both ranges from an insert
---replace edit must be a [single line] and they must contain the position
---at which completion has been requested.
---*Note 2:* If an `InsertReplaceEdit` is returned the edit's insert range
---must be a prefix of the edit's replace range, that means it must be
---contained and starting at the same position.
---
---since 3.16.0 additional type `InsertReplaceEdit`
---@field textEdit? lsp.protocol.TextEdit | lsp.protocol.InsertReplaceEdit
---The edit text used if the completion item is part of a CompletionList and
---CompletionList defines an item default for the text edit range.
---
---Clients will only honor this property if they opt into completion list
---item defaults using the capability `completionList.itemDefaults`.
---
---If not provided and a list's default range is provided the label
---property is used as a text.
---
---since 3.17.0
---@field textEditText? string
---An optional array of additional text edits that are applied when
---selecting this completion. Edits must not overlap (including the same
---insert position) with the main edit nor with themselves.
---
---Additional text edits should be used to change text unrelated to the
---current cursor position (for example adding an import statement at the
---top of the file if the completion item will insert an unqualified type).
---@field additionalTextEdits? lsp.protocol.TextEdit[]
---An optional set of characters that when pressed while this completion is
---active will accept it first and then type that character. *Note* that all
---commit characters should have `length=1` and that superfluous characters
---will be ignored.
---@field commitCharacters? string[]
---An optional command that is executed *after* inserting this completion.
---*Note* that additional modifications to the current document should be
---described with the additionalTextEdits-property.
---@field command? lsp.protocol.Command
---A data entry field that is preserved on a completion item between
---a completion and a completion resolve request.
---@field data? lsp.protocol.LSPAny


---A completion list can be used when a completion request returns many items.
---@class lsp.protocol.CompletionList
---@field isIncomplete boolean
---@field itemDefaults? lsp.protocol.CompletionListItemDefaults
---@field items lsp.protocol.CompletionItem[]


---Completion list defaults applied to every contained completion item.
---
---since 3.17.0
---@class lsp.protocol.CompletionListItemDefaults
---@field commitCharacters? string[]
---@field editRange? lsp.protocol.Range | lsp.protocol.CompletionItemDefaultsEditRange
---@field insertTextFormat? lsp.protocol.InsertTextFormat
---@field insertTextMode? lsp.protocol.InsertTextMode
---@field data? lsp.protocol.LSPAny


---Default insert and replace ranges for a completion list.
---
---since 3.17.0
---@class lsp.protocol.CompletionItemDefaultsEditRange
---@field insert lsp.protocol.Range
---@field replace lsp.protocol.Range


---Completion request context.
---@class lsp.protocol.CompletionContext
---@field triggerKind lsp.protocol.CompletionTriggerKind
---@field triggerCharacter? string


---Completion request parameters.
---@class lsp.protocol.CompletionParams : lsp.protocol.TextDocumentPositionParams
---@field context? lsp.protocol.CompletionContext


---A marked string can be plain text or a language tagged code block.
---@alias lsp.protocol.MarkedString string | { language: string, value: string }


---The hover result contents.
---@alias lsp.protocol.HoverContents lsp.protocol.MarkupContent | lsp.protocol.MarkedString | lsp.protocol.MarkedString[]


---The result of a hover request.
---@class lsp.protocol.Hover
---@field contents lsp.protocol.HoverContents
---@field range? lsp.protocol.Range


---Represents a parameter of a callable signature.
---@class lsp.protocol.ParameterInformation
---@field label string | integer[]
---@field documentation? string | lsp.protocol.MarkupContent


---Represents the signature of a callable.
---@class lsp.protocol.SignatureInformation
---@field label string
---@field documentation? string | lsp.protocol.MarkupContent
---@field parameters? lsp.protocol.ParameterInformation[]
---@field activeParameter? uinteger


---Signature help represents one or more signatures.
---@class lsp.protocol.SignatureHelp
---@field signatures lsp.protocol.SignatureInformation[]
---@field activeSignature? uinteger
---@field activeParameter? uinteger


---Signature help context sent with a request.
---@class lsp.protocol.SignatureHelpContext
---@field triggerKind integer
---@field triggerCharacter? string
---@field isRetrigger boolean
---@field activeSignatureHelp? lsp.protocol.SignatureHelp


---Signature help request parameters.
---@class lsp.protocol.SignatureHelpParams : lsp.protocol.TextDocumentPositionParams
---@field context? lsp.protocol.SignatureHelpContext


---A diagnostic represents a problem, such as a compiler error or warning.
---@class lsp.protocol.Diagnostic
---@field range lsp.protocol.Range
---@field severity? lsp.protocol.DiagnosticSeverity
---@field code? integer | string
---@field codeDescription? lsp.protocol.CodeDescription
---@field source? string
---@field message string
---@field tags? lsp.protocol.DiagnosticTag[]
---@field relatedInformation? lsp.protocol.DiagnosticRelatedInformation[]
---@field data? lsp.protocol.LSPAny


---A code description points to additional information for a diagnostic code.
---@class lsp.protocol.CodeDescription
---@field href string


---Represents a related diagnostic message and source location.
---@class lsp.protocol.DiagnosticRelatedInformation
---@field location lsp.protocol.Location
---@field message string


---A command or edit that fixes, improves, or refactors code.
---@class lsp.protocol.CodeAction
---@field title string
---@field kind? lsp.protocol.CodeActionKind
---@field diagnostics? lsp.protocol.Diagnostic[]
---@field isPreferred? boolean
---@field disabled? lsp.protocol.CodeActionDisabled
---@field edit? lsp.protocol.WorkspaceEdit
---@field command? lsp.protocol.Command
---@field data? lsp.protocol.LSPAny


---@class lsp.protocol.CodeActionDisabled
---@field reason string


---Code action request context.
---@class lsp.protocol.CodeActionContext
---@field diagnostics lsp.protocol.Diagnostic[]
---@field only? lsp.protocol.CodeActionKind[]
---@field triggerKind? lsp.protocol.CodeActionTriggerKind


---Code action request parameters.
---@class lsp.protocol.CodeActionParams
---@field textDocument lsp.protocol.TextDocumentIdentifier
---@field range lsp.protocol.Range
---@field context lsp.protocol.CodeActionContext


---A code lens represents a command that should be shown with source text.
---@class lsp.protocol.CodeLens
---@field range lsp.protocol.Range
---@field command? lsp.protocol.Command
---@field data? lsp.protocol.LSPAny


---A link inside a document.
---@class lsp.protocol.DocumentLink
---@field range lsp.protocol.Range
---@field target? lsp.protocol.DocumentURI
---@field tooltip? string
---@field data? lsp.protocol.LSPAny


---A color in RGBA space.
---@class lsp.protocol.Color
---@field red decimal
---@field green decimal
---@field blue decimal
---@field alpha decimal


---A color range inside a document.
---@class lsp.protocol.ColorInformation
---@field range lsp.protocol.Range
---@field color lsp.protocol.Color


---A color presentation.
---@class lsp.protocol.ColorPresentation
---@field label string
---@field textEdit? lsp.protocol.TextEdit
---@field additionalTextEdits? lsp.protocol.TextEdit[]


---A formatting option value.
---@alias lsp.protocol.FormattingOptionValue boolean | integer | string


---Formatting options.
---@class lsp.protocol.FormattingOptions
---@field tabSize uinteger
---@field insertSpaces boolean
---@field trimTrailingWhitespace? boolean
---@field insertFinalNewline? boolean
---@field trimFinalNewlines? boolean


---A document highlight.
---@class lsp.protocol.DocumentHighlight
---@field range lsp.protocol.Range
---@field kind? lsp.protocol.DocumentHighlightKind


---A folding range.
---@class lsp.protocol.FoldingRange
---@field startLine uinteger
---@field startCharacter? uinteger
---@field endLine uinteger
---@field endCharacter? uinteger
---@field kind? lsp.protocol.FoldingRangeKind | string
---@field collapsedText? string


---A selection range.
---@class lsp.protocol.SelectionRange
---@field range lsp.protocol.Range
---@field parent? lsp.protocol.SelectionRange


---The result of a linked editing range request.
---@class lsp.protocol.LinkedEditingRanges
---@field ranges lsp.protocol.Range[]
---@field wordPattern? string


---Represents programming constructs as returned by workspace/symbol.
---@class lsp.protocol.WorkspaceSymbol
---@field name string
---@field kind lsp.protocol.SymbolKind
---@field tags? lsp.protocol.SymbolTag[]
---@field containerName? string
---@field location lsp.protocol.Location | { uri: lsp.protocol.DocumentURI }
---@field data? lsp.protocol.LSPAny


---Represents an item shown in call hierarchy.
---@class lsp.protocol.CallHierarchyItem
---@field name string
---@field kind lsp.protocol.SymbolKind
---@field tags? lsp.protocol.SymbolTag[]
---@field detail? string
---@field uri lsp.protocol.DocumentURI
---@field range lsp.protocol.Range
---@field selectionRange lsp.protocol.Range
---@field data? lsp.protocol.LSPAny


---@class lsp.protocol.CallHierarchyIncomingCall
---@field from lsp.protocol.CallHierarchyItem
---@field fromRanges lsp.protocol.Range[]


---@class lsp.protocol.CallHierarchyOutgoingCall
---@field to lsp.protocol.CallHierarchyItem
---@field fromRanges lsp.protocol.Range[]


---Represents an item shown in type hierarchy.
---
---since 3.17.0
---@class lsp.protocol.TypeHierarchyItem
---@field name string
---@field kind lsp.protocol.SymbolKind
---@field tags? lsp.protocol.SymbolTag[]
---@field detail? string
---@field uri lsp.protocol.DocumentURI
---@field range lsp.protocol.Range
---@field selectionRange lsp.protocol.Range
---@field data? lsp.protocol.LSPAny


---A semantic tokens legend.
---@class lsp.protocol.SemanticTokensLegend
---@field tokenTypes string[]
---@field tokenModifiers string[]


---Semantic tokens.
---@class lsp.protocol.SemanticTokens
---@field resultId? string
---@field data uinteger[]


---Semantic token edits.
---@class lsp.protocol.SemanticTokensEdit
---@field start uinteger
---@field deleteCount uinteger
---@field data? uinteger[]


---Semantic token delta result.
---@class lsp.protocol.SemanticTokensDelta
---@field resultId? string
---@field edits lsp.protocol.SemanticTokensEdit[]


---A moniker uniquely identifies a symbol across documents or projects.
---@class lsp.protocol.Moniker
---@field scheme string
---@field identifier string
---@field unique lsp.protocol.UniquenessLevel
---@field kind? lsp.protocol.MonikerKind


---Inline value context.
---
---since 3.17.0
---@class lsp.protocol.InlineValueContext
---@field frameId integer
---@field stoppedLocation lsp.protocol.Range


---Inline value expressed as plain text.
---
---since 3.17.0
---@class lsp.protocol.InlineValueText
---@field range lsp.protocol.Range
---@field text string


---Inline value expressed as a variable lookup.
---
---since 3.17.0
---@class lsp.protocol.InlineValueVariableLookup
---@field range lsp.protocol.Range
---@field variableName? string
---@field caseSensitiveLookup boolean


---Inline value expressed as an evaluatable expression.
---
---since 3.17.0
---@class lsp.protocol.InlineValueEvaluatableExpression
---@field range lsp.protocol.Range
---@field expression? string


---@alias lsp.protocol.InlineValue lsp.protocol.InlineValueText | lsp.protocol.InlineValueVariableLookup | lsp.protocol.InlineValueEvaluatableExpression


---An inlay hint label part.
---
---since 3.17.0
---@class lsp.protocol.InlayHintLabelPart
---@field value string
---@field tooltip? string | lsp.protocol.MarkupContent
---@field location? lsp.protocol.Location
---@field command? lsp.protocol.Command


---An inlay hint.
---
---since 3.17.0
---@class lsp.protocol.InlayHint
---@field position lsp.protocol.Position
---@field label string | lsp.protocol.InlayHintLabelPart[]
---@field kind? lsp.protocol.InlayHintKind
---@field textEdits? lsp.protocol.TextEdit[]
---@field tooltip? string | lsp.protocol.MarkupContent
---@field paddingLeft? boolean
---@field paddingRight? boolean
---@field data? lsp.protocol.LSPAny


---A full document diagnostic report.
---
---since 3.17.0
---@class lsp.protocol.RelatedFullDocumentDiagnosticReport
---@field kind 'full'
---@field resultId? string
---@field items lsp.protocol.Diagnostic[]
---@field relatedDocuments? table<lsp.protocol.DocumentURI,lsp.protocol.FullDocumentDiagnosticReport | lsp.protocol.UnchangedDocumentDiagnosticReport>


---An unchanged document diagnostic report.
---
---since 3.17.0
---@class lsp.protocol.RelatedUnchangedDocumentDiagnosticReport
---@field kind 'unchanged'
---@field resultId string
---@field relatedDocuments? table<lsp.protocol.DocumentURI,lsp.protocol.FullDocumentDiagnosticReport | lsp.protocol.UnchangedDocumentDiagnosticReport>


---@class lsp.protocol.FullDocumentDiagnosticReport : lsp.protocol.RelatedFullDocumentDiagnosticReport
---@class lsp.protocol.UnchangedDocumentDiagnosticReport : lsp.protocol.RelatedUnchangedDocumentDiagnosticReport
---@alias lsp.protocol.DocumentDiagnosticReport lsp.protocol.RelatedFullDocumentDiagnosticReport | lsp.protocol.RelatedUnchangedDocumentDiagnosticReport


---A notebook document identifier.
---
---since 3.17.0
---@class lsp.protocol.NotebookDocumentIdentifier
---@field uri lsp.protocol.DocumentURI


---A versioned notebook document identifier.
---
---since 3.17.0
---@class lsp.protocol.VersionedNotebookDocumentIdentifier : lsp.protocol.NotebookDocumentIdentifier
---@field version integer


---A notebook document.
---
---since 3.17.0
---@class lsp.protocol.NotebookDocument
---@field uri lsp.protocol.DocumentURI
---@field notebookType string
---@field version integer
---@field metadata? lsp.protocol.LSPObject
---@field cells lsp.protocol.NotebookCell[]


---A notebook cell.
---
---since 3.17.0
---@class lsp.protocol.NotebookCell
---@field kind lsp.protocol.NotebookCellKind
---@field document lsp.protocol.DocumentURI
---@field metadata? lsp.protocol.LSPObject
---@field executionSummary? lsp.protocol.ExecutionSummary


---A notebook cell kind.
---
---since 3.17.0
---@enum lsp.protocol.NotebookCellKind
protocol.NotebookCellKind = {
	Markup = 1,
	Code = 2
}


---A notebook cell execution summary.
---
---since 3.17.0
---@class lsp.protocol.ExecutionSummary
---@field executionOrder uinteger
---@field success? boolean


---Notebook cell text document filter.
---
---since 3.17.0
---@class lsp.protocol.NotebookCellTextDocumentFilter
---@field notebook string | lsp.protocol.NotebookDocumentFilter
---@field language? string


---Notebook document filter.
---
---since 3.17.0
---@class lsp.protocol.NotebookDocumentFilter
---@field notebookType? string
---@field scheme? string
---@field pattern? string


---Options specific to notebook document synchronization.
---
---since 3.17.0
---@class lsp.protocol.NotebookDocumentSyncOptions
---@field notebookSelector lsp.protocol.NotebookDocumentSyncOptionsNotebookSelector[]
---@field save? boolean


---A notebook selector entry for notebook sync options.
---
---since 3.17.0
---@class lsp.protocol.NotebookDocumentSyncOptionsNotebookSelector
---@field notebook string | lsp.protocol.NotebookDocumentFilter
---@field cells? lsp.protocol.NotebookDocumentSyncOptionsCellSelector[]


---A cell selector entry for notebook sync options.
---
---since 3.17.0
---@class lsp.protocol.NotebookDocumentSyncOptionsCellSelector
---@field language string


---Registration options specific to notebook document synchronization.
---
---since 3.17.0
---@class lsp.protocol.NotebookDocumentSyncRegistrationOptions : lsp.protocol.NotebookDocumentSyncOptions
---@field id string


---Generic work done progress options.
---@class lsp.protocol.WorkDoneProgressOptions
---@field workDoneProgress? boolean


---Generic static registration options.
---@class lsp.protocol.StaticRegistrationOptions
---@field id? string


---Generic text document registration options.
---@class lsp.protocol.TextDocumentRegistrationOptions
---@field documentSelector? lsp.protocol.DocumentSelector


---Generic text document and static registration options.
---@class lsp.protocol.TextDocumentAndStaticRegistrationOptions : lsp.protocol.TextDocumentRegistrationOptions
---@field id? string


---Completion options.
---@class lsp.protocol.CompletionOptions : lsp.protocol.WorkDoneProgressOptions
---@field triggerCharacters? string[]
---@field allCommitCharacters? string[]
---@field resolveProvider? boolean
---@field completionItem? { labelDetailsSupport: boolean }


---@class lsp.protocol.CompletionRegistrationOptions : lsp.protocol.CompletionOptions
---@field documentSelector? lsp.protocol.DocumentSelector
---@field id? string


---@class lsp.protocol.HoverOptions : lsp.protocol.WorkDoneProgressOptions
---@class lsp.protocol.HoverRegistrationOptions : lsp.protocol.HoverOptions
---@field documentSelector? lsp.protocol.DocumentSelector
---@field id? string


---@class lsp.protocol.SignatureHelpOptions : lsp.protocol.WorkDoneProgressOptions
---@field triggerCharacters? string[]
---@field retriggerCharacters? string[]


---@class lsp.protocol.SignatureHelpRegistrationOptions : lsp.protocol.SignatureHelpOptions
---@field documentSelector? lsp.protocol.DocumentSelector
---@field id? string


---@class lsp.protocol.DeclarationOptions : lsp.protocol.WorkDoneProgressOptions
---@class lsp.protocol.DeclarationRegistrationOptions : lsp.protocol.DeclarationOptions
---@field documentSelector? lsp.protocol.DocumentSelector
---@field id? string


---@class lsp.protocol.DefinitionOptions : lsp.protocol.WorkDoneProgressOptions
---@class lsp.protocol.TypeDefinitionOptions : lsp.protocol.WorkDoneProgressOptions
---@class lsp.protocol.TypeDefinitionRegistrationOptions : lsp.protocol.TypeDefinitionOptions
---@field documentSelector? lsp.protocol.DocumentSelector
---@field id? string


---@class lsp.protocol.ImplementationOptions : lsp.protocol.WorkDoneProgressOptions
---@class lsp.protocol.ImplementationRegistrationOptions : lsp.protocol.ImplementationOptions
---@field documentSelector? lsp.protocol.DocumentSelector
---@field id? string


---@class lsp.protocol.ReferenceOptions : lsp.protocol.WorkDoneProgressOptions
---@class lsp.protocol.DocumentHighlightOptions : lsp.protocol.WorkDoneProgressOptions
---@class lsp.protocol.DocumentSymbolOptions : lsp.protocol.WorkDoneProgressOptions
---@field label? string


---@class lsp.protocol.CodeActionOptions : lsp.protocol.WorkDoneProgressOptions
---@field codeActionKinds? lsp.protocol.CodeActionKind[]
---@field resolveProvider? boolean


---@class lsp.protocol.CodeLensOptions : lsp.protocol.WorkDoneProgressOptions
---@field resolveProvider? boolean


---@class lsp.protocol.CodeLensRegistrationOptions : lsp.protocol.CodeLensOptions
---@field documentSelector? lsp.protocol.DocumentSelector
---@field id? string


---@class lsp.protocol.DocumentLinkOptions : lsp.protocol.WorkDoneProgressOptions
---@field resolveProvider? boolean


---@class lsp.protocol.DocumentLinkRegistrationOptions : lsp.protocol.DocumentLinkOptions
---@field documentSelector? lsp.protocol.DocumentSelector
---@field id? string


---@class lsp.protocol.DocumentColorOptions : lsp.protocol.WorkDoneProgressOptions
---@class lsp.protocol.DocumentColorRegistrationOptions : lsp.protocol.DocumentColorOptions
---@field documentSelector? lsp.protocol.DocumentSelector
---@field id? string


---@class lsp.protocol.DocumentFormattingOptions : lsp.protocol.WorkDoneProgressOptions
---@class lsp.protocol.DocumentRangeFormattingOptions : lsp.protocol.WorkDoneProgressOptions
---@class lsp.protocol.DocumentOnTypeFormattingOptions
---@field firstTriggerCharacter string
---@field moreTriggerCharacter? string[]


---@class lsp.protocol.RenameOptions : lsp.protocol.WorkDoneProgressOptions
---@field prepareProvider? boolean


---@class lsp.protocol.FoldingRangeOptions : lsp.protocol.WorkDoneProgressOptions
---@class lsp.protocol.FoldingRangeRegistrationOptions : lsp.protocol.FoldingRangeOptions
---@field documentSelector? lsp.protocol.DocumentSelector
---@field id? string


---@class lsp.protocol.ExecuteCommandOptions : lsp.protocol.WorkDoneProgressOptions
---@field commands string[]


---@class lsp.protocol.SelectionRangeOptions : lsp.protocol.WorkDoneProgressOptions
---@class lsp.protocol.SelectionRangeRegistrationOptions : lsp.protocol.SelectionRangeOptions
---@field documentSelector? lsp.protocol.DocumentSelector
---@field id? string


---@class lsp.protocol.LinkedEditingRangeOptions : lsp.protocol.WorkDoneProgressOptions
---@class lsp.protocol.LinkedEditingRangeRegistrationOptions : lsp.protocol.LinkedEditingRangeOptions
---@field documentSelector? lsp.protocol.DocumentSelector
---@field id? string


---@class lsp.protocol.CallHierarchyOptions : lsp.protocol.WorkDoneProgressOptions
---@class lsp.protocol.CallHierarchyRegistrationOptions : lsp.protocol.CallHierarchyOptions
---@field documentSelector? lsp.protocol.DocumentSelector
---@field id? string


---@class lsp.protocol.SemanticTokensOptions : lsp.protocol.WorkDoneProgressOptions
---@field legend lsp.protocol.SemanticTokensLegend
---@field range? boolean | object
---@field full? boolean | { delta: boolean }


---@class lsp.protocol.SemanticTokensRegistrationOptions : lsp.protocol.SemanticTokensOptions
---@field documentSelector? lsp.protocol.DocumentSelector
---@field id? string


---@class lsp.protocol.MonikerOptions : lsp.protocol.WorkDoneProgressOptions
---@class lsp.protocol.MonikerRegistrationOptions : lsp.protocol.MonikerOptions
---@field documentSelector? lsp.protocol.DocumentSelector
---@field id? string


---@class lsp.protocol.TypeHierarchyOptions : lsp.protocol.WorkDoneProgressOptions
---@class lsp.protocol.TypeHierarchyRegistrationOptions : lsp.protocol.TypeHierarchyOptions
---@field documentSelector? lsp.protocol.DocumentSelector
---@field id? string


---@class lsp.protocol.InlineValueOptions : lsp.protocol.WorkDoneProgressOptions
---@class lsp.protocol.InlineValueRegistrationOptions : lsp.protocol.InlineValueOptions
---@field documentSelector? lsp.protocol.DocumentSelector
---@field id? string


---@class lsp.protocol.InlayHintOptions : lsp.protocol.WorkDoneProgressOptions
---@field resolveProvider? boolean


---@class lsp.protocol.InlayHintRegistrationOptions : lsp.protocol.InlayHintOptions
---@field documentSelector? lsp.protocol.DocumentSelector
---@field id? string


---@class lsp.protocol.DiagnosticOptions : lsp.protocol.WorkDoneProgressOptions
---@field identifier? string
---@field interFileDependencies boolean
---@field workspaceDiagnostics boolean


---@class lsp.protocol.DiagnosticRegistrationOptions : lsp.protocol.DiagnosticOptions
---@field documentSelector? lsp.protocol.DocumentSelector
---@field id? string


---@class lsp.protocol.WorkspaceSymbolOptions : lsp.protocol.WorkDoneProgressOptions
---@field resolveProvider? boolean


---Client releated structures.
---@type lsp.protocol.client
protocol.client = require "plugins.lsp.protocol.client"

---Server releated structures.
---@type lsp.protocol.server
protocol.server = require "plugins.lsp.protocol.server"


return protocol
