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
local Widget = require "widget"
local Button = require "widget.button"
local Label = require "widget.label"
local Line = require "widget.line"
local MessageBox = require "widget.messagebox"
local SearchReplaceList = require "widget.searchreplacelist"

---@class lsp.ui.renamesymbol : widget
---@field public calculating boolean
---@field private title widget.label
---@field private line widget.line
---@field private list widget.searchreplacelist
---@overload fun():lsp.ui.renamesymbol
local RenameSymbol = Widget:extend()

---Indicates if a rename procedure is taking place.
---@type boolean
RenameSymbol.renaming = false

---Constructor
---@param workspace_edit lsp.protocol.WorkspaceEdit
function RenameSymbol:new(workspace_edit)
  RenameSymbol.super.new(self)

  self.name = "Symbol Rename"
  self.defer_draw = false

  self.calculating = true
  self.renamed = false
  self.total_files_processed = 0
  self.replacement = nil
  self.title = Label(self, "")
  self.line = Line(self, 2, style.padding.x)

  self.list = SearchReplaceList(self, "")
  self.list.base_dir = core.root_project().path
  self.list.border.width = 0
  self.list.on_item_click = function(this, item, clicks)
    self:open_selected()
  end

  self.apply_button = Button(self, "Apply Rename")
  self.apply_button:hide()
  self.apply_button.on_click = function(this, button, x, y)
    MessageBox.warning(
      "Apply Rename",
      {
        "This process will modify all selected file locations and\n"
        .. "reload opened documents where rename is also performed.\n"
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
    for file_uri, changes in pairs(workspace_edit.changes) do
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

        if results.lines[1] and results.lines[1].line == ln then
          local offset = 0

          for _, pos in ipairs(results.lines[1].positions) do
            local col1 = pos.col1 + offset
            local col2 = pos.col2 + offset

            if pos.checked or type(pos.checked) == "nil" then
              line = replace_substring(line, col1, col2, replacement)
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

        table.insert(lines, line)
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

---Starts the replacement procedure and worker threads using
---previously matched results.
function RenameSymbol:begin_replace()
  core.add_thread(function()
    RenameSymbol.renaming = true
    self.total_files_processed = 0
    local workers = math.min(
      math.ceil(thread.get_cpu_count() / 2) + 1,
      self.list.total_files
    )

    ---@type thread.Thread[]
    local threads = {}
    ---@type thread.Channel[]
    local file_channels = {}
    ---@type thread.Channel[]
    local status_channels = {}

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
      "Calculating renames: " .. self.list.total_files .. " file(s)"
    )
  elseif RenameSymbol.renaming then
    self.title:set_label(
      "Performing rename: "
      .. self.total_files_processed
      .. " of "
      .. self.list.total_files
      .. " file(s)"
    )
  elseif self.renamed then
    self.title:set_label(
      "Renamed in "
      .. self.total_files_processed
      .. " of "
      .. self.list.total_files
      .. " file(s)"
    )
  else
    self.title:set_label(
      "Found "
      .. self.list.total_results
      .. " candidates in "
      .. self.list.total_files
      .. " file(s)"
    )
  end
  self.line:set_position(0, self.title:get_bottom() + 10)
  self.list:set_position(0, self.line:get_bottom() + 10)
  self.list:set_size(
    self:get_width(),
    self:get_height() - self.line:get_position().y
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
