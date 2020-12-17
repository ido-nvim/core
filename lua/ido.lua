-- Import custom Modules -{{{
require "utils/tables"
require "utils/strings"
-- }}}
-- Helper variables -{{{
local api = vim.api
local fn = vim.fn
-- }}}
-- Variables -{{{
local key_pressed = ''
local win_width
local render_list = {}

ido_matched_items = {}
ido_window, ido_buffer = 0, 0

ido_before_cursor, ido_after_cursor = '', ''
ido_prefix, ido_current_item, ido_prefix_text = '', '', ''
ido_render_text = ''

ido_default_prompt = '>>> '

ido_cursor_position = 1
ido_more_items = false

ido_pattern_text = ''
ido_match_list = {}
ido_prompt = ido_default_prompt
local ido_looping = true
-- }}}
-- Settings -{{{
ido_fuzzy_matching = true
ido_case_sensitive = false
ido_limit_lines = true
ido_overlap_statusline = false

ido_decorations = {
  prefixstart     = '[',
  prefixend       = ']',

  matchstart      = '',
  separator       = ' | ',
  matchend        = '',

  marker          = '',
  moreitems       = '...'
}

ido_max_lines = 10
ido_min_lines = 3
ido_key_bindings = {}
-- }}}
-- Special keys -{{{
local ido_hotkeys = {}
ido_keybindings = {
  ["\\<Escape>"]  = 'ido_close_window',
  ["\\<Return>"]  = 'ido_accept',

  ["\\<Left>"]    = 'ido_cursor_move_left',
  ["\\<Right>"]   = 'ido_cursor_move_right',
  ["\\<C-b>"]     = 'ido_cursor_move_left',
  ["\\<C-f>"]     = 'ido_cursor_move_right',

  ["\\<BS>"]      = 'ido_key_backspace',
  ["\\<Del>"]     = 'ido_key_delete',

  ["\\<C-a>"]     = 'ido_cursor_move_begin',
  ["\\<C-e>"]     = 'ido_cursor_move_end',

  ["\\<Tab>"]     = 'ido_complete_prefix',
  ["\\<C-n>"]     = 'ido_next_item',
  ["\\<C-p>"]     = 'ido_prev_item'
}

function ido_map_keys(table)
  for key_name, action in pairs(table) do
    ido_hotkeys[fn.eval('"' .. key_name .. '"')] = action
  end
end

function ido_load_keys()
  ido_hotkeys = {}
  ido_map_keys(ido_keybindings)
end

ido_load_keys()
-- }}}
-- Open the window -{{{
local function ido_open_window()
  ido_buffer = api.nvim_create_buf(false, true) -- Create new empty buffer
  vim.b.bufhidden='wipe'

  -- Calculate the Ido window size and starting position
  local win_height = ido_min_lines
  local row        = vim.o.lines - win_height - 2 + (ido_overlap_statusline and 1 or 0)

  local col        = 0
  win_width        = vim.o.columns

  -- Set some options
  local win_options = {
    style = "minimal",
    relative = "editor",
    width = win_width,
    height = win_height,
    row = row,
    col = col
  }

  -- And finally create it with buffer attached
  ido_window = api.nvim_open_win(ido_buffer, true, win_options)
  vim.wo.winhl = 'Normal:IdoWindow'
  vim.wo.wrap = false

  ido_cursor_position = 1
  ido_before_cursor, ido_after_cursor, ido_pattern_text, ido_current_item, ido_prefix, ido_prefix_text = '', '', '', '', '', ''
  ido_matched_items = {}
  looping = true

  return ''
end
-- }}}
-- Close the window -{{{
function ido_close_window()
  ido_prompt = ido_default_prompt
  api.nvim_command('bdelete!')
  ido_looping = false
  return ''
end
-- }}}
-- Get the matching items -{{{
function ido_get_matches()

  local ido_pattern_text, true_ido_pattern_text = ido_pattern_text, ido_pattern_text
  ido_matched_items, ido_current_item = {}, ""
  local ido_true_matched_items = {}

  if ido_fuzzy_matching then
    ido_pattern_text = ido_pattern_text:gsub('.', '.*%1')
  end

  if not ido_case_sensitive then
    ido_pattern_text = ido_pattern_text:lower()
  end

  ido_true_matched_items = table.filter(ido_match_list,
  function(v)
    if not ido_case_sensitive then
      v = v:lower()
    end

    if v:match('^' .. true_ido_pattern_text) then
      return true
    end
  end
  )

  ido_matched_items = table.filter(ido_match_list,
  function(v)
    if not ido_case_sensitive then
      v = v:lower()
    end

    if v:match(ido_pattern_text) and not v:match('^' .. true_ido_pattern_text) then
      return true
    end
  end
  )

  if #ido_matched_items > 1 or #ido_true_matched_items > 1 then

    if #ido_true_matched_items > 0 then
      ido_prefix_text = table.prefix(ido_true_matched_items)
      ido_current_item = ido_true_matched_items[1]
      ido_prefix = ido_prefix_text:gsub('^' .. true_ido_pattern_text, '')
    else
      ido_prefix = ''
      ido_prefix_text = ido_prefix
      ido_current_item = ido_matched_items[1]
    end

  elseif ido_matched_items[1] ~= nil or ido_true_matched_items[1] ~= nil then

    if ido_true_matched_items[1] == nil then
      ido_prefix = ido_matched_items[1]
      ido_prefix_text = ido_prefix
      ido_current_item = ido_prefix
      ido_matched_items = {}
    else
      if ido_matched_items[1] == nil then
        ido_prefix = ido_true_matched_items[1]
        ido_prefix_text = ido_prefix
        ido_current_item = ido_prefix
        ido_true_matched_items = {}
      else
        ido_current_item = ido_true_matched_items[1]
      end
    end

  else
    ido_prefix = ''
    ido_prefix_text = ido_prefix
  end

  if #ido_matched_items > 0 then
    for _, v in pairs(ido_matched_items) do
      table.insert(ido_true_matched_items, v)
    end

  end

  ido_matched_items = ido_true_matched_items

  return ''
end
-- }}}
-- Insert a character -{{{
function ido_insert_char()
  if key_pressed ~= '' then
    ido_before_cursor = ido_before_cursor .. key_pressed
    ido_cursor_position = ido_cursor_position + 1
    ido_pattern_text = ido_before_cursor .. ido_after_cursor
  end
  return ''
end
-- }}}
-- Decrement the position of the cursor if possible -{{{
local function cursor_decrement()
  if ido_cursor_position > 1 then
    ido_cursor_position = ido_cursor_position - 1
  end
  return ''
end
-- }}}
-- Increment the position of the cursor if possible -{{{
local function cursor_increment()
  if ido_cursor_position <= ido_pattern_text:len() then
    ido_cursor_position = ido_cursor_position + 1
  end
  return ''
end
-- }}}
-- Backspace key -{{{
function ido_key_backspace()
  cursor_decrement()
  ido_before_cursor = ido_before_cursor:gsub('.$', '')
  ido_pattern_text = ido_before_cursor .. ido_after_cursor
  ido_get_matches()
  return ''
end
-- }}}
-- Delete key -{{{
function ido_key_delete()
  ido_after_cursor = ido_after_cursor:gsub('^.', '')
  ido_pattern_text = ido_before_cursor .. ido_after_cursor
  ido_get_matches()
  return ''
end
-- }}}
-- Move the cursor left a character -{{{
function ido_cursor_move_left()
  ido_after_cursor = ido_before_cursor:sub(-1, -1) .. ido_after_cursor
  ido_key_backspace()
  return ''
end
-- }}}
-- Move the cursor right a character -{{{
function ido_cursor_move_right()
  ido_before_cursor = ido_before_cursor .. ido_after_cursor:sub(1, 1)
  cursor_increment()
  ido_key_delete()
  return ''
end
-- }}}
-- Beginning of line -{{{
function ido_cursor_move_begin()
  ido_after_cursor = ido_before_cursor .. ido_after_cursor
  ido_before_cursor = ''
  ido_cursor_position = 1
  return ''
end
-- }}}
-- End of line -{{{
function ido_cursor_move_end()
  ido_before_cursor = ido_before_cursor .. ido_after_cursor
  ido_after_cursor = ''
  ido_cursor_position = ido_before_cursor:len() + 1
  return ''
end
-- }}}
-- Next item -{{{
function ido_next_item()
  if #ido_matched_items > 1 then
    table.insert(ido_matched_items, ido_current_item)
    table.remove(ido_matched_items, 1)
    ido_current_item = ido_matched_items[1]
  end
  return ''
end
-- }}}
-- Previous item -{{{
function ido_prev_item()
  if #ido_matched_items > 1 then
    table.insert(ido_matched_items, 1, ido_matched_items[#ido_matched_items])
    table.remove(ido_matched_items, #ido_matched_items)
    ido_current_item = ido_matched_items[1]
  end
  return ''
end
-- }}}
-- Complete the prefix -{{{
function ido_complete_prefix()
  if ido_prefix ~= '' and ido_pattern_text ~= ido_prefix_text then
    ido_pattern_text = ido_prefix_text
    ido_prefix = ''
    ido_cursor_position = ido_pattern_text:len() + 1
    ido_before_cursor = ido_pattern_text
    ido_after_cursor = ''
  end
  return ''
end
-- }}}
-- Split the matches into newlines if required -{{{
local function split_matches_lines()
  local render_lines = string.split(ido_render_text, '\n')
  ido_more_items = false

  for key, value in pairs(render_lines) do
    if value:len() > win_width then

      local matches_lines, count = '', 1
      while value:len() > 0 and not (count > ido_min_lines and ido_limit_lines) do
        matches_lines = matches_lines .. '\n' .. value:sub(1, win_width)
        value = value:sub(win_width + 1, -1)
        count = count + 1
      end

      if ido_limit_lines then
        if value == '' then
          render_lines[key] = matches_lines
        else
          render_lines[key] = matches_lines:sub(1,
          matches_lines:len() - ido_decorations['moreitems']:len() - 2)
          .. ' ' .. ido_decorations['moreitems']

          ido_more_items = true
        end
      else
        render_lines[key] = matches_lines
      end

    end
  end

  if not ido_limit_lines then
    if #render_lines > ido_min_lines then
      api.nvim_win_set_height(ido_window, ido_max_lines)
    end
  end

  ido_render_text = table.concat(render_lines, '\n'):gsub('^\n', '')
end
-- }}}
-- Render colors -{{{
local function ido_render_colors()
  local ido_prefix_end = string.len(ido_prompt .. ido_pattern_text)
  local matches_start = {}

  fn.matchadd('IdoPrompt', '\\%1l\\%1c.*\\%' .. ido_prompt:len() .. 'c')
  fn.matchadd('IdoSeparator', '\\M' .. ido_decorations["separator"])

  if ido_prefix ~= '' then
    local ido_prefix_start =
    string.len(ido_prompt .. ido_pattern_text .. ido_decorations['prefixstart'])
    ido_prefix_end =
    string.len(ido_prompt .. ido_pattern_text .. ido_decorations['prefixstart']
    .. ido_prefix .. ido_decorations['prefixend'])

    fn.matchadd('Idoido_Prefix',
    '\\%1l\\%' ..  ido_prefix_start .. 'c.*\\%1l\\%' ..  ido_prefix_end + 2 .. 'c')
  end

  if #ido_matched_items > 0 then
    local _, line = string.gsub(ido_decorations['matchstart'], '\n', '')

    if ido_decorations['matchstart']:len() > 0 then

      if line > 0 then
        matches_start[1] = 1
        matches_start[2] = string.len(ido_decorations['matchstart']:gsub('\n', '')) + 1
      else
        matches_start[1] = string.len(ido_prompt .. ido_pattern_text) + 1
        matches_start[2] = ido_prefix_end + string.len(ido_decorations['matchstart']:gsub('\n', '')) + 2
      end

      vim.fn.matchadd('IdoSeparator',
      '\\%' .. line + 1 .. 'l\\%' .. matches_start[1] .. 'c.*\\%' .. matches_start[2] .. 'c')

    end

    local matches_end = {}

    if ido_decorations['matchend']:len() > 0 then
      matches_end[1] = render_list[#render_list]:len() -
      ido_decorations['matchend']:len() + 1
      matches_end[2] = render_list[#render_list]:len() + 1

      vim.fn.matchadd('IdoSeparator',
      '\\%' .. #render_list .. 'l\\%' .. matches_end[1] .. 'c.*\\%' .. matches_end[2] .. 'c')
    end

  end

  if #ido_matched_items > 0 then
    local _, newlines = string.gsub(ido_decorations['matchstart'], '\n', '')
    local match_start = 0
    if newlines > 0 then
      match_start =
      string.gsub(ido_decorations['marker'], '\n', ''):len() + 1
      match_end = match_start + ido_current_item:len()
    else
      match_start = ido_prefix_end +
      string.len(string.gsub(ido_decorations['matchstart'], '\n', '') ..
      string.gsub(ido_decorations['marker'], '\n', '')) + 2
      match_end = match_start + ido_current_item:len()
    end

    fn.matchadd('IdoSelectedMatch', '\\%' .. newlines + 1 .. 'l\\%' ..
    match_start - string.len(ido_decorations['marker'], '\n', '')
    .. 'c.*\\%' .. match_end .. 'c')

  end

  if ido_more_items then
    local eol_start = render_list[#render_list]:len() -
    ido_decorations['moreitems']:len() + 1

    fn.matchadd('IdoSeparator',
    '\\%' .. #render_list .. 'l\\%'.. eol_start .. 'c.*\\%' .. #render_list ..
    'l\\%' .. render_list[#render_list]:len() .. 'c')
  end

  if string.len(ido_prompt .. ido_pattern_text) >= win_width then
    local length = string.len(ido_prompt .. ido_pattern_text)
    local lines = math.floor(length / win_width) + 1
    local columns = math.floor(length % win_width) + 1
    fn.matchadd('IdoCursor', '\\%' .. lines .. 'l\\%' .. columns .. 'c')
  else
    fn.matchadd('IdoCursor', '\\%1l\\%' .. (ido_prompt:len() + ido_cursor_position)
    .. 'c')
  end

  return ''
end
-- }}}
-- Render IDO -{{{
local function ido_render()
  local ido_prefix_text, matched_text

  if #ido_matched_items > 0 then
    ido_render_text = table.concat(ido_matched_items,
    ido_decorations["separator"])
  end

  if ido_prefix:len() > 0 then
    ido_prefix_text = ido_decorations['prefixstart'] .. ido_prefix ..
    ido_decorations['prefixend']
    if #ido_matched_items == 0 and #ido_matched_items == 1 then
      ido_prefix_text = ido_decorations['matchstart'] .. ido_prefix_text ..
      ido_decorations['matchend']
    end
  else
    ido_prefix_text = ""
  end

  if #ido_matched_items > 0 then
    matched_text =
    ido_decorations['matchstart'] .. ido_decorations['marker'] ..
    ido_render_text .. ido_decorations['matchend']
  else
    matched_text = ""
  end

  ido_render_text = ido_prompt .. ido_pattern_text .. ' ' .. ido_prefix_text .. matched_text
  split_matches_lines()
  render_list = string.split(ido_render_text, '\n')

  api.nvim_buf_set_lines(ido_buffer, 0, -1, false, render_list)

  -- Colors!
  fn.clearmatches()
  ido_render_colors()

  api.nvim_command('redraw!')
end
-- }}}
-- Handle key presses -{{{
local function handle_keys()
  while ido_looping do
    key_pressed = fn.getchar()

    if fn.char2nr(key_pressed) == 128 then
      key_pressed_action = ido_hotkeys[key_pressed] and ido_hotkeys[key_pressed] or fn.nr2char(key_pressed)
    else
      key_pressed_action = ido_hotkeys[fn.nr2char(key_pressed)] and
      ido_hotkeys[fn.nr2char(key_pressed)] or
      fn.nr2char(key_pressed)
    end

    if key_pressed_action == 'ido_accept' then
      if ido_current_item == '' then
        ido_current_item = ido_pattern_text
      end
      ido_close_window()
      return ido_current_item

    elseif key_pressed_action == 'ido_complete_prefix' then
      ido_complete_prefix()

      if ido_prefix_text == ido_current_item and #ido_matched_items == 0 and
        ido_prefix_text ~= '' then
        ido_close_window()
        return ido_prefix_text
      end

      ido_get_matches()

    else
      if key_pressed_action == fn.nr2char(key_pressed) then
        key_pressed = fn.nr2char(key_pressed)
        ido_insert_char()
        ido_get_matches()

      else

        loadstring(key_pressed_action .. '()')()
      end
    end

    if not ido_looping then
      return current_item
    end

    ido_render()
  end
end
-- }}}
-- Completing read -{{{
function ido_complete(opts)
  opts = opts or {}
  ido_match_list = table.unique(opts.items)
  ido_prompt = opts.prompt and opts.prompt:gsub('\n', '') .. ' ' or ido_default_prompt

  if opts.keybinds ~= nil then ido_map_keys(opts.keybinds) end

  ido_open_window()
  ido_get_matches()
  ido_render()

  local selection = handle_keys()

  if opts.keybinds ~= nil then
    ido_hotkeys = {}
    ido_map_keys(ido_keybindings)
  end

  ido_prompt = ido_default_prompt
  ido_looping = true

  if opts.on_enter then
    return opts.on_enter(selection)
  else
    return selection
  end
end
-- }}}
-- Init -{{{
api.nvim_command('hi! IdoCursor         guifg=#161616 guibg=#cc8c3c')
api.nvim_command('hi! IdoSelectedMatch  guifg=#95a99f')
api.nvim_command('hi! Idoido_Prefix         guifg=#9e95c7')
api.nvim_command('hi! IdoSeparator      guifg=#635a5f')
api.nvim_command('hi! IdoPrompt         guifg=#96a6c8')
api.nvim_command('hi! IdoWindow         guibg=#202020')
-- }}}
