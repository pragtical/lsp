--
-- SymbolsTree Widget/View.
-- @copyright Jefferson Gonzalez
-- @license MIT
--

local core = require "core"
local common = require "core.common"
local command = require "core.command"
local keymap = require "core.keymap"
local style = require "core.style"
local util = require "plugins.lsp.util"
local DocView = require "core.docview"
local Widget = require "widget"
local TextBox = require "widget.textbox"
local TreeList = require "widget.treelist"
local SelectBox = require "widget.selectbox"

local Lsp = nil

---@class lsp.ui.symbolstree.itemdata
---@field range lsp.protocol.Range
---@field type lsp.protocol.SymbolKind
---@field uri? lsp.protocol.DocumentUri

local SYMBOLS_KIND_ICONS = {
  { name = "File",          color = "string",   icon = '' }, -- U+F718
  { name = "Module",        color = "literal",  icon = '' }, -- U+F487
  { name = "Namespace",     color = "literal",  icon = '' }, -- U+EA8B
  { name = "Package",       color = "literal",  icon = '' }, -- U+F487
  { name = "Class",         color = "literal",  icon = 'ﴯ' }, -- U+FD2F
  { name = "Method",        color = "function", icon = '' }, -- U+F6A6
  { name = "Property",      color = "keyword2", icon = 'ﰠ' }, -- U+FC20
  { name = "Field",         color = "keyword2", icon = 'ﰠ' }, -- U+FC20
  { name = "Constructor",   color = "literal",  icon = '' }, -- U+F423
  { name = "Enum",          color = "keyword2", icon = '' }, -- U+F15D
  { name = "Interface",     color = "literal",  icon = '' }, -- U+F0E8
  { name = "Function",      color = "function", icon = '' }, -- U+F794
  { name = "Variable",      color = "keyword2", icon = '' }, -- U+F52A
  { name = "Constant",      color = "number",   icon = '' }, -- U+F8FE
  { name = "String",        color = "string",   icon = '' }, -- U+F77E
  { name = "Number",        color = "number",   icon = '' }, -- U+F89F
  { name = "Boolean",       color = "number",   icon = '' }, -- U+F694
  { name = "Array",         color = "keyword2", icon = 'פּ' }, -- U+FB44
  { name = "Object",        color = "keyword2", icon = '' }, -- U+F0E8
  { name = "Key",           color = "string",   icon = '' }, -- U+F80A
  { name = "Null",          color = "number",   icon = '' }, -- U+EB66
  { name = "EnumMember",    color = "number",   icon = '' }, -- U+F15D
  { name = "Struct",        color = "keyword2", icon = 'פּ' }, -- U+FB44
  { name = "Event",         color = "keyword",  icon = '' }, -- U+F0E7
  { name = "Operator",      color = "operator", icon = '' }, -- U+F694
  { name = "TypeParameter", color = "literal",  icon = '' }  -- U+EA92
}

---@class lsp.ui.symbolstree : widget
---@field current_doc? core.doc
---@field last_change_id? integer
---@field kinds table<string, integer>
---@field filter_kind integer
---@field filter_text string
---@field tree widget.treelist
---@field textbox widget.textbox
---@field selectbox widget.selectbox
---@overload fun():lsp.ui.symbolstree
local SymbolsTree = Widget:extend()

---Constructor
function SymbolsTree:new()
  SymbolsTree.super.new(self, nil, false)

  self.current_docview = nil
  self.current_doc = nil
  self.fetching_docs = {}
  self.last_change_id = nil
  self.auto_hide = false
  self.symbols_loaded = false

  self.name = "Document Symbols"
  self.kinds = {}
  self.filter_kind = 0
  self.filter_text = ""

  self.border.width = 0
  self:set_size(200)
  self:show()

  local that = self

  self.tree = TreeList(self)
  self.tree.border.width = 0
  self.tree:set_icon_font(
    renderer.font.load(
      USERDIR .. "/plugins/lsp/fonts/symbols.ttf",
      style.icon_font:get_size()
    )
  )

  ---@param item widget.treelist.item
  ---@param active boolean
  ---@param hovered boolean
  function self.tree:get_item_icon(item, active, hovered)
    local character = item.icon
    local font = self.icon_font or style.icon_font
    local color = item.data and
      style.syntax[SYMBOLS_KIND_ICONS[item.data.type].color]
      or
      style.text
    if active or hovered then
      color = common.lighten_color(color, 40)
    end
    return character, font, color
  end

  function self.tree:on_item_click(item, button, x, y, clicks)
    if clicks == 1 then
      that:goto_symbol(item)
    end
  end

  self.textbox = TextBox(self, "", "filter")
  function self.textbox:on_change(value)
    that:set_name_filter(value)
  end

  self.selectbox = SelectBox(self, "Types")
  function self.selectbox:on_selected(item_idx, item_data)
    that:set_filter(item_data or 0)
  end
end

