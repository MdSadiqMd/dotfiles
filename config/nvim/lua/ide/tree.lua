-- neo-tree as an IDE panel: single-click previews, double-click pins, right-click
-- menu, hover highlight. Files always open in the middle editor window.
local editor_win = require('ide.util').editor_win

local neo_press = { winid = 0, line = 0, buf = -1, opened = false, toggled_id = nil, toggled_at = 0 }
local neo_last_pin = 0

local function neo_state()
  local ok, manager = pcall(require, 'neo-tree.sources.manager')
  if not ok then
    return nil
  end
  local ok2, state = pcall(manager.get_state, 'filesystem')
  if ok2 then
    return state
  end
  return nil
end

local function neo_active_state(state)
  if state and state.tree then
    return state
  end
  return neo_state()
end

local function neo_cursor_node(state)
  state = neo_active_state(state)
  if not state then
    return nil
  end
  local ok, node = pcall(function()
    return state.tree:get_node()
  end)
  if ok then
    return node
  end
  return nil
end

local function neo_node_path(node)
  if not node then
    return nil
  end
  local ok, id = pcall(function()
    return node:get_id()
  end)
  if ok and type(id) == 'string' and id ~= '' then
    return id
  end
  return nil
end

local function neo_open_editor(path, focus_file)
  local tree_win = vim.api.nvim_get_current_win()
  local win = editor_win()
  if not win then
    vim.cmd 'vsplit'
    win = vim.api.nvim_get_current_win()
  end
  vim.api.nvim_set_current_win(win)
  vim.cmd('edit ' .. vim.fn.fnameescape(path))
  if not focus_file then
    if tree_win and vim.api.nvim_win_is_valid(tree_win) then
      pcall(vim.api.nvim_set_current_win, tree_win)
    else
      local ok, nt = pcall(require, 'neo-tree.command')
      if ok then
        pcall(nt.execute, { action = 'focus', source = 'filesystem', position = 'left' })
      end
    end
  end
end

local function neo_open_node(state, node, focus_file)
  if not node then
    return
  end
  -- Visual-mode callers pass nil state; resolve it here so toggle_directory
  -- never receives nil (E5108).
  state = neo_active_state(state)
  if not state then
    return
  end
  if node.type == 'directory' then
    require('neo-tree.sources.filesystem').toggle_directory(state, node)
    return
  end
  local path = neo_node_path(node)
  if not path then
    return
  end
  if vim.fn.filereadable(path) == 0 and vim.fn.isdirectory(path) == 0 then
    return
  end
  neo_open_editor(path, focus_file)
end

-- IDE "open to the side": new split inside the middle editor area,
-- tree and terminal panel untouched.
local function neo_open_side(state, node, how)
  if not node then
    return
  end
  state = neo_active_state(state)
  if not state then
    return
  end
  if node.type == 'directory' then
    require('neo-tree.sources.filesystem').toggle_directory(state, node)
    return
  end
  local path = neo_node_path(node)
  if not path then
    return
  end
  local win = editor_win()
  if not win then
    vim.cmd 'vsplit'
    win = vim.api.nvim_get_current_win()
  end
  vim.api.nvim_set_current_win(win)
  vim.cmd(how == 'split' and 'split' or 'vsplit')
  vim.cmd('edit ' .. vim.fn.fnameescape(path))
end

-- Mouse handlers run scheduled from the dispatcher below, by which time a newer
-- event may have moved the mouse; they read the position their event arrived with.
local mouse_pos
local function mousepos()
  return mouse_pos or vim.fn.getmousepos()
end

-- neo-tree saves the selected row on CursorMoved and puts it back on every redraw.
-- A click that previews or pins leaves the tree before CursorMoved fires, so the
-- next redraw jumped the highlight back to the old row: save it right away.
local function set_tree_cursor(win, line)
  pcall(vim.api.nvim_win_set_cursor, win, { line, 0 })
  local state = neo_state()
  if state and state.winid == win then
    pcall(require('neo-tree.ui.renderer').position.save, state, true)
  end
