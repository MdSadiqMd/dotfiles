-- Cursor-parity IDE plugins. File tree is neo-tree.nvim: single-click
-- previews, double-click pins, right-click menu, hover highlight.

-- neo-tree file tree (IDE panel): files always open in the middle editor
-- window (never the terminal panel). Window targeting reuses the shared
-- _G.IdeEditorWin() from init.lua. All requires run at call time, so this
-- file loads cleanly before `:Lazy sync` installs anything.
local neo_press = { winid = 0, line = 0, buf = -1, opened = false, toggled_id = nil, toggled_at = 0 }
local neo_last_pin = 0

local function neo_state()
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

local function neo_active_state(state)
  if state and state.tree then
    return state
  end
  return neo_state()
end

local function neo_cursor_node(state)
  state = neo_active_state(state)
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

local function neo_node_path(node)
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

local function neo_open_editor(path, focus_file)
  local tree_win = vim.api.nvim_get_current_win()
  local win = _G.IdeEditorWin()
  if not win then
    vim.cmd 'vsplit'
    win = vim.api.nvim_get_current_win()
  end
  vim.api.nvim_set_current_win(win)
  vim.cmd('edit ' .. vim.fn.fnameescape(path))
  if not focus_file then
    if tree_win and vim.api.nvim_win_is_valid(tree_win) then
      pcall(vim.api.nvim_set_current_win, tree_win)
    else
      local ok, nt = pcall(require, 'neo-tree.command')
      if ok then
        pcall(nt.execute, { action = 'focus', source = 'filesystem', position = 'left' })
      end
    end
  end
end

local function neo_open_node(state, node, focus_file)
  if not node then
    return
  end
  -- Visual-mode callers pass nil state; resolve it here so toggle_directory
  -- never receives nil (E5108).
  state = neo_active_state(state)
  if not state then
    return
  end
  if node.type == 'directory' then
    require('neo-tree.sources.filesystem').toggle_directory(state, node)
    return
  end
  local path = neo_node_path(node)
  if not path then
    return
  end
  if vim.fn.filereadable(path) == 0 and vim.fn.isdirectory(path) == 0 then
    return
  end
  neo_open_editor(path, focus_file)
end

-- IDE "open to the side": new split inside the middle editor area,
-- tree and terminal panel untouched.
local function neo_open_side(state, node, how)
  if not node then
    return
  end
  state = neo_active_state(state)
  if not state then
    return
  end
  if node.type == 'directory' then
    require('neo-tree.sources.filesystem').toggle_directory(state, node)
    return
  end
  local path = neo_node_path(node)
  if not path then
    return
  end
  local win = _G.IdeEditorWin()
  if not win then
    vim.cmd 'vsplit'
    win = vim.api.nvim_get_current_win()
  end
  vim.api.nvim_set_current_win(win)
  vim.cmd(how == 'split' and 'split' or 'vsplit')
  vim.cmd('edit ' .. vim.fn.fnameescape(path))
end

-- Clicks must act on the clicked row, not the cursor row. Without this a
-- click on a file expands the previously-focused folder below it.
-- Always the release row: a press on one row and release on another is a
-- sloppy tap, not a drag (text selection is disabled in the tree anyway).
local function neo_node_at_mouse(state)
  local m = vim.fn.getmousepos()
  if m.winid == 0 then
    return nil
  end
  local ok_buf, buf = pcall(vim.api.nvim_win_get_buf, m.winid)
  if not ok_buf or vim.bo[buf].filetype ~= 'neo-tree' then
    return nil -- click outside the tree
  end
  if m.line < 1 or m.line > vim.api.nvim_buf_line_count(buf) then
    return nil -- empty space below the tree: select nothing, open nothing
  end
  pcall(vim.api.nvim_set_current_win, m.winid)
  pcall(vim.api.nvim_win_set_cursor, m.winid, { m.line, 0 })
  return neo_cursor_node(state)
end

-- neo-tree mapping functions swallow the press event, so record it and
-- perform the default click behavior ourselves (cursor follows the mouse).
-- Plain presses also preview files immediately: trackpad taps often drift a
-- row between press and release, and waiting for release meant the first tap
-- was swallowed as a "drag". Folders still toggle on release.
local function neo_record_press(state, do_preview)
  local m = vim.fn.getmousepos()
  neo_press.winid = m.winid
  neo_press.line = m.line
  neo_press.opened = false
  local ok, buf = pcall(vim.api.nvim_win_get_buf, m.winid)
  neo_press.buf = ok and buf or -1
  if not ok or vim.bo[buf].filetype ~= 'neo-tree' then
    return
  end
  pcall(vim.api.nvim_set_current_win, m.winid)
  if m.line < 1 or m.line > vim.api.nvim_buf_line_count(buf) then
    return
  end
  pcall(vim.api.nvim_win_set_cursor, m.winid, { m.line, 0 })
  if not do_preview then
    return
  end
  local node = neo_cursor_node(state)
  if node and node.type == 'file' then
    local path = neo_node_path(node)
    if path and (vim.fn.filereadable(path) == 1 or vim.fn.isdirectory(path) == 1) then
      neo_open_editor(path, false)
      neo_press.opened = true
    end
  end
