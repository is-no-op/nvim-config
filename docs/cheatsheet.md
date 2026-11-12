# Neovim cheat sheet

Your setup: LazyVim + kanagawa-wave, 4-pane IDE layout (neo-tree · editor · terminal · Claude chat).
Verified against the config on 2026-11-20. A local-model variant, `nvim-local`, is covered in section 8.

**Notation:** `<leader>` = **Space**. `\` = local leader (used in the Claude chat). `C-x` = Ctrl+x, `S-x` = Shift+x, `A-x` = Option/Alt+x.
**Lost?** Press **Space** and wait: a menu (which-key) shows every next key. `<leader>sk` searches all keymaps. `<leader>?` shows keys for the current buffer.

---

## 1. Vim basics

### Modes
| Key | Does |
|---|---|
| `Esc` | Back to **Normal** mode (where commands run) |
| `i` / `a` | Insert before / after cursor |
| `I` / `A` | Insert at line start / end |
| `o` / `O` | New line below / above, in Insert mode |
| `v` / `V` / `C-v` | Visual select: characters / lines / block |
| `:` | Command line (`:w`, `:q`, …) |

### Moving
| Key | Does |
|---|---|
| `h j k l` | ← ↓ ↑ → |
| `w` / `b` / `e` | Next word / previous word / end of word |
| `0` / `^` / `$` | Line start / first non-blank / line end |
| `gg` / `G` / `42G` | File top / bottom / line 42 |
| `C-d` / `C-u` | Half page down / up |
| `%` | Jump to matching bracket |
| `s` + 2 chars | **Flash** jump to any visible spot (type the label shown) |
| `C-o` / `C-i` | Jump back / forward (after `gd`, searches, etc.) |

### Editing
Pattern: **operator + motion**, e.g. `dw` delete word, `ci"` change inside quotes, `yap` copy paragraph.

| Key | Does |
|---|---|
| `d` / `c` / `y` | Delete / change / yank (copy) — combine with a motion |
| `dd` / `cc` / `yy` | …the whole line |
| `x` | Delete character |
| `p` / `P` | Paste after / before |
| `u` / `C-r` | Undo / redo |
| `.` | Repeat last change |
| `>>` / `<<` | Indent / outdent line (`>` / `<` in Visual) |
| `gcc` / `gc` (Visual) | Toggle comment |
| `A-j` / `A-k` | Move line(s) down / up* |

\*Option-key shortcuts need **Use Option as Meta key** on in Terminal.app (Settings → Profiles → Keyboard).

### Search & replace
| Key | Does |
|---|---|
| `/text` then `n` / `N` | Search forward, next / previous match |
| `*` | Search word under cursor |
| `:%s/old/new/g` | Replace in file (`/gc` to confirm each) |
| `<leader>sr` | Search & replace across the project (grug-far) |

### Save & quit
| Key | Does |
|---|---|
| `C-s` | Save |
| `:w` / `:q` / `:wq` | Write / quit window / both |
| `:q!` | Quit window, discard changes |
| `<leader>qq` or `:qa` | Quit Neovim (works from any pane) |

---

## 2. Files, buffers, windows

| Key | Does |
|---|---|
| `<leader><space>` / `<leader>ff` | Find file (fuzzy) |
| `<leader>/` | Grep text across the project |
| `<leader>fr` | Recent files |
| `<leader>,` | Open buffers (files you have open) |
| `<leader>sR` | Reopen last search/picker |
| `S-h` / `S-l` | Previous / next buffer (tabs at the top) |
| `<leader>bd` | Close buffer |
| `C-h/j/k/l` | Move to window left / down / up / right |
| `<leader>-` / `<leader>\|` | Split below / right |
| `<leader>wd` | Close window |
| `C-arrows` | Resize window |

In pickers: type to filter, `C-j`/`C-k` to move, `Enter` to open, `Esc` to close.

---

## 3. Coding (Terraform, Go, Python, YAML, JSON)