end

-- getmousepos() reports the last line for the empty space below the rows; the tree
-- never wraps or folds, so a real row satisfies line == topline + winrow - 1.
local function on_row(m)
  local info = vim.fn.getwininfo(m.winid)[1]
  return info ~= nil and m.line >= 1 and m.line == info.topline + m.winrow - 1
end

-- Clicks must act on the clicked row, not the cursor row. Without this a
-- click on a file expands the previously-focused folder below it.
-- Always the release row: a press on one row and release on another is a
-- sloppy tap, not a drag (text selection is disabled in the tree anyway).
local function neo_node_at_mouse(state)
  local m = mousepos()
  if m.winid == 0 then
    return nil
  end
  local ok_buf, buf = pcall(vim.api.nvim_win_get_buf, m.winid)
  if not ok_buf or vim.bo[buf].filetype ~= 'neo-tree' then
    return nil -- click outside the tree
  end
  if not on_row(m) then
    return nil -- empty space below the tree: select nothing, open nothing
  end
  pcall(vim.api.nvim_set_current_win, m.winid)
  set_tree_cursor(m.winid, m.line)
  return neo_cursor_node(state)
end

-- neo-tree mapping functions swallow the press event, so record it and
-- perform the default click behavior ourselves (cursor follows the mouse).
-- Plain presses also preview files immediately: trackpad taps often drift a
-- row between press and release, and waiting for release meant the first tap
-- was swallowed as a "drag". Folders still toggle on release.
local function neo_record_press(state, do_preview)
  local m = mousepos()
  neo_press.winid = m.winid
  neo_press.line = m.line
  neo_press.opened = false
  local ok, buf = pcall(vim.api.nvim_win_get_buf, m.winid)
  neo_press.buf = ok and buf or -1
  if not ok or vim.bo[buf].filetype ~= 'neo-tree' then
    return
  end
  pcall(vim.api.nvim_set_current_win, m.winid)
  if not on_row(m) then
    return
  end
  set_tree_cursor(m.winid, m.line)
  if not do_preview then
    return
  end
  local node = neo_cursor_node(state)
  if node and node.type == 'file' then
    local path = neo_node_path(node)
    if path and (vim.fn.filereadable(path) == 1 or vim.fn.isdirectory(path) == 1) then
      neo_open_editor(path, false)
      neo_press.opened = true
    end
  end
end

local function neo_pin_at_mouse(state)
  neo_last_pin = vim.uv.now()
  local node = neo_node_at_mouse(state)
  if not node then
    return
  end
  -- Double-clicking a folder must not toggle it twice (open then shut).
  if node.type == 'directory' then
    local id = neo_node_path(node)
    if id and id == neo_press.toggled_id and vim.uv.now() - (neo_press.toggled_at or 0) < 600 then
      return
    end
  end
  neo_open_node(state, node, true)
end

local function neo_side_at_mouse(state)
  neo_last_pin = vim.uv.now()
  local node = neo_node_at_mouse(state)
  if node then
    neo_open_side(state, node, 'vsplit')
  end
end

-- Hover highlights the hovered row (cursorline follows the mouse) without
-- opening anything. Only while the tree is focused, so hovering the tree
-- from the editor never steals the selection.
local function neo_hover()
  local m = mousepos()
  if m.winid == 0 or m.winid ~= vim.api.nvim_get_current_win() then
    return
  end
  local ok_buf, buf = pcall(vim.api.nvim_win_get_buf, m.winid)
  if not ok_buf or vim.bo[buf].filetype ~= 'neo-tree' then
    return
  end
  if not on_row(m) then
    return
  end
  set_tree_cursor(m.winid, m.line)
end

-- Right-click: Cursor-style file/folder actions menu (see TreePopUp).
local function neo_show_tree_menu(state)
  neo_node_at_mouse(state) -- position the cursor; menu acts on it
  vim.cmd 'redraw' -- the dispatcher runs this scheduled; popup won't draw itself
  vim.cmd 'popup TreePopUp'
