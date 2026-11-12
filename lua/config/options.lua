-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Heavy pane borders (easier to see and to grab with the mouse). Color is set in autocmds.lua.
vim.opt.fillchars:append({
  vert = "┃",
  horiz = "━",
  horizup = "┻",
  horizdown = "┳",
  vertleft = "┫",
  vertright = "┣",
  verthoriz = "╋",
})
