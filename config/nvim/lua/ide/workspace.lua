-- Per-project workspace restore: open files, cursor, terminal cwds and panel sizes,
-- keyed by git root (or cwd) in stdpath('data')/ide-files.json.
local term = require 'ide.terminal'
local S = term.state

-- Preserve open files across restarts, per directory (Cursor workspace restore).
-- Terminals always start fresh; the tree/panel rebuild via the layout below.
local function ide_state_path()
  return _G.IdeStatePath or (vim.fn.stdpath 'data' .. '/ide-files.json')
end

local function ide_read_state()
  local ok, lines = pcall(vim.fn.readfile, ide_state_path())
  if not ok then
    return {}
  end
  local ok2, data = pcall(vim.json.decode, table.concat(lines, '\n'))
  if ok2 and type(data) == 'table' then
    return data
  end
  return {}
end

-- Workspace key: git root when inside a repo (reopening from any subdir
-- restores the same files), plain cwd otherwise. Cached per cwd.
local ide_key_cache = {}
vim.api.nvim_create_autocmd('DirChanged', {
  desc = 'Drop cached workspace key',
  callback = function()
    ide_key_cache = {}
  end,
})
local function ide_state_key()
  local cwd = vim.fn.getcwd()
  if not ide_key_cache[cwd] then
    local git = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
    if vim.v.shell_error == 0 and git ~= '' then
      ide_key_cache[cwd] = git
    else
      ide_key_cache[cwd] = cwd
    end
  end
  return ide_key_cache[cwd]
end

