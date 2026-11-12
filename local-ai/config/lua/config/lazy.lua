-- nvim-local (NVIM_APPNAME=nvim-local): load the main config's lua/config/lazy.lua, adding one spec
-- import -- `{ import = "local_ai" }` -- right after `{ import = "plugins" }`. Patching it at load
-- time (instead of keeping a copy) means changes to the main bootstrap apply here too.
--
-- The repo is found through the lua/plugins symlink that setup-local.sh creates in
-- ~/.config/nvim-local, so this works wherever the repo is cloned.
local plugins = vim.fn.resolve(vim.fn.stdpath("config") .. "/lua/plugins")
local repo = vim.fn.fnamemodify(plugins, ":h:h")
local main = repo .. "/lua/config/lazy.lua"

local src = table.concat(vim.fn.readfile(main), "\n")
local anchor = '{ import = "plugins" },'
local start, finish = src:find(anchor, 1, true)
if not start then
  error(("nvim-local: couldn't find `%s` in %s to add the local_ai import"):format(anchor, main))
end
src = src:sub(1, finish) .. '\n    { import = "local_ai" }, -- added by nvim-local' .. src:sub(finish + 1)

local chunk, err = load(src, "@" .. main)
if not chunk then
  error("nvim-local: " .. err)
end
return chunk()
