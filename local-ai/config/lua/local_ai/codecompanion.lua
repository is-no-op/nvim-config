-- nvim-local: right-hand chat pane backed by a local model (mlx_lm.server, started by the
-- nvim-local wrapper in local-ai/bin). Replaces agentic.nvim / claudecode.nvim from the main config.
-- Model ids must match DEFAULT_MODEL in local-ai/bin/nvim-local and MODELS in setup-local.sh.
--
-- Hot-swap models: <leader>am (picker), :LocalModel [ministral|gemma], or ga inside a chat.
-- The switch applies to open chats and new ones, and the new model starts loading right away in the
-- background (a few seconds); the server frees the old one, so only one is in memory at a time.

local PORT = vim.env.NVIM_LOCAL_PORT or "8484"

-- Downloaded MLX builds. Sampling follows each vendor's published guidance.
local MODELS = {
  ["mlx-community/gemma-4-12B-it-4bit"] = {
    short = "gemma",
    formatted_name = "Gemma 4 12B (Google) - stronger, slower, ~7 GB",
    temperature = 1.0,
    top_p = 0.95,
  },
  ["mlx-community/Ministral-3-8B-Instruct-2512-4bit"] = {
    short = "ministral",
    formatted_name = "Ministral 3 8B (Mistral) - faster, lighter, ~5.5 GB",
    temperature = 0.1,
    top_p = 0.95,
  },
}
-- Default: the faster model. Must match DEFAULT_MODEL in local-ai/bin/nvim-local (preloaded there).
local DEFAULT_MODEL = "mlx-community/Ministral-3-8B-Instruct-2512-4bit"
-- The model new chats use; hot-swapping changes it for this Neovim session.
local state = { current = DEFAULT_MODEL, warming = 0 }

local function current_model(adapter)
  local ok, utils = pcall(require, "codecompanion.adapters.utils")
  local id = ok and adapter and utils.resolve_model and utils.resolve_model(adapter) or nil
  return MODELS[id] and id or state.current
end

local function label(id)
  return MODELS[id] and MODELS[id].formatted_name or id
end

-- Ask the server to load `id` now (a 1-token request), so the next real message doesn't wait.
local function warm(id)
  state.warming = state.warming + 1
  local token, started = state.warming, vim.uv.now()
  vim.notify("Local model: loading " .. label(id) .. " ...")
  local body = vim.json.encode({
    model = id,
    max_tokens = 1,
    messages = { { role = "user", content = "hi" } },
  })
  vim.system({
    "curl",
    "-s",
    "-o",
    "/dev/null",
    "-w",
    "%{http_code}",
    "--max-time",
    "180",
    "-H",
    "Content-Type: application/json",
    "-d",
    body,
    "http://127.0.0.1:" .. PORT .. "/v1/chat/completions",
  }, { text = true }, function(res)
    vim.schedule(function()
      if token ~= state.warming then
        return -- superseded by a later switch
      end
      if res.code == 0 and vim.trim(res.stdout or "") == "200" then
        vim.notify(("Local model: %s ready (%.1fs)"):format(label(id), (vim.uv.now() - started) / 1000))
      else
        vim.notify(
          "Local model: couldn't load " .. label(id) .. " (is nvim-local's server running? see the server log)",
          vim.log.levels.WARN
        )
      end
    end)
  end)
end

-- Switch every open chat and future chats to `id`, and start loading it.
local function set_model(id)
  if not MODELS[id] then
    return vim.notify("Unknown local model: " .. tostring(id), vim.log.levels.ERROR)
  end
  local changed = id ~= state.current
  state.current = id
  if package.loaded["codecompanion"] then
    for _, entry in ipairs(require("codecompanion.interactions.chat").buf_get_chat()) do
      local chat = entry.chat
      if chat and chat.adapter and chat.adapter.name == "mlx" and current_model(chat.adapter) ~= id then
        chat:change_model({ model = id })
        changed = true
      end
    end
  end
  if changed then
    warm(id)
  else
    vim.notify("Local model: already using " .. label(id))
  end
end

local function find_model(name)
  name = (name or ""):lower()
  for id, m in pairs(MODELS) do
    if m.short == name or id:lower() == name then
      return id
    end
  end
end

local function chat_win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "codecompanion" then
      return win
    end
  end
end

local function switch_model()
  local ids = vim.tbl_keys(MODELS)
  table.sort(ids)
  vim.ui.select(ids, {
    prompt = "Local model",
    format_item = function(id)
      return (id == state.current and "* " or "  ") .. MODELS[id].formatted_name
    end,
  }, function(id)
    if id then
      set_model(id)
    end
  end)
end

