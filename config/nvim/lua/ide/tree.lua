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

-- Clicks must act on the clicked row, not the cursor row. Without this a
-- click on a file expands the previously-focused folder below it.
-- Always the release row: a press on one row and release on another is a
-- sloppy tap, not a drag (text selection is disabled in the tree anyway).
local function neo_node_at_mouse(state)
  local m = vim.fn.getmousepos()
  if m.winid == 0 then
    return nil
  end
  local ok_buf, buf = pcall(vim.api.nvim_win_get_buf, m.winid)
  if not ok_buf or vim.bo[buf].filetype ~= 'neo-tree' then
    return nil -- click outside the tree
  end
  if m.line < 1 or m.line > vim.api.nvim_buf_line_count(buf) then
    return nil -- empty space below the tree: select nothing, open nothing
  end
  pcall(vim.api.nvim_set_current_win, m.winid)
  pcall(vim.api.nvim_win_set_cursor, m.winid, { m.line, 0 })
  return neo_cursor_node(state)
end

-- neo-tree mapping functions swallow the press event, so record it and
-- perform the default click behavior ourselves (cursor follows the mouse).
-- Plain presses also preview files immediately: trackpad taps often drift a
-- row between press and release, and waiting for release meant the first tap
-- was swallowed as a "drag". Folders still toggle on release.
local function neo_record_press(state, do_preview)
  local m = vim.fn.getmousepos()
  neo_press.winid = m.winid
  neo_press.line = m.line
  neo_press.opened = false
  local ok, buf = pcall(vim.api.nvim_win_get_buf, m.winid)
  neo_press.buf = ok and buf or -1
  if not ok or vim.bo[buf].filetype ~= 'neo-tree' then
    return
  end
  pcall(vim.api.nvim_set_current_win, m.winid)
  if m.line < 1 or m.line > vim.api.nvim_buf_line_count(buf) then
    return
  end
  pcall(vim.api.nvim_win_set_cursor, m.winid, { m.line, 0 })
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

local function neo_preview_at_mouse(state)
  local node = neo_node_at_mouse(state)
  if node then
    neo_open_node(state, node, false)
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

local function neo_exit_visual_for_click()
  -- Synchronous (verified `:normal! <Esc>` exits visual immediately).
  pcall(vim.cmd, 'normal! \27')
end

-- Hover highlights the hovered row (cursorline follows the mouse) without
-- opening anything. Only while the tree is focused, so hovering the tree
-- from the editor never steals the selection.
local function neo_hover()
  local m = vim.fn.getmousepos()
  if m.winid == 0 or m.winid ~= vim.api.nvim_get_current_win() then
    return
  end
  local ok_buf, buf = pcall(vim.api.nvim_win_get_buf, m.winid)
  if not ok_buf or vim.bo[buf].filetype ~= 'neo-tree' then
    return
  end
  if m.line < 1 or m.line > vim.api.nvim_buf_line_count(buf) then
    return
  end
  pcall(vim.api.nvim_win_set_cursor, m.winid, { m.line, 0 })
end

-- Right-click: Cursor-style file/folder actions menu (see TreePopUp).
local function neo_show_tree_menu(state)
  neo_node_at_mouse(state) -- position the cursor; menu acts on it
  vim.cmd 'popup TreePopUp'
end

-- Single click / Shift+click: preview in the editor, keep focus in the tree.
-- The press usually previewed the file already; a release on the same row
-- then does nothing, a release elsewhere opens that row instead.
local function neo_single_click(state)
  if vim.uv.now() - neo_last_pin < 300 then
    return -- final release of a double-click: keep focus in the editor
  end
  local m = vim.fn.getmousepos()
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

