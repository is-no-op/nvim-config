"""mlx_lm.server launcher for nvim-local (started by local-ai/bin/nvim-local).

Caps MLX's buffer cache so a model swapped out in the chat (ga / <leader>am) is returned to macOS
instead of being held in MLX's free-buffer pool (without this, switching Gemma -> Ministral -> Gemma
left the server at ~12 GB). Arguments are passed through to mlx_lm.server unchanged.
"""
import os
import sys

# Own session/process group: Neovim suspending itself (Ctrl-Z, :suspend) signals its whole process
# group, which would otherwise freeze the server for every other nvim-local window too.
try:
    os.setsid()
except OSError:
    pass  # already a session leader

import mlx.core as mx  # noqa: E402

mx.set_cache_limit(int(os.environ.get("NVIM_LOCAL_MLX_CACHE_MB", "1024")) * 1024 * 1024)

from mlx_lm.server import main  # noqa: E402

sys.argv[0] = "mlx_lm.server"
main()
