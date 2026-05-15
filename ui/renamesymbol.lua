--
-- RenameSymbol Widget/View.
-- @copyright Jefferson Gonzalez
-- @license MIT
--

local core = require "core"
local common = require "core.common"
local command = require "core.command"
local keymap = require "core.keymap"
local style = require "core.style"
local util = require "plugins.lsp.util"
local workspaceedit = require "plugins.lsp.workspaceedit"
local Widget = require "widget"
local Button = require "widget.button"
local Label = require "widget.label"
local Line = require "widget.line"
local ListBox = require "widget.listbox"
local MessageBox = require "widget.messagebox"
local SearchReplaceList = require "widget.searchreplacelist"

---@class lsp.ui.renamesymbol : widget
---@field public calculating boolean
---@field private title widget.label
---@field private line widget.line
---@field private list widget.searchreplacelist
---@field private resource_list widget.listbox?
---@overload fun():lsp.ui.renamesymbol
local RenameSymbol = Widget:extend()

---Indicates if a rename procedure is taking place.
---@type boolean
RenameSymbol.renaming = false

local function tofilename(uri)
  return common.home_expand(util.tofilename(uri))
end

local function relative_path(path)
  return common.relative_path(core.root_project().path, path)
end

local function operation_label(operation)
  if operation.kind == "create" then
    return "Create", relative_path(tofilename(operation.uri)), ""
  elseif operation.kind == "rename" then
    return "Rename",
      relative_path(tofilename(operation.oldUri)),
      relative_path(tofilename(operation.newUri))
  elseif operation.kind == "delete" then
    return "Delete", relative_path(tofilename(operation.uri)), ""
  end
  return operation.kind or "", "", ""
end

local function operation_color(operation)
  if operation.kind == "create" then
    return style.good or style.syntax.string
  elseif operation.kind == "rename" then
    return style.accent or style.syntax.keyword
  elseif operation.kind == "delete" then
    return style.error or style.syntax.keyword2
  end
  return style.text
end

local function operation_status_color(status)
  if status == "Applied" then
    return style.good or style.syntax.string
  elseif status == "Failed" then
    return style.error or style.syntax.keyword2
  elseif status == "Skipped" then
    return style.dim
  end
  return style.syntax.literal or style.accent
end

local function operation_count_suffix(count)
  if count <= 0 then return "" end
  return ", " .. tostring(count) .. " file operation(s)"
end

local function has_checked_positions(file)
  for _, line in ipairs(file.lines) do
    for _, position in ipairs(line.positions) do
      if position.checked or type(position.checked) == "nil" then
        return true
      end
    end
  end
  return false
end

