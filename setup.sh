#!/bin/bash
# macOS setup for this Neovim config. Safe to re-run.
#
#   git clone <this repo> ~/.config/nvim && ~/.config/nvim/setup.sh [--main | --local | --both] [--no-models]
#
#   --main   (default) `nvim`: the IDE layout with the Claude Code chat pane
#   --local  `nvim-local`: the same layout with a local model (MLX, Apple Silicon) -> setup-local.sh
#   --both   both of the above
#   --no-models  with --local/--both: skip the ~12 GB model download
#
# Cloning somewhere else also works: the script symlinks ~/.config/nvim to the clone.
# It never overwrites or deletes an existing config.
# Testing only: SETUP_SKIP_PACKAGES=1 skips the Homebrew and npm installs.
set -eu -o pipefail

MODE=main
LOCAL_OPTS=""
for arg in "$@"; do
	case "$arg" in
	--main) MODE=main ;;
	--local) MODE=local ;;
	--both) MODE=both ;;
	--no-models) LOCAL_OPTS="--no-models" ;;
	-h | --help)
		awk 'NR > 1 && !/^#/ { exit } NR > 1 { sub(/^# ?/, ""); print }' "$0"
		exit 0
		;;
	*)
		printf 'Unknown option: %s (see --help)\n' "$arg" >&2
		exit 2
		;;
	esac
done
if [ -n "$LOCAL_OPTS" ] && [ "$MODE" = main ]; then
	printf -- '--no-models only applies with --local or --both\n' >&2
	exit 2
fi

ACP_PKG="@agentclientprotocol/claude-agent-acp"
ACP_VERSION="0.98.0"

say() { printf '\n==> %s\n' "$*"; }
die() {
	printf '\nERROR: %s\n' "$*" >&2
	exit 1
}

unset NVIM_APPNAME # nvim would otherwise look for its config under a different name
REPO_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
case "${XDG_CONFIG_HOME:-/}" in
/*) ;;
*) die "XDG_CONFIG_HOME must be an absolute path (got '$XDG_CONFIG_HOME')." ;;
esac
TARGET="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"

if [ "$MODE" != main ] && [ "$(uname -m)" != arm64 ]; then
	die "nvim-local (--$MODE) needs an Apple Silicon Mac (MLX doesn't run on Intel Macs). Use --main here."
fi
if [ "$MODE" = local ]; then
	# shellcheck disable=SC2086 # LOCAL_OPTS is empty or a single flag
	exec "$REPO_DIR/setup-local.sh" $LOCAL_OPTS
fi

# --- 1. Preflight -----------------------------------------------------------------------------
[ "$(uname -s)" = "Darwin" ] || die "This setup is for macOS only."

if ! xcode-select -p >/dev/null 2>&1; then
	xcode-select --install >/dev/null 2>&1 || true
	die "Xcode Command Line Tools are required. Finish the installer window that just opened, then re-run this script."
fi

if ! command -v brew >/dev/null 2>&1; then
	for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
		if [ -x "$b" ]; then
			eval "$("$b" shellenv)"
			break
		fi
	done
fi
command -v brew >/dev/null 2>&1 || die "Homebrew is required: see https://brew.sh (installing Homebrew needs an admin account)."

# --- 2. Put the config where Neovim looks for it ----------------------------------------------
if [ -L "$TARGET" ] || [ -e "$TARGET" ]; then
	current="$(cd "$TARGET" 2>/dev/null && pwd -P || true)"
	if [ "$current" != "$REPO_DIR" ]; then
		die "$TARGET already exists and is not this repo. Move it aside first, e.g.:
  mv \"$TARGET\" \"$TARGET.bak\"
then re-run this script."
	fi
	say "Config location OK: $TARGET"
else
	mkdir -p "$(dirname "$TARGET")"
	ln -s "$REPO_DIR" "$TARGET"
	say "Linked $TARGET -> $REPO_DIR"
fi

# --- 3. Tools ---------------------------------------------------------------------------------
if [ "${SETUP_SKIP_PACKAGES:-0}" = "1" ]; then
	say "Skipping Homebrew and npm packages (SETUP_SKIP_PACKAGES=1)"
else
	say "Installing Homebrew packages from Brewfile (already-installed ones are left as they are)"
	brew bundle --no-upgrade --file="$REPO_DIR/Brewfile"

	# Installing a formula can upgrade a shared library and break another Node you already had
	# (e.g. node@24 losing libsimdjson). The Claude chat adapter runs on whichever `node` is first
	# on PATH, so check it actually runs before going further.
	if ! node -e 'process.exit(0)' >/dev/null 2>&1 || ! npm --version >/dev/null 2>&1; then
		node_path="$(command -v node || true)"
		node_real="$(readlink -f "$node_path" 2>/dev/null || printf '%s' "$node_path")"
		formula="$(printf '%s' "$node_real" | sed -n 's#.*/Cellar/\([^/]*\)/.*#\1#p')"
		die "The 'node' first on your PATH ($node_path) doesn't run, usually because Homebrew upgraded
  a library it depends on. Fix it, then re-run this script:
    brew upgrade ${formula:-<the formula that provides it>}    (or: brew reinstall ${formula:-...})"
	fi

	say "Installing the Claude chat adapter ($ACP_PKG@$ACP_VERSION)"
	acp_json="$(npm ls -g --depth=0 --json "$ACP_PKG" 2>/dev/null || true)"
	if printf '%s' "$acp_json" | grep -qF "\"version\": \"$ACP_VERSION\""; then
		echo "Already installed."
	else
		npm install -g "$ACP_PKG@$ACP_VERSION"
	fi
	command -v claude-agent-acp >/dev/null 2>&1 ||
		die "claude-agent-acp isn't on PATH after installing it (npm global bin: $(npm prefix -g)/bin)."
