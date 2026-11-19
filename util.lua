-- Some functions adapted from: https://github.com/orbitalquark/textadept-lsp
-- and others added as needed.
--
-- @copyright Jefferson Gonzalez
-- @license MIT

local core = require "core"
local common = require "core.common"
local config = require "core.config"
local json = require "plugins.lsp.json"

local util = {}

local POSITION_INDEX_MIN_LENGTH = 4096
local POSITION_INDEX_STEP = 2048

---@class lsp.util.positionindex
---@field text string Indexed document line
---@field bytes integer[] Byte columns at character boundaries
---@field units integer[] Corresponding UTF-16 columns
---@field invalid? boolean Whether indexing encountered invalid UTF-8

-- These indexes must survive Doc:clear_cache so edits can retain their prefix.
local position_indexes = setmetatable({}, { __mode = "k" })

---Find the last checkpoint at or before a column in either coordinate space.
---@param offsets integer[]
---@param column integer
---@return integer index
local function find_position(offsets, column)
  local low, high = 1, #offsets
  while low < high do
    local middle = math.floor((low + high + 1) / 2)
    if offsets[middle] <= column then low = middle else high = middle - 1 end
  end
  return low
end

---Get a line's sparse index, rejecting reloads and unreported text changes.
---@param doc core.doc
---@param line integer
---@return lsp.util.positionindex? index Nil for short lines
---@return string text
local function get_position_index(doc, line)
  local text = doc.lines[line] or ""
  local cache = position_indexes[doc]
  if cache and cache.lines ~= doc.lines then
    position_indexes[doc], cache = nil, nil
  end
  if #text < POSITION_INDEX_MIN_LENGTH then
    if cache then cache.entries[line] = nil end
    return nil, text
  end
  if not cache then
    cache = { lines = doc.lines, entries = {} }
    position_indexes[doc] = cache
  end
  local index = cache.entries[line]
  if not index or index.text ~= text then
    index = { text = text, bytes = { 1 }, units = { 1 } }
    cache.entries[line] = index
  end
  return index, text
end

