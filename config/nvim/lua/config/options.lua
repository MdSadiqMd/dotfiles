-- neo-tree replaces netrw.
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

local o = vim.o
o.number = true
o.mouse = 'a'
o.mousemodel = 'popup' -- right-click opens the PopUp menu
o.mousetime = 1000 -- forgiving double-click for trackpads
o.mousemoveevent = true -- hover in the file tree
o.winborder = 'rounded'
o.showmode = false
o.breakindent = true
o.undofile = true
o.ignorecase = true
o.smartcase = true
o.signcolumn = 'yes'
o.updatetime = 250
o.timeoutlen = 300
o.splitright = true
o.splitbelow = true
o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
o.inccommand = 'split'
o.cursorline = true
o.termguicolors = true
o.showtabline = 2 -- always show the file tabs
o.scrolloff = 10
o.confirm = true

-- The clipboard provider is slow to load; set it after startup.
vim.schedule(function()
  o.clipboard = 'unnamedplus'
end)