end

-- Single click / Shift+click: preview in the editor, keep focus in the tree.
-- The press usually previewed the file already; a release on the same row
-- then does nothing, a release elsewhere opens that row instead.
local function neo_single_click(state)
  if vim.uv.now() - neo_last_pin < 300 then
    return -- final release of a double-click: keep focus in the editor
  end
  local m = mousepos()
  if neo_press.opened and m.winid == neo_press.winid and m.line == neo_press.line then
    return -- press already previewed this exact row
  end
  local node = neo_node_at_mouse(state)
  if not node then
    return
  end
  if node.type == 'directory' then
    neo_press.toggled_id = neo_node_path(node)
    neo_press.toggled_at = vim.uv.now()
  end
  neo_open_node(state, node, false)
end

-- Enter / o (keyboard): open the cursor row and focus it.
local function neo_open_focused(state)
  neo_open_node(state, neo_cursor_node(state), true)
end

-- Right / l, as in Cursor: expand a closed folder, step into an open one,
-- preview a file (focus stays in the tree).
local function neo_expand(state)
  state = neo_active_state(state)
  local node = neo_cursor_node(state)
  if not node then
    return
  end
  if node.type ~= 'directory' then
    neo_open_node(state, node, false)
  elseif not node:is_expanded() then
    require('neo-tree.sources.filesystem').toggle_directory(state, node)
  elseif #node:get_child_ids() > 0 then
    vim.cmd 'normal! j' -- first child is the row below
  end
end

-- Left / h, as in Cursor: collapse an open folder, otherwise select the parent.
local function neo_collapse(state)
  state = neo_active_state(state)
  local node = neo_cursor_node(state)
  if not node then
    return
  end
  if node.type == 'directory' and node:is_expanded() then
    require('neo-tree.sources.filesystem').toggle_directory(state, node)
    return
  end
  local parent = node:get_parent_id()
  if parent then
    require('neo-tree.ui.renderer').focus_node(state, parent)
  end
end

local function noop() end

local neo_mappings = {
  ['<CR>'] = neo_open_focused,
  -- `o` replaces neo-tree's order-by submenu: open like an IDE instead.
  ['o'] = neo_open_focused,
  ['<2-LeftMouse>'] = 'none', -- the mouse dispatcher handles every click
  -- `Y` would yank the rendered line as text (the only unbound yank key
  -- left); copy the relative path instead, like the old tree did.
  ['Y'] = function(state)
    local path = neo_node_path(neo_cursor_node(state))
    if path then
      vim.fn.setreg('+', vim.fn.fnamemodify(path, ':.'))
    end
  end,
  -- `s` / `S`: open to the side, deterministically in the editor area.
  ['s'] = function(state)
    neo_open_side(state, neo_cursor_node(state), 'vsplit')
  end,
  ['S'] = function(state)
    neo_open_side(state, neo_cursor_node(state), 'split')
  end,
  -- Cursor keyboard: arrows walk the tree, F2 renames, Delete/Backspace delete
  -- (neo-tree asks first). Backspace no longer jumps the root up a folder.
  ['<Right>'] = neo_expand,
  ['l'] = neo_expand,
  ['<Left>'] = neo_collapse,
  ['h'] = neo_collapse,
  ['<F2>'] = 'rename',
  ['<Del>'] = 'delete',
  ['<BS>'] = 'delete',
  ['<Home>'] = function()
    vim.cmd 'normal! gg'
  end,
  ['<End>'] = function()
    vim.cmd 'normal! G'
  end,
}

