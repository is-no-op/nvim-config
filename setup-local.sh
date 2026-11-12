#!/bin/bash
# macOS setup for nvim-local: the same Neovim layout, with a local model (MLX) in the chat pane
# instead of Claude. Safe to re-run. Apple Silicon only.
#
#   ~/.config/nvim/setup-local.sh [--no-models]      (or: setup.sh --local / --both)
#
# What it sets up:
#   ~/.config/nvim-local       config for NVIM_APPNAME=nvim-local: symlinks into this repo, plus a
#                              generated lazy-lock.json and a prompts/ folder for your own prompts
#   ~/.local/bin/nvim-local    the launcher (symlink to local-ai/bin/nvim-local)
#   ~/.local/share/mlx-lm/venv Python venv with mlx-lm (versions pinned in local-ai/server/requirements.txt)
#   Hugging Face cache         the two models (~12 GB) unless --no-models
# It never overwrites a file you changed: anything in the way that isn't one of its own links (or
# identical to the repo copy) stops the script with instructions.
#
# Testing only: SETUP_SKIP_PACKAGES=1 skips Homebrew, pip and model downloads (verifies what exists).
# Overrides: NVIM_LOCAL_VENV (venv path), NVIM_LOCAL_BIN_DIR (launcher dir, default ~/.local/bin).
# The launcher reads NVIM_LOCAL_VENV and NVIM_LOCAL_PORT when it runs, so if you override them,
# export them in your shell profile too, not just for this script.
set -eu -o pipefail

# Keep in sync with local-ai/config/lua/local_ai/codecompanion.lua (MODELS) and
# local-ai/bin/nvim-local (DEFAULT_MODEL).
MODELS="mlx-community/gemma-4-12B-it-4bit mlx-community/Ministral-3-8B-Instruct-2512-4bit"
MODELS_GB=13 # free space needed for the downloads, with some headroom

say() { printf '\n==> %s\n' "$*"; }
die() {
	printf '\nERROR: %s\n' "$*" >&2
	exit 1
}
usage() {
	awk 'NR > 1 && !/^#/ { exit } NR > 1 { sub(/^# ?/, ""); print }' "$0"
	exit "${1:-0}"
}

DOWNLOAD_MODELS=1
for arg in "$@"; do
	case "$arg" in
	--no-models) DOWNLOAD_MODELS=0 ;;
	-h | --help) usage 0 ;;
	*)
		echo "Unknown option: $arg" >&2
		usage 2
		;;
	esac
done