---Constructor
---@param workspace_edit lsp.protocol.WorkspaceEdit
function RenameSymbol:new(workspace_edit)
  RenameSymbol.super.new(self)

  self.name = "Symbol Rename"
  self.defer_draw = false

  self.calculating = true
  self.renamed = false
  self.total_files_processed = 0
  self.resource_operations_processed = 0
  self.resource_operations_failed = false
  self.resource_operation_rows = {}
  self.skipped_resource_operations = {}
  self.applied_resource_operations = {}
  self.failed_resource_operation = nil
  self.replacement = nil
  self.title = Label(self, "")
  self.line = Line(self, 2, style.padding.x)
  self.resource_operations = workspaceedit.get_resource_operations(workspace_edit)

  if #self.resource_operations > 0 then
    self.resource_list = ListBox(self)
    self.resource_list.border.width = 0
    self.resource_list:add_column("Operation", style.font:get_width("Operation"))
    self.resource_list:add_column("Path", nil, true)
    self.resource_list:add_column("Target", nil, true)
    self.resource_list:add_column("Status", style.font:get_width("Skipped"))

    for _, operation in ipairs(self.resource_operations) do
      self.resource_list:add_row(self:resource_operation_row(operation), operation)
      self.resource_operation_rows[operation] = #self.resource_list.rows
    end

    local resource_list_on_mouse_pressed = self.resource_list.on_mouse_pressed
    self.resource_list.on_mouse_pressed = function(this, button, x, y, clicks)
      local result = resource_list_on_mouse_pressed(this, button, x, y, clicks)
      if button == "left" and clicks > 1 then
        local index = this:get_row_at_position(x, y)
        local operation = index and this:get_row_data(index)
        if operation and operation.kind == "delete" then
          self.skipped_resource_operations[operation] =
            not self.skipped_resource_operations[operation] or nil
          self:update_resource_operation_rows()
        end
      end
      return result
    end
  end

  self.list = SearchReplaceList(self, "")
  self.list.base_dir = core.root_project().path
  self.list.border.width = 0
  self.list.on_item_click = function(this, item, clicks)
    self:open_selected()
  end
  local list_on_mouse_pressed = self.list.on_mouse_pressed
  self.list.on_mouse_pressed = function(this, button, x, y, clicks)
    local result = list_on_mouse_pressed(this, button, x, y, clicks)
    self:update_resource_operation_rows()
    return result
  end

  self.apply_button = Button(self, "Apply Rename")
  self.apply_button:hide()
  self.apply_button.on_click = function(this, button, x, y)
    local resource_count = #self.resource_operations
    local resource_text = resource_count > 0
      and ("\nThe process will also apply "
        .. tostring(resource_count)
        .. " file operation(s).\n")
      or "\n"
    MessageBox.warning(
      "Apply Rename",
      {
        "This process will modify all selected file locations and\n"
        .. "reload opened documents where rename is also performed.\n"
        .. resource_text
        .. "For safety do not edit any files until renaming finishes.\n\n"
        .. "Do you still want to proceed?"
      },
      function(dialog, button_id, button)
        if button_id == 1 then
          self:begin_replace()
        end
      end,
      MessageBox.BUTTONS_YES_NO
    )
  end

  self.border.width = 0
  self:set_size(200, 200)
  self:show()

  if not workspace_edit then return end

  core.add_thread(function()
    for file_uri, changes in pairs(workspaceedit.get_text_document_changes(workspace_edit)) do
      table.sort(changes, function(a, b)
        if a.range.start.line == b.range.start.line then
          return a.range.start.character < b.range.start.character
        end
        return a.range.start.line < b.range.start.line
      end)
      local file_path = util.tofilename(file_uri)
      local file = io.open(file_path, "r")
      if file then
        ---@type widget.searchreplacelist.line[]
        local lines = {}
        local line = 0
        for text in file:lines("L") do
          line = line + 1
          ---@type widget.searchreplacelist.lineposition[]
          local positions = {}
          if #changes > 0 and line == changes[1].range.start.line+1 then
            if not self.replacement then
              self.replacement = changes[1].newText
              self.list.replacement = self.replacement
            end
            local cremoved = 0
            for cpos=1, #changes do
              local change = changes[cpos - cremoved]
              if change.range.start.line+1 == line then
                local col1 = self:utf16_to_utf8(
                  text, change.range.start.character + 1
                )
                local col2 = self:utf16_to_utf8(
                  text, change.range["end"].character
                )
                table.insert(positions, {col1 = col1, col2 = col2})
                table.remove(changes, cpos - cremoved)
                cremoved = cremoved + 1
              end
            end
            table.insert(lines, {
              line = line,
              text = text,
              positions = positions
            })
          end
          if line % 100 == 0 then coroutine.yield() end
        end
        self.list:add_file(file_path, lines)
        core.redraw = true
        file:close()
      end
    end
    self:update_resource_operation_rows()
    self.calculating = false
  end)
end

---Symbols rename wordker thread function.
---@param id integer
---@param replacement string
local function symbols_rename_thread(id, replacement)
  local file_channel = thread.get_channel("lsp_symbol_rename"..id)
  local status_channel = thread.get_channel("lsp_symbol_rename_status"..id)
  local replacement_len = #replacement

  if not file_channel or not status_channel then
    error("could not retrieve channels for symbols rename thread")
    return
  end

  local replace_substring = function(str, s, e, rep)
    local head = s <= 1 and "" or string.sub(str, 1, s - 1)
    local tail = e >= #str and "" or string.sub(str, e + 1)
    return head .. rep .. tail
  end

  local file_data = file_channel:wait()

  while file_data ~= "{{stop}}" do
    local file_path = file_data[2].path
    local file = io.open(file_path, "r")

    if file then
      local ln = 0
      local lines = {}

      ---@type widget.searchreplacelist.file
      local results = file_data[2]

      for line in file:lines("L") do
        ln = ln + 1
        local current_line = line

        if results.lines[1] and results.lines[1].line == ln then
          local offset = 0

          for _, pos in ipairs(results.lines[1].positions) do
            local col1 = pos.col1 + offset
            local col2 = pos.col2 + offset

            if pos.checked or type(pos.checked) == "nil" then
              current_line = replace_substring(current_line, col1, col2, replacement)
              local current_len = col2 - col1 + 1
              if current_len > replacement_len then
                offset = offset - (current_len - replacement_len)
              elseif current_len < replacement_len then
                offset = offset + (replacement_len - current_len)
              end
            end
          end

          table.remove(results.lines, 1)
        end

        table.insert(lines, current_line)
      end

      file:close()

      file = io.open(file_path, "w")
      if file then
        for _, line in ipairs(lines) do
          file:write(line)
        end
        file:close()
      end
    end

    file_channel:pop()
    status_channel:push(file_data[1])
    file_data = file_channel:wait()
  end

  file_channel:clear()
  status_channel:push("{{done}}")
