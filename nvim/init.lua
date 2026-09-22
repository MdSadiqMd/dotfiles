--[[

=====================================================================
==================== READ THIS BEFORE CONTINUING ====================
=====================================================================
========                                    .-----.          ========
========         .----------------------.   | === |          ========
========         |.-""""""""""""""""""-.|   |-----|          ========
========         ||                    ||   | === |          ========
========         ||   KICKSTART.NVIM   ||   |-----|          ========
========         ||                    ||   | === |          ========
========         ||                    ||   |-----|          ========
========         ||:Tutor              ||   |:::::|          ========
========         |'-..................-'|   |____o|          ========
========         `"")----------------(""`   ___________      ========
========        /::::::::::|  |::::::::::\  \ no mouse \     ========
========       /:::========|  |==hjkl==:::\  \ required \    ========
========      '""""""""""""'  '""""""""""""'  '""""""""""'   ========
========                                                     ========
=====================================================================
=====================================================================

What is Kickstart?

  Kickstart.nvim is *not* a distribution.

  Kickstart.nvim is a starting point for your own configuration.
    The goal is that you can read every line of code, top-to-bottom, understand
    what your configuration is doing, and modify it to suit your needs.

    Once you've done that, you can start exploring, configuring and tinkering to
    make Neovim your own! That might mean leaving Kickstart just the way it is for a while
    or immediately breaking it into modular pieces. It's up to you!

    If you don't know anything about Lua, I recommend taking some time to read through
    a guide. One possible example which will only take 10-15 minutes:
      - https://learnxinyminutes.com/docs/lua/

    After understanding a bit more about Lua, you can use `:help lua-guide` as a
    reference for how Neovim integrates Lua.
    - :help lua-guide
    - (or HTML version): https://neovim.io/doc/user/lua-guide.html

Kickstart Guide:

  TODO: The very first thing you should do is to run the command `:Tutor` in Neovim.

    If you don't know what this means, type the following:
      - <escape key>
      - :
      - Tutor
      - <enter key>

    (If you already know the Neovim basics, you can skip this step.)

  Once you've completed that, you can continue working through **AND READING** the rest
  of the kickstart init.lua.

  Next, run AND READ `:help`.
    This will open up a help window with some basic information
    about reading, navigating and searching the builtin help documentation.

    This should be the first place you go to look when you're stuck or confused
    with something. It's one of my favorite Neovim features.

    MOST IMPORTANTLY, we provide a keymap "<space>sh" to [s]earch the [h]elp documentation,
    which is very useful when you're not exactly sure of what you're looking for.

  I have left several `:help X` comments throughout the init.lua
    These are hints about where to find more information about the relevant settings,
    plugins or Neovim features used in Kickstart.

   NOTE: Look for lines like this

    Throughout the file. These are for you, the reader, to help you understand what is happening.
    Feel free to delete them once you know what you're doing, but they should serve as a guide
    for when you are first encountering a few different constructs in your Neovim config.

If you experience any errors while trying to install kickstart, run `:checkhealth` for more info.

I hope you enjoy your Neovim journey,
- TJ

P.S. You can delete this when you're done too. It's your config now! :)
--]]

-- Set <space> as the leader key
-- See `:help mapleader`
--  NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- neo-tree (left sidebar) replaces netrw
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Set to true if you have a Nerd Font installed and selected in the terminal
vim.g.have_nerd_font = true

-- [[ Setting options ]]
-- See `:help vim.o`
-- NOTE: You can change these options as you wish!
--  For more options, you can see `:help option-list`

-- Make line numbers default
vim.o.number = true
-- You can also add relative line numbers, to help with jumping.
--  Experiment for yourself to see if you like it!
-- vim.o.relativenumber = true

-- Enable mouse mode, can be useful for resizing splits for example!
vim.o.mouse = 'a'
-- Cursor-like mouse: right-click shows popup menu, hover events on, smooth scroll
vim.o.mousemodel = 'popup'
-- Forgiving double-click window (trackpads): clicks within 1s still multi-click
vim.o.mousetime = 1000
pcall(function()
  vim.o.mousemoveevent = true
end)
-- Rounded floating windows (hovers, git previews). Ignored on older Neovim.
pcall(function()
  vim.o.winborder = 'rounded'
end)

-- Don't show the mode, since it's already in the status line
vim.o.showmode = false

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.schedule(function()
  vim.o.clipboard = 'unnamedplus'
end)

-- Enable break indent
vim.o.breakindent = true

-- Save undo history
vim.o.undofile = true

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.o.ignorecase = true
vim.o.smartcase = true

-- Keep signcolumn on by default
vim.o.signcolumn = 'yes'

-- Decrease update time
vim.o.updatetime = 250

-- Decrease mapped sequence wait time
vim.o.timeoutlen = 300

-- Configure how new splits should be opened
vim.o.splitright = true
vim.o.splitbelow = true

-- Sets how neovim will display certain whitespace characters in the editor.
--  See `:help 'list'`
--  and `:help 'listchars'`
--
--  Notice listchars is set using `vim.opt` instead of `vim.o`.
--  It is very similar to `vim.o` but offers an interface for conveniently interacting with tables.
--   See `:help lua-options`
--   and `:help lua-options-guide`
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Preview substitutions live, as you type!
vim.o.inccommand = 'split'

-- Show which line your cursor is on
vim.o.cursorline = true

-- True color (Ghostty supports it). Required for the dark theme + git colors.
vim.o.termguicolors = true

-- Always show the open-files tabs bar (Cursor-like).
vim.o.showtabline = 2

-- Minimal number of screen lines to keep above and below the cursor.
vim.o.scrolloff = 10

-- if performing an operation that would fail due to unsaved changes in the buffer (like `:q`),
-- instead raise a dialog asking if you wish to save the current file(s)
-- See `:help 'confirm'`
vim.o.confirm = true

-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Diagnostic keymaps
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- TIP: Disable arrow keys in normal mode
-- vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
-- vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
-- vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
-- vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- [[ Cursor-like IDE layout: explorer left, terminal right ]]
-- Left file explorer (neo-tree sidebar, mouse-driven IDE panel).
-- Single-click previews, double-click pins, files open in the middle window.
local function toggle_explorer_left()
  local ok, nt = pcall(require, 'neo-tree.command')
  if ok then
    nt.execute { action = 'focus', source = 'filesystem', position = 'left', toggle = true }
  else
    vim.notify('Explorer not installed yet: run :Lazy sync', vim.log.levels.WARN)
  end
end
vim.keymap.set('n', '<leader>e', toggle_explorer_left, { desc = '[E]xplorer toggle left' })
vim.keymap.set({ 'n', 'i', 'v', 't' }, '<C-b>', toggle_explorer_left, { desc = 'Toggle explorer (Cursor Cmd+B)' })
vim.keymap.set({ 'n', 'i', 'v' }, '<M-e>', function()
  local ok, nt = pcall(require, 'neo-tree.command')
  if ok then
    pcall(nt.execute, { action = 'focus', source = 'filesystem', position = 'left' })
  end
end, { desc = 'Focus explorer (Cursor Cmd+Shift+E)' })

