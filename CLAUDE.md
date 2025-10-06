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

### Running the Application

```bash
# Using the installed command
local-llm-chat

# Using Python module
python -m local_llm_chat.app

# With custom options
local-llm-chat --host 0.0.0.0 --port 8080 --debug
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
├── src/local_llm_chat/       # Main package
│   ├── __init__.py           # Package init with version
│   ├── app.py                # Flask application
│   └── templates/            # Jinja2 templates
│       └── chat.html         # Main chat interface
├── tests/                    # Test suite (future)
├── docs/                     # Additional documentation
├── pyproject.toml            # Project configuration
├── requirements.txt          # Python dependencies
├── README.md                 # User documentation
├── SETUP.md                  # Platform setup guides
└── CLAUDE.md                 # This file
```

## Key Features Implementation

1. **Temperature Control**: HTML range slider (0-2) sent with each request
2. **Save Conversation**: Saves to `~/.local_llm_chat/conversations/` as JSON
3. **Clear Chat**: Client-side array reset with confirmation
4. **Copy Response**: JavaScript clipboard API on assistant messages
5. **Model Refresh**: Fetches available models from LLM endpoint
6. **System Prompts**: Sent as first message with role "system"
7. **Conversation History**: Maintained in JavaScript array, sent with each request

## Important Implementation Details

### LLM API Calls

The `_call_local_llm()` method handles both API formats:

- Detects endpoint type by port or URL
- Constructs appropriate payload format
- Extracts response from different JSON structures
- 120-second timeout for responses
- Error handling with detailed messages

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

No configuration files required. All settings are:
- Command-line arguments (host, port, debug)
- UI controls (endpoint, model, temperature)
- Environment variables (FLASK_SECRET_KEY)

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