unset NVIM_APPNAME
REPO_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
LOCAL_SRC="$REPO_DIR/local-ai"
for v in XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME HF_HOME HF_HUB_CACHE NVIM_LOCAL_VENV NVIM_LOCAL_BIN_DIR; do
	eval "val=\${$v:-/}"
	case "$val" in
	/*) ;;
	*) die "$v must be an absolute path (got '$val')." ;;
	esac
done
TARGET="${XDG_CONFIG_HOME:-$HOME/.config}/nvim-local"
VENV="${NVIM_LOCAL_VENV:-$HOME/.local/share/mlx-lm/venv}"
BIN_DIR="${NVIM_LOCAL_BIN_DIR:-$HOME/.local/bin}"
REQS="$LOCAL_SRC/server/requirements.txt"

# --- 1. Preflight -----------------------------------------------------------------------------
[ "$(uname -s)" = "Darwin" ] || die "This setup is for macOS only."
[ "$(uname -m)" = "arm64" ] || die "nvim-local needs an Apple Silicon Mac (MLX doesn't run on Intel Macs)."
[ -d "$LOCAL_SRC/config" ] && [ -f "$REQS" ] || die "$LOCAL_SRC is incomplete; is this a full clone of the repo?"

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

# --- 2. Tools ---------------------------------------------------------------------------------
if [ "${SETUP_SKIP_PACKAGES:-0}" = "1" ]; then
	say "Skipping Homebrew packages (SETUP_SKIP_PACKAGES=1)"
else
	say "Installing Homebrew packages (already-installed ones are left as they are)"
	brew bundle --no-upgrade --file="$REPO_DIR/Brewfile"
	brew bundle --no-upgrade --file="$LOCAL_SRC/Brewfile"
	# Same check as setup.sh: Node-based language servers need a working `node`.
	if ! node -e 'process.exit(0)' >/dev/null 2>&1; then
		die "The 'node' first on your PATH ($(command -v node || echo none)) doesn't run, usually because
  Homebrew upgraded a library it depends on. Fix it (brew upgrade/reinstall that node), then re-run."
	fi
fi

# --- 3. Python venv with mlx-lm ---------------------------------------------------------------
want_mlx="$(sed -n 's/^mlx-lm==//p' "$REQS")"
[ -n "$want_mlx" ] || die "No mlx-lm pin found in $REQS."
have_mlx=""
if [ -x "$VENV/bin/python" ]; then
	have_mlx="$("$VENV/bin/python" -I -c 'import mlx_lm; print(mlx_lm.__version__)' 2>/dev/null || true)"
fi

if [ "$have_mlx" = "$want_mlx" ]; then
	say "mlx-lm $want_mlx already installed in $VENV"
elif [ "${SETUP_SKIP_PACKAGES:-0}" = "1" ]; then
	die "$VENV doesn't have mlx-lm $want_mlx (has: '${have_mlx:-none}') and SETUP_SKIP_PACKAGES=1 skips pip."
else
	if [ ! -x "$VENV/bin/python" ]; then
		py=""
		for c in "$(brew --prefix)/opt/python@3.12/bin/python3.12" python3.13 python3.12 python3.11 python3; do
			if command -v "$c" >/dev/null 2>&1 &&
				"$c" -I -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)' 2>/dev/null; then
				py="$(command -v "$c")"
				break
			fi
		done
		[ -n "$py" ] || die "No Python >= 3.11 found (it should come from local-ai/Brewfile: brew install python@3.12)."
		if [ -e "$VENV" ]; then
			die "$VENV exists but isn't a working venv. Move it aside, then re-run this script."
		fi
		say "Creating Python venv at $VENV ($("$py" --version))"
		mkdir -p "$(dirname "$VENV")"
		"$py" -m venv "$VENV"
	fi
	say "Installing mlx-lm $want_mlx and its pinned dependencies into $VENV"
	"$VENV/bin/python" -I -m pip install --quiet --disable-pip-version-check -r "$REQS"
fi
"$VENV/bin/python" -I -c 'import mlx.core as mx, mlx_lm; mx.eval(mx.array([1.0]) + 1)' ||
	die "mlx-lm is installed in $VENV but doesn't run on this Mac's GPU (see the error above)."

# --- 4. Config: ~/.config/nvim-local ----------------------------------------------------------
# link <path> <points-to>: create it, re-point one of our symlinks, or replace an identical real
# copy. Anything else in the way stops the script, so local edits are never lost.
# "Ours" = a symlink whose target is inside this repo, or ends in the same repo-relative path (an
# older link, or one left from a clone that has since moved). Someone else's symlink is never touched.
link() {
	local dest="$1" src="$2" target rel
	[ -e "$src" ] || die "Missing in the repo: $src"
	rel="${src#"$REPO_DIR"/}"
	if [ -L "$dest" ]; then
		target="$(readlink "$dest")"
		[ "$target" = "$src" ] && return 0
		case "$target" in
		"$REPO_DIR"/* | */"$rel" | "$rel") ;;
		*)
			die "$dest is a symlink to $target, which isn't part of this repo.
  Move it aside (e.g. mv \"$dest\" \"$dest.bak\") and re-run this script."
			;;
		esac
		ln -sfn "$src" "$dest"
		echo "  relinked $dest"
	elif [ "$dest" -ef "$src" ]; then
		# Same file reached another way (e.g. a parent folder links into the repo): deleting
		# "dest" would delete the repo's own file.
		die "$dest is the repo's own $rel (reached through a symlinked folder).
  nvim-local's config folder must be a separate real folder; see the README."
	elif [ -e "$dest" ]; then
		if { [ -f "$dest" ] && cmp -s "$dest" "$src"; } || { [ -d "$dest" ] && diff -rq "$dest" "$src" >/dev/null 2>&1; }; then
			rm -rf "$dest"
			ln -s "$src" "$dest"
			echo "  replaced identical copy with a link: $dest"
		else
			die "$dest exists and differs from the repo's $src.
  Move it aside (e.g. mv \"$dest\" \"$dest.bak\") and re-run this script."
		fi
	else
		ln -s "$src" "$dest"
		echo "  linked $dest"
	fi
}

say "Setting up $TARGET"
# Fail closed, before creating anything, if the config folder and the repo overlap (e.g. the repo
# was cloned to ~/.config/nvim-local, or lua/ links into the repo): links there would replace repo files.
for d in "$TARGET" "$TARGET/lua" "$TARGET/lua/config"; do
	if [ -L "$d" ]; then
		die "$d is a symlink; nvim-local needs real folders there (its lazy-lock.json and prompts are its own).
  Remove the link (rm \"$d\") and re-run this script."
	fi
done
# Resolve the target's real location through its parent (the target itself may not exist yet).
target_parent="$(dirname "$TARGET")"
mkdir -p "$target_parent"
target_real="$(cd "$target_parent" && pwd -P)/$(basename "$TARGET")"
case "$target_real/" in
"$REPO_DIR"/*) die "$TARGET is inside this repo ($REPO_DIR). Clone the repo somewhere else (e.g. ~/.config/nvim)." ;;
esac
case "$REPO_DIR/" in
"$target_real"/*) die "This repo is inside $TARGET. Clone it somewhere else (e.g. ~/.config/nvim)." ;;
esac
mkdir -p "$TARGET/lua/config" "$TARGET/prompts"
link "$TARGET/init.lua" "$REPO_DIR/init.lua"
link "$TARGET/lazyvim.json" "$REPO_DIR/lazyvim.json"
link "$TARGET/.neoconf.json" "$REPO_DIR/.neoconf.json"
link "$TARGET/stylua.toml" "$REPO_DIR/stylua.toml"
link "$TARGET/lua/plugins" "$REPO_DIR/lua/plugins"
for f in options keymaps autocmds; do
	link "$TARGET/lua/config/$f.lua" "$REPO_DIR/lua/config/$f.lua"
done
link "$TARGET/lua/config/lazy.lua" "$LOCAL_SRC/config/lua/config/lazy.lua"
link "$TARGET/lua/config/ide.lua" "$LOCAL_SRC/config/lua/config/ide.lua"
link "$TARGET/lua/local_ai" "$LOCAL_SRC/config/lua/local_ai"

# lazy-lock.json for nvim-local is derived: the main config's pins plus local-ai/lazy-lock.extra.json.
# It's regenerated on every run (lazy.nvim also rewrites it), so the two configs stay on the same versions.
LOCK="$TARGET/lazy-lock.json"
write_lock() {
	python3 -I - "$REPO_DIR/lazy-lock.json" "$LOCAL_SRC/lazy-lock.extra.json" "$LOCK" <<'PY'
import json, sys
main, extra, out = sys.argv[1:4]
lock = json.load(open(main))
lock.update(json.load(open(extra)))
lines = ['  %s: %s' % (json.dumps(k), json.dumps(lock[k], separators=(", ", ": "))) for k in sorted(lock)]
open(out, "w").write("{\n" + ",\n".join(lines) + "\n}\n")
PY
}
write_lock
echo "  wrote $LOCK (main pins + local-ai/lazy-lock.extra.json)"

say "Installing the launcher in $BIN_DIR"
mkdir -p "$BIN_DIR"
link "$BIN_DIR/nvim-local" "$LOCAL_SRC/bin/nvim-local"
case ":$PATH:" in
*":$BIN_DIR:"*) ;;
*) echo "  NOTE: $BIN_DIR isn't on your PATH. Add it (e.g. in ~/.zshrc: export PATH=\"$BIN_DIR:\$PATH\")." ;;
esac

# --- 5. Plugins, language servers, syntax parsers ---------------------------------------------
NVIM="$(brew --prefix)/bin/nvim"
[ -x "$NVIM" ] || NVIM="$(command -v nvim || true)"
[ -n "$NVIM" ] && [ -x "$NVIM" ] || die "Neovim not found (it should come from the Brewfile)."
say "Using $("$NVIM" --version | head -1) at $NVIM"

SNAPSHOT="$(mktemp -t lazy-lock-local)"
cp "$LOCK" "$SNAPSHOT"
trap 'write_lock; rm -f "$SNAPSHOT"' EXIT
export NVIM_APPNAME=nvim-local NVIM_IDE=0

say "Installing plugins"
"$NVIM" --headless +qa || die "Neovim failed to start while installing plugins (network?)."
cp "$SNAPSHOT" "$LOCK"

say "Switching plugins to the pinned versions"
"$NVIM" --headless "+Lazy! restore" +qa || die "Neovim failed while restoring plugin versions."
cp "$SNAPSHOT" "$LOCK"

say "Installing language servers, tools and syntax parsers (the first run takes a few minutes)"
BOOTSTRAP="$REPO_DIR/scripts/bootstrap.lua" LOCK_SNAPSHOT="$SNAPSHOT" \
	"$NVIM" --headless "+lua dofile(os.getenv('BOOTSTRAP'))" "+cquit 3" ||
	die "Some components did not install or verify (see above). Re-running this script usually fixes network hiccups."
unset NVIM_APPNAME NVIM_IDE

# --- 6. Models --------------------------------------------------------------------------------
if [ "$DOWNLOAD_MODELS" = "1" ]; then
	py_hf() { HF_HUB_DISABLE_TELEMETRY=1 "$VENV/bin/python" -I "$@"; }
	missing=""
	for m in $MODELS; do
		py_hf -c 'import sys; from huggingface_hub import snapshot_download as s; s(sys.argv[1], local_files_only=True)' "$m" >/dev/null 2>&1 ||
			missing="$missing $m"
	done
	if [ -n "$missing" ]; then
		# Ask huggingface_hub where it caches (it honors HF_HUB_CACHE, HF_HOME and XDG_CACHE_HOME).
		hub="$(py_hf -c 'from huggingface_hub import constants as c; print(c.HF_HUB_CACHE)')"
		mkdir -p "$hub"
		free_gb=$(($(df -Pk "$hub" | awk 'NR==2 {print $4}') / 1048576))
		[ "$free_gb" -ge "$MODELS_GB" ] || die "Only ${free_gb} GB free for the models (~${MODELS_GB} GB needed). Free some space or use --no-models."
	fi
	for m in $MODELS; do
		say "Model $m"
		case " $missing " in
		*" $m "*) need_download=1 ;;
		*) need_download=0 ;;
		esac
		if [ "$need_download" = 0 ]; then
			echo "  already downloaded; verifying"
		elif [ "${SETUP_SKIP_PACKAGES:-0}" = "1" ]; then
			echo "  not downloading (SETUP_SKIP_PACKAGES=1)"
		else
			ok=0
			for try in 1 2 3; do
				# Plain HTTPS (resumable): the Xet transfer protocol has stalled on slow links.
				if HF_HUB_DISABLE_XET=1 HF_HUB_DISABLE_TELEMETRY=1 "$VENV/bin/hf" download "$m" >/dev/null; then
					ok=1
					break
				fi
				echo "  download interrupted, retrying ($try/3)..."
			done
			[ "$ok" = 1 ] || die "Couldn't download $m. Re-run this script to resume."
		fi
		# Verify the weights: each file's name in the cache's blobs/ folder is its SHA-256.
		snap="$(py_hf -c 'import sys; from huggingface_hub import snapshot_download as s; print(s(sys.argv[1], local_files_only=True))' "$m" 2>/dev/null)" ||
			die "$m isn't in the Hugging Face cache."
		for f in "$snap"/*.safetensors; do
			[ -e "$f" ] || die "No weight files (*.safetensors) in $snap. Delete $(dirname "$(dirname "$snap")") and re-run."
			want="$(basename "$(readlink "$f" || true)")"
			case "$want" in
			[0-9a-f][0-9a-f][0-9a-f][0-9a-f]*) [ "${#want}" -eq 64 ] || want="" ;;
			*) want="" ;;
			esac
			[ -n "$want" ] || die "Can't verify $f (not a standard Hugging Face cache entry)."
			got="$(shasum -a 256 "$f" | cut -c1-64)"
			if [ "$got" != "$want" ]; then
				die "Checksum mismatch for $f. Delete $(dirname "$(dirname "$snap")") and re-run this script."
			fi
		done
		echo "  verified"
	done
else
	say "Skipping model downloads (--no-models). Chat needs them: re-run without --no-models later."
fi

cat <<EOF

==> nvim-local is ready. Run: nvim-local
    Switch models in the chat with ga (or <leader>am). Server log: ${XDG_STATE_HOME:-$HOME/.local/state}/nvim-local/server.log
    Your own chat prompts go in $TARGET/prompts (Markdown; see the CodeCompanion prompt-library docs).
EOF
