# LocalLLMChat

LocalLLMChat is a Flask-based web interface for chatting with local Large Language Model runtimes. It provides a private, network-accessible environment for AI-assisted workflows with no external API keys or internet connectivity required.

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Python](https://img.shields.io/badge/python-3.8+-blue.svg)
![Flask](https://img.shields.io/badge/flask-2.0+-green.svg)

---

## Features

- **Multi-backend support** — Ollama, LM Studio, and any OpenAI-compatible endpoint
- **Persistent settings** — endpoint, model, temperature, system prompt, and theme saved to `~/.local_llm_chat/settings.yaml` and restored on every page load; editable directly in the file
- **Network accessible** — binds to all interfaces (`0.0.0.0`) so any device on your local network can connect
- **Linux background service** — installs as a systemd service with automatic startup at boot, firewall configuration, and Ollama lifecycle management
- **LLM service management** — start Ollama from the UI, monitor running status and active model, shutdown the server from the browser
- **Server hostname display** — shows which machine is serving the interface (useful on multi-host setups)
- **Conversation history** — saved as JSON to `~/.local_llm_chat/conversations/`
- **Dark / light theme** — Cyber Dark theme by default, toggleable and persisted
- **Responsive design** — works on desktop and mobile browsers

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
journalctl --user -u local-llm-chat -f
```

---

## Configuration

### Settings file

All UI settings are automatically saved to `~/.local_llm_chat/settings.yaml` whenever you change them. You can also edit the file directly — changes apply on the next page load.

```yaml
# LocalLLMChat Settings
# Auto-saved whenever you change settings in the UI.
# You can also edit this file directly — changes apply on next page load.

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
├── pyproject.toml                # Build configuration and dependencies
├── requirements.txt              # pip dependencies
├── INSTALL.md                    # Quick-start install reference
├── SETUP.md                      # Detailed platform setup guides
└── README.md                     # This file
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
| `POST` | `/api/save_conversation` | Save chat history to JSON |
| `GET` | `/api/conversations` | List saved conversations |
| `POST` | `/api/shutdown` | Shut down the Flask server |

---

## Supported Backends

| Backend | Default endpoint | Notes |
|---|---|---|
| **Ollama** | `http://localhost:11434` | Recommended; auto-detected by port |
| **LM Studio** | `http://localhost:1234` | OpenAI-compatible local server |
| **LocalAI / vLLM / Llamafile** | varies | Any OpenAI-compatible `/v1/chat/completions` endpoint |

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
