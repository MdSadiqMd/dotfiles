vim.loader.enable()

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.g.have_nerd_font = true

require 'config.options'
require 'config.keymaps'
require 'config.autocmds'
require 'ide.terminal'
require 'ide.layout'
require 'ide.tree'
require 'ide.clicks'
require 'ide.workspace'
require 'config.lazy'
