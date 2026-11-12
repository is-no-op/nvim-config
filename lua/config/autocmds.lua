-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Visible pane borders. Many themes (incl. kanagawa) draw separators darker than the background;
-- use the theme's comment color instead: muted, but clearly visible. Re-applied on theme switch.
-- Covers plugin-specific separator groups (neo-tree, Snacks terminal) too.
local function visible_separators()
  local fg = vim.api.nvim_get_hl(0, { name = "Comment", link = false }).fg
  if not fg then
    return
  end
  for _, group in ipairs({ "WinSeparator", "NeoTreeWinSeparator", "SnacksWinSeparator" }) do
    vim.api.nvim_set_hl(0, group, { fg = fg })
  end
end
visible_separators() -- this file loads after the colorscheme is already applied
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("visible_separators", { clear = true }),
  callback = visible_separators,
})
