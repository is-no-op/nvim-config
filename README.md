# Neovim IDE config (macOS)

LazyVim-based setup used as a lightweight VS Code/Cursor replacement:
neo-tree (left) · editor (center) · terminal (bottom) · Claude Code chat (right, via agentic.nvim + ACP).

Two ways to run it, installable separately or together:

- **`nvim`**: the chat pane is Claude Code (needs a Claude account).
- **`nvim-local`**: same layout and keys, but the chat pane talks to a model running on your Mac
  (MLX, Apple Silicon only; Ministral 3 8B by default for speed, Gemma 4 12B when you want stronger
  answers). No account
  or tokens; works offline. See [nvim-local](#nvim-local).

Keys and commands: [docs/cheatsheet.md](docs/cheatsheet.md) (`docs/cheatsheet-view.sh` renders it in a browser).

## New machine

Prerequisites: Homebrew (installing it needs an admin account) and Claude Code.

```bash
xcode-select --install          # if not already installed
git clone <this repo> ~/.config/nvim
~/.config/nvim/setup.sh         # nvim (Claude). Or: --local for nvim-local, --both for both
claude /login                   # if this machine isn't signed in yet (nvim only)
```

| Command | Sets up |
|---|---|
| `setup.sh` / `setup.sh --main` | `nvim` (Claude chat) |
| `setup.sh --local` | `nvim-local` only (runs `setup-local.sh`) |
| `setup.sh --both` | both |
| add `--no-models` | with `--local`/`--both`: skip the ~12 GB model download (re-run later to fetch) |

`setup.sh` (main) is safe to re-run. It:

1. checks for Xcode Command Line Tools and Homebrew;
2. links `~/.config/nvim` to the clone if you cloned elsewhere (never overwrites an existing config);
3. installs tools from `Brewfile` (Neovim stable, ripgrep, fd, lazygit, node, go, Ghostty, a Nerd Font);
4. installs the Claude chat adapter (`@agentclientprotocol/claude-agent-acp`, pinned);
5. installs plugins at the versions in `lazy-lock.json`, then the language servers, tools and
   syntax parsers this config enables, and verifies all of it (`scripts/bootstrap.lua`).

Then: use Ghostty, or set Terminal.app's font to "JetBrainsMono Nerd Font" and enable
"Use Option as Meta key". Run `nvim`.

## Where things live

| File | Purpose |
|---|---|
| `lua/config/ide.lua`, `lua/plugins/ide.lua` | 4-pane layout, bottom terminal, quit handling |
| `lua/plugins/agentic.lua` | Claude chat panel (model, keys) |
| `lua/plugins/colorschemes.lua` | colorschemes (default: kanagawa-wave), extra Treesitter parsers |
| `lua/config/options.lua`, `lua/config/autocmds.lua` | heavy pane borders |
| `lazyvim.json` | enabled LazyVim extras (`:LazyExtras`) |
| `lazy-lock.json` | pinned plugin versions; commit it after `:Lazy update` |

Opt out of the layout for one launch: `NVIM_IDE=0 nvim file`. Restore it: `<leader>al`.

## nvim-local

`setup-local.sh` (also run by `setup.sh --local` / `--both`) is safe to re-run. It:

1. checks for an Apple Silicon Mac, Xcode Command Line Tools and Homebrew;
2. installs the `Brewfile` tools plus `local-ai/Brewfile` (Python 3.12);
3. creates a Python venv at `~/.local/share/mlx-lm/venv` with mlx-lm, pinned in
   `local-ai/server/requirements.txt`;
4. builds `~/.config/nvim-local` (Neovim's config for `NVIM_APPNAME=nvim-local`) out of symlinks into this
   repo, so both commands share plugins, keys and layout and `git pull` updates both. Its own
   `lazy-lock.json` is generated from the main one plus `local-ai/lazy-lock.extra.json`, and its
   `prompts/` folder is yours (personal chat prompts, not tracked here). It stops rather than
   overwrite a file you changed;
5. links the `nvim-local` launcher into `~/.local/bin`;
6. installs and verifies plugins, language servers and parsers (same checks as the main setup);
7. downloads the models (~12 GB, resumable) and verifies their checksums, unless `--no-models`.

How it runs: the first `nvim-local` window starts a model server on `127.0.0.1:8484` (offline:
it only uses downloaded models) with Ministral preloaded; the last window to close stops it.
Hot-swap models any time with `<leader>am`, `:LocalModel gemma` / `:LocalModel ministral`, or `ga`
inside a chat: open chats and new ones switch, and the new model starts loading in the background
right away (a few seconds). Only one model is in memory at a time. Server log:
`~/.local/state/nvim-local/server.log`.

Overrides: `NVIM_LOCAL_PORT` (default 8484) and `NVIM_LOCAL_VENV` are read by the launcher each time
it runs, so export them in your shell profile, not just for `setup-local.sh`. Windows using different
ports each run their own server, which means memory for two models at once.

Measured on an M3 Pro with 18 GB: Gemma 4 12B ~18 tokens/s using ~7–8 GB; Ministral 3 8B ~27 tokens/s
using ~5.5 GB. With a browser and other apps open, expect some swapping while a model is loaded.

**Agent mode.** Every nvim-local chat starts with CodeCompanion's `agent` tools: the model can read
and search files and check diagnostics on its own, and can edit, create or delete files and run
commands after you approve each step in the chat (`g2` accept, `g1` always accept in this chat,
`g3` reject, `gv` view). The tools are listed in the `> Context:` block at the top of the Message
box; deleting that block turns them off for that chat.

What to expect (tested on this Mac with small real tasks): both models reliably handle one-step
work such as looking something up, making a requested edit and verifying it, or fixing a single
failing test. Neither could fix a problem that needed reading a spec and correcting two interacting
bugs (0/5 each; Ministral once emptied the file it was editing, which the approval prompt would have
caught). Turning on Gemma's thinking mode made it slower (~7 min per task) without helping. For
multi-step debugging and architecture work, use `nvim` with Claude.

| File | Purpose |
|---|---|
| `local-ai/bin/nvim-local` | launcher: starts/stops the model server, runs `nvim` with `NVIM_APPNAME=nvim-local` |
| `local-ai/server/` | server launcher (caps MLX's cache so switching models frees memory) and pinned requirements |
| `local-ai/config/lua/local_ai/codecompanion.lua` | chat pane: models, sampling, keys; turns off the Claude plugins |
| `local-ai/config/lua/config/{lazy,ide}.lua` | load the main config with the local chat pane swapped in |
