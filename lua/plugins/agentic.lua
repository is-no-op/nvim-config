-- Cursor-style chat panel for Claude Code, via the Agent Client Protocol (ACP).
-- Adapter: npm i -g @agentclientprotocol/claude-agent-acp  (uses the existing `claude /login`)
-- Opened on startup by lua/config/ide.lua (right pane).
return {
  {
    "carlos-algms/agentic.nvim",
    lazy = true,
    opts = {
      provider = "claude-agent-acp",
      windows = {
        position = "right",
        width = "35%",
        -- Note: on the Neovim 0.13 dev build, the chat threw "E315: ml_get: Invalid lnum" on open
        -- (Treesitter markdown line-concealing vs. agentic rewriting the buffer). Not reproducible on
        -- 0.12.6 stable. If it returns after a Neovim upgrade, add:
        --   chat = { win_opts = { conceallevel = 0 } }, input = { win_opts = { conceallevel = 0 } },
      },
    },
    keys = {
      { "<leader>a", "", desc = "+ai", mode = { "n", "v" } },
      {
        "<leader>ac",
        function()
          require("agentic").toggle({ auto_add_to_context = false })
        end,
        desc = "Claude chat: toggle",
      },
      {
        "<leader>af",
        function()
          require("agentic").open({ auto_add_to_context = false })
        end,
        desc = "Claude chat: focus",
      },
      {
        "<leader>aa",
        function()
          require("agentic").add_selection_or_file_to_context()
        end,
        mode = { "n", "v" },
        desc = "Claude chat: add file/selection",
      },
      {
        "<leader>ad",
        function()
          require("agentic").add_buffer_diagnostics()
        end,
        desc = "Claude chat: add diagnostics",
      },
      {
        "<leader>an",
        function()
          require("agentic").new_session()
        end,
        desc = "Claude chat: new session",
      },
      {
        "<leader>ah",
        function()
          require("agentic").restore_session()
        end,
        desc = "Claude chat: history",
      },
      {
        "<leader>ax",
        function()
          require("agentic").stop_generation()
        end,
        desc = "Claude chat: stop",
      },
    },
  },

  -- Keep blink.cmp out of the chat input; agentic has its own @file and /command completion.
  {
    "saghen/blink.cmp",
    optional = true,
    opts = function(_, opts)
      local prev = opts.enabled
      opts.enabled = function()
        if vim.bo.filetype == "AgenticInput" then
          return false
        end
        if type(prev) == "function" then
          return prev()
        end
        return prev ~= false
      end
    end,
  },
}