end

local function neo_preview_at_mouse(state)
  local node = neo_node_at_mouse(state)
  if node then
    neo_open_node(state, node, false)
  end
end

local function neo_pin_at_mouse(state)
  neo_last_pin = vim.loop.now()
  local node = neo_node_at_mouse(state)
  if not node then
    return
  end
  -- Double-clicking a folder must not toggle it twice (open then shut).
  if node.type == 'directory' then
    local id = neo_node_path(node)
    if id and id == neo_press.toggled_id and vim.loop.now() - (neo_press.toggled_at or 0) < 600 then
      return
    end
  end
  neo_open_node(state, node, true)
end

local function neo_side_at_mouse(state)
  neo_last_pin = vim.loop.now()
  local node = neo_node_at_mouse(state)
  if node then
    neo_open_side(state, node, 'vsplit')
  end
end

local function neo_exit_visual_for_click()
  -- Synchronous (verified `:normal! <Esc>` exits visual immediately).
  pcall(vim.cmd, 'normal! \27')
end

-- Hover highlights the hovered row (cursorline follows the mouse) without
-- opening anything. Only while the tree is focused, so hovering the tree
-- from the editor never steals the selection.
local function neo_hover()
  local m = vim.fn.getmousepos()
  if m.winid == 0 or m.winid ~= vim.api.nvim_get_current_win() then
    return
  end
  local ok_buf, buf = pcall(vim.api.nvim_win_get_buf, m.winid)
  if not ok_buf or vim.bo[buf].filetype ~= 'neo-tree' then
    return
  end
  if m.line < 1 or m.line > vim.api.nvim_buf_line_count(buf) then
    return
  end
  pcall(vim.api.nvim_win_set_cursor, m.winid, { m.line, 0 })
end

-- Right-click: Cursor-style file/folder actions menu (see TreePopUp).
local function neo_show_tree_menu(state)
  neo_node_at_mouse(state) -- position the cursor; menu acts on it
  vim.cmd 'popup TreePopUp'
end

-- Single click / Shift+click: preview in the editor, keep focus in the tree.
-- The press usually previewed the file already; a release on the same row
-- then does nothing, a release elsewhere opens that row instead.
local function neo_single_click(state)
  if vim.loop.now() - neo_last_pin < 300 then
    return -- final release of a double-click: keep focus in the editor
  end
  local m = vim.fn.getmousepos()
  if neo_press.opened and m.winid == neo_press.winid and m.line == neo_press.line then
    return -- press already previewed this exact row
  end
  local node = neo_node_at_mouse(state)
  if not node then
    return
  end
  if node.type == 'directory' then
    neo_press.toggled_id = neo_node_path(node)
    neo_press.toggled_at = vim.loop.now()
  end
  neo_open_node(state, node, false)
end

-- Enter / o (keyboard): open the cursor row and focus it.
local function neo_open_focused(state)
  neo_open_node(state, neo_cursor_node(state), true)
end

local neo_mappings = {
  ['<CR>'] = neo_open_focused,
  -- `o` replaces neo-tree's order-by submenu: open like an IDE instead.
  ['o'] = neo_open_focused,
  ['<2-LeftMouse>'] = neo_pin_at_mouse,
  ['<LeftMouse>'] = function(state)
    neo_record_press(state, true)
  end,
  ['<S-LeftMouse>'] = function(state)
    neo_record_press(state, true)
  end,
  ['<C-LeftMouse>'] = function(state)
    neo_record_press(state, false)
  end,
  -- Tree text selection is useless (copy via right-click menu instead) and
  -- fights with click-vs-drag detection, so swallow drags. Separator drags
  -- (sidebar resize) are on the separator, not this buffer, and still work.
  ['<LeftDrag>'] = function() end,
  ['<S-LeftDrag>'] = function() end,
  ['<LeftRelease>'] = neo_single_click,
  ['<S-LeftRelease>'] = neo_single_click,
  -- Ctrl+click (Cmd+click equivalent): open to the side, focus the editor.
  ['<C-LeftRelease>'] = neo_side_at_mouse,
  -- Middle-click: open to the side (browser-style). The press is swallowed
  -- so it never pastes into the tree buffer.
  ['<MiddleMouse>'] = function() end,
  ['<MiddleRelease>'] = neo_side_at_mouse,
  ['<MouseMove>'] = neo_hover,
  ['<RightMouse>'] = neo_show_tree_menu,
  -- Double-right-click shows the menu too (no surprise root changes).
  ['<2-RightMouse>'] = neo_show_tree_menu,
  -- `Y` would yank the rendered line as text (the only unbound yank key
  -- left); copy the relative path instead, like the old tree did.
  ['Y'] = function(state)
    local path = neo_node_path(neo_cursor_node(state))
    if path then
      vim.fn.setreg('+', vim.fn.fnamemodify(path, ':.'))
    end
  end,
  -- `s` / `S`: open to the side, deterministically in the editor area.
  ['s'] = function(state)
    neo_open_side(state, neo_cursor_node(state), 'vsplit')
  end,
  ['S'] = function(state)
    neo_open_side(state, neo_cursor_node(state), 'split')
  end,
}