end

---Get text edit files separated by files with any checked edit and all files.
---@return table<string,boolean> checked_files
---@return table<string,boolean> all_files
function RenameSymbol:get_text_edit_file_sets()
  local checked_files, all_files = {}, {}
  if not self.list then return checked_files, all_files end
  for _, item in ipairs(self.list.items) do
    if item.file then
      all_files[item.file.path] = true
      if has_checked_positions(item.file) then
        checked_files[item.file.path] = true
      end
    end
  end
  return checked_files, all_files
end

---Get if the resource operation should apply with current selections.
---@param operation lsp.protocol.WorkspaceEditDocumentChange
---@return boolean
function RenameSymbol:resource_operation_will_apply(operation)
  if self.skipped_resource_operations[operation] then return false end

  local checked_files, all_files = self:get_text_edit_file_sets()
  if operation.kind == "rename" then
    local old_filename = tofilename(operation.oldUri)
    local new_filename = tofilename(operation.newUri)
    local has_related_edits = all_files[old_filename] or all_files[new_filename]
    return
      not has_related_edits
      or checked_files[old_filename]
      or checked_files[new_filename]
  elseif operation.kind == "create" then
    local filename = tofilename(operation.uri)
    return not all_files[filename] or checked_files[filename]
  end

  return true
end

---Get the current display status for a resource operation.
---@param operation lsp.protocol.WorkspaceEditDocumentChange
---@return string
function RenameSymbol:resource_operation_status(operation)
  if self.failed_resource_operation == operation then
    return "Failed"
  elseif self.applied_resource_operations[operation] then
    return "Applied"
  elseif not self:resource_operation_will_apply(operation) then
    return "Skipped"
  end
  return "Pending"
end

---Build a listbox row for a resource operation.
---@param operation lsp.protocol.WorkspaceEditDocumentChange
---@return table
function RenameSymbol:resource_operation_row(operation)
  local kind, path, target = operation_label(operation)
  local status = self:resource_operation_status(operation)
  return {
    operation_color(operation),
    kind,
    ListBox.COLEND,
    style.text,
    path,
    ListBox.COLEND,
    target ~= "" and style.syntax.literal or style.dim,
    target,
    ListBox.COLEND,
    operation_status_color(status),
    status
  }
end

---Refresh resource operation preview rows.
function RenameSymbol:update_resource_operation_rows()
  if not self.resource_list then return end
  for _, operation in ipairs(self.resource_operations) do
    local row = self.resource_operation_rows[operation]
    if row then
      self.resource_list:set_row(row, self:resource_operation_row(operation))
    end
  end
  core.redraw = true
end

---Filter resource operations based on checked text edits.
---@param operations lsp.protocol.WorkspaceEditDocumentChange[]
---@return lsp.protocol.WorkspaceEditDocumentChange[]
function RenameSymbol:filter_resource_operations(operations)
  local filtered = {}

  for _, operation in ipairs(operations) do
    if self:resource_operation_will_apply(operation) then
      table.insert(filtered, operation)
    end
  end

  return filtered
end

