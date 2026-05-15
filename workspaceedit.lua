local core = require "core"
local common = require "core.common"
local util = require "plugins.lsp.util"

local workspaceedit = {}

local function dirname(path)
  return path:match("^(.*)[/\\][^/\\]*$") or "."
end

local function ensure_dir(path)
  local info = system.get_file_info(path)
  if info and info.type == "dir" then return true end
  return common.mkdirp(path)
end

local function doc_for_uri(uri)
  local filename = common.home_expand(util.tofilename(uri))
  local was_open = util.doc_is_open(filename)
  local doc = core.open_doc(filename)
  return doc, not was_open
end

local function get_edit_range(text_edit)
  return text_edit.range or text_edit.insert or text_edit.replace
end

---Apply a text edit to a document.
---@param server lsp.server
---@param doc core.doc
---@param text_edit lsp.protocol.TextEdit | lsp.protocol.AnnotatedTextEdit | lsp.protocol.InsertReplaceEdit
---@param end_col_offset? integer
---@return boolean
function workspaceedit.apply_text_edit(server, doc, text_edit, end_col_offset)
  local range = get_edit_range(text_edit)
  if not range then return false end

  local line1, col1, line2, col2
  if
    not server.capabilities.positionEncoding
    or
    server.capabilities.positionEncoding == "utf-16"
  then
    line1, col1, line2, col2 = util.toselection(range, doc)
  else
    line1, col1, line2, col2 = util.toselection(range)
    core.error(
      "[LSP] Unsupported position encoding: ",
      server.capabilities.positionEncoding
    )
    return false
  end

  doc:remove(line1, col1, line2, col2 + (end_col_offset or 0))
  doc:insert(line1, col1, text_edit.newText)
  return true
end

---Apply text edits to a document in reverse order.
---@param server lsp.server
---@param doc core.doc
---@param edits lsp.protocol.TextEdit[] | lsp.protocol.AnnotatedTextEdit[] | lsp.protocol.InsertReplaceEdit[]
---@return boolean
function workspaceedit.apply_text_edits(server, doc, edits)
  local ok = true
  for i = #edits, 1, -1 do
    ok = workspaceedit.apply_text_edit(server, doc, edits[i]) and ok
  end
  return ok
end

local function apply_uri_edits(server, uri, edits)
  local doc, save_after = doc_for_uri(uri)
  local ok = workspaceedit.apply_text_edits(server, doc, edits)
  if ok and save_after then
    doc:save(doc.filename, doc.abs_filename)
  end
  return ok
end

local function create_file(change)
  local filename = common.home_expand(util.tofilename(change.uri))
  local info = system.get_file_info(filename)
  local options = change.options or {}

  if info and options.ignoreIfExists then return true end
  if info and not options.overwrite then return false end

  local ok, err = ensure_dir(dirname(filename))
  if not ok then
    core.error("[LSP] Could not create parent directory: %s", err or filename)
    return false
  end

  local file = io.open(filename, "w")
  if not file then return false end
  file:close()
  return true
end

local function rename_file(change)
  local old_filename = common.home_expand(util.tofilename(change.oldUri))
  local new_filename = common.home_expand(util.tofilename(change.newUri))
  local options = change.options or {}

  if not system.get_file_info(old_filename) then return false end
  if system.get_file_info(new_filename) then
    if options.ignoreIfExists then return true end
    if not options.overwrite then return false end
    os.remove(new_filename)
  end

  local ok, err = ensure_dir(dirname(new_filename))
  if not ok then
    core.error("[LSP] Could not create parent directory: %s", err or new_filename)
    return false
  end

  return os.rename(old_filename, new_filename) == true
end

local function delete_file(change)
  local filename = common.home_expand(util.tofilename(change.uri))
  local options = change.options or {}
  if not system.get_file_info(filename) then
    return options.ignoreIfNotExists == true
  end

  local ok = common.rm(filename, options.recursive == true)
  return ok == true
end

---Apply a WorkspaceEdit.
---@param server lsp.server
---@param edit lsp.protocol.WorkspaceEdit
---@return boolean
function workspaceedit.apply_workspace_edit(server, edit)
  if not edit then return false end

  if edit.documentChanges then
    for _, change in ipairs(edit.documentChanges) do
      if change.kind == "create" then
        if not create_file(change) then return false end
      elseif change.kind == "rename" then
        if not rename_file(change) then return false end
      elseif change.kind == "delete" then
        if not delete_file(change) then return false end
      elseif change.textDocument and change.edits then
        if not apply_uri_edits(server, change.textDocument.uri, change.edits) then
          return false
        end
      end
    end
  elseif edit.changes then
    for uri, edits in pairs(edit.changes) do
      if not apply_uri_edits(server, uri, edits) then return false end
    end
  end

  return true
end

return workspaceedit