-- Visual/select-mode safety net: a trackpad tap with the slightest movement
-- starts visual mode instead of clicking. These exit visual and open the
-- clicked row anyway; text yank/put stay disabled so the tree never acts
-- like a text buffer (node ops live on normal-mode keys).
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'neo-tree',
  desc = 'Mouse without text selection in the file tree',
  callback = function(ev)
    vim.keymap.set({ 'x', 's' }, '<LeftMouse>', function()
      neo_record_press(nil, false)
    end, { buffer = ev.buf, desc = 'Record press' })
    vim.keymap.set({ 'x', 's' }, '<S-LeftMouse>', function()
      neo_record_press(nil, false)
    end, { buffer = ev.buf, desc = 'Record press' })
    vim.keymap.set({ 'x', 's' }, '<LeftDrag>', function() end, { buffer = ev.buf, desc = 'No text drag in tree' })
    vim.keymap.set({ 'x', 's' }, '<S-LeftDrag>', function() end, { buffer = ev.buf, desc = 'No text drag in tree' })
    vim.keymap.set({ 'x', 's' }, '<MiddleMouse>', function() end, { buffer = ev.buf, desc = 'Swallow middle press' })
    local function visual_release(pin)
      neo_exit_visual_for_click()
      if pin then
        neo_pin_at_mouse(nil)
      else
        neo_single_click(nil)
      end
    end
    vim.keymap.set({ 'x', 's' }, '<LeftRelease>', function()
      visual_release(false)
    end, { buffer = ev.buf, desc = 'Open (single-click from visual)' })
    vim.keymap.set({ 'x', 's' }, '<S-LeftRelease>', function()
      visual_release(false)
    end, { buffer = ev.buf, desc = 'Open (shift-click from visual)' })
    vim.keymap.set({ 'x', 's' }, '<2-LeftMouse>', function()
      visual_release(true)
    end, { buffer = ev.buf, desc = 'Open file (double-click from visual)' })
    vim.keymap.set('x', 'y', '<Nop>', { buffer = ev.buf, desc = 'No text yank in tree' })
    vim.keymap.set('x', 'Y', '<Nop>', { buffer = ev.buf, desc = 'No text yank in tree' })
    vim.keymap.set('x', 'p', '<Nop>', { buffer = ev.buf, desc = 'No text put in tree' })
    -- Clicks from insert/terminal mode: record + leave the mode so the
    -- release lands in normal mode and opens on the first click.
    vim.keymap.set('i', '<LeftMouse>', function()
      vim.cmd 'stopinsert'
      neo_record_press(nil, true)
    end, { buffer = ev.buf, desc = 'Record press' })
    vim.keymap.set('t', '<LeftMouse>', function()
      neo_record_press(nil, false)
      if vim.api.nvim_get_mode().mode == 't' then
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes([[<C-\><C-n>]], true, false, true), 'n', false)
      end
    end, { buffer = ev.buf, desc = 'Record press' })
  end,
})

return {
  { -- Left file tree (neo-tree): IDE panel, files open in the middle window.
    'nvim-neo-tree/neo-tree.nvim',
    branch = 'v3.x',
    dependencies = { 'nvim-lua/plenary.nvim', 'MunifTanjim/nui.nvim' },
    lazy = false,
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
      local comp = { name = { highlight_opened_files = true } }
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
        window = { position = 'left', width = 30, mappings = neo_mappings },
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
      excluded_filetypes = { 'neo-tree', 'TelescopePrompt', 'TelescopeResults', 'lazy', 'mason', 'help', 'qf' },
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
