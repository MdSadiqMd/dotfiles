-- Terminal panel: mouse-clickable tabs of builtin :terminal buffers, right or bottom.
-- Terminal buffers are unlisted and hidden from bufferline (its custom_filter).
local editor_win = require('ide.util').editor_win

local S = { terms = {}, idx = 0, dir = 'vertical', width = 50, height = 15 } -- terms: { buf, name, cwd }
local ide_term_show, ide_term_new, ide_term_kill, ide_term_next
local ide_term_buf_cwd

local function style_panel(win)
  vim.w[win].ide_term_panel = true
  vim.wo[win].winbar = '%!v:lua.IdeTermWinbar()'
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = 'no'
  vim.wo[win].winfixwidth = true -- keep its width when the layout rebalances
end

local function ide_term_panel_win()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.w[win].ide_term_panel then
      return win
    end
  end
  return nil
end

local function ide_term_panel_wins()
  local wins = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.w[win].ide_term_panel then
      wins[#wins + 1] = win
    end
  end
  return wins
end

local function ide_term_prune()
  local live, seen = {}, {}
  for _, t in ipairs(S.terms) do
    if not seen[t.buf] and vim.api.nvim_buf_is_valid(t.buf) then
      seen[t.buf] = true
      live[#live + 1] = t
    end
  end
  S.terms = live
  if #S.terms == 0 then
    S.idx = 0
  else
    S.idx = math.min(math.max(S.idx, 1), #S.terms)
  end
end

-- Clickable tab strip for the panel (pattern from bufferline.nvim source).
-- Single horizontal row: active tab always visible, overflow becomes …+N.
function _G.IdeTermWinbarClick(id, _clicks, button, _mods)
  if id == 999 then
    if button == 'l' then
      ide_term_new()
    end
  elseif id == 998 then
    if button == 'l' then
      ide_term_next()
    end
  elseif id >= 1000 then
    S.idx = id - 1000 -- the × of a tab: close it (any button)
    ide_term_kill()
  elseif button == 'l' then
    ide_term_show(id)
  elseif button == 'm' then
    S.idx = id
    ide_term_kill()
  end
end

function _G.IdeTermWinbar()
  ide_term_prune()
  if #S.terms == 0 then
    return ''
  end
  local draw_win = vim.g.statusline_winid
  if draw_win == nil or draw_win == 0 then
    draw_win = ide_term_panel_win()
  end
  -- Inactive pane: compact own-tab label so the full strip appears only once
  -- (in the focused pane). Plain text: clicking the pane focuses it natively.
  if type(vim.g.statusline_winid) == 'number' and vim.g.statusline_winid ~= 0 then
    local cur = vim.api.nvim_get_current_win()
    if draw_win ~= nil and draw_win ~= cur then
      local ok, b = pcall(vim.api.nvim_win_get_buf, draw_win)
      if ok then
        for i, t in ipairs(S.terms) do
          if t.buf == b then
            return '%#TabLineFill# ' .. i .. ':' .. t.name .. ' %#TabLine#%999@v:lua.IdeTermWinbarClick@ + %X%*'
          end
        end
      end
      return '%#TabLineFill# terminal %#TabLine#%999@v:lua.IdeTermWinbarClick@ + %X%*'
    end
  end
  local maxw = 80
  if draw_win ~= nil then
    local ok, w = pcall(vim.api.nvim_win_get_width, draw_win)
    if ok then
      maxw = math.max(w - 4, 24)
    end
  end
  local function tab_label(i, t, names)
    return names and (' ' .. i .. ':' .. t.name .. ' × ') or (' ' .. i .. ' × ')
  end
  local plus = ' + '
  local labels, widths = {}, {}
  for i, t in ipairs(S.terms) do
    labels[i] = tab_label(i, t, true)
    widths[i] = vim.fn.strdisplaywidth(labels[i])
  end
  local plus_w = vim.fn.strdisplaywidth(plus)
  local total = plus_w
  for _, w in ipairs(widths) do
    total = total + w
  end
  local names = total <= maxw
  if not names then
    for i, t in ipairs(S.terms) do
      labels[i] = tab_label(i, t, false)
      widths[i] = vim.fn.strdisplaywidth(labels[i])
    end
    total = plus_w
    for _, w in ipairs(widths) do
      total = total + w
    end
  end
  -- Fit active + newest tabs; overflow becomes …+N (click = next tab).
  local shown, hidden = {}, 0
  if total <= maxw then
    for i = 1, #S.terms do
      shown[#shown + 1] = i
    end
  else
    local overflow_w = 7 -- ' …+99 ' worst realistic case, reserved once
    local used = plus_w + widths[S.idx]
    local sel = { [S.idx] = true }
    for i = #S.terms, 1, -1 do
      if i ~= S.idx then
        if used + widths[i] + overflow_w <= maxw then
          used = used + widths[i]
          sel[i] = true
        else
          hidden = hidden + 1
        end
      end
    end
    for i = 1, #S.terms do
      if sel[i] then
        shown[#shown + 1] = i
      end
    end
  end
  local parts = { '%#TabLineFill#' }
  for _, i in ipairs(shown) do
    local hl = (i == S.idx) and '%#TabLineSel#' or '%#TabLine#'
    local core = names and (' ' .. i .. ':' .. S.terms[i].name) or (' ' .. i)
    parts[#parts + 1] = '%'
      .. i
      .. '@v:lua.IdeTermWinbarClick@'
      .. hl
      .. core
      .. '%X%*'
      .. '%'
      .. (1000 + i)
      .. '@v:lua.IdeTermWinbarClick@'
      .. hl
      .. ' × '
      .. '%X%*'
  end
  if hidden > 0 then
    parts[#parts + 1] = '%998@v:lua.IdeTermWinbarClick@%#TabLine# …+' .. hidden .. ' %X%*'
  end
  parts[#parts + 1] = '%#TabLine#%999@v:lua.IdeTermWinbarClick@' .. plus .. '%X%*'
  return table.concat(parts)
end

ide_term_show = function(idx)
  ide_term_prune()
  if #S.terms == 0 then
    return nil
  end
  if idx and idx >= 1 and idx <= #S.terms then
    S.idx = idx
  elseif S.idx < 1 or S.idx > #S.terms then
    S.idx = #S.terms
  end
  local cur = vim.api.nvim_get_current_win()
  local win = nil
  if vim.w[cur].ide_term_panel then
    win = cur -- a winbar click switches the tab in its own window
  else
    win = ide_term_panel_win()
  end
  if not win then
    if S.dir == 'vertical' then
      vim.cmd('botright ' .. S.width .. 'vsplit')
    else
      vim.cmd('botright ' .. S.height .. 'split')
    end
    win = vim.api.nvim_get_current_win()
    style_panel(win)
  end
  vim.api.nvim_win_set_buf(win, S.terms[S.idx].buf)
  vim.api.nvim_set_current_win(win)
  vim.cmd 'startinsert'
  vim.cmd.redrawstatus()
  return win
end

ide_term_new = function(cwd)
  ide_term_prune()
  local win = ide_term_panel_win()
  if win then
    vim.api.nvim_set_current_win(win)
  end
  if not ide_term_panel_win() then
    if S.dir == 'vertical' then
      vim.cmd('botright ' .. S.width .. 'vsplit')
    else
      vim.cmd('botright ' .. S.height .. 'split')
    end
  end
  -- The terminal job converts the current buffer, and panel windows show live
  -- terminals, so start from a fresh empty buffer.
  vim.cmd 'enew'
  if type(cwd) ~= 'string' or vim.fn.isdirectory(cwd) == 0 then
    cwd = vim.fn.getcwd()
  end
  vim.fn.jobstart({ vim.o.shell }, { term = true, cwd = cwd })
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buflisted = false -- keep the file tabs clean
  S.terms[#S.terms + 1] = { buf = buf, name = vim.o.shell:match '([^/]+)$' or 'term', cwd = cwd }
  S.idx = #S.terms
  -- Style AFTER :terminal: opening a terminal resets window options (winbar!).
  win = vim.api.nvim_get_current_win()
  style_panel(win)
  vim.cmd 'startinsert'
  vim.cmd.redrawstatus()
end

local function toggle_terminal_right()
  local wins = ide_term_panel_wins()
  if #wins > 0 then
    for _, win in ipairs(wins) do
      vim.api.nvim_win_close(win, false)
    end
    return
  end
  ide_term_prune()
  if #S.terms == 0 then
    ide_term_new()
  else
    ide_term_show()
  end
end

ide_term_next = function()
  ide_term_prune()
  if #S.terms == 0 then
    ide_term_new()
    return
  end
  ide_term_show(S.idx % #S.terms + 1)
end

local function ide_term_prev()
  ide_term_prune()
  if #S.terms == 0 then
    ide_term_new()
    return
  end
  ide_term_show((S.idx - 2) % #S.terms + 1)
end

ide_term_kill = function()
  ide_term_prune()
  if #S.terms == 0 then
    local win = ide_term_panel_win()
    if win then
      vim.api.nvim_win_close(win, false)
    end
    return
  end
  pcall(vim.api.nvim_buf_delete, S.terms[S.idx].buf, { force = true })
  ide_term_prune()
  if #S.terms == 0 then
    for _, win in ipairs(ide_term_panel_wins()) do
      vim.api.nvim_win_close(win, false)
    end
    return
  end
  -- Repoint panel windows left showing the dead buffer.
  for _, win in ipairs(ide_term_panel_wins()) do
    if not vim.api.nvim_buf_is_valid(vim.api.nvim_win_get_buf(win)) then
      vim.api.nvim_win_set_buf(win, S.terms[1].buf)
    end
  end
  S.idx = 1
  ide_term_show()
end

-- Move the panel right/bottom (mouse menu + commands). Reopens if visible.
local function ide_term_place(dir)
  S.dir = dir
  for _, win in ipairs(ide_term_panel_wins()) do
    vim.api.nvim_win_close(win, false)
  end
  ide_term_prune()
  if #S.terms == 0 then
    ide_term_new()
  else
    ide_term_show()
  end
end

-- Split the focused panel window to show another terminal beside it.
-- 'vertical' = side by side, 'horizontal' = stacked.
local function ide_term_split(dir)
  ide_term_prune()
  local cur = vim.api.nvim_get_current_win()
  local win = nil
  if vim.w[cur].ide_term_panel then
    win = cur
  else
    win = ide_term_panel_win()
  end
  if not win then
    if #S.terms == 0 then
      ide_term_new()
    else
      ide_term_show()
    end
    win = ide_term_panel_win()
  end
  vim.api.nvim_set_current_win(win)
  local visible = {}
  for _, w in ipairs(ide_term_panel_wins()) do
    visible[vim.api.nvim_win_get_buf(w)] = true
  end
  local target_idx = nil
  for i, t in ipairs(S.terms) do
    if not visible[t.buf] then
      target_idx = i
      break
    end
  end
  if dir == 'vertical' then
    vim.cmd 'vsplit'
  else
    vim.cmd 'split'
  end
  local newwin = vim.api.nvim_get_current_win()
  if target_idx then
    S.idx = target_idx
    vim.api.nvim_win_set_buf(newwin, S.terms[target_idx].buf)
  else
    vim.cmd 'terminal'
    local buf = vim.api.nvim_get_current_buf()
    vim.bo[buf].buflisted = false
    S.terms[#S.terms + 1] = { buf = buf, name = vim.o.shell:match '([^/]+)$' or 'term', cwd = vim.fn.getcwd() }
    S.idx = #S.terms
  end
  -- Style AFTER (a fresh :terminal resets window options, including winbar).
  style_panel(newwin)
  vim.cmd 'startinsert'
  vim.cmd.redrawstatus()
end
vim.keymap.set({ 'n', 't' }, '<C-`>', toggle_terminal_right, { desc = 'Toggle terminal panel (Cursor Ctrl+`)' })
vim.keymap.set({ 'n', 'i', 'v', 't' }, '<M-j>', toggle_terminal_right, { desc = 'Toggle terminal (Cursor Cmd+J)' })
-- Cursor Ctrl+Shift+`: new terminal tab (opens the panel if hidden).
local function ide_term_combo()
  ide_term_prune()
  if not ide_term_panel_win() and #S.terms > 0 then
    ide_term_show()
  else
    ide_term_new()
  end
end
vim.keymap.set({ 'n', 'i', 'v', 't' }, '<C-^>', ide_term_combo, { desc = 'New terminal tab (Cursor Ctrl+Shift+`)' })
vim.keymap.set({ 'n', 'i', 'v', 't' }, '<M-t>', ide_term_combo, { desc = 'New terminal tab (Cursor Ctrl+Shift+`)' })
vim.keymap.set('n', '<leader>tt', toggle_terminal_right, { desc = '[T]oggle [T]erminal panel' })
vim.keymap.set('n', '<leader>tn', ide_term_new, { desc = '[T]erminal [n]ew tab' })
vim.keymap.set('n', '<leader>tl', ide_term_next, { desc = '[T]erminal next tab' })
vim.keymap.set('n', '<leader>th', ide_term_prev, { desc = '[T]erminal previous tab' })
vim.keymap.set('n', '<leader>tv', function()
  ide_term_split 'vertical'
end, { desc = '[T]erminal split side by side' })
vim.keymap.set('n', '<leader>ts', function()
  ide_term_split 'horizontal'
end, { desc = '[T]erminal split stacked' })

-- Resolve a path clicked in terminal output (git status, tracebacks, diffs).
local function ide_resolve_term_path(fname, test)
  test = test or function(p)
    return vim.fn.filereadable(p) == 1
  end
  local dirs = {}
  local function push_ancestors(d)
    local depth = 0
    while d and d ~= '' and depth < 15 do
      dirs[#dirs + 1] = d
      local parent = vim.fn.fnamemodify(d, ':h')
      if parent == d then
        break
      end
      d = parent
      depth = depth + 1
    end
  end
  -- Nearest match upward (Node-style): covers same-dir files and
  -- repo-root-relative paths (git status) from any subdir, no git call.
  local tcwd = ide_term_buf_cwd(vim.api.nvim_get_current_buf())
  if tcwd then
    push_ancestors(tcwd)
  end
  push_ancestors(vim.fn.getcwd())
  local names = { fname }
  local stripped = fname:gsub('^[ab]/', '') -- git diff a/ b/ prefixes
  if stripped ~= fname then
    names[#names + 1] = stripped
  end
  for _, d in ipairs(dirs) do
    for _, n in ipairs(names) do
      local p = (n:sub(1, 1) == '/') and n or (d .. '/' .. n)
      if test(p) then
        return p
      end
    end
  end
  if fname:sub(1, 1) == '~' then
    local p = vim.fn.expand(fname)
    if test(p) then
      return p
    end
  end
  return nil
end

-- Cursor-style terminal links: open the file under the cursor in the middle
-- editor (with :line jumps). Falls back to word selection like a terminal.
--
-- Terminal panels are narrow, so long paths WRAP across buffer rows. Join
-- visually-wrapped fragments first (never across real entries/whitespace).
local function ide_is_entry_start(s)
  return s:match '^ ?[ MADRCU?!][ MADRCU?!] %S' ~= nil
end

-- A row joins across only if it carries no prompt/command markers:
-- wrapped path fragments have no spaces at all (the head row may
-- still carry its ` M `/`?? ` status prefix).
local function ide_join_up(prev)
  if prev == '' or prev:sub(-1) == ' ' then
    return false
  end
  if not prev:find(' ', 1, true) then
    return true
  end
  return ide_is_entry_start(prev)
end

local function ide_join_down(nxt)
  if nxt == '' or nxt:sub(1, 1) == ' ' then
    return false
  end
  if ide_is_entry_start(nxt) then
    return false
  end
  if nxt:match '^[%$#>%%]' then
    return false -- shell prompt on the next row
  end
  return not nxt:find(' ', 1, true)
end

local function ide_join_wrapped_lines(buf, row, c1)
  local last = vim.api.nvim_buf_line_count(buf)
  local function get(r)
    return vim.api.nvim_buf_get_lines(buf, r - 1, r, false)[1] or ''
  end
  local text = get(row)
  local top, joins = row, 0
  while joins < 3 and top > 1 and text:sub(1, 1) ~= '' and text:sub(1, 1) ~= ' ' do
    local prev = get(top - 1)
    if not ide_join_up(prev) then
      break
    end
    c1 = #prev + c1
    text = prev .. text
    top = top - 1
    joins = joins + 1
  end
  local bot = row
  joins = 0
  while joins < 3 and bot < last and text:sub(-1) ~= '' and text:sub(-1) ~= ' ' do
    local nxt = get(bot + 1)
    if not ide_join_down(nxt) then
      break
    end
    text = text .. nxt
    bot = bot + 1
    joins = joins + 1
  end
  return text, c1
end

function _G.IdeTermOpenPath()
  if vim.bo.buftype ~= 'terminal' then
    return
  end
  -- A double-click's second press arrives in terminal mode, where the cursor stays
  -- at the prompt: act on the clicked cell instead.
  local m = vim.fn.getmousepos()
  if m.winid == vim.api.nvim_get_current_win() and m.line > 0 then
    pcall(vim.api.nvim_win_set_cursor, 0, { m.line, math.max(m.column - 1, 0) })
  end
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local text, c1 = ide_join_wrapped_lines(vim.api.nvim_get_current_buf(), row, col + 1)
  -- Candidate names, best first: path:line span, isfname word (punctuation
  -- aware), whitespace word (wrapped fragments). First resolvable wins.
  local cands = {}
  for _, pat in ipairs { '()([%w%._%/%-+~]+%.[%w]+):(%d+)()', '()([%w%._%/%-+~]+):(%d+)()' } do
    for s, p, l, e in text:gmatch(pat) do
      if s <= c1 and c1 <= e then
        cands[#cands + 1] = { p, tonumber(l) }
        break
      end
    end
    if #cands > 0 then
      break
    end
  end
  local cf = vim.fn.expand '<cfile>'
  if cf ~= '' then
    cands[#cands + 1] = { cf, nil }
  end
  if text:sub(c1, c1):match '%S' then
    local s, e = c1, c1
    while s > 1 and text:sub(s - 1, s - 1):match '%S' do
      s = s - 1
    end
    while e < #text and text:sub(e + 1, e + 1):match '%S' do
      e = e + 1
    end
    local w = text:sub(s, e)
    if w ~= '' and w ~= cf then
      cands[#cands + 1] = { w, nil }
    end
  end
  for _, cand in ipairs(cands) do
    local path = ide_resolve_term_path(cand[1])
    if path then
      local win = editor_win()
      if not win then
        vim.cmd 'vsplit'
        win = vim.api.nvim_get_current_win()
      end
      vim.api.nvim_set_current_win(win)
      vim.cmd('edit ' .. vim.fn.fnameescape(path))
      if cand[2] then
        pcall(vim.api.nvim_win_set_cursor, 0, { cand[2], 0 })
      end
      return
    end
    -- Directories (git status `docs/`) reveal in the file tree instead.
    local dir = ide_resolve_term_path(cand[1], function(p)
      return vim.fn.isdirectory(p) == 1
    end)
    if dir then
      local ok, nt = pcall(require, 'neo-tree.command')
      if ok then
        pcall(nt.execute, { action = 'focus', source = 'filesystem', position = 'left', reveal_file = dir })
      end
      return
    end
  end
  -- Not a path: copy the word, as a double-click does in Ghostty.
  vim.cmd 'normal! viw"+y'
  vim.cmd 'startinsert'
end

-- Terminal mouse: right-click opens the IDE menu (splits live here;
-- without this, right-click shows nvim's default menu), double-click
-- a path to open it in the editor (Cursor terminal links; the t-mode
-- mapping exits to normal first, sequentially).
-- Terminals behave like Ghostty, not like text buffers: a drag copies the selection
-- and returns to the shell, typing after scrolling back goes to the shell, paste
-- always reaches the shell. Double-click still opens paths in the editor.
local function copy_and_resume()
  vim.cmd 'normal! "+y'
  vim.cmd 'startinsert'
end

vim.api.nvim_create_autocmd('TermOpen', {
  desc = 'Terminal: Ghostty-like mouse and keys',
  callback = function(ev)
    local function map(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = ev.buf, desc = desc })
    end
    map({ 'n', 't' }, '<RightMouse>', function()
      vim.cmd 'popup PopUp'
    end, 'Panel menu (right-click)')
    map('n', '<2-LeftMouse>', '<Cmd>lua IdeTermOpenPath()<CR>', 'Open path or copy word')
    map('t', '<2-LeftMouse>', '<C-\\><C-n><Cmd>lua IdeTermOpenPath()<CR>', 'Open path or copy word')
    map('x', '<LeftRelease>', copy_and_resume, 'Copy selection, back to the shell')
    map('x', '<S-LeftRelease>', copy_and_resume, 'Copy selection, back to the shell')
    -- Scrolled back (normal mode): any typed key returns to the shell and is sent.
    for c = 32, 126 do
      local key = c == 32 and '<Space>' or c == 60 and '<lt>' or c == 124 and '<Bar>' or c == 92 and '<Bslash>' or string.char(c)
      map('n', key, 'i' .. key, 'Type into the shell')
    end
    for _, key in ipairs { '<CR>', '<BS>', '<Tab>', '<Up>', '<Down>', '<C-c>', '<C-d>', '<C-r>' } do
      map('n', key, 'i' .. key, 'Type into the shell')
    end
  end,
})

-- Paste while scrolled back would hit a read-only buffer; send it to the shell instead.
local paste = vim.paste
vim.paste = function(lines, phase)
  if vim.bo.buftype == 'terminal' and vim.fn.mode() ~= 't' then
    vim.api.nvim_chan_send(vim.bo.channel, table.concat(lines, '\n'))
    if phase == -1 or phase == 3 then
      vim.cmd 'startinsert'
    end
    return true
  end
  return paste(lines, phase)
end

-- Cursor terminal: focusing a terminal is always ready to type.
-- (Selecting still works: Stay in the window after Esc Esc and drag,
-- or Shift+drag from anywhere for a Ghostty-native selection + Cmd+C.)
vim.api.nvim_create_autocmd({ 'BufEnter', 'WinEnter' }, {
  pattern = 'term://*',
  desc = 'Auto-enter insert mode when focusing a terminal',
  nested = true, -- startinsert must fire InsertEnter (autopairs lazy-load)
  callback = function()
    if vim.bo.buftype == 'terminal' then
      vim.cmd 'startinsert'
    end
  end,
})

vim.api.nvim_create_user_command('IdeTermNew', function(o)
  ide_term_new(o.args ~= '' and o.args or nil)
end, { nargs = '?', complete = 'dir', desc = 'New terminal tab (optional start dir)' })
vim.api.nvim_create_user_command('IdeTermNext', function()
  ide_term_next()
end, { desc = 'Next terminal tab' })
vim.api.nvim_create_user_command('IdeTermPrev', function()
  ide_term_prev()
end, { desc = 'Previous terminal tab' })
vim.api.nvim_create_user_command('IdeTermKill', function()
  ide_term_kill()
end, { desc = 'Close current terminal tab' })
vim.api.nvim_create_user_command('IdeTermRight', function()
  ide_term_place 'vertical'
end, { desc = 'Terminal panel on the right' })
vim.api.nvim_create_user_command('IdeTermBottom', function()
  ide_term_place 'horizontal'
end, { desc = 'Terminal panel at the bottom' })
vim.api.nvim_create_user_command('IdeTermVSplit', function()
  ide_term_split 'vertical'
end, { desc = 'Split terminal side by side' })
vim.api.nvim_create_user_command('IdeTermSplit', function()
  ide_term_split 'horizontal'
end, { desc = 'Split terminal stacked' })

-- Live cwd of a terminal's shell: users cd constantly, so the start dir is stale.
ide_term_buf_cwd = function(buf)
  local ok, job = pcall(vim.api.nvim_buf_get_var, buf, 'terminal_job_id')
  if not ok or type(job) ~= 'number' then
    return nil
  end
  local ok2, pid = pcall(vim.fn.jobpid, job)
  if not ok2 or type(pid) ~= 'number' or pid <= 0 then
    return nil
  end
  local proc = vim.uv.fs_readlink('/proc/' .. pid .. '/cwd') -- Linux: no process spawn
  if proc then
    return proc
  end
  local ok3, out = pcall(vim.fn.systemlist, 'lsof -a -d cwd -p ' .. pid .. ' -F n 2>/dev/null')
  if not ok3 or type(out) ~= 'table' then
    return nil
  end
  for _, line in ipairs(out) do
    if line:sub(1, 1) == 'n' then
      local dir = line:sub(2)
      if dir ~= '' and vim.fn.isdirectory(dir) == 1 then
        return dir
      end
    end
  end
  return nil
end

return {
  state = S,
  new = ide_term_new,
  show = ide_term_show,
  kill = ide_term_kill,
  toggle = toggle_terminal_right,
  panel_win = ide_term_panel_win,
  panel_wins = ide_term_panel_wins,
  buf_cwd = ide_term_buf_cwd,
}
