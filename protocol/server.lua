--
-- This file defines some of the LSP protocol elements related to server
-- for type hinting usage with the sumneko lua language server.
--
-- LSP Documentation:
-- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification

---@class lsp.protocol.server
local server = {}


---A pattern kind describing if a glob pattern matches a file a folder or
---both.
---
---since 3.16.0
---@enum lsp.protocol.server.FileOperationPatternKind
server.FileOperationPatternKind = {
	---The pattern matches a file only.
	file = 'file',
	---The pattern matches a folder only.
	folder = 'folder'
}


---Matching options for the file operation pattern.
---
---since 3.16.0
---@class lsp.protocol.server.FileOperationPatternOptions
---The pattern should be matched ignoring casing.
---@field ignoreCase? boolean


---A pattern to describe in which file operation requests or notifications
---the server is interested in.
---
---since 3.16.0
---@class lsp.protocol.server.FileOperationPattern
---The glob pattern to match. Glob patterns can have the following syntax:
--- `*` to match one or more characters in a path segment
--- `?` to match on one character in a path segment
--- `**` to match any number of path segments, including none
--- `{}` to group sub patterns into an OR expression. (e.g. `**​/*.{ts,js}`
---  matches all TypeScript and JavaScript files)
--- `[]` to declare a range of characters to match in a path segment
---  (e.g., `example.[0-9]` to match on `example.0`, `example.1`, …)
--- `[!...]` to negate a range of characters to match in a path segment
---  (e.g., `example.[!0-9]` to match on `example.a`, `example.b`, but
---  not `example.0`)
---@field glob string
---Whether to match files or folders with this pattern.
---
---Matches both if undefined.
---@field matches? lsp.protocol.server.FileOperationPatternKind
---Additional options used during matching.
---@field options? lsp.protocol.server.FileOperationPatternOptions


---A filter to describe in which file operation requests or notifications
---the server is interested in.
---
---since 3.16.0
---@class lsp.protocol.server.FileOperationFilter
---A Uri like `file` or `untitled`.
---@field scheme? string
---The actual file operation pattern.
---@field pattern lsp.protocol.server.FileOperationPattern


---The options to register for file operations.
---
---since 3.16.0
---@class lsp.protocol.server.FileOperationRegistrationOptions
---The actual filters.
---@field filters lsp.protocol.server.FileOperationFilter[]


---@class lsp.protocol.server.FileOperationsServerCapabilities
---The server is interested in receiving didCreateFiles
---notifications.
---@field didCreate? lsp.protocol.server.FileOperationRegistrationOptions
---The server is interested in receiving willCreateFiles requests.
---@field willCreate? lsp.protocol.server.FileOperationRegistrationOptions
---The server is interested in receiving didRenameFiles
---notifications.
---@field didRename? lsp.protocol.server.FileOperationRegistrationOptions
---The server is interested in receiving willRenameFiles requests.
---@field willRename? lsp.protocol.server.FileOperationRegistrationOptions
---The server is interested in receiving didDeleteFiles file
---notifications.
---@field didDelete? lsp.protocol.server.FileOperationRegistrationOptions
---The server is interested in receiving willDeleteFiles file
---requests.
---@field willDelete? lsp.protocol.server.FileOperationRegistrationOptions


---@class lsp.protocol.server.WorkspaceFoldersServerCapabilities
---The server has support for workspace folders
---@field supported? boolean
---Whether the server wants to receive workspace folder
---change notifications.
---
---If a string is provided, the string is treated as an ID
---under which the notification is registered on the client
---side. The ID can be used to unregister for these events
---using the `client/unregisterCapability` request.
---@field changeNotifications? string | boolean


---@class lsp.protocol.server.WorkspaceServerCapabilities
---The server supports workspace folder.
---
---since 3.6.0
---@field workspaceFolders? lsp.protocol.server.WorkspaceFoldersServerCapabilities
---The server is interested in file notifications/requests.
---
---since 3.16.0
---@field fileOperations? lsp.protocol.server.FileOperationsServerCapabilities