---Starts the replacement procedure and worker threads using
---previously matched results.
function RenameSymbol:begin_replace()
  core.add_thread(function()
    RenameSymbol.renaming = true
    self.total_files_processed = 0
    self.resource_operations_processed = 0
    self.resource_operations_failed = false
    self.applied_resource_operations = {}
    self.failed_resource_operation = nil
    self:update_resource_operation_rows()
    local workers = self.list.total_files > 0
      and math.min(math.ceil(thread.get_cpu_count() / 2) + 1, self.list.total_files)
      or 0

    ---@type thread.Thread[]
    local threads = {}
    ---@type thread.Channel[]
    local file_channels = {}
    ---@type thread.Channel[]
    local status_channels = {}

    if workers > 0 then
      -- create all threads and channels
      for id=1, workers, 1 do
        table.insert(
          file_channels,
          thread.get_channel("lsp_symbol_rename"..id)
        )
        table.insert(
          status_channels,
          thread.get_channel("lsp_symbol_rename_status"..id)
        )
        table.insert(
          threads,
          thread.create(
            "lspsrpool"..id, symbols_rename_thread, id, self.replacement
          )
        )
      end

      -- populate all replace channels by distributing the load
      local next_file_channel = 1
      for i, file in self.list:each_file() do
        file_channels[next_file_channel]:push({i, file})
        next_file_channel = next_file_channel + 1
        if next_file_channel > workers then
          next_file_channel = 1
        end
        if i % 100 == 0 then
          coroutine.yield()
          core.redraw = true
        end
      end

      -- send stop command to all threads
      for _, chan in ipairs(file_channels) do
        chan:push("{{stop}}")
      end

      -- wait for all worker threads to finish
      local c = 0
      while #status_channels > 0 do
        for i=1, #status_channels do
          local value
          repeat
            value = status_channels[i]:first()
            if value == "{{done}}" then
              status_channels[i]:clear()
              table.remove(status_channels, i)
              goto outside
            elseif type(value) == "number" then
              self.total_files_processed = self.total_files_processed + 1
              status_channels[i]:pop()
              self.list:apply_replacement(value)
              local item = self.list.items[value]
              for _, doc in ipairs(core.docs) do
                if doc.abs_filename and item.file.path == doc.abs_filename then
                  doc:reload()
                end
              end
              core.redraw = true
            end
            if c % 100 == 0 then coroutine.yield() end
            c = c + 1
          until not value
          core.redraw = true
        end
        ::outside::
        c = c + 1
        core.redraw = true
        if c % 100 == 0 then coroutine.yield() end
      end
    end

    if #self.resource_operations > 0 then
      for index, operation in ipairs(self.resource_operations) do
        if not self:resource_operation_will_apply(operation) then
          goto continue
        end
        if not workspaceedit.apply_resource_operation(operation) then
          self.resource_operations_failed = true
          self.failed_resource_operation = operation
          self:update_resource_operation_rows()
          core.error("[LSP] Could not apply rename file operation.")
          break
        end
        self.resource_operations_processed = self.resource_operations_processed + 1
        self.applied_resource_operations[operation] = true
        self:update_resource_operation_rows()
        ::continue::
        if index % 10 == 0 then coroutine.yield() end
      end
    end

    self.renamed = true
    self.list.replacement = nil
    RenameSymbol.renaming = false
  end)
end

---Converts a utf-16 column position into the equivalent utf-8 position.
---@param line string
---@param column integer
---@return integer col_position
function RenameSymbol:utf16_to_utf8(line, column)
  local line_len = line and #line or 0
  local line_ulen = line and utf8extra.len(line) or 0
  column = common.clamp(column, 1, line_len > 0 and line_len or 1)
  -- no need for conversion so return column as is
  if line_len == line_ulen then return column end
  if column > 1 then
    local col = 1
    local utf8_pos = 1
    for pos, code in utf8extra.next, line do
      if col >= column then
        return pos
      end
      utf8_pos = pos
      if code < 0x010000 then
        col = col + 1
      else
        col = col + 2
      end
    end
    return utf8_pos
  end
  return column
end

---Opens a DocView of the user selected match.
function RenameSymbol:open_selected()
  local item = self.list:get_selected()
  if not item or not item.position then return end
  core.try(function()
    local dv = core.root_view:open_doc(core.open_doc(item.parent.file.path))
    core.root_view.root_node:update_layout()
    local l, c1, c2 = item.line.line, item.position.col1, item.position.col2+1
    dv.doc:set_selection(l, c2, l, c1)
    dv:scroll_to_line(l, false, true)
  end)
  return true
end

