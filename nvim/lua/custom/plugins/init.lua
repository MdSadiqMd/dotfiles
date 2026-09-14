-- Lightweight Cursor-parity plugins. Each is dependency-free and tiny;
-- heavy alternatives deliberately avoided (neo-tree+nui, toggleterm,
-- diffview/neogit, AI assistants, dashboards).

-- Cursor-like tree mouse: files always open in the middle editor window
-- (never the terminal panel), single-click previews, double-click pins.
local function nvim_tree_editor_win()
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(w).relative == '' then
      local b = vim.api.nvim_win_get_buf(w)
      if vim.bo[b].buftype == '' and vim.bo[b].filetype ~= 'NvimTree' and not vim.w[w].ide_term_panel then
        return w
      end
    end
  end
  return nil
end

local function nvim_tree_open_node(api, node, focus_file)
  if node.type == 'directory' then
    api.node.open.edit() -- expand/collapse only, never touches windows
    return
  end
  local win = nvim_tree_editor_win()
  if not win then
    vim.cmd 'vsplit'
    win = vim.api.nvim_get_current_win()
  end
  vim.api.nvim_set_current_win(win)
  vim.cmd('edit ' .. vim.fn.fnameescape(node.absolute_path))
  if not focus_file then
    api.tree.focus()
  end
end

local function nvim_tree_on_attach(bufnr)
  local api = require 'nvim-tree.api'
  api.config.mappings.default_on_attach(bufnr)
  local function under_cursor()
    return api.tree.get_node_under_cursor()
  end
  -- Single click: preview in the editor, keep focus in the tree.
  vim.keymap.set('n', '<LeftRelease>', function()
    local node = under_cursor()
    if node then
      nvim_tree_open_node(api, node, false)
    end
  end, { buffer = bufnr, desc = 'Open (single-click)' })
  -- Double-click / Enter / o: open in the editor and focus it.
  local function open_focused()
    local node = under_cursor()
    if node then
      nvim_tree_open_node(api, node, true)
    end
  end
  vim.keymap.set('n', '<2-LeftMouse>', open_focused, { buffer = bufnr, desc = 'Open file (double-click)' })
  vim.keymap.set('n', '<CR>', open_focused, { buffer = bufnr, desc = 'Open file' })
  vim.keymap.set('n', 'o', open_focused, { buffer = bufnr, desc = 'Open file' })
  -- Right-click: Cursor-style file/folder actions menu (see TreePopUp).
  vim.keymap.set('n', '<RightMouse>', function()
    local m = vim.fn.getmousepos()
    if m.winid ~= 0 then
      vim.api.nvim_set_current_win(m.winid)
      pcall(vim.api.nvim_win_set_cursor, m.winid, { m.line, 0 })
    end
    vim.cmd 'popup TreePopUp'
  end, { buffer = bufnr, desc = 'File actions menu (right-click)' })
end

