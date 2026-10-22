-- Cursor gutter peek: single-click a changed line's gutter sign to open a
-- focused diff popup with revert / stage / navigate actions.
-- Plain text clicks, drags and other windows behave exactly as before.
local click_press = {}
vim.keymap.set('n', '<LeftMouse>', function()
  local m = vim.fn.getmousepos()
  click_press = { winid = m.winid, line = m.line, wincol = m.wincol }
  return '<LeftMouse>' -- expr results are literal: performs the default click
end, { expr = true, replace_keycodes = true, desc = 'Record click position' })

local function line_in_hunk(bufnr, line)
  local ok, hunks = pcall(require('gitsigns').get_hunks, bufnr)
  if not ok or not hunks then
    return false
  end
  for _, h in ipairs(hunks) do
    local s, c = h.added.start, h.added.count
    if line >= s and line <= s + math.max(c, 1) then
      return true
    end
  end
  return false
end

local function open_hunk_peek(orig_win)
  local ok, gitsigns = pcall(require, 'gitsigns')
  if not ok then
    return
  end
  gitsigns.preview_hunk()
  gitsigns.preview_hunk() -- second call focuses the popup
  local peek_win = vim.api.nvim_get_current_win()
  if peek_win == orig_win then
    return -- no preview opened (no hunk under cursor)
  end
  local peek_buf = vim.api.nvim_win_get_buf(peek_win)
  local function back_to_code()
    pcall(vim.api.nvim_win_close, peek_win, true)
    if vim.api.nvim_win_is_valid(orig_win) then
      vim.api.nvim_set_current_win(orig_win)
    end
  end
  local function goto_hunk(dir)
    back_to_code()
    gitsigns.nav_hunk(dir)
    open_hunk_peek(orig_win)
  end
  local function peek_map(key, fn, desc)
    vim.keymap.set('n', key, fn, { buffer = peek_buf, desc = desc })
  end
  peek_map('r', function()
    back_to_code()
    gitsigns.reset_hunk() -- Cursor's revert-arrow
  end, 'Revert hunk')
  peek_map('s', function()
    back_to_code()
    gitsigns.stage_hunk() -- Cursor's stage-plus
  end, 'Stage hunk')
  peek_map('n', function()
    goto_hunk 'next'
  end, 'Next change')
  peek_map('N', function()
    goto_hunk 'prev'
  end, 'Previous change')
  peek_map(']c', function()
    goto_hunk 'next'
  end, 'Next change')
  peek_map('[c', function()
    goto_hunk 'prev'
  end, 'Previous change')
  peek_map('q', back_to_code, 'Close peek')
  peek_map('<Esc>', back_to_code, 'Close peek')
end

vim.keymap.set('n', '<LeftRelease>', function()
  local m = vim.fn.getmousepos()
  if m.winid == 0 or m.winid ~= click_press.winid or m.line ~= click_press.line or m.wincol ~= (click_press.wincol or -1) then
    return -- drag or cross-window: ignore
  end
  local buf = vim.api.nvim_win_get_buf(m.winid)
  -- Cursor terminal: a clean click (no drag) focuses the shell for typing,
  -- even inside the already-focused terminal. Drags still select text.
  if vim.bo[buf].buftype == 'terminal' then
    vim.cmd 'startinsert'
    return
  end
  local wi = vim.fn.getwininfo(m.winid)[1]
  if not wi then
    return
  end
  -- textoff covers fold+sign+number columns; the sign strip sits before numbers.
  local wo = vim.wo[m.winid]
  local sign_end = wi.textoff - (wo.number and wo.numberwidth or 0) - (tonumber(wo.foldcolumn) or 0)
  if m.wincol > sign_end or (click_press.wincol or 99) > sign_end then
    return -- text/number area: ignore
  end
  if vim.bo[buf].buftype ~= '' or vim.bo[buf].filetype == 'neo-tree' then
    return
  end
  if line_in_hunk(buf, m.line) then
    vim.api.nvim_set_current_win(m.winid)
    open_hunk_peek(m.winid)
  end
end, { desc = 'Gutter click opens hunk peek' })