function RenameSymbol:update()
  if not RenameSymbol.super.update(self) then return end
  -- update the positions and sizes
  self.background_color = style.background
  self.title:set_position(style.padding.x, style.padding.y)
  if self.calculating then
    self.title:set_label(
      "Calculating renames: "
      .. self.list.total_files
      .. " file(s)"
      .. operation_count_suffix(#self.resource_operations)
    )
  elseif RenameSymbol.renaming then
    local label = "Performing rename: "
      .. self.total_files_processed
      .. " of "
      .. self.list.total_files
      .. " file(s)"
    if #self.resource_operations > 0 then
      label = label
        .. ", "
        .. self.resource_operations_processed
        .. " of "
        .. tostring(#self.resource_operations)
        .. " file operation(s)"
    end
    self.title:set_label(label)
  elseif self.renamed then
    local label = "Renamed in "
      .. self.total_files_processed
      .. " of "
      .. self.list.total_files
      .. " file(s)"
    if #self.resource_operations > 0 then
      label = label
        .. ", "
        .. self.resource_operations_processed
        .. " of "
        .. tostring(#self.resource_operations)
        .. " file operation(s)"
    end
    self.title:set_label(label)
  else
    self.title:set_label(
      "Found "
      .. self.list.total_results
      .. " candidates in "
      .. self.list.total_files
      .. " file(s)"
      .. operation_count_suffix(#self.resource_operations)
    )
  end
  self.line:set_position(0, self.title:get_bottom() + 10)
  local list_top = self.line:get_bottom() + 10
  if self.resource_list then
    local resource_height = math.min(
      self.resource_list:get_scrollable_size() * SCALE,
      130 * SCALE
    )
    self.resource_list:set_position(0, list_top)
    self.resource_list:set_size(self:get_width(), resource_height)
    list_top = self.resource_list:get_bottom() + 10
  end
  self.list:set_position(0, list_top)
  self.list:set_size(
    self:get_width(),
    math.max(0, self:get_height() - list_top)
  )

  if self.apply_button and not self.calculating then
    self.apply_button:show()
    self.apply_button:set_position(
      self.list:get_right() - self.apply_button:get_width() - style.padding.x,
      self.list:get_position().y
    )
  elseif self.apply_button and RenameSymbol.renaming then
    self:remove_child(self.apply_button)
    self.apply_button = nil
  end
end

--
-- Register commands and Key bindings for the RenameSymbol widget view
--
command.add(RenameSymbol, {
  ["lsp-symbol-rename:select-previous"] = function(view)
    view.list:select_prev()
  end,

  ["lsp-symbol-rename:select-next"] = function(view)
    view.list:select_next()
  end,

  ["lsp-symbol-rename:toggle-expand"] = function(view)
    view.list:toggle_expand(view.list.selected)
  end,

  ["lsp-symbol-rename:toggle-checkbox"] = function(view)
    view.list:toggle_check(view.list.selected)
    view:update_resource_operation_rows()
  end,

  ["lsp-symbol-rename:open-selected"] = function(view)
    view:open_selected()
  end,

  ["lsp-symbol-rename:move-to-previous-page"] = function(view)
    view.list.scroll.to.y = view.list.scroll.to.y - view.list.size.y
  end,

  ["lsp-symbol-rename:move-to-next-page"] = function(view)
    view.list.scroll.to.y = view.list.scroll.to.y + view.list.size.y
  end,

  ["lsp-symbol-rename:move-to-start-of-doc"] = function(view)
    view.list.scroll.to.y = 0
  end,

  ["lsp-symbol-rename:move-to-end-of-doc"] = function(view)
    view.list.scroll.to.y = view.list:get_scrollable_size()
  end
})

keymap.add {
  ["up"]                 = "lsp-symbol-rename:select-previous",
  ["down"]               = "lsp-symbol-rename:select-next",
  ["left"]               = "lsp-symbol-rename:toggle-expand",
  ["right"]              = "lsp-symbol-rename:toggle-expand",
  ["space"]              = "lsp-symbol-rename:toggle-checkbox",
  ["return"]             = "lsp-symbol-rename:open-selected",
  ["pageup"]             = "lsp-symbol-rename:move-to-previous-page",
  ["pagedown"]           = "lsp-symbol-rename:move-to-next-page",
  ["ctrl+home"]          = "lsp-symbol-rename:move-to-start-of-doc",
  ["ctrl+end"]           = "lsp-symbol-rename:move-to-end-of-doc",
  ["home"]               = "lsp-symbol-rename:move-to-start-of-doc",
  ["end"]                = "lsp-symbol-rename:move-to-end-of-doc"
}


return RenameSymbol
