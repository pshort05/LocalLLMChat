# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LocalLLMChat is a Flask-based web interface for chatting with local LLM models. It provides a clean, modern chat interface that works with Ollama, LM Studio, and other OpenAI-compatible local LLM services. No external API keys required.

## Architecture

### Core Components

1. **Flask Application** (`src/local_llm_chat/app.py`)
   - Main application class: `LocalLLMChat`
   - Handles routing, API calls to local LLMs, and conversation storage
   - Supports both Ollama API format and OpenAI-compatible format

2. **Web Interface** (`src/local_llm_chat/templates/chat.html`)
   - Single-page chat application
   - Bootstrap 5 for styling
   - Marked.js for markdown rendering
   - Real-time chat with typing indicators

3. **Configuration** (`pyproject.toml`)
   - Standard Python packaging configuration
   - Entry point: `local-llm-chat` command
   - Minimal dependencies: Flask and Requests

### API Endpoints

- `GET /` - Main chat interface
- `POST /api/chat` - Send message to LLM and get response
- `GET /api/models` - List available models from endpoint
- `POST /api/save_conversation` - Save chat history to file
- `GET /api/conversations` - List saved conversations
- `GET /api/settings` - Load settings from `~/.local_llm_chat/settings.yaml`
- `POST /api/settings` - Save settings to `~/.local_llm_chat/settings.yaml`
- `GET /api/llm_status` - Check LLM service status, installed state, models, and hostname
- `POST /api/start_llm` - Start the local Ollama service (platform-aware)
- `POST /api/shutdown` - Shutdown the Flask server

### Local LLM Integration

The application supports two API formats:

1. **Ollama API** (default port 11434)
   - Endpoint: `/api/chat`
   - Auto-detected by port 11434 or "ollama" in URL

2. **OpenAI-Compatible API** (e.g., LM Studio on port 1234)
   - Endpoint: `/v1/chat/completions`
   - Standard OpenAI format

## Development Commands

### Installation

```bash
# Development install
pip install -e .

# Or install dependencies only
pip install -r requirements.txt
```

Platform-specific install scripts are available in the repo root:

```bash
# Linux (interactive, foreground use)
./install-linux.sh

# Linux (persistent background service — recommended for workstations/servers)
./install-service-linux.sh             # system-wide service (sudo required)
./install-service-linux.sh --user      # per-user service (no sudo)
./install-service-linux.sh --uninstall # remove everything

# macOS
./install-macos.sh

# Chromebook (Linux Beta)
./install-chromebook.sh

# Windows (PowerShell)
powershell -ExecutionPolicy Bypass -File install-windows.ps1
```

See `INSTALL.md` for quick-start instructions per platform.

### Running the Application

```bash
# Using the installed command (runs in background by default)
local-llm-chat

# Using Python module
python -m local_llm_chat.app

# With custom options
local-llm-chat --host 0.0.0.0 --port 8080 --debug

# Force foreground mode (stays attached to terminal)
local-llm-chat --foreground
```

In production mode (no `--debug`), the server launches itself via `nohup` and detaches from the terminal. Logs go to `local_llm_chat.log` in the working directory. Use the "Shutdown Server" button in the UI to stop it.

### Committing Changes

This repo uses `push.sh` for committing and pushing. The script reads the commit message from a file named `commit_message` in the repo root, then deletes it after a successful push.

**Workflow:**
1. Create or update `commit_message` with a summary of all changes in the current work session
2. Run `./push.sh` to commit and push

**When working with Claude Code:**
- At the end of each session (or when asked to commit), write a `commit_message` file summarising all changes made
- If no `commit_message` file exists, assume it is the start of a new commit and create a fresh one
- Keep messages concise: a one-line subject, blank line, then bullet points for each significant change
- The file is deleted automatically on successful push — absence means a clean slate

**Example format:**
```
feat: add settings persistence and Linux service installer

- Add settings.yaml load/save via GET/POST /api/settings
- Auto-save settings from UI with 600ms debounce
- Add install-service-linux.sh with systemd + firewall setup
- Open firewall port via ufw/firewalld/iptables
- Update README, INSTALL.md, CLAUDE.md
```

### Code Formatting

```bash
# Format with Black (line length 88)
black src/ tests/

# Check without modifying
black --check src/
```

### Testing

Currently no automated tests. Future additions should use pytest:

```bash
pytest tests/
```

## Project Structure

```
LocalLLMChat/
├── src/local_llm_chat/         # Main package
│   ├── __init__.py             # Package init with version
│   ├── app.py                  # Flask application
│   └── templates/              # Jinja2 templates
│       └── chat.html           # Main chat interface
├── tests/                      # Test suite (future)
├── docs/                       # Additional documentation
├── install-linux.sh            # Linux interactive install
├── install-service-linux.sh    # Linux systemd service install (server/workstation)
├── install-macos.sh            # macOS install script
├── install-windows.ps1         # Windows PowerShell install script
├── install-chromebook.sh       # Chromebook install script
├── update-models.sh            # Update all installed Ollama models to latest
├── pyproject.toml              # Project configuration
├── requirements.txt            # Python dependencies
├── README.md                   # User documentation
├── INSTALL.md                  # Quick install guide (per platform)
├── SETUP.md                    # Detailed platform setup guides
└── CLAUDE.md                   # This file
```

