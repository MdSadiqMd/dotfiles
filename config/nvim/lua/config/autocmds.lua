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
      local uv = vim.uv
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
