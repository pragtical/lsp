-- A configurable listbox that can be used as tooltip, selection box and
-- selection box with fuzzy search, this may change in the future.
--
-- @note This code is a readaptation of autocomplete plugin from rxi :)
--
-- TODO implement select box with fuzzy search

local core = require "core"
local common = require "core.common"
local command = require "core.command"
local config = require "core.config"
local style = require "core.style"
local keymap = require "core.keymap"
local util = require "plugins.lsp.util"
local MarkdownView = require "core.markdownview"
local RootView = require "core.rootview"
local View = require "core.view"
local DocView = require "core.docview"

---@class lsp.listbox.item
---@field text string
---@field info string
---@field on_draw fun(item:lsp.listbox.item, x:number, y:number, calc_only?:boolean):number

---@alias lsp.listbox.callback fun(doc: core.doc, item: lsp.listbox.item)

---@class lsp.listbox.signature_param
---@field label string

---@class lsp.listbox.signature
---@field label string
---@field activeParameter? integer
---@field activeSignature? integer
---@field parameters lsp.listbox.signature_param[]

---@class lsp.listbox.signature_list
---@field activeParameter? integer
---@field activeSignature? integer
---@field signatures lsp.listbox.signature[]

---@class lsp.listbox.position
---@field line integer
---@field col integer

---@class lsp.listbox
local listbox = {}

---@class lsp.listbox.settings
---@field items lsp.listbox.item[]
---@field shown_items lsp.listbox.item[]
---@field selected_item_idx integer
---@field first_visible_idx integer First row in the list viewport
---@field wheel_delta number Accumulated fractional wheel movement
---@field show_items_count boolean
---@field max_height integer
---@field active_view core.docview | nil
---@field line integer | nil
---@field col integer | nil
---@field last_line integer | nil
---@field last_col integer | nil
---@field callback lsp.listbox.callback | nil
---@field is_list boolean
---@field has_fuzzy_search boolean
---@field above_text boolean
local settings = {
  items = {},
  shown_items = {},
  selected_item_idx = 1,
  first_visible_idx = 1,
  wheel_delta = 0,
  show_items_count = false,
  max_height = 6,
  active_view = nil,
  line = nil,
  col = nil,
  last_line = nil,
  last_col = nil,
  callback = nil,
  is_list = false,
  has_fuzzy_search = false,
  above_text = false,
}

local mt = { __tostring = function(t) return t.text end }
local markdown_view
local markdown_rect
local popup, sync_popup

--------------------------------------------------------------------------------
-- Private functions
--------------------------------------------------------------------------------

local function point_over_rect(x, y, rect)
  return rect
    and x >= rect.x and y >= rect.y
    and x <= rect.x + rect.w and y <= rect.y + rect.h
end

---@return core.docview | nil
local function get_active_view()
  if getmetatable(core.active_view) == DocView then
    return core.active_view
  end
end

local function get_anchor_position(active_view)
  local line, col
  if settings.line then
    line, col = settings.line, settings.col
  else
    line, col = active_view.doc:get_selection()
  end

  -- Validate line against current view because there can be cases
  -- when user rapidly switches between tabs causing the deferred draw
  -- to be called late and the current document view already changed.
  if line > #active_view.doc.lines then
    listbox.hide()
    return
  end

  local x, y = active_view:get_line_screen_position(line, col)

  if settings.above_text and line > 1 then
    y = y - active_view:get_line_height() - style.padding.y
  else
    y = y + active_view:get_line_height() + style.padding.y
  end

  return x, y
end

