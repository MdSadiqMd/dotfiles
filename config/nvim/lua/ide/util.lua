local M = {}

-- The middle editor window: a normal file window, not the tree, terminal panel or a float.
function M.editor_win()
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(w).relative == '' then
      local b = vim.api.nvim_win_get_buf(w)
      if vim.bo[b].buftype == '' and vim.bo[b].filetype ~= 'neo-tree' and not vim.w[w].ide_term_panel then
        return w
      end
    end
  end
end

function M.tree_win()
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(w).relative == '' and vim.bo[vim.api.nvim_win_get_buf(w)].filetype == 'neo-tree' then
      return w
    end
  end
end

return M