-- A row list, not text: no visual selection, sideways motions, horizontal
-- scrolling, word search or insert. Keys neo-tree binds (w, b, e, f, t, i, a, ...)
-- keep their tree actions.
for _, key in ipairs {
  'v',
  'V',
  '<C-v>',
  'gv',
  '0',
  '^',
  '$',
  'W',
  'B',
  'E',
  'F',
  'ge',
  'gE',
  '*',
  'I',
  'O',
  'gi',
  'gI',
  'zh',
  'zl',
  'zH',
  'zL',
  '<ScrollWheelLeft>',
  '<ScrollWheelRight>',
} do
  neo_mappings[key] = neo_mappings[key] or noop
end

-- Cursor shows a highlighted row, not a text cursor: hide the terminal cursor
-- (blend=100, see :h tui-cursor-shape) while a tree window is focused. Only
-- normal/visual modes, so prompts and the cmdline keep a visible cursor.
local saved_guicursor
local function sync_tree_cursor()
  local in_tree = vim.bo.filetype == 'neo-tree'
  if in_tree and not saved_guicursor then
    saved_guicursor = vim.o.guicursor
    vim.api.nvim_set_hl(0, 'IdeHiddenCursor', { blend = 100, nocombine = true })
    vim.o.guicursor = saved_guicursor .. ',n-v:IdeHiddenCursor'
  elseif not in_tree and saved_guicursor then
    vim.o.guicursor = saved_guicursor
    saved_guicursor = nil
  end
end
vim.api.nvim_create_autocmd({ 'BufEnter', 'WinEnter', 'FileType' }, {
  desc = 'Hide the text cursor in the file tree',
  callback = sync_tree_cursor,
})
vim.api.nvim_create_autocmd('VimLeavePre', {
  desc = 'Leave the shell with a visible cursor',
  callback = function()
    if saved_guicursor then
      vim.o.guicursor = saved_guicursor
    end
  end,
})

-- Last line of defence for "it's a list, not text": whatever route enters visual
-- or select mode in the tree (a key not covered above, a plugin), leave it at once.
vim.api.nvim_create_autocmd('ModeChanged', {
  pattern = '*:[vVsS\22\19]*',
  desc = 'File tree: no text selection',
  callback = function()
    if vim.bo.filetype == 'neo-tree' then
      vim.schedule(function()
        if vim.bo.filetype == 'neo-tree' and vim.api.nvim_get_mode().mode:find '^[vVsS\22\19]' then
          vim.api.nvim_feedkeys(vim.keycode '<Esc>', 'nx', false)
        end
      end)
    end
  end,
})

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'neo-tree',
  desc = 'File tree: panel display',
  callback = function()
    vim.opt_local.list = false
    vim.opt_local.wrap = false
  end,
})

-- One dispatcher for every mouse event over the tree, whichever window has focus.
-- Mappings resolve against the focused buffer, so a click arriving from the editor
-- or terminal ran their behavior (text cursor, visual selection, editor menu);
-- on_key sees the typed key and drops it, then the tree acts on it instead.
-- A press in the tree owns its drags and release; separators and status lines
-- (line 0) are left alone so the sidebar still resizes. Wheel scrolling stays native.
local function is_tree_win(win)
  return win ~= 0
    and vim.api.nvim_win_is_valid(win)
    and vim.api.nvim_win_get_config(win).relative == ''
    and vim.bo[vim.api.nvim_win_get_buf(win)].filetype == 'neo-tree'
end

local tree_mouse = {
  Left = {
    Mouse = function(mods, count)
      if count >= 2 then
        neo_pin_at_mouse()
      else
        neo_record_press(nil, not mods:find 'C%-') -- Ctrl+click opens on release
      end
    end,
    Release = function(mods)
      if mods:find 'C%-' then
        neo_side_at_mouse()
      else
        neo_single_click()
      end
    end,
  },
  Right = { Mouse = neo_show_tree_menu },
  Middle = { Release = neo_side_at_mouse }, -- browser-style open to the side
}

