# LocalLLMChat

LocalLLMChat is a Flask-based web interface for chatting with local Large Language Model runtimes. It provides a private, network-accessible environment for AI-assisted workflows with no external API keys or internet connectivity required.

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Python](https://img.shields.io/badge/python-3.8+-blue.svg)
![Flask](https://img.shields.io/badge/flask-2.0+-green.svg)

---

## Features

- **Multi-backend support** — Ollama, LM Studio, and any OpenAI-compatible endpoint
- **Persistent settings** — endpoint, model, temperature, system prompt, and theme saved to `~/.local_llm_chat/settings.yaml`; auto-saved on every change and restorable with the Save Configuration button
- **Chat history browser** — conversations auto-saved after every reply; browse, load, and delete from the History modal; model-agnostic so any saved chat can be continued with any model
- **Collapsible sidebar** — collapses to a compact icon strip; state persisted across page loads
- **Token usage display** — each assistant reply shows duration, token counts, tokens/sec, and model name
- **Network accessible** — binds to all interfaces (`0.0.0.0`) so any device on your local network can connect
- **Linux background service** — installs as a systemd service with automatic startup at boot, firewall configuration, and Ollama lifecycle management
- **LLM service management** — start Ollama from the UI, monitor running status and active model, shut down the server from the browser
- **Server hostname display** — shows which machine is serving the interface (useful on multi-host setups)
- **Dark / light theme** — Cyber Dark theme by default, toggleable and persisted; all modals themed to match
- **Responsive design** — works on desktop and mobile browsers

---

## Documentation

| File | Contents |
|------|----------|
| [INSTALL.md](INSTALL.md) | Quick-start install commands per platform |
| [SETUP.md](SETUP.md) | Detailed platform setup: Ollama, LM Studio, per-OS troubleshooting |
| [MODELS.md](MODELS.md) | Runtime deep-dive, hardware tiers, quantization guide, model recommendations |

---

## Installation

### Linux — Persistent Service (recommended for workstations and servers)

Installs LocalLLMChat and Ollama as systemd services that start at boot, opens the firewall port, and prints your local network URL.

```bash
git clone https://github.com/yourusername/LocalLLMChat.git
cd LocalLLMChat

# System-wide service — starts at boot for all users (requires sudo)
chmod +x install-service-linux.sh
./install-service-linux.sh

# Per-user service — starts on login, no sudo needed for the app
./install-service-linux.sh --user

# Remove everything
./install-service-linux.sh --uninstall
```

The installer will:
1. Install Ollama via the official installer if not present
2. Enable and start the `ollama` systemd service
3. Install LocalLLMChat into a virtualenv at `/opt/local-llm-chat`
4. Create and enable a `local-llm-chat` systemd service (with a dedicated service user for system installs)
5. Open port 5000 in `ufw`, `firewalld`, or `iptables` (whichever is active)
6. Print both localhost and local-network access URLs

### Linux — Interactive (foreground / development)

```bash
git clone https://github.com/yourusername/LocalLLMChat.git
cd LocalLLMChat
chmod +x install-linux.sh
./install-linux.sh
```

### macOS

```bash
git clone https://github.com/yourusername/LocalLLMChat.git
cd LocalLLMChat
chmod +x install-macos.sh
./install-macos.sh
```

### Windows (PowerShell)

```powershell
git clone https://github.com/yourusername/LocalLLMChat.git
cd LocalLLMChat
powershell -ExecutionPolicy Bypass -File install-windows.ps1
```

### Chromebook (Linux Beta)

```bash
git clone https://github.com/yourusername/LocalLLMChat.git
cd LocalLLMChat
chmod +x install-chromebook.sh
./install-chromebook.sh
```

### Manual

```bash
git clone https://github.com/yourusername/LocalLLMChat.git
cd LocalLLMChat
python3 -m venv venv
source venv/bin/activate
pip install -e .
```

---

## Running the Application

```bash
# Background mode (default on Unix — detaches after launch)
local-llm-chat

# Stay attached to the terminal
local-llm-chat --foreground

# Development mode with hot-reload and verbose logging
local-llm-chat --debug

# Custom host and port
local-llm-chat --host 0.0.0.0 --port 8080
```

Then open `http://localhost:5000` in your browser, or use the local network URL printed at startup to access from any other device on your network.

---

## Service Management (Linux systemd install)

```bash
# System service
sudo systemctl status local-llm-chat
sudo systemctl restart local-llm-chat
sudo journalctl -u local-llm-chat -f

# User service
systemctl --user status local-llm-chat
systemctl --user restart local-llm-chat
journalctl --user -u local-llm-chat -f
```

---

## Configuration

### Settings file

All UI settings are automatically saved to `~/.local_llm_chat/settings.yaml` whenever you change them. You can also click **Save Configuration** in the sidebar to save immediately with visual confirmation, or edit the file directly — changes apply on the next page load.

```yaml
# LocalLLMChat Settings
endpoint: http://localhost:11434
model: llama3.2
temperature: 0.8
theme: dark
system_prompt: |
  You are a helpful assistant.
```

| Field | Description |
|---|---|
| `endpoint` | LLM service base URL — Ollama default `:11434`, LM Studio `:1234` |
| `model` | Model name passed to the LLM (e.g. `llama3.2`, `mistral`, `codellama`) |
| `temperature` | `0.0` = precise / deterministic, `2.0` = highly creative; default `0.8` |
| `theme` | `dark` (Cyber Dark) or `light` |
| `system_prompt` | Instructions prepended to every conversation as a system message |

### CLI options

| Flag | Default | Description |
|---|---|---|
| `--host` | `0.0.0.0` | Interface to bind (use `0.0.0.0` for network access) |
| `--port` | `5000` | TCP port |
| `--debug` | off | Flask debug mode with hot-reload |
| `--foreground` | off | Stay attached to terminal instead of daemonising |

---

## Chat History

Conversations are **automatically saved** after every assistant reply — no manual action required. Each conversation is stored as a JSON file in `~/.local_llm_chat/conversations/`.

### History browser

Click **Chat History** in the sidebar to open the history modal. For each saved conversation it shows:

- The title (derived from your first message)
- The model that was originally used
- The date and time of the last reply
- The total number of messages

### Loading a conversation

Click **Load** on any history entry. If there is an active chat, you will be prompted to confirm before it is replaced. The conversation is restored into the chat window and the **currently selected model** is used for all new replies — you can continue any conversation with any model regardless of which model originally generated it.

If the loaded conversation came from a different model than the one currently selected, a brief notice appears in the status bar: `Loaded from llama3.2 — continuing with mistral`.

### Deleting conversations

- Click the **trash** icon on a row to delete that conversation.
- Click **Delete All** in the modal header to clear all saved conversations.

Both actions require confirmation.

### Conversation file format

```json
{
  "id": "20260405_142345",
  "title": "Why does the moon affect tides?",
  "created_at": "2026-04-05T14:23:45.123456",
  "updated_at": "2026-04-05T15:01:12.000000",
  "origin_model": "llama3.2",
  "origin_endpoint": "http://localhost:11434",
  "messages": [
    { "role": "user",      "content": "Why does the moon affect tides?" },
    { "role": "assistant", "content": "The moon exerts gravitational pull..." }
  ]
}
```

---

## Sidebar

The left sidebar contains all configuration controls. It can be collapsed to a compact icon strip by clicking the **‹** chevron at the top right of the sidebar. The collapsed strip shows icons for the most common actions. The collapsed/expanded state is saved in the browser and restored on next load.

### Sidebar actions

| Button | Description |
|---|---|
| **Save Configuration** | Immediately saves all current settings (endpoint, model, temperature, theme, system prompt) to `settings.yaml` with visual confirmation |
| **Clear Chat** | Clears the current conversation from the screen and resets the history |
| **Save Conversation** | Manually saves the current conversation (also updates the auto-save file) |
| **Chat History** | Opens the history browser modal |
| **Setup LLM** | Opens the platform-specific LLM installation guide |
| **Shutdown Server** | Stops the Flask server process |

---

## Token Usage

Every assistant reply shows a stats bar beneath the message:

| Indicator | Description |
|---|---|
| ⏱ duration | Total wall-clock time for the response in seconds |
| # tokens | Prompt tokens + completion tokens |
| ⚡ tok/s | Tokens generated per second (Ollama: from eval_duration; OpenAI-compatible: approximated) |
| 🖥 model | Model name as reported by the LLM endpoint |

---

## Project Structure

```
LocalLLMChat/
├── src/local_llm_chat/
│   ├── app.py                    # Flask application, API routes, settings I/O
│   └── templates/
│       └── chat.html             # Single-page UI (styles, layout, JavaScript)
├── install-linux.sh              # Interactive Linux installer
├── install-service-linux.sh      # Linux systemd service installer
├── install-macos.sh              # macOS installer
├── install-windows.ps1           # Windows PowerShell installer
├── install-chromebook.sh         # Chromebook installer
├── update-models.sh              # Update all installed Ollama models to latest
├── pyproject.toml                # Build configuration and dependencies
├── requirements.txt              # pip dependencies
├── [INSTALL.md](INSTALL.md)              # Quick-start install reference
├── [SETUP.md](SETUP.md)                  # Detailed platform setup guides
├── [MODELS.md](MODELS.md)                # Runtime guide, model selection, hardware requirements
└── README.md                             # This file
```

---

## API Reference

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/` | Chat interface |
| `POST` | `/api/chat` | Send a message to the LLM |
| `GET` | `/api/models` | List models available at the endpoint |
| `GET` | `/api/settings` | Load settings from `settings.yaml` |
| `POST` | `/api/settings` | Save settings to `settings.yaml` |
| `GET` | `/api/llm_status` | LLM running state, installed status, model list, hostname |
| `POST` | `/api/start_llm` | Start the local Ollama service |
| `POST` | `/api/save_conversation` | Save or update a conversation (upsert by id) |
| `GET` | `/api/conversations` | List saved conversations (newest first) |
| `GET` | `/api/conversations/<id>` | Load a single conversation by id |
| `DELETE` | `/api/conversations/<id>` | Delete a single conversation |
| `DELETE` | `/api/conversations` | Delete all conversations |
| `POST` | `/api/shutdown` | Shut down the Flask server |

---

## Supported Backends

| Backend | Default endpoint | Notes |
|---|---|---|
| **Ollama** | `http://localhost:11434` | Recommended; auto-detected by port |
| **LM Studio** | `http://localhost:1234` | OpenAI-compatible local server |
| **LocalAI / vLLM / Llamafile** | varies | Any OpenAI-compatible `/v1/chat/completions` endpoint |

See [MODELS.md](MODELS.md) for a full guide to both runtimes, hardware requirements, quantization formats, and model recommendations by use case.

---

## Updating Ollama Models

`update-models.sh` updates all locally installed Ollama models to the latest versions.

```bash
./update-models.sh                  # Interactive update
./update-models.sh --dry-run        # Show what would run, no changes
./update-models.sh --auto           # Non-interactive (cron / systemd)
./update-models.sh --install-timer  # Install a weekly systemd timer (Sun 03:00)
./update-models.sh --remove-timer   # Remove the timer
```

---

## Troubleshooting

**Can't connect from another device on the network**
- Verify the service is bound to `0.0.0.0` (it is by default)
- Check the firewall: `sudo ufw status` or `sudo firewall-cmd --list-ports`
- Open the port manually if needed: `sudo ufw allow 5000/tcp`

**LLM connection refused**
```bash
curl http://localhost:11434/api/tags   # Ollama health check
sudo systemctl status ollama           # Service status
```

**Model not found**
```bash
ollama list          # Show downloaded models
ollama pull llama3.2 # Download a model
```

**Slow responses**
Use a smaller or more quantized model (e.g. `llama3.2:1b`, `phi`) or lower the temperature.

**Settings not loading**
Check `~/.local_llm_chat/settings.yaml` for YAML syntax errors. Delete the file to regenerate defaults on next startup.

**Conversation history missing after Clear Chat**
Clear Chat resets the active session. Conversations are auto-saved after each reply, so the history browser will still contain all previous exchanges.

---

## Development

```bash
pip install -e ".[dev]"
black src/          # Format
flake8 src/         # Lint
```

---

## License

MIT — see [LICENSE](LICENSE).

---

## Acknowledgments

- [Ollama](https://ollama.com/)
- [LM Studio](https://lmstudio.ai/)
- [Flask](https://flask.palletsprojects.com/)