---@param self lsp.ui.symbolstree
local function apply_filter(self)
  local filter_text = self.filter_text
  local filter_kind = self.filter_kind
  if filter_kind == 0 and filter_text == "" then
    self.tree:filter()
    return
  end

  self.tree:filter(function(_, item)
    local kind_matches = filter_kind == 0
      or (item.data and item.data.type == filter_kind)
    local text_matches = filter_text == ""
      or system.fuzzy_match(item.label or item.name, filter_text, false)
    return kind_matches and text_matches
  end)
end

---Get currently selected view if it is a docview with a valid file.
---@return core.doc? doc
---@return core.view view
function SymbolsTree:get_active_doc()
  local av = core.active_view
  if getmetatable(av) == DocView and av.doc and av.doc.abs_filename then
    return av.doc, av
  end
  return nil, av
end

---@param results? lsp.protocol.DocumentSymbol[] | lsp.protocol.SymbolInformation[]
local function reset_selectbox(self, results)
  self.selectbox.list:clear()
  self.selectbox:set_label("Types")
  if results and #results > 0 then
    self.selectbox:add_option("All", 0)
  end
  self.selectbox:set_selected(0)
end

---@param self lsp.ui.symbolstree
local function sync_selectbox_selection(self)
  local selected = 0
  for idx = 2, #self.selectbox.list.rows do
    if self.selectbox.list:get_row_data(idx) == self.filter_kind then
      selected = idx - 1
      break
    end
  end
  if self.filter_kind ~= 0 and selected == 0 then
    self.filter_kind = 0
  end
  self.selectbox:set_selected(selected)
end

---@param self lsp.ui.symbolstree
local function add_select_kinds(self)
  if #self.tree.items == 0 then
    reset_selectbox(self)
    return
  end

  reset_selectbox(self, self.tree.items)
  local kinds = {}
  for kind in pairs(self.kinds) do
    table.insert(kinds, kind)
  end
  table.sort(kinds)
  for _, kind in ipairs(kinds) do
    self.selectbox:add_option(kind, self.kinds[kind])
  end
  sync_selectbox_selection(self)
end

---Build tree items from document symbols.
---@param results lsp.protocol.DocumentSymbol[] | lsp.protocol.SymbolInformation[]
---@param top_level? boolean
---@return widget.treelist.item[]
function SymbolsTree:add_results(results, top_level)
  ---@type widget.treelist.item[]
  local items = {}

  for i=1, #results do
    local result = results[i]
    local kind = SYMBOLS_KIND_ICONS[result.kind]
    local childs = result.children and self:add_results(result.children) or nil

    self.kinds[kind.name] = result.kind

    ---@type widget.treelist.item
    local item = {
      name = result.name,
      label = result.name
    }

    item.icon = kind.icon
    if childs and #childs > 0 then
      item.childs = childs
    end

    if top_level and #results <= 2 then
      item.expanded = true
    end

    ---@type lsp.ui.symbolstree.itemdata
    item.data = {
      range = result.selectionRange or result.location.range,
      type = result.kind,
    }
    if result.uri then
      item.data.uri = result.uri
    elseif result.location and result.location.uri then
      item.data.uri = result.location.uri
    end

    item.tooltip = kind.name

    local container = result.containerName
      and self.tree:query_item(result.containerName, items) or nil
    if container then
      container.childs = container.childs or {}
      table.insert(container.childs, item)
    else
      table.insert(items, item)
    end
  end

  return items
end

---@param results? lsp.protocol.DocumentSymbol[] | lsp.protocol.SymbolInformation[]
function SymbolsTree:set_results(results)
  self.kinds = {}

  if not results or #results == 0 then
    self.tree:clear()
    add_select_kinds(self)
    self.symbols_loaded = false
    return
  end

  self.tree.items = self:add_results(results, true)
  self.tree.selected_item = nil
  add_select_kinds(self)
  self:set_filter(self.filter_kind)
  self.symbols_loaded = #self.tree.items > 0
end

---@param kind integer?
function SymbolsTree:set_filter(kind)
  self.filter_kind = kind or 0
  apply_filter(self)
  sync_selectbox_selection(self)
end

---@param text string?
function SymbolsTree:set_name_filter(text)
  self.filter_text = text or ""
  apply_filter(self)
end

function SymbolsTree:clear_current_doc(doc_check)
  if doc_check then
    local active_doc = self:get_active_doc()
    if doc_check ~= active_doc then return end
  end
  self.current_doc = nil
  self.last_change_id = nil
end

---Enable or disable auto hiding the tree when no symbols are available.
---@param enable boolean
function SymbolsTree:set_auto_hide(enable)
  if enable and self.auto_hide then return end
  self.auto_hide = enable
  if enable then
    core.add_thread(function()
      while self.auto_hide do
        if not self:is_visible() then
          self:clear_current_doc()
          self:update_symbols()
          if self.symbols_loaded then
            self:show()
          end
        end
        coroutine.yield(1)
      end
    end)
  end
end