---Extend an index only as far as the requested byte or UTF-16 column.
---Count bounded chunks in native code, including supplementary surrogate pairs.
---@param index lsp.util.positionindex
---@param column integer
---@param to_utf16 boolean Whether the input column is a byte offset
---@return boolean valid
local function extend_position_index(index, column, to_utf16)
  if index.invalid then return false end
  local offsets = to_utf16 and index.bytes or index.units
  local count, text = #index.bytes, index.text
  while offsets[count] < column and index.bytes[count] <= #text do
    local first = index.bytes[count]
    local next_byte = math.min(first + POSITION_INDEX_STEP, #text + 1)
    while next_byte > first and next_byte <= #text and common.is_utf8_cont(text, next_byte) do
      next_byte = next_byte - 1
    end
    if next_byte == first then
      index.invalid = true
      return false
    end
    local chunk = text:sub(first, next_byte - 1)
    local length = utf8extra.len(chunk)
    if not length then
      index.invalid = true
      return false
    end
    local _, supplementary = chunk:gsub("[\240-\244]", "")
    index.bytes[count + 1] = next_byte
    index.units[count + 1] = index.units[count] + length + supplementary
    count = count + 1
  end
  return true
end

---Convert a short line using the original character-boundary rounding rules.
---@param text string
---@param column integer Already clamped to the stored line length
---@param to_utf16 boolean
---@return integer column
local function convert_position_text(text, column, to_utf16)
  if #text == utf8extra.len(text) or column == 1 then return column end
  local units, last_byte = 1, 1
  for pos, code in utf8extra.next, text do
    if (to_utf16 and pos or units) >= column then
      return to_utf16 and units or pos
    end
    units = units + (code < 0x10000 and 1 or 2)
    last_byte = pos
  end
  return to_utf16 and units or last_byte
end

---Convert from the nearest checkpoint, scanning at most one bounded chunk.
---@param doc core.doc
---@param line integer
---@param column integer
---@param to_utf16 boolean
---@return integer column
local function convert_position(doc, line, column, to_utf16)
  local index, text = get_position_index(doc, line)
  column = common.clamp(column, 1, math.max(#text, 1))
  if not index or not extend_position_index(index, column, to_utf16) then
    return convert_position_text(text, column, to_utf16)
  end
  local offsets = to_utf16 and index.bytes or index.units
  local point = find_position(offsets, column)
  local first, units = index.bytes[point], index.units[point]
  if first > #text then
    local last_byte = #text
    while last_byte > 1 and common.is_utf8_cont(text, last_byte) do last_byte = last_byte - 1 end
    return last_byte
  end
  if offsets[point] == column then return to_utf16 and units or first end
  local next_byte, next_units = index.bytes[point + 1], index.units[point + 1]
  if next_units - units == next_byte - first then
    return (to_utf16 and units or first) + column - offsets[point]
  end
  local last_byte = first
  for pos, code in utf8extra.next, text:sub(first, next_byte - 1) do
    local byte = first + pos - 1
    if (to_utf16 and byte or units) >= column then
      return to_utf16 and units or byte
    end
    units = units + (code < 0x10000 and 1 or 2)
    last_byte = byte
  end
  if to_utf16 then return units end
  return next_byte <= #text and next_byte or last_byte
end

---Retain an edited line's unchanged prefix and shift indexes for later lines.
---Call after the raw edit, with its old first line and actual line-count delta.
---Omitting the line clears the entire document's index on reload or close.
---@param doc core.doc
---@param line? integer First changed line
---@param column? integer First changed byte column
---@param old_text? string First line's contents before the edit
---@param line_delta? integer Inserted/negative removed lines; required with line
function util.invalidate_position_cache(doc, line, column, old_text, line_delta)
  local cache = position_indexes[doc]
  if not cache then return end
  if not line or cache.lines ~= doc.lines then
    position_indexes[doc] = nil
    return
  end
  local entries = cache.entries
  if line_delta ~= 0 then
    local shifted = {}
    for row, index in pairs(entries) do
      if row <= line then
        shifted[row] = index
      elseif row > line - math.min(line_delta, 0) then
        shifted[row + line_delta] = index
      end
    end
    entries, cache.entries = shifted, shifted
  end
  local index, text = entries[line], doc.lines[line]
  if index and index.text == old_text and #text >= POSITION_INDEX_MIN_LENGTH then
    local keep = find_position(index.bytes, column)
    for i = #index.bytes, keep + 1, -1 do
      index.bytes[i], index.units[i] = nil, nil
    end
    index.text, index.invalid = text, nil
  else
    entries[line] = nil
  end
end

---Check if the given file is currently opened on the editor.
---@param abs_filename string
function util.doc_is_open(abs_filename)
  -- Normalize path format to the one used by normal docs
  abs_filename = common.normalize_path(abs_filename) or abs_filename
  for _, doc in ipairs(core.docs) do
    ---@cast doc core.doc
    if doc.abs_filename == abs_filename then
      return true;
    end
  end
  return false
end

---Converts a utf-8 column position into the equivalent utf-16 position.
---@param doc core.doc
---@param line integer
---@param column integer
---@return integer col_position
function util.doc_utf8_to_utf16(doc, line, column)
  return convert_position(doc, line, column, true)
end

---Converts a utf-16 column position into the equivalent utf-8 position.
---@param doc core.doc
---@param line integer
---@param column integer
---@return integer col_position
function util.doc_utf16_to_utf8(doc, line, column)
  return convert_position(doc, line, column, false)
end

---Split a string by the given delimeter
---@param s string The string to split
---@param delimeter string Delimeter without lua patterns
---@param delimeter_pattern? string Optional delimeter with lua patterns
---@return table
---@return boolean ends_with_delimiter
function util.split(s, delimeter, delimeter_pattern)
  if not delimeter_pattern then
    delimeter_pattern = delimeter
  end

  local last_idx = 1
  local result = {}
  for match_idx, afer_match_idx in s:gmatch("()"..delimeter_pattern.."()") do
    table.insert(result, string.sub(s, last_idx, match_idx - 1))
    last_idx = afer_match_idx
  end
  if last_idx > #s then
    return result, true
  else
    table.insert(result, string.sub(s, last_idx))
    return result, false
  end
end

---Get the extension component of a filename.
---@param filename string
---@return string
function util.file_extension(filename)
  local parts = util.split(filename, "%.")
  if #parts > 1 then
    return parts[#parts]:gsub("%%", "")
  end

  return filename
end

---Check if a file exists.
---@param file_path string
---@return boolean
function util.file_exists(file_path)
  local file = io.open(file_path, "r")
  if file ~= nil then
    file:close()
    return true
  end
 return false
end

---Converts the given LSP DocumentUri into a valid filename path.
---@param uri lsp.protocol.DocumentUri LSP DocumentUri to convert into a filename.
---@return string
function util.tofilename(uri)
  local filename = ""
  if PLATFORM == "Windows" then
    filename = uri:gsub('^file:///', '')
  else
    filename = uri:gsub('^file://', '')
  end

  filename = filename:gsub(
    '%%(%x%x)',
    function(hex) return string.char(tonumber(hex, 16)) end
  )

  if PLATFORM == "Windows" then filename = filename:gsub('/', '\\') end

  return filename
end

---Convert a file path to a LSP valid uri.
---@param file_path string
---@return lsp.protocol.DocumentUri
function util.touri(file_path)
  local function char_escape(char)
    if string.match(char, "[_.~-]") then return char end
    if char == "/" then return char end
    if char == "\\" and PLATFORM == "Windows" then return "/" end
    return string.format("%%%02X", string.byte(char))
  end

  file_path = string.gsub(file_path, "([%W ])", char_escape)
  if PLATFORM ~= "Windows" then
    file_path = 'file://' .. file_path
  else
    file_path = 'file:///' .. file_path:gsub('\\', '/')
  end

  return file_path
end

---Converts a document range returned by lsp to a valid document selection.
---@param range lsp.protocol.Range LSP Range.
---@param doc? core.doc
---@return integer line1
---@return integer col1
---@return integer line2
---@return integer col2
function util.toselection(range, doc)
  local line1 = range.start.line + 1
  local col1 = range.start.character + 1
  local line2 = range['end'].line + 1
  local col2 = range['end'].character + 1

  if doc then
    col1 = util.doc_utf16_to_utf8(doc, line1, col1)
    col2 = util.doc_utf16_to_utf8(doc, line2, col2)
  end

  return line1, col1, line2, col2
end

---Prettify json output and logs it if config.lsp.log_file is set.
---@param code string
---@return string
function util.jsonprettify(code)
  if config.plugins.lsp.prettify_json then
    code = json.prettify(code)
  end

  if config.plugins.lsp.log_file and #config.plugins.lsp.log_file > 0 then
    local log = io.open(config.plugins.lsp.log_file, "a+")
    if log then
      log:write("Output: \n" .. tostring(code) .. "\n\n")
      log:close()
    end
  end

  return code
end

---Gets the last component of a path. For example:
---/my/path/to/somwhere would return somewhere.
---@param path string
---@return string
function util.getpathname(path)
  local components = {}
  if PLATFORM == "Windows" then
    components = util.split(path, "\\")
  else
    components = util.split(path, "/")
  end

  if #components > 0 then
    return components[#components]
  end

  return path
end

---Check if a value is on a table.
---@param value any
---@param table_array table
---@return boolean
function util.intable(value, table_array)
  for _, element in pairs(table_array) do
    if element == value then
      return true
    end
  end

  return false
end

---Used on windows to check if command is a valid executable on the given path.
---
---If the command does not contains a file extension it will automatically
---search using the extensions: .exe, .com, .cmd or .bat in that same order.
---@param command string
---@param path? string
---@param extensions? string[]
---@return boolean
local function win_command_exists(command, path, extensions)
  path = path or ""
  extensions = extensions or {"com", "exe", "cmd", "bat"}
  local has_extension = false
  for _, ext in ipairs(extensions) do
    if command:lower():find("%."..ext.."$") then
      has_extension = true
      break
    end
  end
  if has_extension then
    if util.file_exists(path .. command) then
      return true
    end
  else
    for _, ext in ipairs(extensions) do
      local command_ext = command .. "." .. ext
      if util.file_exists(path .. command_ext) then
        return true
      end
    end
  end
  return false
end

---Check if a command can be launched directly by the Windows process API.
---
---This intentionally excludes .cmd and .bat scripts because those still need
---cmd.exe as an interpreter.
---@param command string
---@return boolean
function util.win_command_is_executable(command)
  local extensions = {"com", "exe"}

  if util.file_exists(command) or win_command_exists(command, nil, extensions) then
    return true
  end

  local env_path = os.getenv("PATH") or ""
  for _, path in pairs(util.split(env_path, ";")) do
    local path_fix = path:gsub("[/\\]$", "") .. PATHSEP
    if util.file_exists(path_fix .. command) then
      return true
    elseif win_command_exists(command, path_fix, extensions) then
      return true
    end
  end

  return false
end

---Check if a command exists on the system by inspecting the PATH envar.
---@param command string
---@return boolean
function util.command_exists(command)
  local is_win = PLATFORM == "Windows"

  if util.file_exists(command) or (is_win and win_command_exists(command)) then
    return true
  end

  local env_path = os.getenv("PATH") or ""
  local path_list = {}

  if not is_win then
    path_list = util.split(env_path, ":")
  else
    path_list = util.split(env_path, ";")
  end

  -- Automatic support for brew, macports, etc...
  if PLATFORM == "Mac OS X" then
    if
      system.get_file_info("/usr/local/bin")
      and
      not string.find(env_path, "/usr/local/bin", 1, true)
    then
      table.insert(path_list, 1, "/usr/local/bin")
      system.setenv("PATH", table.concat(path_list, ":"))
    end
  end

  for _, path in pairs(path_list) do
    local path_fix = path:gsub("[/\\]$", "") .. PATHSEP
    if util.file_exists(path_fix .. command) then
      return true
    elseif is_win and win_command_exists(command, path_fix) then
      return true
    end
  end

  return false
end

---From a list of executable names get the one that is installed
---on the system or first one if none of them exists.
---@param executables table<integer,string>
---@return string executable_name
function util.get_best_executable(executables)
  for _, executable in ipairs(executables) do
    if util.command_exists(executable) then
      return executable
    end
  end
  return executables[1]
end

---Remove by key from a table and returns a new
---table with element removed.
---@param table_object table
---@param key_name string|integer
---@return table
function util.table_remove_key(table_object, key_name)
  local new_table = {}
  for key, data in pairs(table_object) do
    if key ~= key_name then
      new_table[key] = data
    end
  end

  return new_table
end

---Get a table specific field or nil if not found.
---@param t table The table we are going to search for the field.
---@param fieldset string A field spec in the format
---"parent[.child][.subchild]" eg: "myProp.subProp.subSubProp"
---@return any|nil The value of the given field or nil if not found.
function util.table_get_field(t, fieldset)
  local fields = util.split(fieldset, ".", "%.")
  local field = fields[1]
  local value = nil

  if field and #fields > 1 and t[field] then
    local sub_fields = table.concat(fields, ".", 2)
    value = util.table_get_field(t[field], sub_fields)
  elseif field and #fields > 0 and t[field] then
    value = t[field]
  end

  return value
end

---Merge the content of the tables into a new one.
---Arguments from the later tables take precedence.
---Doesn't touch the original tables.
---`nil` arguments are ignored.
---@param ... table?
---@return table
function util.deep_merge(...)
  local t = {}
  local args = table.pack(...)
  for i=1,args.n do
    local other = args[i]
    if other then
      assert(type(other) == "table", string.format("Argument %d must be a table", i))
      for k, v in pairs(other) do
        if type(v) == "table" then
          if type(t[k]) == "table" then
            t[k] = util.deep_merge(t[k], v)
          else
            t[k] = util.deep_merge({}, v)
          end
        else
          t[k] = v
        end
      end
    end
  end
  return t
end

---Check if a table is really empty.
---@param t table
---@return boolean
function util.table_empty(t)
  return next(t) == nil
end

---Convert markdown to plain text.
---@param text string
---@return string
function util.strip_markdown(text)
  local clean_text = ""
  for match in (text.."\n"):gmatch("(.-)".."\n") do
    local line = match .. "\n"

    -- strip markdown
    local new_line = line
      -- Block quotes
      :gsub("^>+(%s*)", "%1")
      -- headings
      :gsub("^(%s*)######%s(.-)\n", "%1%2\n")
      :gsub("^(%s*)#####%s(.-)\n", "%1%2\n")
      :gsub("^(%s*)####%s(.-)\n", "%1%2\n")
      :gsub("^(%s*)####%s(.-)\n", "%1%2\n")
      :gsub("^(%s*)###%s(.-)\n", "%1%2\n")
      :gsub("^(%s*)##%s(.-)\n", "%1%2\n")
      :gsub("^(%s*)#%s(.-)\n", "%1%2\n")
      -- heading custom id
      :gsub("{#.-}", "")
      -- emoji
      :gsub(":[%w%-_]+:", "")
      -- bold and italic
      :gsub("%*%*%*(.-)%*%*%*", "%1")
      :gsub("___(.-)___", "%1")
      :gsub("%*%*_(.-)_%*%*", "%1")
      :gsub("__%*(.-)%*__", "%1")
      :gsub("___(.-)___", "%1")
      -- bold
      :gsub("%*%*(.-)%*%*", "%1")
      :gsub("__(.-)__", "%1")
      -- strikethrough
      :gsub("%-%-(.-)%-%-", "%1")
      -- italic
      :gsub("%*(.-)%*", "%1")
      :gsub("(%s)_(.-)_(%s)", "%1%2%3")
      :gsub("\\_(.-)\\_", "_%1_")
      :gsub("^_(.-)_", "%1")
      -- code
      :gsub("^%s*```%a[%w%-]*%s*\n", "")
      :gsub("^%s*```%s*\n", "")
      :gsub("``(.-)``", "%1")
      :gsub("`(.-)`", "%1")
      -- lines
      :gsub("^%-%-%-%-*%s*\n", "")
      :gsub("^%*%*%*%**%s*\n", "")
      -- reference links
      :gsub("^%[[^%^](.-)%]:.-\n", "")
      -- footnotes
      :gsub("^%[%^(.-)%]:%s+", "[%1]: ")
      :gsub("%[%^(.-)%]", "[%1]")
      -- Images
      :gsub("!%[(.-)%]%((.-)%)", "")
      -- links
      :gsub("(%s)<(%w+:/+[^>]*)>(%s)", "%1%2%3")
      :gsub("%[(.-)%]%s*%[(.-)%]", "%1")
      :gsub("%[(.-)%]%((.-)%)", "%1: %2")
      -- remove escaped punctuations
      :gsub("\\(%p)", "%1")
      -- convert less than and more than tags
      :gsub("&lt;", "<"):gsub("&gt;", ">")

    clean_text = clean_text .. new_line
  end
  return clean_text
end

---@param text string
---@param font renderer.font
---@param max_width number
function util.wrap_text(text, font, max_width)
  local lines = util.split(text, "\n")
  local wrapped_text = ""
  local longest_line = 0;
  for _, line in ipairs(lines) do
    local line_len = line:ulen() or 0
    if line_len > longest_line then
      longest_line = line_len
      local line_width = font:get_width(line)
      if line_width > max_width then
        local words = util.split(line, " ")
        local new_line = words[1] and words[1] or ""
        wrapped_text = wrapped_text .. new_line
        for w=2, #words do
          if font:get_width(new_line .. " " .. words[w]) <= max_width then
            new_line = new_line .. " " .. words[w]
            wrapped_text = wrapped_text .. " " .. words[w]
          else
            wrapped_text = wrapped_text .. "\n" .. words[w]
            new_line = words[w]
          end
        end
        wrapped_text = wrapped_text .. "\n"
      else
        wrapped_text = wrapped_text .. line .. "\n"
      end
    else
      wrapped_text = wrapped_text .. line .. "\n"
    end
  end

  wrapped_text = wrapped_text:gsub("\n\n\n\n?", "\n\n"):gsub("%s*$", "")

  return wrapped_text
end


return util
