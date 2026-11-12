-- nvim-local: reuse the main IDE layout (lua/config/ide.lua in the repo) and swap the right pane
-- from agentic.nvim (Claude) to the CodeCompanion chat (local model).
-- The repo is found through the lua/plugins symlink that setup-local.sh creates.
local repo = vim.fn.fnamemodify(vim.fn.resolve(vim.fn.stdpath("config") .. "/lua/plugins"), ":h:h")
local M = dofile(repo .. "/lua/config/ide.lua")

local function is_side_or_special(win)
  local cfg = vim.api.nvim_win_get_config(win)
  if cfg.relative ~= "" then
    return true
  end
  local buf = vim.api.nvim_win_get_buf(win)
  local ft = vim.bo[buf].filetype
  return ft == "neo-tree" or ft:match("^codecompanion") ~= nil or vim.bo[buf].buftype == "terminal"
end

--- The main editor window (largest normal window), or nil. Excludes the chat pane.
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

local function chat_visible()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "codecompanion" then
      return true
    end
  end
  return false
end

-- The main layout() puts focus back on the window it started in unless that window is a side pane,
-- but its side-pane check doesn't know the chat. Start from the editor when called from the chat
-- (e.g. <leader>al pressed inside it).
local main_layout = M.layout
function M.layout(opts)
  local cur = vim.api.nvim_get_current_win()
  if vim.bo[vim.api.nvim_win_get_buf(cur)].filetype:match("^codecompanion") and M.main_win() then
    vim.api.nvim_set_current_win(M.main_win())
  end
  return main_layout(opts)
end

--- Open the local chat pane on the right (replaces the Claude pane), then hand focus back.
function M.claude_show(on_ready)
  if chat_visible() then
    return
  end
  local ok, cc = pcall(require, "codecompanion")
  if not ok then
    vim.notify("IDE layout: codecompanion.nvim failed to load: " .. tostring(cc), vim.log.levels.ERROR)
    return
  end
  cc.toggle_chat()
  if on_ready then
    vim.schedule(on_ready)
  end
end

return M
