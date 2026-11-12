-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Bottom terminal under the editor (overrides LazyVim's full-width <c-/> terminal)
local ide_term = function()
  require("config.ide").terminal_focus()
end
vim.keymap.set({ "n", "t" }, "<c-/>", ide_term, { desc = "Terminal (bottom)" })
vim.keymap.set({ "n", "t" }, "<c-_>", ide_term, { desc = "which_key_ignore" })