fi

# --- 4. Plugins, language servers, syntax parsers ---------------------------------------------
NVIM="$(brew --prefix)/bin/nvim"
if [ ! -x "$NVIM" ]; then
	NVIM="$(command -v nvim || true)"
fi
[ -n "$NVIM" ] && [ -x "$NVIM" ] || die "Neovim not found (it should come from the Brewfile)."
say "Using $("$NVIM" --version | head -1) at $NVIM"

# lazy.nvim rewrites lazy-lock.json while installing (on a fresh machine it first installs some
# plugins at their latest commit). Keep a pristine copy, restore from it, verify against it, and
# always put it back so the repo's pinned versions never change.
LOCK="$REPO_DIR/lazy-lock.json"
SNAPSHOT="$(mktemp -t lazy-lock)"
cp "$LOCK" "$SNAPSHOT"
trap 'cp "$SNAPSHOT" "$LOCK"; rm -f "$SNAPSHOT"' EXIT

say "Installing plugins"
NVIM_IDE=0 "$NVIM" --headless +qa || die "Neovim failed to start while installing plugins (network?)."
cp "$SNAPSHOT" "$LOCK"

say "Switching plugins to the versions pinned in lazy-lock.json"
NVIM_IDE=0 "$NVIM" --headless "+Lazy! restore" +qa || die "Neovim failed while restoring plugin versions."
cp "$SNAPSHOT" "$LOCK"

say "Installing language servers, tools and syntax parsers (the first run takes a few minutes)"
NVIM_IDE=0 BOOTSTRAP="$REPO_DIR/scripts/bootstrap.lua" LOCK_SNAPSHOT="$SNAPSHOT" \
	"$NVIM" --headless "+lua dofile(os.getenv('BOOTSTRAP'))" "+cquit 3" ||
	die "Some components did not install or verify (see above). Re-running this script usually fixes network hiccups."

# --- 5. nvim-local (--both) -------------------------------------------------------------------
if [ "$MODE" = both ]; then
	cp "$SNAPSHOT" "$LOCK" # setup-local.sh derives nvim-local's pins from this file
	say "Main setup finished; now setting up nvim-local"
	# shellcheck disable=SC2086
	"$REPO_DIR/setup-local.sh" $LOCAL_OPTS
fi

# --- 6. Manual steps --------------------------------------------------------------------------
if command -v claude >/dev/null 2>&1; then
	claude_step="Run 'claude /login' if this machine isn't signed in to Claude Code yet."
else
	claude_step="Install Claude Code, then run 'claude /login'."
fi

run_cmd="nvim"
if [ "$MODE" = both ]; then
	run_cmd="nvim (or nvim-local)"
fi

cat <<EOF

==> Done. Remaining manual steps:
  1. $claude_step
  2. Terminal: use Ghostty (in ~/Applications), or in Terminal.app set the font to
     "JetBrainsMono Nerd Font" and enable Settings > Profiles > Keyboard > "Use Option as Meta key".
  3. Open a new terminal window and run: $run_cmd
EOF
