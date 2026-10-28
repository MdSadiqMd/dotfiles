local images = { 'png', 'jpg', 'jpeg', 'gif', 'webp', 'avif', 'heic', 'bmp', 'ico' }

return {
  {
    'folke/tokyonight.nvim',
    priority = 1000,
    config = function()
      ---@diagnostic disable-next-line: missing-fields
      require('tokyonight').setup {
        styles = {
          comments = { italic = false }, -- Disable italics in comments
        },
      }

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

  { -- Left file tree (neo-tree): IDE panel, files open in the middle window.
    'nvim-neo-tree/neo-tree.nvim',
    branch = 'v3.x',
    dependencies = { 'nvim-lua/plenary.nvim', 'MunifTanjim/nui.nvim' },
    cmd = 'Neotree', -- also loads on require('neo-tree...') from the IDE layout
    config = function()
      local ok, neotree = pcall(require, 'neo-tree')
      if not ok then
        vim.notify('neo-tree not installed yet: run :Lazy sync and restart', vim.log.levels.WARN)
        return
      end
      local nerd = vim.g.have_nerd_font
      -- Old nvim-tree look (icons + arrows + git letters). With a Nerd Font
      -- neo-tree's own defaults already render it, so only override with
      -- plain glyphs when there is no Nerd Font (nothing renders as tofu).
      -- NOTE: never put Nerd-Font codepoints here literally; with a font
      -- they come from neo-tree/devicons defaults.
      -- Opened-file highlighting replaces the git color (bold, no fg), so a modified
      -- file turned white once opened. Like Cursor: names keep their git status color.
      local comp = { name = { highlight_opened_files = false, use_git_status_colors = true } }
      comp.indent = { with_expanders = true }
      if not nerd then
        comp.indent.expander_collapsed = '▸'
        comp.indent.expander_expanded = '▾'
        -- No folder glyph: the expander already shows open/closed.
        comp.icon = {
          folder_closed = '',
          folder_open = '',
          folder_empty = '',
          folder_empty_open = '',
          default = ' ',
          provider = function(icon, node, _state)
            if node.type == 'file' or node.type == 'terminal' then
              icon.text = ' '
            end
          end,
        }
        comp.git_status = {
          symbols = {
            added = 'A',
            deleted = 'D',
            modified = 'M',
            renamed = 'R',
            untracked = '?',
            ignored = '!',
            unstaged = 'M',
            staged = 'S',
            conflict = 'C',
          },
        }
      end
      neotree.setup {
        sources = { 'filesystem' },
        close_if_last_window = false,
        enable_diagnostics = true,
        enable_git_status = true,
        open_files_do_not_replace_types = { 'terminal', 'Trouble', 'qf', 'edgy' },
        popup_border_style = 'rounded',
        default_component_configs = comp,
        window = { position = 'left', width = 30, mappings = require('ide.tree').mappings },
        filesystem = {
          bind_to_cwd = false,
          follow_current_file = { enabled = true }, -- tree follows the open file
          group_empty_dirs = true,
          hijack_netrw_behavior = 'open_default',
          filtered_items = { hide_dotfiles = false, hide_gitignored = false },
          use_libuv_file_watcher = true, -- instant refresh on file changes
        },
      }
      -- Git badges must follow commits made outside the tree (terminal
      -- panel, fugitive, lazygit): those touch .git/ only, which neither
      -- buffer writes nor the file watcher (it skips .git) can see.
      local git_pending = false
      local function refresh_git_status()
        if git_pending then
          return
        end
        git_pending = true
        vim.defer_fn(function()
          git_pending = false
          local visible = false
          for _, w in ipairs(vim.api.nvim_list_wins()) do
            if vim.api.nvim_win_get_config(w).relative == '' and vim.bo[vim.api.nvim_win_get_buf(w)].filetype == 'neo-tree' then
              visible = true
              break
            end
          end
          if not visible then
            return
          end
          local ok_ev, ev = pcall(require, 'neo-tree.events')
          if ok_ev and type(ev.fire_event) == 'function' and type(ev.GIT_EVENT) == 'string' then
            pcall(ev.fire_event, ev.GIT_EVENT)
          end
        end, 400)
      end
      vim.api.nvim_create_autocmd({ 'FocusGained', 'TermClose', 'TermLeave', 'DirChanged' }, {
        desc = 'Refresh tree git status after outside git changes',
        callback = refresh_git_status,
      })
      vim.api.nvim_create_autocmd({ 'BufWritePost', 'BufDelete' }, {
        pattern = { '*COMMIT_EDITMSG*', '*MERGE_MSG*' },
        desc = 'Refresh tree git status after committing',
        callback = refresh_git_status,
      })
    end,
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
          if vim.bo[bufnr].filetype == 'neo-tree' then
            return false
          end
          if vim.bo[bufnr].buftype == '' and vim.fn.bufname(bufnr) == '' then
            return false
          end
          return true
        end,
        offsets = {
          { filetype = 'neo-tree', text = 'File Explorer', text_align = 'left', separator = true },
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
  { -- Inline images (Ghostty speaks the Kitty graphics protocol); videos open externally.
    '3rd/image.nvim',
    ft = 'markdown',
    event = vim.tbl_map(function(ext)
      return 'BufReadPre *.' .. ext
    end, images),
    build = false, -- never build the luarock; use the CLI processor
    opts = {
      backend = 'kitty',
      processor = 'magick_cli',
      hijack_file_patterns = vim.tbl_map(function(ext)
        return '*.' .. ext
      end, images),
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
      excluded_filetypes = { 'neo-tree', 'TelescopePrompt', 'TelescopeResults', 'lazy', 'help', 'qf' },
      handlers = {
        gitsigns = { enable = true },
        marks = { enable = false },
      },
    },
    config = function(_, opts)
      -- satellite maps rows to the bar with height * rows / (line_count - 1): a
      -- one-line buffer divides by zero and every handler errors with `id = nan`.
      -- ponytail: guards upstream util (unfixed as of 87843c9); drop when it is.
      local util = require 'satellite.util'
      local function to_bar(winid, row, row2)
        local lines0 = util.virtual_line_count(winid, 1) - 1
        if lines0 < 1 then
          return 0
        end
        return (util.get_winheight(winid) - 1) * util.virtual_line_count(winid, row, row2) / lines0
      end
      util.height_to_virtual = function(winid, row, row2)
        return math.max(1, util.round(to_bar(winid, row, row2)))
      end
      util.row_to_barpos = function(winid, row)
        local v = to_bar(winid, 1, row)
        local vr = util.round(v)
        return vr, vr - v
      end
      require('satellite').setup(opts)
    end,
  },
}
