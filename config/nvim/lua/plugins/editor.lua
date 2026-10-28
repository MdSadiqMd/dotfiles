-- Telescope loads on first use; keymaps go through this so they don't force it at startup.
local function pick(name, opts)
  return function()
    require('telescope.builtin')[name](type(opts) == 'function' and opts() or opts)
  end
end

return {
  { 'NMAC427/guess-indent.nvim', event = 'BufReadPre', opts = {} },

  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    opts = {
      -- 300 ms, not 0: instant popups ambush trackpad users in the file tree,
      -- where every letter is a mapping and any micro-drag enters visual mode.
      delay = 300,
      -- Never auto-show on entering visual mode (trackpad micro-drags do that).
      defer = function()
        return true
      end,
      spec = {
        { '<leader>s', group = '[S]earch' },
        { '<leader>t', group = '[T]oggle' },
        { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } },
        { '<leader>g', group = '[G]it' },
        { '<leader>e', group = '[E]xplorer' },
      },
    },
  },

  {
    'nvim-telescope/telescope.nvim',
    cmd = 'Telescope',
    dependencies = {
      'nvim-lua/plenary.nvim',
      { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
      'nvim-telescope/telescope-ui-select.nvim',
    },
    init = function()
      -- vim.ui.select (code actions, etc.) loads telescope and its ui-select on first use.
      vim.ui.select = function(...)
        require('lazy').load { plugins = { 'telescope.nvim' } }
        return vim.ui.select(...)
      end
    end,
    keys = {
      -- Cmd+P (Ghostty sends Ctrl+P): files in the current file's folder.
      {
        '<C-p>',
        pick('find_files', function()
          local dir = vim.fn.expand '%:p:h'
          return { cwd = vim.fn.isdirectory(dir) == 1 and dir or vim.fn.getcwd() }
        end),
        mode = { 'n', 'i', 'v' },
        desc = 'Find files here (Cmd+P)',
      },
      { '<M-f>', pick 'live_grep', mode = { 'n', 'i', 'v' }, desc = 'Search in files (Cmd+Shift+F)' },
      { '<M-p>', pick 'builtin', mode = { 'n', 'i', 'v' }, desc = 'Command palette (Cmd+Shift+P)' },
      { '<leader>sh', pick 'help_tags', desc = '[S]earch [H]elp' },
      { '<leader>sk', pick 'keymaps', desc = '[S]earch [K]eymaps' },
      { '<leader>sf', pick 'find_files', desc = '[S]earch [F]iles' },
      { '<leader>ss', pick 'builtin', desc = '[S]earch [S]elect Telescope' },
      { '<leader>sw', pick 'grep_string', desc = '[S]earch current [W]ord' },
      { '<leader>sg', pick 'live_grep', desc = '[S]earch by [G]rep' },
      { '<leader>sd', pick 'diagnostics', desc = '[S]earch [D]iagnostics' },
      { '<leader>sr', pick 'resume', desc = '[S]earch [R]esume' },
      { '<leader>s.', pick 'oldfiles', desc = '[S]earch Recent Files' },
      { '<leader><leader>', pick 'buffers', desc = '[ ] Find existing buffers' },
      {
        '<leader>/',
        pick('current_buffer_fuzzy_find', function()
          return require('telescope.themes').get_dropdown { winblend = 10, previewer = false }
        end),
        desc = '[/] Fuzzily search in current buffer',
      },
      { '<leader>s/', pick('live_grep', { grep_open_files = true, prompt_title = 'Live Grep in Open Files' }), desc = '[S]earch [/] in Open Files' },
      { '<leader>sn', pick('find_files', { cwd = vim.fn.stdpath 'config' }), desc = '[S]earch [N]eovim files' },
    },
    config = function()
      local telescope = require 'telescope'
      telescope.setup {
        extensions = { ['ui-select'] = { require('telescope.themes').get_dropdown() } },
      }
      pcall(telescope.load_extension, 'fzf')
      telescope.load_extension 'ui-select'
    end,
  },

  { 'folke/todo-comments.nvim', event = { 'BufReadPost', 'BufNewFile' }, dependencies = { 'nvim-lua/plenary.nvim' }, opts = { signs = false } },

  {
    'echasnovski/mini.nvim',
    config = function()
      require('mini.ai').setup { n_lines = 500 }
      require('mini.surround').setup()
      require('mini.icons').setup()
      require('mini.icons').mock_nvim_web_devicons() -- one icon provider for neo-tree, telescope, bufferline
      local statusline = require 'mini.statusline'
      statusline.setup { use_icons = true }
      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_location = function()
        return '%2l:%-2v'
      end
    end,
  },

  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'master',
    build = ':TSUpdate',
    event = { 'BufReadPost', 'BufNewFile' },
    cmd = { 'TSInstall', 'TSUpdate' },
    main = 'nvim-treesitter.configs',
    opts = {
      -- Pre-installed: auto_install compiles a missing parser in the background and the
      -- file that triggered it stays plain until reopened. Covers every language here.
      ensure_installed = {
        'bash',
        'c',
        'css',
        'csv',
        'diff',
        'dockerfile',
        'eex',
        'elixir',
        'erlang',
        'git_config',
        'gitcommit',
        'gitignore',
        'go',
        'gomod',
        'gosum',
        'hcl',
        'heex',
        'html',
        'ini',
        'javascript',
        'json',
        'jsonc',
        'just',
        'lua',
        'luadoc',
        'make',
        'markdown',
        'markdown_inline',
        'nix',
        'python',
        'query',
        'regex',
        'rust',
        'sql',
        'terraform',
        'toml',
        'tsx',
        'typescript',
        'vim',
        'vimdoc',
        'xml',
        'yaml',
      },
      auto_install = true,
      highlight = {
        enable = true,
        -- Large generated/minified files re-parse slowly on every edit: show them plain.
        disable = function(_, buf)
          local ok, stat = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(buf))
          return ok and stat ~= nil and stat.size > 512 * 1024
        end,
        additional_vim_regex_highlighting = { 'ruby' },
      },
      indent = { enable = true, disable = { 'ruby' } },
    },
  },

  { 'windwp/nvim-autopairs', event = 'InsertEnter', opts = {} },
  { 'lukas-reineke/indent-blankline.nvim', main = 'ibl', event = { 'BufReadPost', 'BufNewFile' }, opts = {} },
}