## Key Features Implementation

1. **Temperature Control**: HTML range slider (0-2) sent with each request
2. **Save Conversation**: Saves to `~/.local_llm_chat/conversations/` as JSON
3. **Clear Chat**: Client-side array reset with confirmation
4. **Copy Response**: JavaScript clipboard API on assistant messages
5. **Model Refresh**: Fetches available models from LLM endpoint
6. **System Prompts**: Sent as first message with role "system"
7. **Conversation History**: Maintained in JavaScript array, sent with each request
8. **LLM Status Check**: `/api/llm_status` returns running state, installed state, model list, and server hostname
9. **Start LLM from UI**: `/api/start_llm` triggers `systemctl`, `brew services`, or `ollama serve` depending on platform
10. **Server Shutdown**: `/api/shutdown` button in UI stops the Flask process cleanly
11. **Server Hostname Display**: Hostname shown in UI via status API response
12. **Background Mode**: Production runs detach via `nohup`; foreground forced with `--foreground` flag

## Important Implementation Details

### LLM API Calls

The `_call_local_llm()` method handles both API formats:

- Detects endpoint type by port or URL
- Constructs appropriate payload format
- Extracts response from different JSON structures
- 120-second timeout for responses
- Error handling with detailed messages

### LLM Service Management

`_check_llm_status(endpoint)` returns: `running`, `installed`, `endpoint`, `models`, `active_model`, `platform`, `hostname`.

`_start_llm_service()` is platform-aware:
- Linux: tries `systemctl start ollama`, falls back to `ollama serve` in background
- macOS: tries `brew services start ollama`, falls back to `ollama serve`
- Windows: tries `net start Ollama`, returns error with manual instructions if it fails

### Conversation Storage

- Default location: `~/.local_llm_chat/conversations/`
- Format: JSON with timestamp and messages array
- Filename: `conversation_YYYYMMDD_HHMMSS.json`
- Created on first save (directory auto-created)

### UI/UX Considerations

- Bootstrap 5 for responsive design
- Marked.js renders markdown in assistant responses
- Typing indicators during LLM processing
- Auto-scroll to latest message
- Keyboard shortcuts (Enter to send, Shift+Enter for newline)
- Copy button appears on assistant messages only

## Common Development Tasks

### Adding a New Feature

1. Add backend logic in `app.py` (new route or modify existing)
2. Update frontend in `chat.html` (JavaScript and HTML)
3. Test with both Ollama and LM Studio
4. Update README.md with feature documentation

### Modifying the UI

All UI code is in `src/local_llm_chat/templates/chat.html`:
- Styles in `<style>` section
- Layout in `<body>` section
- Logic in `<script>` section

### Adding New Endpoints

Follow Flask patterns in `_setup_routes()`:
```python
@self.app.route("/api/new_endpoint", methods=["POST"])
def new_endpoint():
    # Implementation
    return jsonify({"result": data})
```

## Dependencies

### Required
- `flask>=2.0.0` - Web framework
- `requests>=2.25.0` - HTTP client for LLM APIs

### Development
- `pytest>=6.0` - Testing framework
- `pytest-cov` - Coverage reporting
- `black` - Code formatting
- `flake8` - Linting

## Configuration

### Settings file: `~/.local_llm_chat/settings.yaml`

Created automatically on first run. All UI settings are auto-saved to this file whenever changed (600ms debounce). The file can also be edited directly — changes apply on the next page load.

```yaml
# LocalLLMChat Settings
endpoint: http://localhost:11434
model: llama3.2
temperature: 0.8
theme: dark
system_prompt: |
  You are a helpful assistant.
```

Persisted settings: `endpoint`, `model`, `temperature`, `theme`, `system_prompt`.

### Other configuration
- Command-line arguments (host, port, debug, foreground)
- Environment variables (`FLASK_SECRET_KEY`)

## Local LLM Setup

Refer to SETUP.md for detailed instructions:
- Linux: Ollama via curl, LM Studio via download
- macOS: Ollama via Homebrew or .dmg, LM Studio via .dmg
- Windows: Ollama installer, LM Studio installer
- Chromebook: Linux Beta with Ollama

## Troubleshooting

### Common Issues

1. **Connection refused**: Check if LLM service is running
2. **Model not found**: Verify model is downloaded (`ollama list`)
3. **Port conflicts**: Check if port is already in use
4. **Slow responses**: Use smaller models or lower temperature

### Debug Mode

Run with `--debug` flag for detailed logging:
```bash
local-llm-chat --debug
```

## Code Style

- Follow PEP 8 guidelines
- Use Black formatter (line length 88)
- Type hints where appropriate
- Docstrings for classes and complex functions
- Clear variable names

## Future Enhancements

Potential areas for contribution:
- Conversation history browser in UI
- Multiple conversation threads
- Export to Markdown/PDF
- Voice input/output
- Dark mode toggle
- Model performance metrics
- WebSocket for streaming responses
- Authentication/multi-user support
