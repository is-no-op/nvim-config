-- Headless bootstrap for this config. Run by setup.sh after plugins are installed and restored:
--   NVIM_IDE=0 BOOTSTRAP=<this file> LOCK_SNAPSHOT=<pristine lazy-lock.json> \
--     nvim --headless "+lua dofile(os.getenv('BOOTSTRAP'))" "+cquit 3"
-- Installs what the config wants (read from LazyVim's resolved options, so adding or removing a
-- language extra stays in sync), then verifies everything. Exits non-zero if anything is missing.
-- (`+cquit 3` is a safety net: it only runs if this script dies without calling finish().)

local function say(msg)
  io.stdout:write("\n" .. msg .. "\n") -- leading newline: plugin/Mason progress output has none
end
local problems = {}
local function problem(msg)
  table.insert(problems, msg)
  io.stderr:write("  ! " .. msg .. "\n")
end
local function finish()
  if #problems > 0 then
    io.stderr:write(("bootstrap: %d problem(s), see above\n"):format(#problems))
    vim.cmd("cquit 1")
  else
    say("bootstrap: all checks passed")
    vim.cmd("qall!")
  end
end

local function check_plugins()
  -- Compare against the pristine lockfile: lazy.nvim rewrites lazy-lock.json during installs.
  local lockfile = os.getenv("LOCK_SNAPSHOT") or (vim.fn.stdpath("config") .. "/lazy-lock.json")
  local lock = vim.json.decode(table.concat(vim.fn.readfile(lockfile), "\n"))
  local lazy_config = require("lazy.core.config")
  local matched, total, skipped = 0, 0, {}
  for name, entry in pairs(lock) do
    local plugin = lazy_config.plugins[name]
    if not plugin and (lazy_config.spec.disabled[name] or lazy_config.spec.ignore_installed[name]) then
      -- disabled on purpose here (e.g. venv-selector when `fd` is missing): not a failure
      table.insert(skipped, name)
    elseif not plugin then
      total = total + 1
      problem(("plugin %s is in lazy-lock.json but not in the config"):format(name))
    else
      total = total + 1
      local head = vim.trim(vim.fn.system({ "git", "-C", plugin.dir, "rev-parse", "HEAD" }))
      if vim.v.shell_error ~= 0 then
        problem(("plugin %s is not installed"):format(name))
      elseif head ~= entry.commit then
        problem(("plugin %s is at %s, lockfile pins %s"):format(name, head:sub(1, 7), entry.commit:sub(1, 7)))
      else
        matched = matched + 1
      end
    end
  end
  -- Every plugin the config uses must be pinned (otherwise it silently floats to latest).
  for name, plugin in pairs(lazy_config.plugins) do
    if not lock[name] and not plugin._.is_local then
      problem(("plugin %s is used by the config but not pinned in lazy-lock.json"):format(name))
    end
  end
  say(("plugins: %d/%d at lockfile versions"):format(matched, total))
  if #skipped > 0 then
    table.sort(skipped)
    say("  (disabled in this environment, skipped: " .. table.concat(skipped, ", ") .. ")")
  end
end

local function install_mason()
  local registry = require("mason-registry")
  local refreshed, refresh_ok = false, false
  registry.refresh(function(success)
    refresh_ok = success
    refreshed = true
  end)
  if not vim.wait(180000, function()
    return refreshed
  end, 200) then
    return problem("Mason registry refresh timed out (network?)")
  end
  if not refresh_ok or #registry.get_all_package_names() == 0 then
    return problem("Mason registry is unavailable (network?), so no language servers could be installed")
  end

  -- Tools LazyVim wants + LSP servers mapped to Mason package names (mapping needs the registry).
  local wanted, seen = {}, {}
  local function want(name)
    if name and not seen[name] then
      seen[name] = true
      table.insert(wanted, name)
    end
  end
  for _, tool in ipairs(LazyVim.opts("mason.nvim").ensure_installed or {}) do
    want(tool)
  end
  want("tree-sitter-cli") -- LazyVim installs it on its own; we must wait for it before building parsers
  local to_package = require("mason-lspconfig").get_mappings().lspconfig_to_package
  for server, sopts in pairs(LazyVim.opts("nvim-lspconfig").servers or {}) do
    local enabled = sopts == true or (type(sopts) == "table" and sopts.enabled ~= false and sopts.mason ~= false)
    if server ~= "*" and enabled then
      if to_package[server] then
        want(to_package[server])
      else
        problem(("LSP server %s has no Mason package (set mason = false if it's installed another way)"):format(server))
      end
    end
  end
  table.sort(wanted)

  local failed = {}
  for _, name in ipairs(wanted) do
    local found, pkg = pcall(registry.get_package, name)
    if not found then
      problem(("Mason package %s does not exist in the registry"):format(name))
    elseif not pkg:is_installed() and not pkg:is_installing() then
      local started, err = pcall(pkg.install, pkg, {}, function(success, result)
        if not success then
          failed[name] = tostring(result)
        end
      end)
      if not started then
        failed[name] = tostring(err)
      end
    end
  end
  say(("mason: installing/verifying %d packages..."):format(#wanted))
  vim.wait(1800000, function()
    for _, name in ipairs(wanted) do
      local found, pkg = pcall(registry.get_package, name)
      if found and pkg:is_installing() then
        return false
      end
    end
    return true
  end, 500)
  local installed = 0
  for _, name in ipairs(wanted) do
    if registry.is_installed(name) then
      installed = installed + 1
    else
      problem(("Mason package %s did not install%s"):format(name, failed[name] and (": " .. failed[name]) or ""))
    end
  end
  say(("mason: %d/%d packages installed (%s)"):format(installed, #wanted, table.concat(wanted, " ")))
end

local function install_parsers()
  local parsers = vim.deepcopy(LazyVim.opts("nvim-treesitter").ensure_installed or {})
  table.sort(parsers)
  if vim.fn.executable("tree-sitter") ~= 1 then
    return problem("tree-sitter CLI not found on PATH, so syntax parsers can't be built")
  end
  say(("treesitter: installing/verifying %d parsers..."):format(#parsers))
  local ok, done = pcall(function()
    return require("nvim-treesitter").install(parsers):wait(1800000)
  end)
  if not ok then
    problem("treesitter install failed: " .. tostring(done))
  elseif done ~= true then
    problem("treesitter install did not complete for every parser")
  end
  local loaded = 0
  for _, lang in ipairs(parsers) do
    -- language.add returns nil + message (it doesn't throw) when a parser is missing
    local called, res = pcall(vim.treesitter.language.add, lang)
    if called and res then
      loaded = loaded + 1
    else
      problem(("parser %s is not installed or doesn't load"):format(lang))
    end
  end
  say(("treesitter: %d/%d parsers load"):format(loaded, #parsers))
end

xpcall(function()
  require("lazy").load({ plugins = { "mason.nvim", "mason-lspconfig.nvim", "nvim-lspconfig", "nvim-treesitter" } })
  check_plugins()
  install_mason()
  install_parsers()
end, function(err)
  problem("bootstrap crashed: " .. debug.traceback(tostring(err), 2))
end)
finish()