local tree_press = false
local swallow_rest = false
vim.on_key(function(key, typed)
  -- A dropped mapping still queues the rest of its keys (a Lua callback is
  -- <K_LUA>{id}<CR>, a <Cmd> rhs is its command text): drop them up to the <CR>,
  -- or `150<CR>` would move the cursor 150 lines. They arrive untyped.
  if swallow_rest then
    if typed == '' then
      swallow_rest = key ~= '\r'
      return ''
    end
    swallow_rest = false
  end
  -- The mouse key is {key} itself, or (when a mapping turned it into something else)
  -- the last key of {typed}, which can also hold keys typed before it.
  local mods, button, action = vim.fn.keytrans(key):match '^<([^<>]-)(%u%l+)(%u%l+)>$'
  local from_mapping = not button
  if from_mapping then
    mods, button, action = vim.fn.keytrans(typed):match '<([^<>]-)(%u%l+)(%u%l+)>$'
  end
  if button == 'Mouse' and action == 'Move' then
    local m = vim.fn.getmousepos()
    if m.winid == vim.api.nvim_get_current_win() and is_tree_win(m.winid) then
      vim.schedule(function()
        mouse_pos = m
        neo_hover()
        mouse_pos = nil
      end)
    end
    return
  end
  if not tree_mouse[button] then
    return
  end
  local m = vim.fn.getmousepos()
  if action == 'Mouse' then
    tree_press = is_tree_win(m.winid) and m.line > 0
  end
  if not tree_press then
    return
  end
  if action == 'Release' then
    tree_press = false
  end
  swallow_rest = from_mapping
  local handler = tree_mouse[button][action]
  local count = tonumber(mods:match '(%d)%-') or 1
  vim.schedule(function()
    -- Leave insert/visual/terminal mode now (`x`: synchronously), or the tree
    -- inherits it: a menu from terminal mode never draws.
    if vim.api.nvim_get_mode().mode ~= 'n' then
      swallow_rest = false
      vim.api.nvim_feedkeys(vim.keycode '<C-\\><C-n>', 'nx', false)
    end
    mouse_pos = m
    if handler then
      pcall(handler, mods, count)
    end
    mouse_pos = nil
  end)
  return ''
end, vim.api.nvim_create_namespace 'ide_tree_mouse')

local function nt_cmd(name)
  local state = neo_state()
  if not state then
    return
  end
  local ok, cmds = pcall(require, 'neo-tree.sources.filesystem.commands')
  if ok and type(cmds[name]) == 'function' then
    pcall(cmds[name], state)
  end
