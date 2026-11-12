-- IDE layout: neo-tree left, editor center, terminal bottom, Claude chat right.
-- Layout logic lives in lua/config/ide.lua. The Claude chat pane is agentic.nvim
-- (lua/plugins/agentic.lua); claudecode.nvim stays as a fallback for the full CLI.
return {
  -- Layout wiring. Attached to snacks.nvim (always present, and it owns the bottom terminal)
  -- so the layout doesn't depend on any one AI plugin.
  {
    "folke/snacks.nvim",
    init = function()
      -- Detect `cmd | nvim -` so the layout isn't built around piped input
      vim.api.nvim_create_autocmd("StdinReadPre", {
        once = true,
        callback = function()
          require("config.ide").stdin = true
        end,
      })
      local exit_group = vim.api.nvim_create_augroup("ide_layout_exit", { clear = true })
      -- `:qa` typed inside a terminal pane: Snacks closes its terminal windows on ExitPre,
      -- and Neovim cancels a quit when the window it was typed in gets closed. So when a
      -- quit-all command is entered from a terminal pane, move to the editor before it runs.
      vim.api.nvim_create_autocmd("CmdlineLeave", {
        group = exit_group,
        callback = function()
          if vim.v.event.abort or vim.fn.getcmdtype() ~= ":" or vim.bo.buftype ~= "terminal" then
            return
          end
          local cmd = vim.fn.getcmdline()
          if cmd:match("^%s*q[uit]*a[ll]*!?%s*$") or cmd:match("^%s*wq?a[ll]*!?%s*$") or cmd:match("^%s*xa[ll]*!?%s*$") then
            local main = require("config.ide").main_win()
            if main then
              vim.api.nvim_set_current_win(main)
            end
          end
        end,
      })
      -- If a quit is refused (e.g. unsaved changes), Snacks has already hidden the terminal
      -- panes. This scheduled callback only runs if Neovim is still alive: restore the layout.
      vim.api.nvim_create_autocmd("ExitPre", {
        group = exit_group,
        callback = function()
          vim.schedule(function()
            require("config.ide").layout()
          end)
        end,
      })
      -- Build the layout once Neovim has started (not earlier: neo-tree needs cwd settled)
      vim.api.nvim_create_autocmd("VimEnter", {
        group = vim.api.nvim_create_augroup("ide_layout_startup", { clear = true }),
        once = true,
        callback = function()
          require("config.ide").startup()
        end,
      })
    end,
    keys = {
      {
        "<leader>al",
        function()
          require("config.ide").layout()
        end,
        desc = "Restore IDE layout",
      },
    },
  },

  -- Fallback: the full Claude Code CLI in a terminal (for anything the ACP chat doesn't cover).
  -- Not opened at startup. Its LazyVim keys are replaced so <leader>a* belongs to the chat pane.
  {
    "coder/claudecode.nvim",
    opts = {
      terminal = {
        provider = "snacks",
        split_side = "right",
        split_width_percentage = 0.35,
      },
    },
    keys = function()
      return {
        { "<leader>aC", "<cmd>ClaudeCode<cr>", desc = "Claude CLI (terminal)" },
        { "<leader>aR", "<cmd>ClaudeCode --resume<cr>", desc = "Claude CLI: resume session" },
        { "<leader>aA", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Claude CLI: accept diff" },
        { "<leader>aD", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Claude CLI: deny diff" },
      }
    end,
  },

  -- venv-selector (from the lang.python extra) hard-requires the `fd` binary; without it, it
  -- errors on every .py file and blocks pyright/ruff from attaching. So only enable it where fd
  -- is installed (setup.sh's Brewfile installs it). pyright auto-detects ./.venv either way.
  {
    "linux-cultist/venv-selector.nvim",
    enabled = function()
      return vim.fn.executable("fd") == 1
    end,
  },
}