| Key | Does |
|---|---|
| `K` | Hover docs for symbol |
| `gd` | Go to definition (`C-o` to come back) |
| `gr` | References |
| `gI` / `gy` | Implementation / type definition |
| `<leader>ca` | Code action (quick fixes) |
| `<leader>cr` | Rename symbol |
| `<leader>cf` | Format file (also runs on save — e.g. `terraform fmt`) |
| `<leader>uf` | Toggle format-on-save |
| `]d` / `[d` | Next / previous diagnostic |
| `<leader>cd` | Show diagnostic for line |
| `<leader>xx` | Diagnostics list (Trouble) |
| `<leader>ss` | Symbols in file |
| Insert mode: `Enter` / `C-y` | Accept completion (`C-n`/`C-p` to move; `Tab` jumps snippet fields) |

---

## 4. Git

| Key | Does |
|---|---|
| `<leader>gg` | **lazygit** (stage, commit, branch, push — `?` for help, `q` to quit) |
| `]h` / `[h` | Next / previous changed hunk |
| `<leader>ghp` | Preview hunk |
| `<leader>ghs` / `<leader>ghr` | Stage / reset hunk |
| `<leader>ghb` | Blame line |
| `<leader>ghd` | Diff this file |
| `<leader>gd` | Git diff (files picker) |

---

## 5. Your IDE layout

Opens automatically: **neo-tree** left · **editor** center · **terminal** bottom · **Claude chat** right.

| Key / command | Does |
|---|---|
| `cd some-repo && nvim` | Best way to work: tree, terminal and Claude scoped to that repo |
| `nvim file` / `nvim dir` | Opens layout; with a dir, cursor starts in the tree |
| `NVIM_IDE=0 nvim file` | Plain editor, no panes (git commit, `nvim -d`, piped input are plain automatically) |
| `<leader>al` | Restore the layout (reopens any pane you closed) |
| `C-/` | Terminal: focus → hide → show again (always at the workspace root) |
| `Esc Esc` (in terminal) | Terminal → Normal mode (scroll, copy); `i` to type again |
| `<leader>e` / `<leader>E` | Toggle tree (project root / cwd) |
| `C-h` / `C-l` | Hop between tree, editor, Claude |

**In neo-tree:** `l`/`Enter` open · `h` close folder · `a` add file (end with `/` for a folder) · `d` delete · `r` rename · `c` copy · `m` move · `Y` copy path · `H` show hidden · `?` all keys.

---

## 6. Claude chat panel (right)

### Open & add context
| Key | Does |
|---|---|
| `<leader>ac` | Toggle the chat |
| `<leader>af` | Focus the chat |
| `<leader>aa` | Add current file — or the Visual selection — to the chat |
| `<leader>ad` | Add the file's diagnostics |
| `<leader>an` | New chat session |
| `<leader>ah` | Chat history / restore a session |
| `<leader>ax` | Stop the current response |

### In the prompt box
| Key | Does |
|---|---|
| Type, then `C-s` (or `Enter` in Normal mode) | Send |
| `@` | Mention a file (completion) |
| `/` (first character) | Claude slash commands |
| `C-v` | Paste an image |
| `S-Tab` | Switch mode (default / plan / accept edits …) |
| `\m` | **Switch model** (keeps history) |
| `\t` | Thinking effort level |
| `\o` | Options menu |
| `\l` · `\]` · `\[` | List / next / previous session |
| `\D` | Delete session |
| `q` | Close the chat panel |

### Reading responses & approving work
| Key | Does |
|---|---|
| `]]` / `[[` | Next / previous message |
| `]t` / `[t` | Next / previous tool call |
| `1`, `2`, `3`… | Answer a permission prompt (allow once / always / reject…) |
| `C-n` / `C-p` | Cycle permission buttons |
| `]c` / `[c` | Next / previous hunk in a proposed edit |

### Full Claude Code CLI (fallback)
For anything the chat can't do (some CLI-only commands/features):

| Key | Does |
|---|---|
| `<leader>aC` | Open the Claude CLI in a terminal pane |
| `<leader>aR` | Resume a CLI session |
| `<leader>aA` / `<leader>aD` | Accept / deny a CLI-proposed diff |