-- Terminal panel with multiple mouse-clickable tabs (Cursor's bottom/right panel).
-- Separate from the file tabs: terminal buffers are hidden from bufferline
-- (see its custom_filter) and marked unlisted. Zero plugins, builtin :terminal.
local ide_terms = {} -- { { buf = bufnr, name = 'zsh' }, ... }
local ide_term_idx = 0
local ide_term_dir = 'vertical' -- 'vertical' (right) or 'horizontal' (bottom)
local ide_term_width = 50 -- vertical panel width (drag the separator to resize)
local ide_term_height = 15 -- horizontal panel height
-- Forward declarations: the clickable winbar (below) runs after full startup.
local ide_term_show, ide_term_new, ide_term_kill, ide_term_next
local ide_term_buf_cwd

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
  for _, t in ipairs(ide_terms) do
    if not seen[t.buf] and vim.api.nvim_buf_is_valid(t.buf) then
      seen[t.buf] = true
      live[#live + 1] = t
    end
  end
  ide_terms = live
  if #ide_terms == 0 then
    ide_term_idx = 0
  else
    ide_term_idx = math.min(math.max(ide_term_idx, 1), #ide_terms)
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
    ide_term_idx = id - 1000 -- the × of a tab: close it (any button)
    ide_term_kill()
  elseif button == 'l' then
    ide_term_show(id)
  elseif button == 'm' then
    ide_term_idx = id
    ide_term_kill()
  end
end

function _G.IdeTermWinbar()
  ide_term_prune()
  if #ide_terms == 0 then
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
        for i, t in ipairs(ide_terms) do
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
  for i, t in ipairs(ide_terms) do
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
    for i, t in ipairs(ide_terms) do
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
    for i = 1, #ide_terms do
      shown[#shown + 1] = i
    end
  else
    local overflow_w = 7 -- ' …+99 ' worst realistic case, reserved once
    local used = plus_w + widths[ide_term_idx]
    local sel = { [ide_term_idx] = true }
    for i = #ide_terms, 1, -1 do
      if i ~= ide_term_idx then
        if used + widths[i] + overflow_w <= maxw then
          used = used + widths[i]
          sel[i] = true
        else
          hidden = hidden + 1
        end
      end
    end
    for i = 1, #ide_terms do
      if sel[i] then
        shown[#shown + 1] = i
      end
    end
  end
  local parts = { '%#TabLineFill#' }
  for _, i in ipairs(shown) do
    local hl = (i == ide_term_idx) and '%#TabLineSel#' or '%#TabLine#'
    local core = names and (' ' .. i .. ':' .. ide_terms[i].name) or (' ' .. i)
    parts[#parts + 1] = '%' .. i .. '@v:lua.IdeTermWinbarClick@' .. hl .. core .. '%X%*'
      .. '%' .. (1000 + i) .. '@v:lua.IdeTermWinbarClick@' .. hl .. ' × ' .. '%X%*'
  end
  if hidden > 0 then
    parts[#parts + 1] = '%998@v:lua.IdeTermWinbarClick@%#TabLine# …+' .. hidden .. ' %X%*'
  end
  parts[#parts + 1] = '%#TabLine#%999@v:lua.IdeTermWinbarClick@' .. plus .. '%X%*'
  return table.concat(parts)
end

ide_term_show = function(idx)
  ide_term_prune()
  if #ide_terms == 0 then
    return nil
  end
  if idx and idx >= 1 and idx <= #ide_terms then
    ide_term_idx = idx
  elseif ide_term_idx < 1 or ide_term_idx > #ide_terms then
    ide_term_idx = #ide_terms
  end
  local cur = vim.api.nvim_get_current_win()
  local win = nil
  if vim.w[cur].ide_term_panel then
    win = cur -- a winbar click switches the tab in its own window
  else
    win = ide_term_panel_win()
  end
  if not win then
    if ide_term_dir == 'vertical' then
      vim.cmd('botright ' .. ide_term_width .. 'vsplit')
    else
      vim.cmd('botright ' .. ide_term_height .. 'split')
    end
    win = vim.api.nvim_get_current_win()
    vim.w[win].ide_term_panel = true
    vim.wo[win].winbar = '%!v:lua.IdeTermWinbar()'
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = 'no'
    vim.wo[win].winfixwidth = true -- keep its width when layout rebalances
  end
  vim.api.nvim_win_set_buf(win, ide_terms[ide_term_idx].buf)
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
    if ide_term_dir == 'vertical' then
      vim.cmd('botright ' .. ide_term_width .. 'vsplit')
    else
      vim.cmd('botright ' .. ide_term_height .. 'split')
    end
  end
  -- Fresh scratch buffer first: termopen() needs a job-free buffer, but
  -- panel windows show live terminals. (:terminal converts in place.)
  vim.cmd 'enew'
  local scratch = vim.api.nvim_get_current_buf()
  if type(cwd) == 'string' and vim.fn.isdirectory(cwd) == 1 then
    vim.fn.termopen({ vim.o.shell }, { cwd = cwd })
  else
    vim.cmd 'terminal'
  end
  local buf = vim.api.nvim_get_current_buf()
  if buf ~= scratch then
    pcall(vim.api.nvim_buf_delete, scratch, { force = true })
  end
  vim.bo[buf].buflisted = false -- keep the file tabs clean
  ide_terms[#ide_terms + 1] = { buf = buf, name = vim.o.shell:match '([^/]+)$' or 'term' }
  ide_term_idx = #ide_terms
  -- Style AFTER :terminal: opening a terminal resets window options (winbar!).
  win = vim.api.nvim_get_current_win()
  vim.w[win].ide_term_panel = true
  vim.wo[win].winbar = '%!v:lua.IdeTermWinbar()'
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = 'no'
  vim.wo[win].winfixwidth = true -- keep its width when layout rebalances
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
  if #ide_terms == 0 then
    ide_term_new()
  else
    ide_term_show()
  end
end

ide_term_next = function()
  ide_term_prune()
  if #ide_terms == 0 then
    ide_term_new()
    return
  end
  ide_term_show(ide_term_idx % #ide_terms + 1)
end

local function ide_term_prev()
  ide_term_prune()
  if #ide_terms == 0 then
    ide_term_new()
    return
  end
  ide_term_show((ide_term_idx - 2) % #ide_terms + 1)
end

ide_term_kill = function()
  ide_term_prune()
  if #ide_terms == 0 then
    local win = ide_term_panel_win()
    if win then
      vim.api.nvim_win_close(win, false)
    end
    return
  end
  pcall(vim.api.nvim_buf_delete, ide_terms[ide_term_idx].buf, { force = true })
  ide_term_prune()
  if #ide_terms == 0 then
    for _, win in ipairs(ide_term_panel_wins()) do
      vim.api.nvim_win_close(win, false)
    end
    return
  end
  -- Repoint panel windows left showing the dead buffer.
  for _, win in ipairs(ide_term_panel_wins()) do
    if not vim.api.nvim_buf_is_valid(vim.api.nvim_win_get_buf(win)) then
      vim.api.nvim_win_set_buf(win, ide_terms[1].buf)
    end
  end
  ide_term_idx = 1
  ide_term_show()
end

-- Move the panel right/bottom (mouse menu + commands). Reopens if visible.
local function ide_term_place(dir)
  ide_term_dir = dir
  for _, win in ipairs(ide_term_panel_wins()) do
    vim.api.nvim_win_close(win, false)
  end
  ide_term_prune()
  if #ide_terms == 0 then
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
    if #ide_terms == 0 then
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
  for i, t in ipairs(ide_terms) do
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
    ide_term_idx = target_idx
    vim.api.nvim_win_set_buf(newwin, ide_terms[target_idx].buf)
  else
    vim.cmd 'terminal'
    local buf = vim.api.nvim_get_current_buf()
    vim.bo[buf].buflisted = false
    ide_terms[#ide_terms + 1] = { buf = buf, name = vim.o.shell:match '([^/]+)$' or 'term' }
    ide_term_idx = #ide_terms
  end
  -- Style AFTER (a fresh :terminal resets window options, including winbar).
  vim.w[newwin].ide_term_panel = true
  vim.wo[newwin].winbar = '%!v:lua.IdeTermWinbar()'
  vim.wo[newwin].number = false
  vim.wo[newwin].relativenumber = false
  vim.wo[newwin].signcolumn = 'no'
  vim.wo[newwin].winfixwidth = true -- keep its width when layout rebalances
  vim.cmd 'startinsert'
  vim.cmd.redrawstatus()
end
vim.keymap.set({ 'n', 't' }, '<C-`>', toggle_terminal_right, { desc = 'Toggle terminal panel (Cursor Ctrl+`)' })
vim.keymap.set({ 'n', 'i', 'v', 't' }, '<M-j>', toggle_terminal_right, { desc = 'Toggle terminal (Cursor Cmd+J)' })
-- Cursor Ctrl+Shift+`: new terminal tab (opens the panel if hidden).
local function ide_term_combo()
  ide_term_prune()
  if not ide_term_panel_win() and #ide_terms > 0 then
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

-- Shared helper: middle editor window (not tree, panel, or float).
function _G.IdeEditorWin()
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(w).relative == '' then
      local b = vim.api.nvim_win_get_buf(w)
      if vim.bo[b].buftype == '' and vim.bo[b].filetype ~= 'neo-tree' and not vim.w[w].ide_term_panel then
        return w
      end
    end
  end
  return nil
end

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
  return s:match('^ ?[ MADRCU?!][ MADRCU?!] %S') ~= nil
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
  if nxt:match('^[%$#>%%]') then
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
  if text:sub(c1, c1):match('%S') then
    local s, e = c1, c1
    while s > 1 and text:sub(s - 1, s - 1):match('%S') do
      s = s - 1
    end
    while e < #text and text:sub(e + 1, e + 1):match('%S') do
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
      local win = _G.IdeEditorWin()
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
  vim.cmd 'normal! viw' -- not a path: select word like a terminal would
end

-- Terminal mouse: right-click opens the IDE menu (splits live here;
-- without this, right-click shows nvim's default menu), double-click
-- a path to open it in the editor (Cursor terminal links; the t-mode
-- mapping exits to normal first, sequentially).
vim.api.nvim_create_autocmd('TermOpen', {
  desc = 'Terminal mouse: right-click menu, double-click paths',
  callback = function(ev)
    vim.keymap.set({ 'n', 't' }, '<RightMouse>', function()
      vim.cmd 'popup PopUp'
    end, { buffer = ev.buf, desc = 'Panel menu (right-click)' })
    vim.keymap.set('n', '<2-LeftMouse>', '<Cmd>lua IdeTermOpenPath()<CR>', { buffer = ev.buf, desc = 'Open path under cursor' })
    vim.keymap.set('t', '<2-LeftMouse>', '<C-\\><C-n><Cmd>lua IdeTermOpenPath()<CR>', { buffer = ev.buf, desc = 'Open path under cursor' })
    vim.keymap.set('n', '<CR>', '<Cmd>lua IdeTermOpenPath()<CR>', { buffer = ev.buf, desc = 'Open path under cursor (Enter)' })
  end,
})

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

-- Cursor Cmd+W: close the current file (layout kept; tree/terminal just hide).
-- NOTE: this takes over the <C-w> window prefix; navigate with <C-h/j/k/l> + mouse instead.
local function close_file_smart()
  if vim.bo.filetype == 'neo-tree' then
    local ok, nt = pcall(require, 'neo-tree.command')
    if ok then
      pcall(nt.execute, { action = 'close' })
    end
    return
  end
  if vim.bo.buftype == 'terminal' then
    ide_term_kill() -- Cursor Cmd+W on a terminal kills that tab
    return
  end
  -- Cursor Cmd+W: first reveal the most recently used real file
  -- (the global alternate is polluted by tree/terminal buffers),
  -- then close. Dirty files get a save prompt.
  local cur = vim.api.nvim_get_current_buf()
  local candidates = {}
  for _, info in ipairs(vim.fn.getbufinfo { buflisted = 1 }) do
    if info.bufnr ~= cur and vim.bo[info.bufnr].buftype == '' and vim.bo[info.bufnr].filetype ~= 'neo-tree' then
      candidates[#candidates + 1] = info
    end
  end
  table.sort(candidates, function(a, b)
    return a.lastused > b.lastused
  end)
  if #candidates > 0 then
    vim.api.nvim_set_current_buf(candidates[1].bufnr)
  else
    -- Last file: blank screen. (Plain :bdelete would fall back to the
    -- alternate buffer, which is often a terminal.)
    vim.cmd 'enew'
  end
  pcall(vim.cmd, 'confirm bdelete ' .. cur)
end
vim.keymap.set({ 'n', 'i', 'v' }, '<C-w>', close_file_smart, { desc = 'Close file (Cursor Cmd+W)' })

-- Cursor Cmd+S: save (stays in insert mode).
vim.keymap.set({ 'n', 'i', 'v' }, '<C-s>', '<cmd>update<cr>', { desc = 'Save file (Cursor Cmd+S)' })
vim.keymap.set('t', '<C-s>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- Cursor Cmd+/: toggle comment (mini.comment provides gcc/gc; resolves at press time).
vim.keymap.set('n', '<M-/>', 'gcc', { remap = true, desc = 'Toggle line comment (Cursor Cmd+/)' })
vim.keymap.set('v', '<M-/>', 'gc', { remap = true, desc = 'Toggle comment (Cursor Cmd+/)' })

-- Mouse-friendly git: right-click a changed line for Preview / Undo / Stage.
-- (Left-click still moves the cursor; this mirrors Cursor's gutter-click menu.)
vim.api.nvim_create_user_command('IdeTerminalRight', function()
  toggle_terminal_right()
end, { desc = 'Toggle right terminal' })
vim.api.nvim_create_user_command('IdeExplorerLeft', function()
  toggle_explorer_left()
end, { desc = 'Toggle left explorer' })
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
vim.cmd [[
  anoremenu PopUp.-CursorGit- <Nop>
  anoremenu PopUp.Preview\ git\ hunk :Gitsigns preview_hunk<CR>
  anoremenu PopUp.Undo\ hunk\ (reset) :Gitsigns reset_hunk<CR>
  anoremenu PopUp.Stage\ hunk :Gitsigns stage_hunk<CR>
  anoremenu PopUp.Blame\ line :Gitsigns blame_line<CR>
  anoremenu PopUp.-CursorIDE- <Nop>
  anoremenu PopUp.Toggle\ terminal\ panel :IdeTerminalRight<CR>
  anoremenu PopUp.Toggle\ file\ explorer :IdeExplorerLeft<CR>
  anoremenu PopUp.New\ terminal\ tab :IdeTermNew<CR>
  anoremenu PopUp.Close\ terminal\ tab :IdeTermKill<CR>
  anoremenu PopUp.Terminal\ panel\ right :IdeTermRight<CR>
  anoremenu PopUp.Terminal\ panel\ bottom :IdeTermBottom<CR>
  anoremenu PopUp.Split\ terminal\ side\ by\ side :IdeTermVSplit<CR>
  anoremenu PopUp.Split\ terminal\ stacked :IdeTermSplit<CR>
]]

-- Cursor-style tree context menu (right-click a file/folder in the explorer).
-- neo-tree is required lazily inside each command, so this is safe pre-install.
local function nt_state()
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
local function nt_node()
  local state = nt_state()
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
local function nt_path(node)
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
local function nt_cmd(name)
  local state = nt_state()
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
  local path = nt_path(nt_node())
  if path then
    vim.fn.setreg('+', vim.fn.fnamemodify(path, ':.'))
  end
end, { desc = 'Tree: copy relative path' })
vim.api.nvim_create_user_command('TreeCopyAbsPath', function()
  local path = nt_path(nt_node())
  if path then
    vim.fn.setreg('+', path)
  end
end, { desc = 'Tree: copy absolute path' })
vim.api.nvim_create_user_command('TreeCopyName', function()
  local node = nt_node()
  if node then
    vim.fn.setreg('+', node.name)
  end
end, { desc = 'Tree: copy file name' })
vim.api.nvim_create_user_command('TreeOpenSide', function()
  local node = nt_node()
  if not node then
    return
  end
  if node.type == 'directory' then
    nt_cmd 'toggle_node'
    return
  end
  local path = nt_path(node)
  if not path then
    return
  end
  local win = _G.IdeEditorWin()
  if not win then
    vim.cmd 'vsplit'
    win = vim.api.nvim_get_current_win()
  end
  vim.api.nvim_set_current_win(win)
  vim.cmd 'vsplit'
  vim.cmd('edit ' .. vim.fn.fnameescape(path))
end, { desc = 'Tree: open file in a side split' })
vim.api.nvim_create_user_command('TreeReveal', function()
  local path = nt_path(nt_node())
  if not path then
    return
  end
  if vim.fn.isdirectory(path) == 0 then
    path = vim.fn.fnamemodify(path, ':h')
  end
  vim.ui.open(path)
end, { desc = 'Tree: reveal in Finder/File Explorer' })
vim.api.nvim_create_user_command('TreeTermHere', function()
  local path = nt_path(nt_node())
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
  anoremenu TreePopUp.Copy\ Relative\ Path :TreeCopyRelPath<CR>
  anoremenu TreePopUp.Copy\ Absolute\ Path :TreeCopyAbsPath<CR>
  anoremenu TreePopUp.-sep3- <Nop>
  anoremenu TreePopUp.Expand\ All :TreeExpandAll<CR>
  anoremenu TreePopUp.Collapse\ All :TreeCollapseAll<CR>
  anoremenu TreePopUp.Refresh :TreeRefresh<CR>
]]

-- The explorer is a panel, not a text buffer: no listchars, no wrapping.
-- (neo-tree itself sets nomodifiable/nofile; full-row highlight comes from
-- its `indent` expander + cursorline, configured in custom/plugins/init.lua.)
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'neo-tree',
  desc = 'Panel (not text) display for the file tree',
  callback = function()
    vim.opt_local.list = false
    vim.opt_local.wrap = false
  end,
})

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

-- Live cwd of a terminal's shell (macOS lsof). Fresh shells inherit nvim's
-- cwd, but users cd constantly -- only the live lookup is truthful.
ide_term_buf_cwd = function(buf)
  local ok, job = pcall(vim.api.nvim_buf_get_var, buf, 'terminal_job_id')
  if not ok or type(job) ~= 'number' then
    return nil
  end
  local ok2, pid = pcall(vim.fn.jobpid, job)
  if not ok2 or type(pid) ~= 'number' or pid <= 0 then
    return nil
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

local function ide_save_files(allow_delete)
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
  local terms = {}
  for _, t in ipairs(ide_terms) do
    if vim.api.nvim_buf_is_valid(t.buf) and #terms < 10 then
      terms[#terms + 1] = ide_term_buf_cwd(t.buf) or vim.fn.getcwd()
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
  local panel = ide_term_panel_win()
  local termsize = { dir = ide_term_dir, width = ide_term_width, height = ide_term_height }
  if panel and vim.api.nvim_win_get_config(panel).relative == '' then
    if ide_term_dir == 'vertical' then
      termsize.width = vim.api.nvim_win_get_width(panel)
    else
      termsize.height = vim.api.nvim_win_get_height(panel)
    end
    ide_term_width, ide_term_height = termsize.width, termsize.height
  end
  if #files == 0 and #terms == 0 then
    if not allow_delete then
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
  pcall(vim.fn.writefile, { vim.json.encode(state) }, ide_state_path())
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
      ide_term_dir = state.termsize.dir
    end
    if type(state.termsize.width) == 'number' then
      ide_term_width = math.min(math.max(state.termsize.width, 20), math.max(vim.o.columns - 40, 30))
    end
    if type(state.termsize.height) == 'number' then
      ide_term_height = math.min(math.max(state.termsize.height, 5), math.max(vim.o.lines - 10, 10))
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
    for _, w in ipairs(ide_term_panel_wins()) do
      pcall(vim.api.nvim_win_close, w, false)
    end
    for _, t in ipairs(ide_terms) do
      pcall(vim.api.nvim_buf_delete, t.buf, { force = true })
    end
    ide_terms = {}
    ide_term_idx = 0
    for _, c in ipairs(state.terms) do
      if type(c) == 'string' and vim.fn.isdirectory(c) == 1 then
        ide_term_new(c)
      end
    end
    if #ide_terms == 0 then
      ide_term_new()
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
  local panel = ide_term_panel_win()
  if panel then
    if ide_term_dir == 'vertical' then
      pcall(vim.api.nvim_win_set_width, panel, ide_term_width)
    else
      pcall(vim.api.nvim_win_set_height, panel, ide_term_height)
    end
  end
  vim.g.ide_restoring = false
  return did
end

vim.api.nvim_create_autocmd({ 'VimLeavePre', 'FocusLost', 'BufEnter', 'WinResized' }, {
  desc = 'Remember open files and window sizes for next launch',
  callback = function(ev)
    if vim.g.ide_restoring then
      return
    end
    -- Only a real quit may wipe state; transient empty moments must not.
    ide_save_files(ev.event == 'VimLeavePre')
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
  for i, t in ipairs(ide_terms) do
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
  _G.IdeTest = { save = ide_save_files, restore = ide_restore_files, term_cwd = ide_term_buf_cwd }
end

-- Auto-open the full IDE layout (tree left, terminal right) for a bare
-- launch or a directory launch (nvim .): the same workspace every time.
-- nested = true: files opened here must trigger detection, LSP, git signs.
vim.api.nvim_create_autocmd('VimEnter', {
  desc = 'Auto-open IDE layout except for explicit file launches',
  nested = true,
  callback = function()
    -- Skip only for explicit file launches. (neo-tree's directory hijack
    -- opens the tree itself for `nvim .`, so argv can't detect it.)
    for i = 0, vim.fn.argc() - 1 do
      local a = vim.fn.argv(i)
      if a == '-' or (vim.fn.filereadable(a) == 1 and vim.fn.isdirectory(a) == 0) then
        return -- focused file/stdin edit, no IDE chrome
      end
    end
    -- Drop the directory buffer itself (nvim .): the tree replaces it.
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      local name = vim.api.nvim_buf_get_name(b)
      if name ~= '' and vim.fn.isdirectory(name) == 1 then
        pcall(vim.api.nvim_buf_delete, b, { force = true })
      end
    end
    -- Pause workspace saves until launch settles: intermediate buffers
    -- (tree, fresh terminal) must never overwrite the saved state that
    -- restore is about to read.
    vim.g.ide_restoring = true
    local function editor_win()
      for _, w in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_config(w).relative == '' then
          local b = vim.api.nvim_win_get_buf(w)
          if vim.bo[b].buftype == '' and vim.bo[b].filetype ~= 'neo-tree' and not vim.w[w].ide_term_panel then
            return w
          end
        end
      end
      return nil
    end
    local ok_nt, nt_cmd = pcall(require, 'neo-tree.command')
    if ok_nt then
      pcall(nt_cmd.execute, { action = 'show', source = 'filesystem', position = 'left' })
    else
      vim.notify('neo-tree not installed: run :Lazy sync and restart', vim.log.levels.WARN)
    end
    if not editor_win() then
      -- nvim <dir> leaves only the tree: open a blank editor beside it.
      for _, w in ipairs(vim.api.nvim_list_wins()) do
        if vim.bo[vim.api.nvim_win_get_buf(w)].filetype == 'neo-tree' then
          vim.api.nvim_set_current_win(w)
          break
        end
      end
      vim.cmd 'rightbelow vsplit'
      vim.cmd 'enew'
    end
    toggle_terminal_right()
    vim.cmd 'stopinsert'
    local mid = editor_win()
    if mid then
      vim.api.nvim_set_current_win(mid) -- files restore into the middle
    end
    ide_restore_files() -- reopen last session's files (blank editor only)
    mid = editor_win()
    if mid then
      vim.api.nvim_set_current_win(mid) -- leave focus in the middle, like Cursor
    end
    vim.g.ide_restoring = false
  end,
})

-- Cursor layout guarantee: the middle editor can never vanish. If its last
-- window closes while tree/panel remain (e.g. :q on the last file), reopen
-- a blank middle instead of letting the terminal take the whole screen.
vim.api.nvim_create_autocmd('WinClosed', {
  pattern = '*',
  desc = 'Reopen blank editor if it was the last one (keep layout)',
  callback = function()
    if vim.v.dying ~= 0 then
      return
    end
    vim.schedule(function()
      if vim.v.dying ~= 0 then
        return
      end
      if _G.IdeEditorWin() then
        return
      end
      local anchor = nil
      for _, w in ipairs(vim.api.nvim_list_wins()) do
        local b = vim.api.nvim_win_get_buf(w)
        if vim.bo[b].filetype == 'neo-tree' or vim.w[w].ide_term_panel then
          anchor = w
          break
        end
      end
      if not anchor then
        return -- nothing IDE-like left; quit/shrink normally
      end
      vim.api.nvim_set_current_win(anchor)
      if vim.bo[vim.api.nvim_win_get_buf(anchor)].filetype == 'neo-tree' then
        vim.cmd 'rightbelow vsplit'
        vim.cmd 'enew'
      else
        vim.cmd 'topleft vsplit'
        vim.cmd 'enew'
      end
    end)
  end,
})

-- Cursor-like media: videos open in the system player (no in-terminal
-- video player exists), images render inline via image.nvim.
local video_patterns = { '*.mp4', '*.mov', '*.mkv', '*.webm', '*.avi', '*.m4v', '*.3gp', '*.ogv', '*.mpg', '*.mpeg' }
vim.api.nvim_create_autocmd('BufReadCmd', {
  pattern = video_patterns,
  desc = 'Open videos in the system player instead of a buffer',
  callback = function(ev)
    vim.ui.open(ev.file)
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(ev.buf) then
        pcall(vim.cmd, 'bprevious')
        pcall(vim.api.nvim_buf_delete, ev.buf, { force = true })
      end
    end)
  end,
})
vim.keymap.set('n', 'gx', function()
  local path = vim.fn.expand '%:p'
  if path ~= '' and (vim.fn.filereadable(path) == 1 or vim.fn.isdirectory(path) == 1) then
    vim.ui.open(path)
  end
end, { desc = 'Open file externally (images, videos)' })

-- NOTE: Some terminals have colliding keymaps or are not able to send distinct keycodes
-- vim.keymap.set("n", "<C-S-h>", "<C-w>H", { desc = "Move window to the left" })
-- vim.keymap.set("n", "<C-S-l>", "<C-w>L", { desc = "Move window to the right" })
-- vim.keymap.set("n", "<C-S-j>", "<C-w>J", { desc = "Move window to the lower" })
-- vim.keymap.set("n", "<C-S-k>", "<C-w>K", { desc = "Move window to the upper" })

-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.hl.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

-- Never block the IDE on swap files. Respawns/restarts can leave stale
-- swaps behind; without this every :edit of such a file stops on E325.
vim.api.nvim_create_autocmd('SwapExists', {
  desc = 'Auto-resolve swap files instead of prompting (E325)',
  callback = function()
    local swap = vim.v.swapname
    local fname = vim.fn.expand '<afile>:p'
    local pid = nil
    local ok, info = pcall(vim.fn.swapinfo, swap)
    if ok and type(info) == 'table' then
      pid = tonumber(info.pid)
    end
    local dead = true
    if pid and pid > 0 then
      local uv = vim.uv or vim.loop
      dead = not pcall(uv.kill, pid, 0) -- signal 0: exists check only
    end
    if dead and vim.fn.getftime(fname) >= vim.fn.getftime(swap) then
      vim.v.swapchoice = 'd' -- stale, nothing newer in it: delete + open
    else
      vim.v.swapchoice = 'e' -- live session or possible unsaved work: open anyway
      vim.schedule(function()
        if not dead then
          vim.notify('File also open in nvim pid ' .. pid .. ': editing anyway', vim.log.levels.WARN)
        else
          vim.notify('Stale swap kept (may hold unsaved work): ' .. swap, vim.log.levels.WARN)
        end
      end)
    end
  end,
})

-- [[ Install `lazy.nvim` plugin manager ]]
--    See `:help lazy.nvim.txt` or https://github.com/folke/lazy.nvim for more info
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
  if vim.v.shell_error ~= 0 then
    error('Error cloning lazy.nvim:\n' .. out)
  end
end

---@type vim.Option
local rtp = vim.opt.rtp
rtp:prepend(lazypath)

-- [[ Configure and install plugins ]]
--
--  To check the current status of your plugins, run
--    :Lazy
--
--  You can press `?` in this menu for help. Use `:q` to close the window
--
--  To update plugins you can run
--    :Lazy update
--
-- NOTE: Here is where you install your plugins.
require('lazy').setup({
  -- NOTE: Plugins can be added with a link (or for a github repo: 'owner/repo' link).
  'NMAC427/guess-indent.nvim', -- Detect tabstop and shiftwidth automatically

  -- NOTE: Plugins can also be added by using a table,
  -- with the first argument being the link and the following
  -- keys can be used to configure plugin behavior/loading/etc.
  --
  -- Use `opts = {}` to automatically pass options to a plugin's `setup()` function, forcing the plugin to be loaded.
  --

  -- Alternatively, use `config = function() ... end` for full control over the configuration.
  -- If you prefer to call `setup` explicitly, use:
  --    {
  --        'lewis6991/gitsigns.nvim',
  --        config = function()
  --            require('gitsigns').setup({
  --                -- Your gitsigns configuration here
  --            })
  --        end,
  --    }
  --
  -- Here is a more advanced example where we pass configuration
  -- options to `gitsigns.nvim`.
  --
  -- See `:help gitsigns` to understand what the configuration keys do
  { -- Adds git related signs to the gutter, as well as utilities for managing changes
    'lewis6991/gitsigns.nvim',
    opts = {
      signs = {
        add = { text = '┃' },
        change = { text = '┃' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '┃' },
        untracked = { text = '┆' },
      },
      attach_to_untracked = true, -- new files also get gutter marks
      -- Cursor-like inline blame on the current line (toggle with <leader>tb)
      current_line_blame = true,
      current_line_blame_opts = {
        virt_text = true,
        virt_text_pos = 'eol',
        delay = 500,
      },
      preview_config = { border = 'rounded' },
      on_attach = function(bufnr)
        local gitsigns = require 'gitsigns'

        local function map(mode, l, r, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, l, r, opts)
        end

        -- Navigation
        map('n', ']c', function()
          if vim.wo.diff then
            vim.cmd.normal { ']c', bang = true }
          else
            gitsigns.nav_hunk 'next'
          end
        end, { desc = 'Jump to next git [c]hange' })

        map('n', '[c', function()
          if vim.wo.diff then
            vim.cmd.normal { '[c', bang = true }
          else
            gitsigns.nav_hunk 'prev'
          end
        end, { desc = 'Jump to previous git [c]hange' })

        -- Actions (visual = partial hunk, normal = full hunk under cursor)
        map('v', '<leader>hs', function()
          gitsigns.stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = 'git [s]tage hunk' })
        map('v', '<leader>hr', function()
          gitsigns.reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = 'git [r]eset (undo) hunk' })
        map('n', '<leader>hs', gitsigns.stage_hunk, { desc = 'git [s]tage hunk' })
        map('n', '<leader>hr', gitsigns.reset_hunk, { desc = 'git [r]eset (undo) hunk' })
        map('n', '<leader>hS', gitsigns.stage_buffer, { desc = 'git [S]tage buffer' })
        map('n', '<leader>hu', function()
          gitsigns.undo_stage_hunk()
        end, { desc = 'git [u]ndo stage hunk' })
        map('n', '<leader>hR', gitsigns.reset_buffer, { desc = 'git [R]eset buffer' })
        map('n', '<leader>hp', gitsigns.preview_hunk, { desc = 'git [p]review hunk' })
        map('n', '<leader>hi', gitsigns.preview_hunk_inline, { desc = 'git preview hunk [i]nline' })
        map('n', '<leader>hb', function()
          gitsigns.blame_line { full = true }
        end, { desc = 'git [b]lame line' })
        map('n', '<leader>hd', gitsigns.diffthis, { desc = 'git [d]iff against index' })
        map('n', '<leader>hD', function()
          gitsigns.diffthis '@'
        end, { desc = 'git [D]iff against last commit' })
        -- Toggles
        map('n', '<leader>tb', gitsigns.toggle_current_line_blame, { desc = '[T]oggle git show [b]lame line' })
        map('n', '<leader>tD', gitsigns.toggle_deleted, { desc = '[T]oggle git show [D]eleted' })
        map('n', '<leader>tw', gitsigns.toggle_word_diff, { desc = '[T]oggle git [w]ord diff' })
        -- Hunk text object (e.g. `vih` selects the hunk)
        map({ 'o', 'x' }, 'ih', gitsigns.select_hunk, { desc = 'select g[i]t [h]unk' })
      end,
    },
  },

  -- NOTE: Plugins can also be configured to run Lua code when they are loaded.
  --
  -- This is often very useful to both group configuration, as well as handle
  -- lazy loading plugins that don't need to be loaded immediately at startup.
  --
  -- For example, in the following configuration, we use:
  --  event = 'VimEnter'
  --
  -- which loads which-key before all the UI elements are loaded. Events can be
  -- normal autocommands events (`:help autocmd-events`).
  --
  -- Then, because we use the `opts` key (recommended), the configuration runs
  -- after the plugin has been loaded as `require(MODULE).setup(opts)`.

  { -- Useful plugin to show you pending keybinds.
    'folke/which-key.nvim',
    event = 'VimEnter', -- Sets the loading event to 'VimEnter'
    opts = {
      -- delay between pressing a key and opening which-key (milliseconds)
      -- this setting is independent of vim.o.timeoutlen
      -- 300 (not 0): instant popups ambush trackpad/mouse users in the file
      -- tree, where every letter is a mapping and any micro-drag enters visual.
      delay = 300,
      -- Never auto-show the popup on entering visual mode (a trackpad
      -- micro-drag does that constantly); show it on the first keypress
      -- instead. Prefix keys in normal mode still use `delay` above.
      defer = function()
        return true
      end,
      icons = {
        -- set icon mappings to true if you have a Nerd Font
        mappings = vim.g.have_nerd_font,
        -- If you are using a Nerd Font: set icons.keys to an empty table which will use the
        -- default which-key.nvim defined Nerd Font icons, otherwise define a string table
        keys = vim.g.have_nerd_font and {} or {
          Up = '<Up> ',
          Down = '<Down> ',
          Left = '<Left> ',
          Right = '<Right> ',
          C = '<C-…> ',
          M = '<M-…> ',
          D = '<D-…> ',
          S = '<S-…> ',
          CR = '<CR> ',
          Esc = '<Esc> ',
          ScrollWheelDown = '<ScrollWheelDown> ',
          ScrollWheelUp = '<ScrollWheelUp> ',
          NL = '<NL> ',
          BS = '<BS> ',
          Space = '<Space> ',
          Tab = '<Tab> ',
          F1 = '<F1>',
          F2 = '<F2>',
          F3 = '<F3>',
          F4 = '<F4>',
          F5 = '<F5>',
          F6 = '<F6>',
          F7 = '<F7>',
          F8 = '<F8>',
          F9 = '<F9>',
          F10 = '<F10>',
          F11 = '<F11>',
          F12 = '<F12>',
        },
      },

      -- Document existing key chains
      spec = {
        { '<leader>s', group = '[S]earch' },
        { '<leader>t', group = '[T]oggle' },
        { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } },
        { '<leader>g', group = '[G]it' },
        { '<leader>e', group = '[E]xplorer' },
      },
    },
  },

  -- NOTE: Plugins can specify dependencies.
  --
  -- The dependencies are proper plugin specifications as well - anything
  -- you do for a plugin at the top level, you can do for a dependency.
  --
  -- Use the `dependencies` key to specify the dependencies of a particular plugin

  { -- Fuzzy Finder (files, lsp, etc)
    'nvim-telescope/telescope.nvim',
    event = 'VimEnter',
    dependencies = {
      'nvim-lua/plenary.nvim',
      { -- If encountering errors, see telescope-fzf-native README for installation instructions
        'nvim-telescope/telescope-fzf-native.nvim',

        -- `build` is used to run some command when the plugin is installed/updated.
        -- This is only run then, not every time Neovim starts up.
        build = 'make',

        -- `cond` is a condition used to determine whether this plugin should be
        -- installed and loaded.
        cond = function()
          return vim.fn.executable 'make' == 1
        end,
      },
      { 'nvim-telescope/telescope-ui-select.nvim' },

      -- Useful for getting pretty icons, but requires a Nerd Font.
      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    config = function()
      -- Telescope is a fuzzy finder that comes with a lot of different things that
      -- it can fuzzy find! It's more than just a "file finder", it can search
      -- many different aspects of Neovim, your workspace, LSP, and more!
      --
      -- The easiest way to use Telescope, is to start by doing something like:
      --  :Telescope help_tags
      --
      -- After running this command, a window will open up and you're able to
      -- type in the prompt window. You'll see a list of `help_tags` options and
      -- a corresponding preview of the help.
      --
      -- Two important keymaps to use while in Telescope are:
      --  - Insert mode: <c-/>
      --  - Normal mode: ?
      --
      -- This opens a window that shows you all of the keymaps for the current
      -- Telescope picker. This is really useful to discover what Telescope can
      -- do as well as how to actually do it!

      -- [[ Configure Telescope ]]
      -- See `:help telescope` and `:help telescope.setup()`
      require('telescope').setup {
        -- You can put your default mappings / updates / etc. in here
        --  All the info you're looking for is in `:help telescope.setup()`
        --
        -- defaults = {
        --   mappings = {
        --     i = { ['<c-enter>'] = 'to_fuzzy_refine' },
        --   },
        -- },
        -- pickers = {}
        extensions = {
          ['ui-select'] = {
            require('telescope.themes').get_dropdown(),
          },
        },
      }

      -- Enable Telescope extensions if they are installed
      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')

      -- See `:help telescope.builtin`
      local builtin = require 'telescope.builtin'
      -- Cursor Cmd+P: quick file search, scoped to the current file's folder.
      -- (Workspace-wide search stays on <leader>sf.)
      -- Ghostty forwards Cmd+P as Ctrl+P (see ghostty-config keybinds).
      local function find_files_same_folder()
        local dir = vim.fn.expand '%:p:h'
        if vim.fn.isdirectory(dir) == 0 then
          dir = vim.fn.getcwd()
        end
        builtin.find_files { cwd = dir }
      end
      vim.keymap.set({ 'n', 'i', 'v' }, '<C-p>', find_files_same_folder, { desc = 'Find files here (Cursor Cmd+P)' })
      vim.keymap.set({ 'n', 'i', 'v' }, '<D-p>', find_files_same_folder, { desc = 'Find files here (GUI Cmd+P)' })
      -- Cursor Cmd+Shift+F: search text in files. Cmd+Shift+P: command palette.
      -- (Ghostty forwards them as Alt+f / Alt+p; see ghostty-config keybinds.)
      vim.keymap.set({ 'n', 'i', 'v' }, '<M-f>', builtin.live_grep, { desc = 'Search in files (Cursor Cmd+Shift+F)' })
      vim.keymap.set({ 'n', 'i', 'v' }, '<M-p>', builtin.builtin, { desc = 'Command palette (Cursor Cmd+Shift+P)' })
      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
      vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
      vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
      vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
      vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
      vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
      vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
      vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
      vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
      vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })

      -- Slightly advanced example of overriding default behavior and theme
      vim.keymap.set('n', '<leader>/', function()
        -- You can pass additional configuration to Telescope to change the theme, layout, etc.
        builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          winblend = 10,
          previewer = false,
        })
      end, { desc = '[/] Fuzzily search in current buffer' })

      -- It's also possible to pass additional configuration options.
      --  See `:help telescope.builtin.live_grep()` for information about particular keys
      vim.keymap.set('n', '<leader>s/', function()
        builtin.live_grep {
          grep_open_files = true,
          prompt_title = 'Live Grep in Open Files',
        }
      end, { desc = '[S]earch [/] in Open Files' })

      -- Shortcut for searching your Neovim configuration files
      vim.keymap.set('n', '<leader>sn', function()
        builtin.find_files { cwd = vim.fn.stdpath 'config' }
      end, { desc = '[S]earch [N]eovim files' })
    end,
  },

  -- LSP Plugins
  {
    -- `lazydev` configures Lua LSP for your Neovim config, runtime and plugins
    -- used for completion, annotations and signatures of Neovim apis
    'folke/lazydev.nvim',
    ft = 'lua',
    opts = {
      library = {
        -- Load luvit types when the `vim.uv` word is found
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
      },
    },
  },
  {
    -- Main LSP Configuration
    'neovim/nvim-lspconfig',
    dependencies = {
      -- Automatically install LSPs and related tools to stdpath for Neovim
      -- Mason must be loaded before its dependents so we need to set it up here.
      -- NOTE: `opts = {}` is the same as calling `require('mason').setup({})`
      { 'mason-org/mason.nvim', opts = {} },
      'mason-org/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',

      -- Useful status updates for LSP.
      { 'j-hui/fidget.nvim', opts = {} },

      -- Allows extra capabilities provided by blink.cmp
      'saghen/blink.cmp',
    },
    config = function()
      -- Brief aside: **What is LSP?**
      --
      -- LSP is an initialism you've probably heard, but might not understand what it is.
      --
      -- LSP stands for Language Server Protocol. It's a protocol that helps editors
      -- and language tooling communicate in a standardized fashion.
      --
      -- In general, you have a "server" which is some tool built to understand a particular
      -- language (such as `gopls`, `lua_ls`, `rust_analyzer`, etc.). These Language Servers
      -- (sometimes called LSP servers, but that's kind of like ATM Machine) are standalone
      -- processes that communicate with some "client" - in this case, Neovim!
      --
      -- LSP provides Neovim with features like:
      --  - Go to definition
      --  - Find references
      --  - Autocompletion
      --  - Symbol Search
      --  - and more!
      --
      -- Thus, Language Servers are external tools that must be installed separately from
      -- Neovim. This is where `mason` and related plugins come into play.
      --
      -- If you're wondering about lsp vs treesitter, you can check out the wonderfully
      -- and elegantly composed help section, `:help lsp-vs-treesitter`

      --  This function gets run when an LSP attaches to a particular buffer.
      --    That is to say, every time a new file is opened that is associated with
      --    an lsp (for example, opening `main.rs` is associated with `rust_analyzer`) this
      --    function will be executed to configure the current buffer
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          -- NOTE: Remember that Lua is a real programming language, and as such it is possible
          -- to define small helper and utility functions so you don't have to repeat yourself.
          --
          -- In this case, we create a function that lets us more easily define mappings specific
          -- for LSP related items. It sets the mode, buffer and description for us each time.
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          -- Rename the variable under your cursor.
          --  Most Language Servers support renaming across files, etc.
          map('grn', vim.lsp.buf.rename, '[R]e[n]ame')

          -- Execute a code action, usually your cursor needs to be on top of an error
          -- or a suggestion from your LSP for this to activate.
          map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })

          -- Find references for the word under your cursor.
          map('grr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')

          -- Jump to the implementation of the word under your cursor.
          --  Useful when your language has ways of declaring types without an actual implementation.
          map('gri', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')

          -- Jump to the definition of the word under your cursor.
          --  This is where a variable was first declared, or where a function is defined, etc.
          --  To jump back, press <C-t>.
          map('grd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')

          -- WARN: This is not Goto Definition, this is Goto Declaration.
          --  For example, in C this would take you to the header.
          map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

          -- Fuzzy find all the symbols in your current document.
          --  Symbols are things like variables, functions, types, etc.
          map('gO', require('telescope.builtin').lsp_document_symbols, 'Open Document Symbols')

          -- Fuzzy find all the symbols in your current workspace.
          --  Similar to document symbols, except searches over your entire project.
          map('gW', require('telescope.builtin').lsp_dynamic_workspace_symbols, 'Open Workspace Symbols')

          -- Jump to the type of the word under your cursor.
          --  Useful when you're not sure what type a variable is and you want to see
          --  the definition of its *type*, not where it was *defined*.
          map('grt', require('telescope.builtin').lsp_type_definitions, '[G]oto [T]ype Definition')

          -- This function resolves a difference between neovim nightly (version 0.11) and stable (version 0.10)
          ---@param client vim.lsp.Client
          ---@param method vim.lsp.protocol.Method
          ---@param bufnr? integer some lsp support methods only in specific files
          ---@return boolean
          local function client_supports_method(client, method, bufnr)
            if vim.fn.has 'nvim-0.11' == 1 then
              return client:supports_method(method, bufnr)
            else
              return client.supports_method(method, { bufnr = bufnr })
            end
          end

          -- The following two autocommands are used to highlight references of the
          -- word under your cursor when your cursor rests there for a little while.
          --    See `:help CursorHold` for information about when this is executed
          --
          -- When you move your cursor, the highlights will be cleared (the second autocommand).
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
            local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })

            vim.api.nvim_create_autocmd('LspDetach', {
              group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
              end,
            })
          end

          -- The following code creates a keymap to toggle inlay hints in your
          -- code, if the language server you are using supports them
          --
          -- This may be unwanted, since they displace some of your code
          if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
            map('<leader>th', function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
            end, '[T]oggle Inlay [H]ints')
          end
        end,
      })

      -- Diagnostic Config
      -- See :help vim.diagnostic.Opts
      vim.diagnostic.config {
        severity_sort = true,
        float = { border = 'rounded', source = 'if_many' },
        underline = { severity = vim.diagnostic.severity.ERROR },
        signs = vim.g.have_nerd_font and {
          text = {
            [vim.diagnostic.severity.ERROR] = '󰅚 ',
            [vim.diagnostic.severity.WARN] = '󰀪 ',
            [vim.diagnostic.severity.INFO] = '󰋽 ',
            [vim.diagnostic.severity.HINT] = '󰌶 ',
          },
        } or {},
        virtual_text = {
          source = 'if_many',
          spacing = 2,
          format = function(diagnostic)
            local diagnostic_message = {
              [vim.diagnostic.severity.ERROR] = diagnostic.message,
              [vim.diagnostic.severity.WARN] = diagnostic.message,
              [vim.diagnostic.severity.INFO] = diagnostic.message,
              [vim.diagnostic.severity.HINT] = diagnostic.message,
            }
            return diagnostic_message[diagnostic.severity]
          end,
        },
      }

      -- LSP servers and clients are able to communicate to each other what features they support.
      --  By default, Neovim doesn't support everything that is in the LSP specification.
      --  When you add blink.cmp, luasnip, etc. Neovim now has *more* capabilities.
      --  So, we create new capabilities with blink.cmp, and then broadcast that to the servers.
      local capabilities = require('blink.cmp').get_lsp_capabilities()

      -- Enable the following language servers
      --  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
      --
      --  Add any additional override configuration in the following tables. Available keys are:
      --  - cmd (table): Override the default command used to start the server
      --  - filetypes (table): Override the default list of associated filetypes for the server
      --  - capabilities (table): Override fields in capabilities. Can be used to disable certain LSP features.
      --  - settings (table): Override the default settings passed when initializing the server.
      --        For example, to see the options for `lua_ls`, you could go to: https://luals.github.io/wiki/settings/
      local servers = {
        -- clangd = {},
        -- gopls = {},
        -- pyright = {},
        -- rust_analyzer = {},
        -- ... etc. See `:help lspconfig-all` for a list of all the pre-configured LSPs
        --
        -- Some languages (like typescript) have entire language plugins that can be useful:
        --    https://github.com/pmizio/typescript-tools.nvim
        --
        -- But for many setups, the LSP (`ts_ls`) will work just fine
        -- ts_ls = {},
        --

        lua_ls = {
          -- cmd = { ... },
          -- filetypes = { ... },
          -- capabilities = {},
          settings = {
            Lua = {
              completion = {
                callSnippet = 'Replace',
              },
              -- You can toggle below to ignore Lua_LS's noisy `missing-fields` warnings
              -- diagnostics = { disable = { 'missing-fields' } },
            },
          },
        },
      }

      -- Ensure the servers and tools above are installed
      --
      -- To check the current status of installed tools and/or manually install
      -- other tools, you can run
      --    :Mason
      --
      -- You can press `g?` for help in this menu.
      --
      -- `mason` had to be setup earlier: to configure its options see the
      -- `dependencies` table for `nvim-lspconfig` above.
      --
      -- You can add other tools here that you want Mason to install
      -- for you, so that they are available from within Neovim.
      local ensure_installed = vim.tbl_keys(servers or {})
      vim.list_extend(ensure_installed, {
        'stylua', -- Used to format Lua code
      })
      require('mason-tool-installer').setup { ensure_installed = ensure_installed }

      require('mason-lspconfig').setup {
        ensure_installed = {}, -- explicitly set to an empty table (Kickstart populates installs via mason-tool-installer)
        automatic_installation = false,
        handlers = {
          function(server_name)
            local server = servers[server_name] or {}
            -- This handles overriding only values explicitly passed
            -- by the server configuration above. Useful when disabling
            -- certain features of an LSP (for example, turning off formatting for ts_ls)
            server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
            require('lspconfig')[server_name].setup(server)
          end,
        },
      }
    end,
  },

  { -- Autoformat
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {
      {
        '<leader>f',
        function()
          require('conform').format { async = true, lsp_format = 'fallback' }
        end,
        mode = '',
        desc = '[F]ormat buffer',
      },
    },
    opts = {
      notify_on_error = false,
      format_on_save = function(bufnr)
        -- Disable "format_on_save lsp_fallback" for languages that don't
        -- have a well standardized coding style. You can add additional
        -- languages here or re-enable it for the disabled ones.
        local disable_filetypes = { c = true, cpp = true }
        if disable_filetypes[vim.bo[bufnr].filetype] then
          return nil
        else
          return {
            timeout_ms = 500,
            lsp_format = 'fallback',
          }
        end
      end,
      formatters_by_ft = {
        lua = { 'stylua' },
        -- Conform can also run multiple formatters sequentially
        -- python = { "isort", "black" },
        --
        -- You can use 'stop_after_first' to run the first available formatter from the list
        -- javascript = { "prettierd", "prettier", stop_after_first = true },
      },
    },
  },

  { -- Autocompletion
    'saghen/blink.cmp',
    event = 'VimEnter',
    version = '1.*',
    dependencies = {
      -- Snippet Engine
      {
        'L3MON4D3/LuaSnip',
        version = '2.*',
        build = (function()
          -- Build Step is needed for regex support in snippets.
          -- This step is not supported in many windows environments.
          -- Remove the below condition to re-enable on windows.
          if vim.fn.has 'win32' == 1 or vim.fn.executable 'make' == 0 then
            return
          end
          return 'make install_jsregexp'
        end)(),
        dependencies = {
          -- `friendly-snippets` contains a variety of premade snippets.
          --    See the README about individual language/framework/plugin snippets:
          --    https://github.com/rafamadriz/friendly-snippets
          -- {
          --   'rafamadriz/friendly-snippets',
          --   config = function()
          --     require('luasnip.loaders.from_vscode').lazy_load()
          --   end,
          -- },
        },
        opts = {},
      },
      'folke/lazydev.nvim',
    },
    --- @module 'blink.cmp'
    --- @type blink.cmp.Config
    opts = {
      keymap = {
        -- 'default' (recommended) for mappings similar to built-in completions
        --   <c-y> to accept ([y]es) the completion.
        --    This will auto-import if your LSP supports it.
        --    This will expand snippets if the LSP sent a snippet.
        -- 'super-tab' for tab to accept
        -- 'enter' for enter to accept
        -- 'none' for no mappings
        --
        -- For an understanding of why the 'default' preset is recommended,
        -- you will need to read `:help ins-completion`
        --
        -- No, but seriously. Please read `:help ins-completion`, it is really good!
        --
        -- All presets have the following mappings:
        -- <tab>/<s-tab>: move to right/left of your snippet expansion
        -- <c-space>: Open menu or open docs if already open
        -- <c-n>/<c-p> or <up>/<down>: Select next/previous item
        -- <c-e>: Hide menu
        -- <c-k>: Toggle signature help
        --
        -- See :h blink-cmp-config-keymap for defining your own keymap
        preset = 'default',

        -- For more advanced Luasnip keymaps (e.g. selecting choice nodes, expansion) see:
        --    https://github.com/L3MON4D3/LuaSnip?tab=readme-ov-file#keymaps
      },

      appearance = {
        -- 'mono' (default) for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
        -- Adjusts spacing to ensure icons are aligned
        nerd_font_variant = 'mono',
      },

      completion = {
        -- By default, you may press `<c-space>` to show the documentation.
        -- Optionally, set `auto_show = true` to show the documentation after a delay.
        documentation = { auto_show = false, auto_show_delay_ms = 500 },
      },

      sources = {
        default = { 'lsp', 'path', 'snippets', 'lazydev' },
        providers = {
          lazydev = { module = 'lazydev.integrations.blink', score_offset = 100 },
        },
      },

      snippets = { preset = 'luasnip' },

      -- Blink.cmp includes an optional, recommended rust fuzzy matcher,
      -- which automatically downloads a prebuilt binary when enabled.
      --
      -- By default, we use the Lua implementation instead, but you may enable
      -- the rust implementation via `'prefer_rust_with_warning'`
      --
      -- See :h blink-cmp-config-fuzzy for more information
      fuzzy = { implementation = 'lua' },

      -- Shows a signature help window while you type arguments for a function
      signature = { enabled = true },
    },
  },

  { -- You can easily change to a different colorscheme.
    -- Change the name of the colorscheme plugin below, and then
    -- change the command in the config to whatever the name of that colorscheme is.
    --
    -- If you want to see what colorschemes are already installed, you can use `:Telescope colorscheme`.
    'folke/tokyonight.nvim',
    priority = 1000, -- Make sure to load this before all the other start plugins.
    config = function()
      ---@diagnostic disable-next-line: missing-fields
      require('tokyonight').setup {
        styles = {
          comments = { italic = false }, -- Disable italics in comments
        },
      }

      -- Load the colorscheme here.
      -- Like many other themes, this one has different styles, and you could load
      -- any other, such as 'tokyonight-storm', 'tokyonight-moon', or 'tokyonight-day'.
      vim.cmd.colorscheme 'tokyonight-night'

      -- Cohesive dark git palette (tree + gutter + blame), applied after the theme.
      vim.api.nvim_set_hl(0, 'GitSignsAdd', { fg = '#9ece6a' })
      vim.api.nvim_set_hl(0, 'GitSignsChange', { fg = '#e0af68' })
      vim.api.nvim_set_hl(0, 'GitSignsDelete', { fg = '#f7768e' })
      vim.api.nvim_set_hl(0, 'GitSignsTopdelete', { fg = '#f7768e' })
      vim.api.nvim_set_hl(0, 'GitSignsChangedelete', { fg = '#e0af68' })
      vim.api.nvim_set_hl(0, 'GitSignsUntracked', { fg = '#7aa2f7' })
      -- Staged (committed-to-index): muted teal, dim but distinct on dark bg.
      vim.api.nvim_set_hl(0, 'GitSignsStagedAdd', { fg = '#5f9ea0' })
      vim.api.nvim_set_hl(0, 'GitSignsStagedChange', { fg = '#5f9ea0' })
      vim.api.nvim_set_hl(0, 'GitSignsStagedDelete', { fg = '#5f9ea0' })
      vim.api.nvim_set_hl(0, 'GitSignsStagedTopdelete', { fg = '#5f9ea0' })
      vim.api.nvim_set_hl(0, 'GitSignsStagedChangedelete', { fg = '#5f9ea0' })
      vim.api.nvim_set_hl(0, 'GitSignsStagedUntracked', { fg = '#5f9ea0' })
      -- Overview ruler (satellite.nvim) reuses the same git palette.
      vim.api.nvim_set_hl(0, 'SatelliteGitSignsAdd', { link = 'GitSignsAdd' })
      vim.api.nvim_set_hl(0, 'SatelliteGitSignsChange', { link = 'GitSignsChange' })
      vim.api.nvim_set_hl(0, 'SatelliteGitSignsDelete', { link = 'GitSignsDelete' })
      vim.api.nvim_set_hl(0, 'GitSignsCurrentLineBlame', { fg = '#565f89', italic = true })
      vim.api.nvim_set_hl(0, 'NeoTreeGitAdded', { fg = '#9ece6a' })
      vim.api.nvim_set_hl(0, 'NeoTreeGitModified', { fg = '#e0af68' })
      vim.api.nvim_set_hl(0, 'NeoTreeGitDeleted', { fg = '#f7768e' })
      vim.api.nvim_set_hl(0, 'NeoTreeGitUntracked', { fg = '#7aa2f7' })
      vim.api.nvim_set_hl(0, 'NeoTreeGitRenamed', { fg = '#bb9af7' })
      vim.api.nvim_set_hl(0, 'NeoTreeGitStaged', { fg = '#5f9ea0' })
    end,
  },

  -- Highlight todo, notes, etc in comments
  { 'folke/todo-comments.nvim', event = 'VimEnter', dependencies = { 'nvim-lua/plenary.nvim' }, opts = { signs = false } },

  { -- Collection of various small independent plugins/modules
    'echasnovski/mini.nvim',
    config = function()
      -- Better Around/Inside textobjects
      --
      -- Examples:
      --  - va)  - [V]isually select [A]round [)]paren
      --  - yinq - [Y]ank [I]nside [N]ext [Q]uote
      --  - ci'  - [C]hange [I]nside [']quote
      require('mini.ai').setup { n_lines = 500 }

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      --
      -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
      -- - sd'   - [S]urround [D]elete [']quotes
      -- - sr)'  - [S]urround [R]eplace [)] [']
      require('mini.surround').setup()

      -- Icons for the file explorer and pickers (zero extra plugins: part of mini.nvim).
      require('mini.icons').setup()
      pcall(require('mini.icons').mock_nvim_web_devicons)

      -- Cursor Cmd+/: line commenting (zero extra plugins).
      require('mini.comment').setup()

      -- Simple and easy statusline.
      --  You could remove this setup call if you don't like it,
      --  and try some other statusline plugin
      local statusline = require 'mini.statusline'
      -- set use_icons to true if you have a Nerd Font
      statusline.setup { use_icons = vim.g.have_nerd_font }

      -- You can configure sections in the statusline by overriding their
      -- default behavior. For example, here we set the section for
      -- cursor location to LINE:COLUMN
      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_location = function()
        return '%2l:%-2v'
      end

      -- ... and there is more!
      --  Check out: https://github.com/echasnovski/mini.nvim
    end,
  },
  { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    main = 'nvim-treesitter.configs', -- Sets main module to use for opts
    -- [[ Configure Treesitter ]] See `:help nvim-treesitter`
    opts = {
      -- Pre-installed so opening these never triggers an on-demand
      -- download popup (seen fail once for typescript).
      ensure_installed = { 'bash', 'c', 'diff', 'html', 'javascript', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'query', 'tsx', 'typescript', 'vim', 'vimdoc' },
      -- Autoinstall languages that are not installed
      auto_install = true,
      highlight = {
        enable = true,
        -- Some languages depend on vim's regex highlighting system (such as Ruby) for indent rules.
        --  If you are experiencing weird indenting issues, add the language to
        --  the list of additional_vim_regex_highlighting and disabled languages for indent.
        additional_vim_regex_highlighting = { 'ruby' },
      },
      indent = { enable = true, disable = { 'ruby' } },
    },
    -- There are additional nvim-treesitter modules that you can use to interact
    -- with nvim-treesitter. You should go explore a few and see what interests you:
    --
    --    - Incremental selection: Included, see `:help nvim-treesitter-incremental-selection-mod`
    --    - Show your current context: https://github.com/nvim-treesitter/nvim-treesitter-context
    --    - Treesitter + textobjects: https://github.com/nvim-treesitter/nvim-treesitter-textobjects
  },

  -- The following comments only work if you have downloaded the kickstart repo, not just copy pasted the
  -- init.lua. If you want these files, they are in the repository, so you can just download them and
  -- place them in the correct locations.

  -- NOTE: Next step on your Neovim journey: Add/Configure additional plugins for Kickstart
  --
  --  Here are some example plugins that I've included in the Kickstart repository.
  --  Uncomment any of the lines below to enable them (you will need to restart nvim).
  --
  -- require 'kickstart.plugins.debug',
  -- require 'kickstart.plugins.indent_line',
  -- require 'kickstart.plugins.lint',
  -- require 'kickstart.plugins.autopairs',
  -- require 'kickstart.plugins.neo-tree',
  -- require 'kickstart.plugins.gitsigns', -- adds gitsigns recommend keymaps

  -- NOTE: The import below can automatically add your own plugins, configuration, etc from `lua/custom/plugins/*.lua`
  --    This is the easiest way to modularize your config.
  --
  --  Uncomment the following line and add your plugins to `lua/custom/plugins/*.lua` to get going.
  { import = 'custom.plugins' },
  --
  -- For additional information with loading, sourcing and examples see `:help lazy.nvim-🔌-plugin-spec`
  -- Or use telescope!
  -- In normal mode type `<space>sh` then write `lazy.nvim-plugin`
  -- you can continue same window with `<space>sr` which resumes last telescope search
}, {
  ui = {
    -- If you are using a Nerd Font: set icons to an empty table which will use the
    -- default lazy.nvim defined Nerd Font icons, otherwise define a unicode icons table
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
})

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