---@param active_view core.docview
---@return number x
---@return number y
---@return number width
---@return number height
local function get_suggestions_rect(active_view)
  if #settings.shown_items == 0 then
    listbox.hide()
    return 0, 0, 0, 0
  end

  local x, y = get_anchor_position(active_view)
  if not x then
    return 0, 0, 0, 0
  end
  local padding_x = style.padding.x
  local padding_y = style.padding.y

  local font = settings.is_list and active_view:get_font() or style.font
  local text_height = font:get_height()

  local max_width = 0
  for _, item in ipairs(settings.shown_items) do
    local w = 0
    if item.on_draw then
      w = item.on_draw(item, 0, 0, true)
    else
      w = font:get_width(item.text)
      if item.info then
        w = w + style.font:get_width(item.info) + style.padding.x
      end
    end
    max_width = math.max(max_width, w)
  end

  local max_items = #settings.shown_items
  if settings.is_list and max_items > settings.max_height then
    max_items = settings.max_height
  end

  -- additional line to display total items
  if settings.show_items_count then
    max_items = max_items + 1
  end

  if max_width < 150 then
    max_width = 150
  end

  local height = max_items * (text_height + (padding_y/4)) + (padding_y*2)
  local width = max_width + padding_x * 2

  x = x - padding_x
  y = y - padding_y

  local win_w = system.get_window_size(core.window)
  if (width/win_w*100) >= 85 and (width+style.padding.x*4) < win_w then
    x = win_w - width - style.padding.x*2
  elseif width > (win_w - x) then
    x = x - (width - (win_w - x))
    if x < 0 then
      x = 0
    end
  end

  if View.set_floating then
    x, y, width, height = core.root_view:clamp_floating_bounds(x, y, width, height)
  end
  return x, y, width, height
end