---

## 7. Config & maintenance

| What | Where / how |
|---|---|
| Your config | `~/.config/nvim` (`<leader>fc` to search it) |
| Layout code | `lua/config/ide.lua`, `lua/plugins/ide.lua` |
| Claude chat config | `lua/plugins/agentic.lua` (e.g. default model: `initial_model`) |
| Colorscheme | `lua/plugins/colorschemes.lua`; preview others with `<leader>uC` |
| Plugins | `<leader>l` (Lazy) — `U` update, `R` restore from lockfile if an update breaks things |
| LazyVim extras | `:LazyExtras` (Terraform, Go, Python, YAML, JSON, neo-tree, Claude enabled) |
| Language servers/tools | `<leader>cm` (Mason) |
| Health check | `:checkhealth` |
| Messages / errors | `:messages` (or `<leader>n` for notification history) |
| Help | `:help <topic>` · `:Tutor` for an interactive Vim tutorial |

**Known quirks**
- Python virtualenv picker (`<leader>cv`) needs `fd` (installed by `setup.sh` from the Brewfile); without it the picker is disabled and pyright still auto-detects `./.venv`.
- If the Claude chat ever throws `E315: ml_get: Invalid lnum` after a Neovim upgrade, apply the `conceallevel = 0` workaround noted in `lua/plugins/agentic.lua`.

---

## 8. nvim-local (local model, no Claude)

`nvim-local` opens the same layout and keys, but the right pane is a **CodeCompanion** chat backed by a model running on your Mac (MLX). No account, no tokens, works offline. Set up with `setup.sh --local` (see the README).

| Key / command | Does |
|---|---|
| `nvim-local` / `nvim-local file` | Start it (the model server starts with the first window and stops with the last) |
| `<leader>ac` / `<leader>af` | Toggle / focus the chat |
| `<leader>an` | New chat |
| `<leader>aa` (Visual) | Add the selection to the chat |
| `<leader>am` | **Hot-swap model** (picker; works with or without a chat open) |
| `:LocalModel gemma` / `:LocalModel ministral` | Switch directly |
| `<leader>ap` | Actions & prompt library |
| `<leader>ai` | Inline prompt (`:CodeCompanion …`) |

**The chat pane:** replies on top (title bar shows the model), a **Message** box at the bottom. Type there, then `C-s` (or `Enter` in Normal mode) to send · `q` stop the reply · `gr` regenerate · `ga` change model · `gx` clear chat · `C-c` close · `?` all keys.
`/` opens slash commands (`/file`, `/buffer`, … plus your own prompts from `~/.config/nvim-local/prompts/`).

**Models**
| Model | Memory | Speed (M3 Pro) | Use for |
|---|---|---|---|
| Ministral 3 8B (default) | ~5.5 GB | ~27 tokens/s | Quick questions, everyday coding help; lighter on memory |
| Gemma 4 12B | ~7–8 GB | ~18 tokens/s | Harder coding/troubleshooting; noticeably better answers |

- A switch applies to open and new chats and starts loading right away (a notification says when it's ready, usually 5–15 s). Each reply's header shows which model wrote it, e.g. `Local (ministral)`. Only one model is in memory at a time.
- `CLAUDE.md` / `AGENTS.md` files are **not** auto-attached (slow for a local model); add files with `/file`.

**Agent mode** (on in every chat): the model reads and searches files on its own; edits, new/deleted files and commands wait for your OK in the chat:

| Key (in the chat) | Does |
|---|---|
| `g2` | Accept this step |
| `g1` | Always accept this kind of step in this chat |
| `g3` / `g4` | Reject / cancel |
| `gv` | View the proposed change in full |

The `> Context:` block at the top of the Message box lists the agent tools: type below it; deleting it turns agent mode off for that chat. Good for small, well-defined tasks (look something up, make an edit and check it, fix one failing test); use `nvim` with Claude for multi-step debugging.
- Server log: `~/.local/state/nvim-local/server.log`. Local models are much weaker than Claude — double-check anything important.

