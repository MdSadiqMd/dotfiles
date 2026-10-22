-- IDE layout: explorer left, editor middle, terminal panel right.
local term = require 'ide.terminal'
local editor_win = require('ide.util').editor_win

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
    term.kill() -- Cursor Cmd+W on a terminal kills that tab
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

vim.api.nvim_create_user_command('IdeTerminalRight', function()
  term.toggle()
end, { desc = 'Toggle right terminal' })
vim.api.nvim_create_user_command('IdeExplorerLeft', function()
  toggle_explorer_left()
end, { desc = 'Toggle left explorer' })

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
    term.toggle()
    vim.cmd 'stopinsert'
    local mid = editor_win()
    if mid then
      vim.api.nvim_set_current_win(mid) -- files restore into the middle
    end
    require('ide.workspace').restore() -- reopen last session's files (blank editor only)
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
      if editor_win() then
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