local last_written
local function ide_save_files(final)
  local state = ide_read_state()
  local cwd = ide_state_key()
  local files = {}
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.fn.buflisted(b) == 1 and vim.bo[b].buftype == '' and vim.bo[b].filetype ~= 'neo-tree' then
      local name = vim.api.nvim_buf_get_name(b)
      if name ~= '' and vim.fn.filereadable(name) == 1 then
        files[#files + 1] = name
        if #files >= 25 then
          break
        end
      end
    end
  end
  -- Live terminal cwds cost a process spawn each (lsof), so only the final save
  -- looks them up; periodic saves reuse the last known cwd.
  local terms = {}
  for _, t in ipairs(S.terms) do
    if vim.api.nvim_buf_is_valid(t.buf) and #terms < 10 then
      if final then
        t.cwd = term.buf_cwd(t.buf) or t.cwd
      end
      terms[#terms + 1] = t.cwd or vim.fn.getcwd()
    end
  end
  -- Chrome sizes: tree width + terminal panel size/dir (non-floating only).
  -- Missing windows keep their previous saved sizes (e.g. tree was toggled
  -- off); locals stay live so reopening in-session keeps resized sizes.
  local tree_width = nil
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(w).relative == '' and vim.bo[vim.api.nvim_win_get_buf(w)].filetype == 'neo-tree' then
      tree_width = vim.api.nvim_win_get_width(w)
      break
    end
  end
  local panel = term.panel_win()
  local termsize = { dir = S.dir, width = S.width, height = S.height }
  if panel and vim.api.nvim_win_get_config(panel).relative == '' then
    if S.dir == 'vertical' then
      termsize.width = vim.api.nvim_win_get_width(panel)
    else
      termsize.height = vim.api.nvim_win_get_height(panel)
    end
    S.width, S.height = termsize.width, termsize.height
  end
  if #files == 0 and #terms == 0 then
    if not final then
      return -- don't wipe good state on transient empty moments (startup)
    end
    state[cwd] = nil -- everything closed: reopen to blank, not stale
  else
    -- Active/cursor only when quitting from a real file (not the terminal:
    -- term:// paths can never be re-focused on restore).
    local cur_buf = vim.api.nvim_get_current_buf()
    local cur_name = vim.api.nvim_buf_get_name(cur_buf)
    local active, cursor = '', { 1, 1 }
    if vim.bo[cur_buf].buftype == '' and cur_name ~= '' and vim.fn.filereadable(cur_name) == 1 then
      active = cur_name
      cursor = { vim.fn.line '.', vim.fn.col '.' }
    end
    local prev = type(state[cwd]) == 'table' and state[cwd] or {}
    state[cwd] = {
      files = files,
      active = active,
      cursor = cursor,
      terms = terms,
      tree_width = tree_width or prev.tree_width,
      termsize = (panel and termsize or prev.termsize) or termsize,
    }
  end
  local json = vim.json.encode(state)
  if json ~= last_written then
    last_written = json
    pcall(vim.fn.writefile, { json }, ide_state_path())
  end
end

local function ide_restore_files()
  -- Only onto a blank editor (never clobber real content).
  if vim.fn.expand '%' ~= '' or vim.bo.modified then
    return false
  end
  local state = ide_read_state()[ide_state_key()]
  if type(state) ~= 'table' then
    return false
  end
  -- Chrome sizes first: new panels open at the saved size, tree/panel are
  -- reapplied exactly at the end (splits rebalance as windows open).
  if type(state.termsize) == 'table' then
    if state.termsize.dir == 'vertical' or state.termsize.dir == 'horizontal' then
      S.dir = state.termsize.dir
    end
    if type(state.termsize.width) == 'number' then
      S.width = math.min(math.max(state.termsize.width, 20), math.max(vim.o.columns - 40, 30))
    end
    if type(state.termsize.height) == 'number' then
      S.height = math.min(math.max(state.termsize.height, 5), math.max(vim.o.lines - 10, 10))
    end
  end
  vim.g.ide_restoring = true -- pause BufEnter saves until done
  local did = false
  if type(state.files) == 'table' and #state.files > 0 then
    local opened = false
    for _, path in ipairs(state.files) do
      if vim.fn.filereadable(path) == 1 then
        if not opened then
          vim.cmd('edit ' .. vim.fn.fnameescape(path))
          opened = true
        else
          vim.cmd('badd ' .. vim.fn.fnameescape(path))
        end
      end
    end
    if opened then
      did = true
      if type(state.active) == 'string' and state.active ~= '' then
        for _, b in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_get_name(b) == state.active then
            vim.api.nvim_set_current_buf(b)
            if type(state.cursor) == 'table' then
              pcall(vim.api.nvim_win_set_cursor, 0, { state.cursor[1] or 1, (state.cursor[2] or 1) - 1 })
              vim.cmd 'normal! zz'
            end
            break
          end
        end
      end
    end
  end
  -- Terminal tabs: fresh shells in the saved cwds (live ptys can't persist).
  if type(state.terms) == 'table' and #state.terms > 0 then
    for _, w in ipairs(term.panel_wins()) do
      pcall(vim.api.nvim_win_close, w, false)
    end
    for _, t in ipairs(S.terms) do
      pcall(vim.api.nvim_buf_delete, t.buf, { force = true })
    end
    S.terms = {}
    S.idx = 0
    for _, c in ipairs(state.terms) do
      if type(c) == 'string' and vim.fn.isdirectory(c) == 1 then
        term.new(c)
      end
    end
    if #S.terms == 0 then
      term.new()
    end
    did = true
  end
  -- Reapply chrome sizes last, exactly as left (splits rebalanced above).
  if type(state.tree_width) == 'number' then
    local w = math.min(math.max(state.tree_width, 15), math.max(math.floor(vim.o.columns / 2), 20))
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_config(win).relative == '' and vim.bo[vim.api.nvim_win_get_buf(win)].filetype == 'neo-tree' then
        pcall(vim.api.nvim_win_set_width, win, w)
        break
      end
    end
  end
  local panel = term.panel_win()
  if panel then
    if S.dir == 'vertical' then
      pcall(vim.api.nvim_win_set_width, panel, S.width)
    else
      pcall(vim.api.nvim_win_set_height, panel, S.height)
    end
  end
  vim.g.ide_restoring = false
  return did
end

-- Saves are debounced: switching buffers fires BufEnter in bursts.
local timer = assert(vim.uv.new_timer())
vim.api.nvim_create_autocmd({ 'FocusLost', 'BufEnter', 'WinResized' }, {
  desc = 'Remember open files and window sizes for next launch',
  callback = function()
    timer:start(
      1000,
      0,
      vim.schedule_wrap(function()
        if not vim.g.ide_restoring then
          ide_save_files(false)
        end
      end)
    )
  end,
})
vim.api.nvim_create_autocmd('VimLeavePre', {
  desc = 'Final workspace save (the only one allowed to clear state)',
  callback = function()
    timer:stop()
    if not vim.g.ide_restoring then
      ide_save_files(true)
    end
  end,
})

vim.api.nvim_create_user_command('IdeFiles', function()
  local st = ide_read_state()[ide_state_key()]
  if type(st) ~= 'table' or type(st.files) ~= 'table' or #st.files == 0 then
    vim.notify('No saved files for this project', vim.log.levels.INFO)
    return
  end
  vim.notify(table.concat(st.files, '\n'), vim.log.levels.INFO)
end, { desc = 'Show saved workspace files' })

vim.api.nvim_create_user_command('IdeTerms', function()
  local lines = {}
  for i, t in ipairs(S.terms) do
    lines[#lines + 1] = string.format('tab %d buf=%d valid=%s', i, t.buf, tostring(vim.api.nvim_buf_is_valid(t.buf)))
  end
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.w[w].ide_term_panel then
      lines[#lines + 1] = string.format('panel win=%d buf=%d', w, vim.api.nvim_win_get_buf(w))
    end
  end
  if #lines == 0 then
    lines = { 'no terminals' }
  end
  vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO)
end, { desc = 'Show terminal panel state (debug)' })

if vim.env.NVIM_IDE_TEST then
  _G.IdeTest = { save = ide_save_files, restore = ide_restore_files, term_cwd = term.buf_cwd }
end

return { restore = ide_restore_files }
