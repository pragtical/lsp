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
local CommandView = require "core.commandview"
local SearchUI = require "plugins.search_ui"
local TreeList = require "widget.treelist"

local Lsp = nil

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

---@class lsp.ui.symbolstree : widget.treelist
---@field current_doc? core.doc
---@field last_change_id? integer
---@overload fun():lsp.ui.symbolstree
local SymbolsTree = TreeList:extend()

---Constructor
function SymbolsTree:new()
  SymbolsTree.super.new(self)

  self.current_docview = nil
  self.current_doc = nil
  self.last_change_id = nil
  self.auto_hide = false
  self.symbols_loaded = false

  self.name = "Document Symbols"
  self.defer_draw = false

  self.border.width = 0
  self:set_size(200)
  self:show()

  self:set_icon_font(
    renderer.font.load(
      USERDIR .. "/plugins/lsp/fonts/symbols.ttf",
      style.icon_font:get_size()
    )
  )
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

---Set the tree items with results returned from a textDocument/documentSymbol
---@param results lsp.protocol.DocumentSymbol[] | lsp.protocol.SymbolInformation[]
---@param parent? widget.treelist.item
function SymbolsTree:add_results(results, parent)
  ---@type widget.treelist.item[]
  local items = {}

  for i=1, #results do
    local result = results[i]

    ---@type widget.treelist.item
    local item = {
      name = result.name,
      label = result.name
    }

    item.icon = SYMBOLS_KIND_ICONS[result.kind].icon

    if result.children then
      self:add_results(result.children, item)
    end

    if not parent and #results <= 2 then
      item.expanded = true
    end

    item.data = {
      range = result.selectionRange or result.location.range,
      type = result.kind,
    }

    item.tooltip = SYMBOLS_KIND_ICONS[result.kind].name

    local container = result.containerName
      and self:query_item(result.containerName, parent or items) or nil
    if container then
      container.childs = container.childs or {}
      table.insert(container.childs, item)
    else
      table.insert(items, item)
    end
  end

  if not parent then
    self.items = items
    self.symbols_loaded = true
  else
    parent.childs = items
  end
end

---Retrieve an item by name using the query format:
---"parent_name>child_name_2>child_name_2>etc..."
---@param query string
---@param items? widget.treelist.item[]
---@param separator? string Use a different separator (default: >)
---@return widget.treelist.item?
function SymbolsTree:query_item(query, items, separator)
  local parent = items or self.items
  local item = nil
  separator = separator or ">"
  for name in query:gmatch("([^"..separator.."]+)") do
      if parent then
        local found = false
        for _, child in ipairs(parent) do
          if name == child.name then
            item = child
            parent = child.childs
            found = true
            break
          end
        end
        if not found then return nil end
      else
        return nil
      end
  end
  return item
end

---@param item widget.treelist.item
---@param active boolean
---@param hovered boolean
function SymbolsTree:get_item_icon(item, active, hovered)
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

---Enable or disable auto hiding the tree when no symbols are available.
---@param enable boolean
function SymbolsTree:set_auto_hide(enable)
  if enable and self.auto_hide then return end
  self.auto_hide = enable
  if enable then
    core.add_thread(function()
      while self.auto_hide do
        if not self:is_visible() then
          self.current_doc = nil
          self.last_change_id = nil
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
  item = item or self.selected_item
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

function SymbolsTree:on_item_click(item, button, x, y, clicks)
  if clicks == 1 then
    self:goto_symbol(item)
  end
end

---Update the tree items each time a different docview is focused or
---currently focused related doc is edited.
function SymbolsTree:update_symbols()
  local doc = self:get_active_doc()

  if not doc or not doc.lsp_open then
    if
      doc
      or
      (
        self.current_doc
        and
        #core.get_views_referencing_doc(self.current_doc) == 0
      )
    then
      self.items = {
        {name = "no-symbols", label = "No Symbols Found"}
      }
      self.symbols_loaded = false

      if self.auto_hide then
        self:hide()
      end
    end
    return
  end

  if doc ~= self.current_doc or doc:get_change_id() ~= self.last_change_id then
    if self.current_doc ~= doc then
      self.items = {
        {name = "loading", label = "Loading..."}
      }
    end
    self.current_doc = doc
    self.last_change_id = doc:get_change_id()
  else
    return
  end

  if not Lsp then Lsp = require "plugins.lsp" end

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
          if response.result and response.result and #response.result > 0 then
            self:add_results(response.result)
          end
        end,
        on_expired = function()
          -- retry if request expired without response
          self.current_doc = nil
        end
      })
      break
    end
  end
  if not pushed then
    self.current_doc = nil
  end
end

function SymbolsTree:update()
  SymbolsTree.super.update(self)
  self:update_symbols()
end

--
-- Register commands and Key bindings for the SymbolsTree widget
--
command.add(SymbolsTree, {
  ["lsp-symbols-tree:select-previous"] = function(view)
    view:select_prev()
  end,

  ["lsp-symbols-tree:select-next"] = function(view)
    view:select_next()
  end,

  ["lsp-symbols-tree:toggle-expand"] = function(view)
    view:toggle_expand()
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