local neo_mappings = {
  ['<CR>'] = neo_open_focused,
  -- `o` replaces neo-tree's order-by submenu: open like an IDE instead.
  ['o'] = neo_open_focused,
  ['<2-LeftMouse>'] = neo_pin_at_mouse,
  ['<LeftMouse>'] = function(state)
    neo_record_press(state, true)
  end,
  ['<S-LeftMouse>'] = function(state)
    neo_record_press(state, true)
  end,
  ['<C-LeftMouse>'] = function(state)
    neo_record_press(state, false)
  end,
  -- Tree text selection is useless (copy via right-click menu instead) and
  -- fights with click-vs-drag detection, so swallow drags. Separator drags
  -- (sidebar resize) are on the separator, not this buffer, and still work.
  ['<LeftDrag>'] = function() end,
  ['<S-LeftDrag>'] = function() end,
  ['<LeftRelease>'] = neo_single_click,
  ['<S-LeftRelease>'] = neo_single_click,
  -- Ctrl+click (Cmd+click equivalent): open to the side, focus the editor.
  ['<C-LeftRelease>'] = neo_side_at_mouse,
  -- Middle-click: open to the side (browser-style). The press is swallowed
  -- so it never pastes into the tree buffer.
  ['<MiddleMouse>'] = function() end,
  ['<MiddleRelease>'] = neo_side_at_mouse,
  ['<MouseMove>'] = neo_hover,
  ['<RightMouse>'] = neo_show_tree_menu,
  -- Double-right-click shows the menu too (no surprise root changes).
  ['<2-RightMouse>'] = neo_show_tree_menu,
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
}

-- Visual/select-mode safety net: a trackpad tap with the slightest movement
-- starts visual mode instead of clicking. These exit visual and open the
-- clicked row anyway; text yank/put stay disabled so the tree never acts
-- like a text buffer (node ops live on normal-mode keys).
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'neo-tree',
  desc = 'File tree: panel display, mouse without text selection',
  callback = function(ev)
    vim.opt_local.list = false
    vim.opt_local.wrap = false
    vim.keymap.set({ 'x', 's' }, '<LeftMouse>', function()
      neo_record_press(nil, false)
    end, { buffer = ev.buf, desc = 'Record press' })
    vim.keymap.set({ 'x', 's' }, '<S-LeftMouse>', function()
      neo_record_press(nil, false)
    end, { buffer = ev.buf, desc = 'Record press' })
    vim.keymap.set({ 'x', 's' }, '<LeftDrag>', function() end, { buffer = ev.buf, desc = 'No text drag in tree' })
    vim.keymap.set({ 'x', 's' }, '<S-LeftDrag>', function() end, { buffer = ev.buf, desc = 'No text drag in tree' })
    vim.keymap.set({ 'x', 's' }, '<MiddleMouse>', function() end, { buffer = ev.buf, desc = 'Swallow middle press' })
    local function visual_release(pin)
      neo_exit_visual_for_click()
      if pin then
        neo_pin_at_mouse(nil)
      else
        neo_single_click(nil)
      end
    end
    vim.keymap.set({ 'x', 's' }, '<LeftRelease>', function()
      visual_release(false)
    end, { buffer = ev.buf, desc = 'Open (single-click from visual)' })
    vim.keymap.set({ 'x', 's' }, '<S-LeftRelease>', function()
      visual_release(false)
    end, { buffer = ev.buf, desc = 'Open (shift-click from visual)' })
    vim.keymap.set({ 'x', 's' }, '<2-LeftMouse>', function()
      visual_release(true)
    end, { buffer = ev.buf, desc = 'Open file (double-click from visual)' })
    vim.keymap.set('x', 'y', '<Nop>', { buffer = ev.buf, desc = 'No text yank in tree' })
    vim.keymap.set('x', 'Y', '<Nop>', { buffer = ev.buf, desc = 'No text yank in tree' })
    vim.keymap.set('x', 'p', '<Nop>', { buffer = ev.buf, desc = 'No text put in tree' })
    -- Clicks from insert/terminal mode: record + leave the mode so the
    -- release lands in normal mode and opens on the first click.
    vim.keymap.set('i', '<LeftMouse>', function()
      vim.cmd 'stopinsert'
      neo_record_press(nil, true)
    end, { buffer = ev.buf, desc = 'Record press' })
    vim.keymap.set('t', '<LeftMouse>', function()
      neo_record_press(nil, false)
      if vim.api.nvim_get_mode().mode == 't' then
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes([[<C-\><C-n>]], true, false, true), 'n', false)
      end
    end, { buffer = ev.buf, desc = 'Record press' })
  end,
})

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