---A server capabilities.
---@class lsp.protocol.server.ServerCapabilities
---The position encoding the server picked from the encodings offered
---by the client via the client capability `general.positionEncodings`.
---
---If the client didn't provide any position encodings the only valid
---value that a server can return is 'utf-16'.
---
---If omitted it defaults to 'utf-16'.
---
---since 3.17.0
---@field positionEncoding? lsp.protocol.PositionEncodingKind
---Defines how text documents are synced. Is either a detailed structure
---defining each notification or for backwards compatibility the
---TextDocumentSyncKind number. If omitted it defaults to
---`TextDocumentSyncKind.None`.
---@field textDocumentSync? lsp.protocol.TextDocumentSyncOptions | lsp.protocol.TextDocumentSyncKind
---Defines how notebook documents are synced.
---
---since 3.17.0
---@field notebookDocumentSync? lsp.protocol.NotebookDocumentSyncOptions | lsp.protocol.NotebookDocumentSyncRegistrationOptions
---The server provides completion support.
---@field completionProvider? lsp.protocol.CompletionOptions
---The server provides hover support.
---@field hoverProvider? boolean | lsp.protocol.HoverOptions
---The server provides signature help support.
---@field signatureHelpProvider? lsp.protocol.SignatureHelpOptions
---The server provides go to declaration support.
---
---since 3.14.0
---@field declarationProvider? boolean | lsp.protocol.DeclarationOptions | lsp.protocol.DeclarationRegistrationOptions
---The server provides goto definition support.
---@field definitionProvider? boolean | lsp.protocol.DefinitionOptions
---The server provides goto type definition support.
---
---since 3.6.0
---@field typeDefinitionProvider? boolean | lsp.protocol.TypeDefinitionOptions | lsp.protocol.TypeDefinitionRegistrationOptions
---The server provides goto implementation support.
---
---since 3.6.0
---@field implementationProvider? boolean | lsp.protocol.ImplementationOptions | lsp.protocol.ImplementationRegistrationOptions
---The server provides find references support.
---@field referencesProvider? boolean | lsp.protocol.ReferenceOptions
---The server provides document highlight support.
---@field documentHighlightProvider? boolean | lsp.protocol.DocumentHighlightOptions
---The server provides document symbol support.
---@field documentSymbolProvider? boolean | lsp.protocol.DocumentSymbolOptions
---The server provides code actions. The `CodeActionOptions` return type is
---only valid if the client signals code action literal support via the
---property `textDocument.codeAction.codeActionLiteralSupport`.
---@field codeActionProvider? boolean | lsp.protocol.CodeActionOptions
---The server provides code lens.
---@field codeLensProvider? lsp.protocol.CodeLensOptions
---The server provides document link support.
---@field documentLinkProvider? lsp.protocol.DocumentLinkOptions
---The server provides color provider support.
---
---since 3.6.0
---@field colorProvider? boolean | lsp.protocol.DocumentColorOptions | lsp.protocol.DocumentColorRegistrationOptions
---The server provides document formatting.
---@field documentFormattingProvider? boolean | lsp.protocol.DocumentFormattingOptions
---The server provides document range formatting.
---@field documentRangeFormattingProvider? boolean | lsp.protocol.DocumentRangeFormattingOptions
---The server provides document formatting on typing.
---@field documentOnTypeFormattingProvider? lsp.protocol.DocumentOnTypeFormattingOptions
---The server provides rename support. RenameOptions may only be
---specified if the client states that it supports
---`prepareSupport` in its initial `initialize` request.
---@field renameProvider? boolean | lsp.protocol.RenameOptions
---The server provides folding provider support.
---
---since 3.10.0
---@field foldingRangeProvider? boolean | lsp.protocol.FoldingRangeOptions | lsp.protocol.FoldingRangeRegistrationOptions
---The server provides execute command support.
---@field executeCommandProvider? lsp.protocol.ExecuteCommandOptions
---The server provides selection range support.
---
---since 3.15.0
---@field selectionRangeProvider? boolean | lsp.protocol.SelectionRangeOptions | lsp.protocol.SelectionRangeRegistrationOptions
---The server provides linked editing range support.
---
---since 3.16.0
---@field linkedEditingRangeProvider? boolean | lsp.protocol.LinkedEditingRangeOptions | lsp.protocol.LinkedEditingRangeRegistrationOptions
---The server provides call hierarchy support.
---
---since 3.16.0
---@field callHierarchyProvider? boolean | lsp.protocol.CallHierarchyOptions | lsp.protocol.CallHierarchyRegistrationOptions
---The server provides semantic tokens support.
---
---since 3.16.0
---@field semanticTokensProvider? lsp.protocol.SemanticTokensOptions | lsp.protocol.SemanticTokensRegistrationOptions
---Whether server provides moniker support.
---
---since 3.16.0
---@field monikerProvider? boolean | lsp.protocol.MonikerOptions | lsp.protocol.MonikerRegistrationOptions
---The server provides type hierarchy support.
---
---since 3.17.0
---@field typeHierarchyProvider? boolean | lsp.protocol.TypeHierarchyOptions | lsp.protocol.TypeHierarchyRegistrationOptions
---The server provides inline values.
---
---since 3.17.0
---@field inlineValueProvider? boolean | lsp.protocol.InlineValueOptions | lsp.protocol.InlineValueRegistrationOptions
---The server provides inlay hints.
---
---since 3.17.0
---@field inlayHintProvider? boolean | lsp.protocol.InlayHintOptions | lsp.protocol.InlayHintRegistrationOptions
---The server has support for pull model diagnostics.
---
---since 3.17.0
---@field diagnosticProvider? lsp.protocol.DiagnosticOptions | lsp.protocol.DiagnosticRegistrationOptions
---The server provides workspace symbol support.
---@field workspaceSymbolProvider? boolean | lsp.protocol.WorkspaceSymbolOptions
---Workspace specific server capabilities
---@field workspace? lsp.protocol.server.WorkspaceServerCapabilities
---Experimental server capabilities.
---@field experimental? lsp.protocol.LSPAny


return server