end
vim.api.nvim_create_user_command('TreeCreate', function()
  nt_cmd 'add'
end, { desc = 'Tree: new file/folder (trailing / = folder)' })
vim.api.nvim_create_user_command('TreeRename', function()
  nt_cmd 'rename_basename'
end, { desc = 'Tree: rename' })
vim.api.nvim_create_user_command('TreeDelete', function()
  nt_cmd 'delete'
end, { desc = 'Tree: delete (confirms)' })
vim.api.nvim_create_user_command('TreeCut', function()
  nt_cmd 'cut_to_clipboard'
end, { desc = 'Tree: cut' })
vim.api.nvim_create_user_command('TreeCopy', function()
  nt_cmd 'copy_to_clipboard'
end, { desc = 'Tree: copy' })
vim.api.nvim_create_user_command('TreePaste', function()
  nt_cmd 'paste_from_clipboard'
end, { desc = 'Tree: paste here' })
vim.api.nvim_create_user_command('TreeCopyRelPath', function()
  local path = neo_node_path(neo_cursor_node())
  if path then
    local rel = vim.fn.fnamemodify(path, ':.')
    vim.fn.setreg('+', rel)
    vim.fn.setreg('*', rel)
    vim.notify('Copied relative path: ' .. rel, vim.log.levels.INFO)
  end
end, { desc = 'Tree: copy relative path' })
vim.api.nvim_create_user_command('TreeCopyAbsPath', function()
  local path = neo_node_path(neo_cursor_node())
  if path then
    vim.fn.setreg('+', path)
    vim.fn.setreg('*', path)
    vim.notify('Copied path: ' .. path, vim.log.levels.INFO)
  end
end, { desc = 'Tree: copy absolute path' })
vim.api.nvim_create_user_command('TreeCopyName', function()
  local node = neo_cursor_node()
  if node then
    vim.fn.setreg('+', node.name)
    vim.fn.setreg('*', node.name)
    vim.notify('Copied name: ' .. node.name, vim.log.levels.INFO)
  end
end, { desc = 'Tree: copy file name' })
vim.api.nvim_create_user_command('TreeOpenSide', function()
  local node = neo_cursor_node()
  if not node then
    return
  end
  if node.type == 'directory' then
    nt_cmd 'toggle_node'
    return
  end
  local path = neo_node_path(node)
  if not path then
    return
  end
  local win = editor_win()
  if not win then
    vim.cmd 'vsplit'
    win = vim.api.nvim_get_current_win()
  end
  vim.api.nvim_set_current_win(win)
  vim.cmd 'vsplit'
  vim.cmd('edit ' .. vim.fn.fnameescape(path))
end, { desc = 'Tree: open file in a side split' })
vim.api.nvim_create_user_command('TreeReveal', function()
  local path = neo_node_path(neo_cursor_node())
  if not path then
    return
  end
  if vim.fn.isdirectory(path) == 0 then
    path = vim.fn.fnamemodify(path, ':h')
  end
  vim.ui.open(path)
end, { desc = 'Tree: reveal in Finder/File Explorer' })
vim.api.nvim_create_user_command('TreeTermHere', function()
  local path = neo_node_path(neo_cursor_node())
  local dir = vim.fn.getcwd()
  if path then
    if vim.fn.isdirectory(path) == 1 then
      dir = path
    else
      dir = vim.fn.fnamemodify(path, ':h')
    end
  end
  vim.cmd('IdeTermNew ' .. vim.fn.fnameescape(dir))
end, { desc = 'Tree: open terminal here' })
vim.api.nvim_create_user_command('TreeExpandAll', function()
  nt_cmd 'expand_all_nodes'
end, { desc = 'Tree: expand all folders' })
vim.api.nvim_create_user_command('TreeCollapseAll', function()
  nt_cmd 'close_all_nodes'
end, { desc = 'Tree: collapse all folders' })
vim.api.nvim_create_user_command('TreeRefresh', function()
  nt_cmd 'refresh'
end, { desc = 'Tree: refresh' })
vim.cmd [[
  anoremenu TreePopUp.New\ File/Folder… :TreeCreate<CR>
  anoremenu TreePopUp.Open\ to\ the\ Side :TreeOpenSide<CR>
  anoremenu TreePopUp.Reveal\ in\ Finder :TreeReveal<CR>
  anoremenu TreePopUp.Open\ Terminal\ Here :TreeTermHere<CR>
  anoremenu TreePopUp.-sep1- <Nop>
  anoremenu TreePopUp.Cut :TreeCut<CR>
  anoremenu TreePopUp.Copy :TreeCopy<CR>
  anoremenu TreePopUp.Paste :TreePaste<CR>
  anoremenu TreePopUp.Rename… :TreeRename<CR>
  anoremenu TreePopUp.Delete :TreeDelete<CR>
  anoremenu TreePopUp.-sep2- <Nop>
  anoremenu TreePopUp.Copy\ Name :TreeCopyName<CR>
  anoremenu TreePopUp.Copy\ Path :TreeCopyAbsPath<CR>
  anoremenu TreePopUp.Copy\ Relative\ Path :TreeCopyRelPath<CR>
  anoremenu TreePopUp.-sep3- <Nop>
  anoremenu TreePopUp.Expand\ All :TreeExpandAll<CR>
  anoremenu TreePopUp.Collapse\ All :TreeCollapseAll<CR>
  anoremenu TreePopUp.Refresh :TreeRefresh<CR>
]]

return { mappings = neo_mappings }