return {
  -- The Claude panes from the main config are off in this instance.
  { "carlos-algms/agentic.nvim", enabled = false },
  { "coder/claudecode.nvim", enabled = false },

  {
    "olimorris/codecompanion.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = { "CodeCompanion", "CodeCompanionChat", "CodeCompanionActions", "CodeCompanionCmd" },
    init = function()
      -- :LocalModel            pick a model
      -- :LocalModel ministral  switch directly (also: gemma)
      vim.api.nvim_create_user_command("LocalModel", function(cmd)
        if cmd.args == "" then
          return switch_model()
        end
        local id = find_model(cmd.args)
        if not id then
          return vim.notify("Unknown local model: " .. cmd.args, vim.log.levels.ERROR)
        end
        set_model(id)
      end, {
        nargs = "?",
        desc = "Switch the local chat model",
        complete = function()
          local names = {}
          for _, m in pairs(MODELS) do
            table.insert(names, m.short)
          end
          table.sort(names)
          return names
        end,
      })
      -- Label the prompt box so it's clear where to type.
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "codecompanion_chat_input",
        callback = function(ev)
          vim.schedule(function()
            for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
              vim.wo[win].winbar = "%#Comment# Message · Ctrl-S to send"
            end
          end)
        end,
      })
      -- A switch made inside a chat with `ga` also becomes the default for new chats and starts loading.
      vim.api.nvim_create_autocmd("User", {
        pattern = "CodeCompanionChatModel",
        callback = function(ev)
          local id = ev.data and ev.data.model
          if MODELS[id] and id ~= state.current then
            state.current = id
            warm(id)
          end
        end,
      })
    end,
    opts = {
      adapters = {
        http = {
          opts = {
            show_presets = false, -- only the local adapter in the `ga` picker (no cloud providers)
            show_model_choices = true,
          },
          mlx = function()
            return require("codecompanion.adapters").extend("openai_compatible", {
              name = "mlx",
              formatted_name = "Local",
              env = {
                url = "http://127.0.0.1:" .. PORT,
                api_key = "nvim-local-no-key", -- server needs none; not an env var name
              },
              schema = {
                model = {
                  default = function()
                    return state.current
                  end,
                  choices = MODELS,
                },
                temperature = {
                  order = 2,
                  mapping = "parameters",
                  type = "number",
                  default = function(self)
                    return MODELS[current_model(self)].temperature
                  end,
                },
                top_p = {
                  order = 3,
                  mapping = "parameters",
                  type = "number",
                  default = function(self)
                    return MODELS[current_model(self)].top_p
                  end,
                },
              },
            })
          end,
        },
        acp = { opts = { show_presets = false } },
      },
      interactions = {
        chat = {
          adapter = "mlx",
          -- Agent mode in every chat: the model can read/search files, check diagnostics, and (each
          -- time with your approval, via the prompt shown in the chat) edit, create or delete files and
          -- run commands. Local models handle small, well-scoped tasks; see the README for limits.
          tools = {
            opts = {
              default_tools = { "agent" },
              approval_mode = "ask",
            },
            -- Like the Claude chat: reading files doesn't ask; edits, deletes and commands still do.
            read_file = { opts = { require_approval_before = false } },
          },
          roles = {
            -- Show which model wrote each reply, e.g. "Local (ministral)".
            llm = function(adapter)
              local id = current_model(adapter)
              return "Local (" .. (MODELS[id] and MODELS[id].short or id) .. ")"
            end,
          },
        },
        inline = { adapter = "mlx" },
        cmd = { adapter = "mlx" },
        background = { adapter = "mlx" },
      },
      -- Don't auto-attach CLAUDE.md / AGENTS.md etc. to every chat: in a repo with large instruction
      -- files that can be ~10k tokens of prompt per chat, which a local model processes slowly. Add
      -- files on demand with /file or /buffer instead.
      rules = {
        opts = {
          chat = { enabled = false },
          inline = { autoload = {} },
        },
      },
      prompt_library = {
        markdown = {
          dirs = { vim.fn.stdpath("config") .. "/prompts" },
        },
      },
      display = {
        chat = {
          window = {
            layout = "vertical",
            position = "right",
            full_height = true,
            width = 0.35,
            opts = { number = false, relativenumber = false, signcolumn = "no", statuscolumn = "", foldcolumn = "0" },
          },
          -- Agent-chat look: a slim title bar showing the model (instead of a "# CodeCompanion.nvim"
          -- heading in the buffer) and a separate prompt box at the bottom of the pane.
          title = {
            position = "winbar",
            text = {
              winbar = function(metadata)
                local id = metadata.adapter and metadata.adapter.model
                id = MODELS[id] and id or state.current
                return "%#CodeCompanionChatHeader# Local chat%*%=%#Comment#"
                  .. MODELS[id].short
                  .. " · <leader>am to switch "
              end,
            },
          },
          input = { layout = "split", height = 6 },
          intro_message = "Ask anything. Ctrl-S to send, ? for keys.",
        },
      },
    },
    keys = {
      { "<leader>a", "", desc = "+ai (local)", mode = { "n", "v" } },
      { "<leader>ac", "<cmd>CodeCompanionChat Toggle<cr>", desc = "Local chat: toggle" },
      {
        "<leader>af",
        function()
          local win = chat_win()
          if win then
            vim.api.nvim_set_current_win(win)
          else
            vim.cmd("CodeCompanionChat Toggle")
          end
        end,
        desc = "Local chat: focus",
      },
      { "<leader>aa", "<cmd>CodeCompanionChat Add<cr>", mode = "v", desc = "Local chat: add selection" },
      { "<leader>an", "<cmd>CodeCompanionChat<cr>", desc = "Local chat: new chat" },
      { "<leader>am", switch_model, desc = "Local chat: switch model" },
      { "<leader>ap", "<cmd>CodeCompanionActions<cr>", mode = { "n", "v" }, desc = "Local AI: actions/prompts" },
      { "<leader>ai", ":CodeCompanion ", mode = { "n", "v" }, desc = "Local AI: inline prompt" },
    },
  },
}
