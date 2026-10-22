local map = vim.keymap.set

map('n', '<Esc>', '<cmd>nohlsearch<CR>')
map('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })
map('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

map('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
map('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
map('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
map('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- Cmd+S (Ghostty sends Ctrl+S): save without leaving insert mode.
map({ 'n', 'i', 'v' }, '<C-s>', '<cmd>update<cr>', { desc = 'Save file (Cmd+S)' })
map('t', '<C-s>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- Cmd+/ (Ghostty sends Alt+/): builtin gc commenting.
map('n', '<M-/>', 'gcc', { remap = true, desc = 'Toggle line comment (Cmd+/)' })
map('v', '<M-/>', 'gc', { remap = true, desc = 'Toggle comment (Cmd+/)' })
