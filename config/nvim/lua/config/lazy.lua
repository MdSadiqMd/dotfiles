local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', 'https://github.com/folke/lazy.nvim.git', lazypath }
  if vim.v.shell_error ~= 0 then
    error('Error cloning lazy.nvim:\n' .. out)
  end
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup({ { import = 'plugins' } }, {
  install = { colorscheme = { 'tokyonight-night' } },
  change_detection = { enabled = false }, -- no file watcher on the config; restart to apply
  rocks = { enabled = false }, -- no plugin here needs luarocks
  performance = {
    rtp = { disabled_plugins = { 'gzip', 'netrwPlugin', 'rplugin', 'tarPlugin', 'tohtml', 'tutor', 'zipPlugin' } },
  },
})
