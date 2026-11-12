-- Colorschemes to compare with <leader>uC.
-- lazy = false + priority = 1000: every scheme plugin loads at startup, before other plugins,
-- so each one is fully set up when you switch to it.
return {
  { "rebelot/kanagawa.nvim", lazy = false, priority = 1000 },
  { "rose-pine/neovim", name = "rose-pine", lazy = false, priority = 1000 },
  { "sainnhe/gruvbox-material", lazy = false, priority = 1000 },
  { "EdenEast/nightfox.nvim", lazy = false, priority = 1000 }, -- includes carbonfox, terafox
  { "ribru17/bamboo.nvim", lazy = false, priority = 1000 }, -- warm green, everforest-like
  {
    "sainnhe/everforest",
    lazy = false,
    priority = 1000,
    init = function()
      vim.g.everforest_background = "medium" -- Medium Dark flavor (with background=dark)
      vim.g.everforest_better_performance = 1
    end,
  },
  -- Shipped by LazyVim as lazy-loaded; load them up front too
  { "folke/tokyonight.nvim", lazy = false, priority = 1000 },
  { "catppuccin/nvim", name = "catppuccin", lazy = false, priority = 1000 },

  -- Default colorscheme
  { "LazyVim/LazyVim", opts = { colorscheme = "kanagawa-wave" } },

  -- Extra syntax highlighting parsers that LazyVim doesn't ship by default
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "go", "gomod", "gosum", "java", "dockerfile", "make", "sql" } },
  },
}
