-- IDE layout:
--   ┌──────────┬──────────────────────┬──────────────┐
--   │          │  editor (top/center) │              │
--   │ neo-tree ├──────────────────────┤ Claude Code  │
--   │          │  terminal (bottom)   │              │
--   └──────────┴──────────────────────┴──────────────┘
-- Side panes run full height; the terminal sits under the editor only (like VS Code's panel).
local M = {}

M.terminal_height = 0.25 -- fraction of the editor column

local function is_side_or_special(win)
  local cfg = vim.api.nvim_win_get_config(win)
  if cfg.relative ~= "" then
    return true -- floating
  end
  local buf = vim.api.nvim_win_get_buf(win)
  local ft = vim.bo[buf].filetype
  return ft == "neo-tree" or ft:match("^Agentic") ~= nil or vim.bo[buf].buftype == "terminal"
end

--- The main editor window (largest normal window), or nil.
function M.main_win()
  local best, best_area
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if not is_side_or_special(win) then
      local area = vim.api.nvim_win_get_width(win) * vim.api.nvim_win_get_height(win)
      if not best or area > best_area then
        best, best_area = win, area
      end
    end
  end
  return best
end

local function term_opts(enter)
  return {
    -- One terminal at the workspace root (like VS Code). LazyVim.root() would change per file
    -- once an LSP attaches (e.g. terraform-ls roots at the module dir) and spawn extra terminals.
    cwd = vim.fn.getcwd(-1, -1),
    count = 1,
    win = {
      position = "bottom",
      relative = "win",
      win = M.main_win(),
      height = M.terminal_height,
      enter = enter,
    },
  }
end

--- Show / focus / hide the bottom terminal (replaces LazyVim's full-width <c-/> terminal).
function M.terminal_focus()
  local opts = term_opts(true)
  local term, created = Snacks.terminal.get(nil, vim.tbl_extend("force", opts, { create = false }))
  if not term then
    Snacks.terminal.get(nil, opts)
    return
  end
  if term:valid() and vim.api.nvim_get_current_buf() == term.buf then
    term:hide()
    return
  end
  if not term:valid() then
    -- re-anchor under the current editor window in case the original one was closed
    term.opts.win = M.main_win()
    term:show()
  end
  term:focus()
end

--- Open the bottom terminal without moving focus.
function M.terminal_show()
  local opts = term_opts(false)
  opts.start_insert = false
  local term = Snacks.terminal.get(nil, opts)
  if term and not term:valid() then
    term.opts.win = M.main_win()
    term:show()
  end
end

local function chat_visible()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "AgenticChat" then
      return true
    end
  end
  return false
end

--- Open the Claude chat pane (agentic.nvim) on the right.
--- agentic creates its session asynchronously and focuses its input when the widget appears,
--- so wait for the widget, then call `on_ready` (used to hand focus back).
function M.claude_show(on_ready)
  if chat_visible() then
    return
  end
  local ok, agentic = pcall(require, "agentic")
  if not ok then
    vim.notify("IDE layout: agentic.nvim failed to load: " .. tostring(agentic), vim.log.levels.ERROR)
    return
  end
  -- Don't attach the current file to a new chat automatically; use <leader>aa for that.
  agentic.open({ auto_add_to_context = false })
  if not on_ready then
    return
  end
  local tries = 0
  local function wait()
    tries = tries + 1
    if chat_visible() then
      on_ready()
    elseif tries < 50 then -- up to ~5s
      vim.defer_fn(wait, 100)
    end
  end
  vim.defer_fn(wait, 50)
end

--- Open the tree on the left without moving focus (or focus it for `nvim <dir>`).
function M.tree_show(dir, focus)
  require("neo-tree.command").execute({ action = focus and "focus" or "show", dir = dir or LazyVim.root() })
end

--- Build the full layout. Safe to call again to restore closed panes.
function M.layout(opts)
  opts = opts or {}
  local start = vim.api.nvim_get_current_win()
  M.tree_show(opts.dir, false)
  M.terminal_show()

  -- leave the cursor where it started (or in the tree for `nvim <dir>`)
  local function restore_focus()
    if opts.focus_tree then
      M.tree_show(opts.dir, true)
    elseif vim.api.nvim_win_is_valid(start) and not is_side_or_special(start) then
      vim.api.nvim_set_current_win(start)
    elseif M.main_win() then
      vim.api.nvim_set_current_win(M.main_win())
    end
    vim.cmd("stopinsert")
  end

  restore_focus()
  -- the chat opens asynchronously and takes focus when it appears; restore focus again then
  M.claude_show(restore_focus)
end

--- Called once on VimEnter.
function M.startup()
  -- Opt out for a single launch with:  NVIM_IDE=0 nvim ...
  if vim.env.NVIM_IDE == "0" then
    return
  end
  -- Skip: headless scripts, diff mode, git commit/rebase messages, piped stdin
  if #vim.api.nvim_list_uis() == 0 or vim.o.diff or M.stdin then
    return
  end
  local ft = vim.bo.filetype
  if ft == "gitcommit" or ft == "gitrebase" then
    return
  end

  local arg = vim.fn.argv(0)
  local stat = arg ~= "" and vim.uv.fs_stat(arg)
  vim.schedule(function()
    if stat and stat.type == "directory" then
      -- `nvim <dir>`: replace the netrw listing with an empty buffer, root the tree at <dir>
      local dirbuf = vim.api.nvim_get_current_buf()
      vim.cmd("enew")
      if vim.api.nvim_buf_is_valid(dirbuf) then
        pcall(vim.api.nvim_buf_delete, dirbuf, { force = true })
      end
      M.layout({ dir = vim.fn.fnamemodify(arg, ":p"), focus_tree = true })
    else
      M.layout()
    end
  end)
end

return M
