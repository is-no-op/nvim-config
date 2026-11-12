#!/bin/bash
# Render cheatsheet.md to cheatsheet.html (GitHub styling, light/dark) and open it in Chrome (or the default browser).
# Re-run after editing the .md. The page loads the renderer and stylesheet from cdnjs, so it needs network.
set -eu -o pipefail

DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
SRC="$DIR/cheatsheet.md"
OUT="$DIR/cheatsheet.html"
[ -f "$SRC" ] || {
	echo "Not found: $SRC" >&2
	exit 1
}

python3 -I - "$SRC" "$OUT" <<'PY'
import json, sys
src, out = sys.argv[1], sys.argv[2]
md = open(src, encoding="utf-8").read()
# JSON-encode for a JS string; escape "</" so the content can never close the <script> tag.
data = json.dumps(md).replace("</", "<\\/")
html = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Neovim cheat sheet</title>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/github-markdown-css/5.5.1/github-markdown.min.css">
<style>
  :root { color-scheme: light dark; }
  body { margin: 0; background: #ffffff; }
  @media (prefers-color-scheme: dark) { body { background: #0d1117; } }
  .markdown-body { box-sizing: border-box; max-width: 980px; margin: 0 auto; padding: 32px 16px; }
  .markdown-body table { display: table; width: 100%; }
  .markdown-body td:first-child code { white-space: nowrap; }
</style>
</head>
<body>
<article class="markdown-body" id="content">Loading…</article>
<script src="https://cdnjs.cloudflare.com/ajax/libs/marked/12.0.2/marked.min.js"></script>
<script>
  const md = """ + data + """;
  const el = document.getElementById("content");
  if (window.marked) {
    el.innerHTML = marked.parse(md, { gfm: true });
  } else {
    el.textContent = md; // offline: show the raw Markdown rather than nothing
    el.style.whiteSpace = "pre-wrap";
  }
</script>
</body>
</html>
"""
open(out, "w", encoding="utf-8").write(html)
PY

echo "Wrote $OUT"
if [ "${NO_OPEN:-0}" != "1" ]; then
	open -a "Google Chrome" "$OUT" 2>/dev/null || open "$OUT" # default browser if Chrome isn't installed
fi