---Count complete rows and clamp the first row after viewport size changes.
---Excludes padding and the optional count footer.
---@param height number Popup height
---@param line_height number Row height
---@return integer count Visible row count
local function get_visible_rows(height, line_height)
  local available = height - style.padding.y * 2
  if settings.show_items_count then available = available - line_height end
  local limit = settings.is_list and settings.max_height or #settings.shown_items
  local rows = math.max(0, math.min(limit, #settings.shown_items,
    math.floor(available / line_height + 0.001)))
  if settings.is_list then
    settings.first_visible_idx = math.min(settings.first_visible_idx,
      math.max(1, #settings.shown_items - rows + 1))
  end
  return rows
end

---Select a result and keep keyboard navigation inside the current viewport.
---@param index integer Result index, clamped to the available results
local function select_item(index)
  local av = settings.active_view
  if not av or #settings.shown_items == 0 then return end
  settings.selected_item_idx = common.clamp(index, 1, #settings.shown_items)
  local _, _, _, height = get_suggestions_rect(av)
  local rows = math.max(1, get_visible_rows(height,
    av:get_font():get_height() + style.padding.y / 4))
  if settings.selected_item_idx < settings.first_visible_idx then
    settings.first_visible_idx = settings.selected_item_idx
  elseif settings.selected_item_idx >= settings.first_visible_idx + rows then
    settings.first_visible_idx = settings.selected_item_idx - rows + 1
  end
  settings.wheel_delta = 0
  core.redraw = true
end

---Hit-test selectable rows, excluding the popup's padding and optional count footer.
---@param x number Screen x coordinate
---@param y number Screen y coordinate
---@return integer? index Result under the pointer
local function get_item_at(x, y)
  local av = settings.active_view
  if not av or not settings.is_list or markdown_view then return end
  local rx, ry, rw, rh = get_suggestions_rect(av)
  local line_height = av:get_font():get_height() + style.padding.y / 4
  local rows = get_visible_rows(rh, line_height)
  local row = math.floor((y - ry - style.padding.y) / line_height)
  if x >= rx and x < rx + rw and row >= 0 and row < rows then
    return settings.first_visible_idx + row
  end
end

---Accept a clicked result through the same command and callback as keyboard selection.
---@param button core.view.mousebutton Pressed mouse button
---@param x number Screen x coordinate
---@param y number Screen y coordinate
---@return boolean handled Whether a result was accepted
local function list_mouse_pressed(button, x, y)
  if button ~= "left" then return false end
  local index = get_item_at(x, y)
  if not index then return false end
  select_item(index)
  command.perform "listbox:select"
  return true
end

---Highlight a hovered result without moving the document caret or editor focus.
---@param x number Screen x coordinate
---@param y number Screen y coordinate
---@return boolean handled Whether the pointer is over a selectable row
local function list_mouse_moved(x, y)
  local index = get_item_at(x, y)
  if not index then return false end
  if index ~= settings.selected_item_idx then select_item(index) end
  core.request_cursor("arrow")
  return true
end

---Scroll list rows independently of the selected result, retaining fractional deltas.
---@param delta number Vertical wheel delta
---@return boolean handled Whether a result list is active
local function list_mouse_wheel(delta)
  local av = settings.active_view
  if not av or not settings.is_list or markdown_view then return false end
  local _, _, _, height = get_suggestions_rect(av)
  local rows = math.max(1, get_visible_rows(height,
    av:get_font():get_height() + style.padding.y / 4))
  settings.wheel_delta = settings.wheel_delta - delta
  local steps = math.modf(settings.wheel_delta)
  settings.wheel_delta = settings.wheel_delta - steps
  settings.first_visible_idx = common.clamp(settings.first_visible_idx + steps,
    1, math.max(1, #settings.shown_items - rows + 1))
  core.redraw = true
  return true
end

---Measure and position LSP Markdown near its document anchor.
---Shows a floating MarkdownView on modern cores or draws it directly on legacy cores.
---@param av core.docview Document containing the popup anchor
local function position_markdown_box(av)
  if not markdown_view then
    return
  end

  local x, y = get_anchor_position(av)
  if not x then
    return
  end

  local win_w, win_h = system.get_window_size(core.window)
  local width = math.min(math.max(360 * SCALE, win_w * 0.45), win_w - x - style.padding.x * 2)
  if width < 180 * SCALE then
    width = win_w - style.padding.x * 4
    x = style.padding.x * 2
  end
  local _, content_height = markdown_view:get_rendered_size(width)
  local available_height = win_h - y - style.padding.y
  local height = math.min(content_height, math.max(available_height, 1), math.max(120 * SCALE, win_h * 0.55))

  if View.set_floating then
    markdown_view:set_floating_bounds(x, y, width, height)
    if not markdown_view.floating_visible then markdown_view:show_floating() end
  else markdown_view:draw_at(x, y, width, height, style.background3, true) end
  markdown_rect = { x = x, y = y, w = width, h = height }
end

---@param av core.docview
local function draw_listbox(av)
  if #settings.shown_items <= 0 then
    return
  end

  -- draw background rect
  local rx, ry, rw, rh = get_suggestions_rect(av)

  -- draw border
  if not settings.is_list then
    local border_width = 1
    renderer.draw_rect(
      rx - border_width,
      ry - border_width,
      rw + (border_width * 2),
      rh + (border_width * 2),
      style.divider
    )
  end

  renderer.draw_rect(rx, ry, rw, rh, style.background3)

  local padding_x = style.padding.x
  local padding_y = style.padding.y

  -- draw text
  local font = settings.is_list and av:get_font() or style.font
  local line_height = font:get_height() + (padding_y / 4)
  local y = ry + padding_y

  local show_count = get_visible_rows(rh, line_height)
  local start_index = settings.is_list and settings.first_visible_idx or 1

  for i=start_index, start_index+show_count-1, 1 do
    if not settings.shown_items[i] then
      break
    end

    local item = settings.shown_items[i]

    if item.on_draw then
      item.on_draw(item, rx + padding_x, y)
    else
      local color = (i == settings.selected_item_idx and settings.is_list) and
        style.accent or style.text

      common.draw_text(
        font, color, item.text, "left",
        rx + padding_x, y, rw, line_height
      )

      if item.info then
        color = (i == settings.selected_item_idx and settings.is_list) and
          style.text or style.dim

        common.draw_text(
          style.font, color, item.info, "right",
          rx, y, rw - padding_x, line_height
        )
      end
    end
    y = y + line_height
  end

  if settings.show_items_count then
    renderer.draw_rect(rx, y, rw, 2, style.caret)
    renderer.draw_rect(rx, y+2, rw, line_height, style.background)
    common.draw_text(
      style.font,
      style.accent,
      "Items",
      "left",
      rx + padding_x, y, rw, line_height
    )
    common.draw_text(
      style.font,
      style.accent,
      tostring(settings.selected_item_idx) .. "/" .. tostring(#settings.shown_items),
      "right",
      rx, y, rw - padding_x, line_height
    )
  end
end

---Set the document position where the listbox will be draw.
---@param position? lsp.listbox.position
local function set_position(position)
  if type(position) == "table" then
    settings.line = position.line
    settings.col = position.col
  else
    settings.line = nil
    settings.col = nil
  end
end

--------------------------------------------------------------------------------
-- Public functions
--------------------------------------------------------------------------------

---@param elements lsp.listbox.item[]
function listbox.add(elements)
  if type(elements) == "table" and #elements > 0 then
    local items = {}
    for _, element in pairs(elements) do
      table.insert(items, setmetatable(element, mt))
    end
    settings.items = items
  end
end

function listbox.clear()
  if popup then popup:hide_floating() end
  if markdown_view and markdown_view.hide_floating then markdown_view:hide_floating() end
  settings.items = {}
  settings.selected_item_idx = 1
  settings.first_visible_idx, settings.wheel_delta = 1, 0
  settings.shown_items = {}
  settings.line = nil
  settings.col = nil
  markdown_view = nil
  markdown_rect = nil
end

---@param element lsp.listbox.item
function listbox.append(element)
  table.insert(settings.items, setmetatable(element, mt))
end

function listbox.hide()
  settings.active_view = nil
  if popup then popup:hide_floating() end
  if markdown_view and markdown_view.hide_floating then markdown_view:hide_floating() end
  settings.active_view = nil
  settings.line = nil
  settings.col = nil
  settings.selected_item_idx = 1
  settings.first_visible_idx, settings.wheel_delta = 1, 0
  settings.shown_items = {}
  markdown_view = nil
  markdown_rect = nil
  core.redraw = true
end

---@param is_list? boolean
---@param position? lsp.listbox.position
function listbox.show(is_list, position)
  if markdown_view and markdown_view.hide_floating then markdown_view:hide_floating() end
  markdown_view, markdown_rect = nil, nil
  set_position(position)
  settings.selected_item_idx, settings.first_visible_idx, settings.wheel_delta = 1, 1, 0

  local active_view = get_active_view()
  if active_view then
    settings.active_view = active_view
    settings.last_line, settings.last_col = active_view.doc:get_selection()
    if settings.items and #settings.items > 0 then
      settings.is_list = is_list or false
      settings.shown_items = settings.items
    end
    if sync_popup then sync_popup() end
    core.redraw = true
  end
end

---@param text string
---@param position? lsp.listbox.position
function listbox.show_text(text, position)
  if markdown_view and markdown_view.hide_floating then markdown_view:hide_floating() end
  markdown_view = nil
  markdown_rect = nil
  if text and type("text") == "string" then
    local win_w = system.get_window_size(core.window) - style.padding.x * 6
    text = util.wrap_text(text, style.font, win_w)

    local items = {}
    for result in string.gmatch(text.."\n", "(.-)\n") do
      table.insert(items, {text = result})
    end
    listbox.add(items)
  end

  listbox.show(false, position)
end

---@param text string
---@param position? lsp.listbox.position
function listbox.show_markdown(text, position)
  listbox.clear()
  if text and type(text) == "string" and #text > 0 then
    markdown_view = MarkdownView({
      text = text,
      title = "LSP Documentation"
    })
  end

  set_position(position)

  local active_view = get_active_view()
  if active_view and markdown_view then
    settings.active_view = active_view
    settings.last_line, settings.last_col = active_view.doc:get_selection()
    if View.set_floating then
      markdown_view:set_floating(true, { owner = popup, focus = "none" })
      ---Render LSP Markdown inside its current floating bounds with the popup background.
      ---@param view core.markdownview Documentation popup
      markdown_view.draw = function(view)
        view:draw_at(view.position.x, view.position.y, view.size.x, view.size.y, style.background3, true)
      end
      ---Scroll LSP documentation, treating Shift+wheel as horizontal movement.
      ---@param view core.markdownview Documentation popup
      ---@param y number Vertical wheel delta
      ---@param x? number Horizontal wheel delta
      ---@return boolean consumed Always true
      markdown_view.on_mouse_wheel = function(view, y, x)
        if keymap.modkeys.shift then x, y = y, 0 end
        view.scroll.to.y = view.scroll.to.y - (y or 0) * config.mouse_wheel_scroll
        view.scroll.to.x = view.scroll.to.x - (x or 0) * config.mouse_wheel_scroll
        core.redraw = true
        return true
      end
      sync_popup()
    end
    core.redraw = true
  end
end

---@param items lsp.listbox.item[]
---@param callback lsp.listbox.callback
---@param position? lsp.listbox.position
function listbox.show_list(items, callback, position)
  listbox.add(items)

  if callback then
    settings.callback = callback
  end

  listbox.show(true, position)
end

---@param signatures lsp.listbox.signature_list
---@param position? lsp.listbox.position
function listbox.show_signatures(signatures, position)
  local active_parameter = nil
  local active_signature = nil

  if signatures.activeParameter then
    active_parameter = signatures.activeParameter + 1
  end

  if signatures.activeSignature then
    active_signature = signatures.activeSignature + 1
  end

  local signatures_count = #signatures.signatures

  local items = {}
  for index, signature in ipairs(signatures.signatures) do
    table.insert(items, {
      text = signature.label,
      signature = signature,
      on_draw = function(item, x, y, calc_only)
        local width = 0
        local height = style.font:get_height()

        if item.signature.parameters then
          if signatures_count > 1 then
            if index == active_signature then
              width = style.font:get_width("> ")
            else
              width = style.font:get_width("> ")
              x = x + style.font:get_width("> ")
            end
          end

          width = width
            + style.font:get_width("(")
            + style.font:get_width(")")

          if not calc_only then
            if signatures_count > 1 and index == active_signature then
              x = renderer.draw_text(style.font, "> ", x, y, style.caret)
            end
            x = renderer.draw_text(style.font, "(", x, y, style.text)
          end

          local params_count = #item.signature.parameters
          for pindex, param in ipairs(item.signature.parameters) do
            local label = ""
            if type(param.label) == "table" then
              label = signature.label:sub(param.label[1]+1, param.label[2])
            else
              label = param.label
            end
            if label and pindex ~= params_count then
              label = label .. ", "
            end
            width = width + style.font:get_width(label)
            if not calc_only then
              local color = style.text
              if
                (
                  signature.activeParameter
                  and
                  (signature.activeParameter + 1) == pindex
                )
                or
                (index == active_signature and active_parameter == pindex)
              then
                color = style.accent
              end
              x = renderer.draw_text(
                style.font,
                label,
                x, y,
                color
              )
            end
          end

          if not calc_only then
            renderer.draw_text(style.font, ")", x, y, style.text)
          end
        else
          width = style.font:get_width(item.signature.label)
          if not calc_only then
            renderer.draw_text(
              style.font,
              item.signature.label,
              x, y,
              style.text
            )
          end
        end
        return width, width > 0 and height or 0
      end
    })
  end

  listbox.add(items)

  listbox.show(false, position)
end

function listbox.toggle_above(enable)
  if enable then
    settings.above_text = true
  else
    settings.above_text = false
  end
end

--------------------------------------------------------------------------------
-- Patch event logic into RootView
--------------------------------------------------------------------------------
if View.set_floating then
  popup = View()
  ---Clear listbox state when its floating owner disappears or RootView removes it.
  ---@param _ core.view Listbox companion
  ---@param visible boolean Whether the popup remains shown
  popup.on_floating_visibility_changed = function(_, visible)
    if not visible and settings.active_view then listbox.hide() end
  end
  popup:set_floating(true, { focus = "none", interactive = false })
  ---Compute list bounds, or an empty ownership rectangle while Markdown is shown.
  ---@return number x Screen x coordinate
  ---@return number y Screen y coordinate
  ---@return number w List width, or zero for Markdown-only display
  ---@return number h List height, or zero for Markdown-only display
  popup.get_floating_bounds = function()
    local av = settings.active_view
    if av and not markdown_view then return get_suggestions_rect(av) end
    return 0, 0, 0, 0
  end
  ---Ignore placement writes because this companion computes its bounds from its owner.
  popup.set_floating_bounds = function() end
  ---Close stale LSP results after owner or caret changes and place any Markdown popup.
  popup.update = function()
    local av = get_active_view()
    if not av or av ~= settings.active_view then listbox.hide(); return end
    local line, col = av.doc:get_selection()
    if line ~= settings.last_line or col ~= settings.last_col then listbox.hide(); return end
    if markdown_view then position_markdown_box(av) end
  end
  ---Draw list results for the saved document when Markdown is not being shown.
  popup.draw = function()
    if settings.active_view and not markdown_view then draw_listbox(settings.active_view) end
  end
  ---Accept a result while keeping the owning document focused.
  ---@param _ core.view Listbox companion
  ---@param button core.view.mousebutton Pressed mouse button
  ---@param x number Screen x coordinate
  ---@param y number Screen y coordinate
  ---@return boolean handled Whether a result was accepted
  popup.on_mouse_pressed = function(_, button, x, y)
    return list_mouse_pressed(button, x, y)
  end
  ---Highlight the row under the pointer without scrolling the viewport.
  ---@param _ core.view Listbox companion
  ---@param x number Screen x coordinate
  ---@param y number Screen y coordinate
  ---@return boolean handled Whether the pointer is over a row
  popup.on_mouse_moved = function(_, x, y)
    return list_mouse_moved(x, y)
  end
  ---Scroll results without forwarding the wheel to the document.
  ---@param _ core.view Listbox companion
  ---@param y number Vertical wheel delta
  ---@return boolean handled Whether a result list is active
  popup.on_mouse_wheel = function(_, y)
    return list_mouse_wheel(y)
  end
  ---Assign the current editor as owner, show the shared companion, and update it.
  sync_popup = function()
    popup.floating_options.owner = settings.active_view
    popup.floating_options.interactive = settings.is_list and not markdown_view
    if not popup.floating_visible then popup:show_floating() end
    popup:update()
  end
else
local root_view_update = RootView.update
local root_view_draw = RootView.draw
local root_view_on_mouse_pressed = RootView.on_mouse_pressed
local root_view_on_mouse_released = RootView.on_mouse_released
local root_view_on_mouse_moved = RootView.on_mouse_moved
local root_view_on_mouse_wheel = RootView.on_mouse_wheel

RootView.update = function(...)
  root_view_update(...)
  if not settings.active_view then return end

  if markdown_view then
    markdown_view:update()
  end

  local active_view = get_active_view()
  if active_view then
    -- reset suggestions if caret was moved or not same active view
    local line, col = active_view.doc:get_selection()
    if
      settings.active_view ~= active_view
      or
      line ~= settings.last_line or col ~= settings.last_col
    then
      listbox.hide()
    end
  else
    listbox.hide()
  end
end

RootView.draw = function(...)
  if settings.active_view then
    local active_view = get_active_view()
    if
      active_view and settings.active_view == active_view
    then
      if markdown_view then
        core.root_view:defer_draw(position_markdown_box, active_view)
      elseif #settings.shown_items > 0 then
        -- draw suggestions box after everything else
        core.root_view:defer_draw(draw_listbox, active_view)
      end
    end
  end
  root_view_draw(...)
end

RootView.on_mouse_pressed = function(self, button, x, y, clicks)
  if list_mouse_pressed(button, x, y) then return true end
  if markdown_view and point_over_rect(x, y, markdown_rect) then
    if markdown_view:on_mouse_pressed(button, x, y, clicks) then
      return true
    end
  end
  return root_view_on_mouse_pressed(self, button, x, y, clicks)
end

RootView.on_mouse_released = function(self, button, x, y)
  if markdown_view then
    markdown_view:on_mouse_released(button, x, y)
  end
  return root_view_on_mouse_released(self, button, x, y)
end

RootView.on_mouse_moved = function(self, x, y, dx, dy)
  self.mouse.x, self.mouse.y = x, y
  if list_mouse_moved(x, y) then return true end
  if markdown_view and (point_over_rect(x, y, markdown_rect) or markdown_view:scrollbar_dragging()) then
    local handled = markdown_view:on_mouse_moved(x, y, dx, dy)
    if handled then
      core.request_cursor(markdown_view.cursor)
      core.redraw = true
      return true
    end
    local result = root_view_on_mouse_moved(self, x, y, dx, dy)
    core.request_cursor(markdown_view.cursor)
    core.redraw = true
    return result
  elseif markdown_view then
    markdown_view:on_mouse_left()
  end
  return root_view_on_mouse_moved(self, x, y, dx, dy)
end

RootView.on_mouse_wheel = function(self, y, x)
  if settings.active_view and settings.is_list and not markdown_view then
    local rx, ry, rw, rh = get_suggestions_rect(settings.active_view)
    if point_over_rect(self.mouse.x, self.mouse.y, { x = rx, y = ry, w = rw, h = rh }) then
      return list_mouse_wheel(y)
    end
  end
  if markdown_view and point_over_rect(core.root_view.mouse.x, core.root_view.mouse.y, markdown_rect) then
    if keymap.modkeys["shift"] then
      x = y
      y = 0
    end
    if y and y ~= 0 then
      markdown_view.scroll.to.y = markdown_view.scroll.to.y + y * -config.mouse_wheel_scroll
    end
    if x and x ~= 0 then
      markdown_view.scroll.to.x = markdown_view.scroll.to.x + x * -config.mouse_wheel_scroll
    end
    core.redraw = true
    return true
  end
  return root_view_on_mouse_wheel(self, y, x)
end

end

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------
local function predicate()
  local av = get_active_view()
  return av and settings.active_view and (#settings.shown_items > 0 or markdown_view), av
end

command.add(predicate, {
  ["listbox:select"] = function(av)
    ---@cast av core.docview
    if settings.is_list then
      local doc = av.doc
      local item = settings.shown_items[settings.selected_item_idx]

      if settings.callback then
        settings.callback(doc, item)
      end

      listbox.hide()
    end
  end,

  ["listbox:previous"] = function()
    if settings.is_list then
      select_item(settings.selected_item_idx - 1)
    else
      listbox.hide()
    end
  end,

  ["listbox:next"] = function()
    if settings.is_list then
      select_item(settings.selected_item_idx + 1)
    else
      listbox.hide()
    end
  end,

  ["listbox:cancel"] = function()
    listbox.hide()
  end,
})

--------------------------------------------------------------------------------
-- Keymaps
--------------------------------------------------------------------------------
keymap.add {
  ["tab"]    = "listbox:select",
  ["up"]     = "listbox:previous",
  ["down"]   = "listbox:next",
  ["escape"] = "listbox:cancel",
}


return listbox