return {
  { -- Left file tree: folders/files with color-only git status, mouse-clickable.
    -- Lighter than neo-tree (no nui/plenary deps). Files open in middle window.
    'nvim-tree/nvim-tree.lua',
    lazy = false,
    opts = {
      on_attach = nvim_tree_on_attach,
      view = { side = 'left', width = 30 },
      renderer = {
        group_empty = true,
        highlight_git = true, -- git status via filename color, no letter badges
        highlight_opened_files = 'name',
        icons = { show = { file = true, folder = true, folder_arrow = true, git = false } },
      },
      git = { enable = true, show_on_dirs = true, show_on_open_dirs = true, timeout = 400 },
      diagnostics = { enable = true, show_on_dirs = true },
      update_focused_file = { enable = true }, -- tree follows the open file, like Cursor
      filters = { dotfiles = false },
      actions = { open_file = { quit_on_open = false } },
    },
  },

  { -- Cursor-like file tabs: full-height tree, tabs only over the editor.
    -- Mouse: click switches, right/middle-click closes, hover reveals x.
    'akinsho/bufferline.nvim',
    version = '*',
    lazy = false,
    opts = {
      options = {
        mode = 'buffers',
        diagnostics = 'nvim_lsp',
        diagnostics_update_in_insert = false,
        -- Files only: terminal panel and tree have their own strips.
        -- Unnamed blank screen is hidden too: zero files = zero tabs.
        custom_filter = function(bufnr)
          if vim.bo[bufnr].buftype == 'terminal' then
            return false
          end
          if vim.bo[bufnr].filetype == 'NvimTree' then
            return false
          end
          if vim.bo[bufnr].buftype == '' and vim.fn.bufname(bufnr) == '' then
            return false
          end
          return true
        end,
        offsets = {
          { filetype = 'NvimTree', text = 'File Explorer', text_align = 'left', separator = true },
        },
        show_buffer_close_icons = true,
        show_close_icon = false,
        separator_style = 'thin',
        always_show_bufferline = true,
        hover = { enabled = true, reveal = { 'close' } },
        sort_by = 'insert_after_current',
        left_mouse_command = 'buffer %d',
        right_mouse_command = 'bdelete %d',
        middle_mouse_command = 'bdelete %d',
        indicator = { style = 'underline' },
      },
    },
  },
  { -- Inline image viewing (Ghostty renders via the Kitty graphics protocol).
    -- Videos open externally instead (see the BufReadCmd autocmd in init.lua).
    -- Requires: brew install imagemagick
    '3rd/image.nvim',
    lazy = false,
    build = false, -- never build the luarock; use the CLI processor
    opts = {
      backend = 'kitty',
      processor = 'magick_cli',
      hijack_file_patterns = { '*.png', '*.jpg', '*.jpeg', '*.gif', '*.webp', '*.avif', '*.heic', '*.bmp', '*.ico' },
      integrations = {
        markdown = { enabled = true, only_render_image_at_cursor = false },
      },
    },
  },
  { -- Markdown read view (headings, lists, tables, code) inside the buffer.
    -- Raw by default; Cmd+I toggles. No icon/tree-sitter deps needed
    -- (mini.icons is set up, nvim-treesitter is installed).
    'MeanderingProgrammer/render-markdown.nvim',
    ft = { 'markdown' },
    keys = {
      { '<M-i>', '<cmd>RenderMarkdown toggle<cr>', mode = { 'n', 'i', 'v' }, desc = 'Toggle markdown read view (Cmd+I)' },
    },
    opts = {
      enabled = false, -- start raw; render only on Cmd+I
    },
  },
  { -- Cursor-like overview ruler: file-wide git marks on the right edge.
    -- Same author as gitsigns, no dependencies. Left gutter stays per-line.
    'lewis6991/satellite.nvim',
    event = { 'BufReadPost', 'BufNewFile' },
    opts = {
      current_only = false,
      winblend = 50,
      width = 2,
      excluded_filetypes = { 'NvimTree', 'TelescopePrompt', 'TelescopeResults', 'lazy', 'mason', 'help', 'qf' },
      handlers = {
        gitsigns = { enable = true },
        marks = { enable = false },
      },
    },
  },
  { -- Full git commands (:Git status/diff/blame/log). Single file, no deps.
    -- Pairs with gitsigns (per-line gutter in init.lua) for Cursor parity.
    'tpope/vim-fugitive',
    cmd = { 'Git', 'G', 'Gdiffsplit', 'Gread', 'Gwrite', 'GMove', 'GDelete', 'GBrowse' },
    keys = {
      { '<leader>gs', '<cmd>Git<cr>', desc = '[G]it [S]tatus (Source Control)' },
      { '<M-G>', '<cmd>Git<cr>', desc = '[G]it status (Cursor Cmd+Shift+G)' },
      { '<leader>gd', '<cmd>Gdiffsplit<cr>', desc = '[G]it [D]iff split' },
      { '<leader>gb', '<cmd>Git blame<cr>', desc = '[G]it [B]lame' },
      { '<leader>gl', '<cmd>Git log --oneline<cr>', desc = '[G]it [L]og' },
    },
  },

  { -- Cursor-like auto-close brackets. Tiny, loads only in insert mode.
    'windwp/nvim-autopairs',
    event = 'InsertEnter',
    opts = {},
  },

  { -- Cursor-like indent guides. Tiny, loads on first file read.
    'lukas-reineke/indent-blankline.nvim',
    main = 'ibl',
    event = { 'BufReadPost', 'BufNewFile' },
    opts = {},
  },
}