---Jumps to the symbol associated to current or given item.
---@param item? widget.treelist.item
function SymbolsTree:goto_symbol(item)
  item = item or self.tree.selected_item
  if not item or not item.data then return end
  local line1, col1 = util.toselection(item.data.range, self.current_doc)

  core.try(function()
    local dv = core.root_view:open_doc(
      core.open_doc(self.current_doc.abs_filename)
    )
    core.root_view.root_node:update_layout()
    dv.doc:set_selection(line1, col1, line1, col1)
    dv:scroll_to_line(line1, false, true)
  end)
end

---Update the tree items each time a different docview is focused or
---currently focused related doc is edited.
function SymbolsTree:update_symbols()
  local doc = self:get_active_doc()

  if not doc or not doc.lsp_open then
    -- prevent removing symbols for every focused view (eg: TreeView, SearchUI, etc...)
    if
      doc
      or
      (
        self.current_doc
        and
        #core.get_views_referencing_doc(self.current_doc) == 0
      )
    then
      if #self.tree.items < 1 or self.tree.items[1].name ~= "no-symbols" then
        self.tree.items = {
          {name = "no-symbols", label = "No Symbols Found"}
        }
        self.filter_kind = 0
        reset_selectbox(self)
        self.symbols_loaded = false
        self:clear_current_doc()
      end
      if self.auto_hide then
        self:hide()
      end
    end
    return
  elseif self.fetching_docs[doc.abs_filename] then
    return
  end

  if doc ~= self.current_doc or doc:get_change_id() ~= self.last_change_id then
    if doc ~= self.current_doc and doc.lsp_symbols then
      self.current_doc = doc
      self.last_change_id = doc:get_change_id()
      self:set_results(doc.lsp_symbols)
      return
    end
    if self.current_doc ~= doc and not doc.lsp_symbols then
      self.tree.items = {
        {name = "loading", label = "Loading..."}
      }
      self.filter_kind = 0
      reset_selectbox(self)
    end
    self.current_doc = doc
    self.last_change_id = doc:get_change_id()
  else
    return
  end

  if not Lsp then Lsp = require "plugins.lsp" end

  self.fetching_docs[doc.abs_filename] = true

  local last_change_id = self.last_change_id
  core.add_thread(function()
    coroutine.yield(1)
    while last_change_id ~= doc:get_change_id() do
      last_change_id = doc:get_change_id()
      coroutine.yield(1)
    end
    local pushed = false
    for _, name in pairs(Lsp.get_active_servers(doc.filename, true)) do
      local server = Lsp.servers_running[name]
      if server.capabilities.documentSymbolProvider then
        pushed = server:push_request('textDocument/documentSymbol', {
          overwrite = true,
          params = {
            textDocument = {
              uri = util.touri(doc.abs_filename),
            }
          },
          callback = function(server, response)
            local active_doc = self:get_active_doc()
            if response.result and response.result and #response.result > 0 then
              if doc == active_doc then
                self:set_results(response.result)
              end
              doc.lsp_symbols = response.result
            elseif doc == active_doc then
              self.tree.items = {
                {name = "no-symbols", label = "No Symbols Found"}
              }
              self.filter_kind = 0
              reset_selectbox(self)
              self.symbols_loaded = false
            end
            self.fetching_docs[doc.abs_filename] = nil
          end,
          on_expired = function()
            -- retry if request expired without response
            self:clear_current_doc(doc)
            self.fetching_docs[doc.abs_filename] = nil
          end
        })
        break
      end
    end
    if not pushed then
      self:clear_current_doc(doc)
      self.fetching_docs[doc.abs_filename] = nil
    end
  end)
end

function SymbolsTree:update()
  self.textbox:set_size(self:get_width() - self.textbox.border.width * 2)
  self.selectbox:set_size(self:get_width() - self.selectbox.border.width * 2)
  self.textbox:update_size_position()
  self.selectbox:update_size_position()

  local textbox_height = self.textbox:get_height()
  local selectbox_height = self.selectbox:get_height()
  self.tree:set_position(0, 0)
  self.tree:set_size(
    self:get_width(),
    self:get_height() - textbox_height - selectbox_height
  )
  self.textbox:set_position(0, self:get_height() - selectbox_height - textbox_height)
  self.selectbox:set_position(0, self:get_height() - selectbox_height)
  if not SymbolsTree.super.update(self) then return false end
  if self:is_visible() then self:update_symbols() end
  return true
end

--
-- Register commands and Key bindings for the SymbolsTree widget
--
command.add(SymbolsTree, {
  ["lsp-symbols-tree:select-previous"] = function(view)
    view.tree:select_prev()
  end,

  ["lsp-symbols-tree:select-next"] = function(view)
    view.tree:select_next()
  end,

  ["lsp-symbols-tree:toggle-expand"] = function(view)
    view.tree:toggle_expand()
  end,

  ["lsp-symbols-tree:open-selected"] = function(view)
    view:goto_symbol()
  end
})

keymap.add {
  ["up"]                 = "lsp-symbols-tree:select-previous",
  ["down"]               = "lsp-symbols-tree:select-next",
  ["left"]               = "lsp-symbols-tree:toggle-expand",
  ["right"]              = "lsp-symbols-tree:toggle-expand",
  ["return"]             = "lsp-symbols-tree:open-selected"
}


return SymbolsTree
