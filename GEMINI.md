# GEMINI.md - LocalLLMChat Context

This file serves as a foundational guide for AI assistants (like Gemini) to understand the project's architecture, development workflows, and operational mandates.

## Project Overview

**LocalLLMChat** is a lightweight, Flask-based web application providing a modern interface for interacting with local Large Language Models (LLMs). It acts as a bridge between the user and local model runtimes like **Ollama**, **LM Studio**, or any OpenAI-compatible API.

-   **Primary Goal:** Provide a 100% local, privacy-focused chat interface without requiring external API keys.
-   **Core Technologies:**
    -   **Backend:** Python 3.8+, Flask, Requests.
    -   **Frontend:** HTML5, CSS3 (Bootstrap 5), JavaScript (Vanilla), Marked.js (Markdown rendering).
    -   **LLM Integration:** Ollama (default), LM Studio, LocalAI, vLLM.

## Architecture & System Design

### 1. Backend Service (`src/local_llm_chat/app.py`)
-   The core logic resides in the `LocalLLMChat` class.
-   **API Wrapper:** Translates standard chat requests into specific formats for Ollama or OpenAI-compatible endpoints.
-   **Persistence:** Conversations are saved as JSON files in `~/.local_llm_chat/conversations/`.
-   **Server Modes:**
    -   **Foreground:** Standard interactive mode.
    -   **Background:** Uses `nohup` (on Unix) to persist after the terminal session ends.
    -   **Debug:** Enables Flask's auto-reload and detailed logging.

### 2. Frontend Interface (`src/local_llm_chat/templates/chat.html`)
-   A single-page application (SPA) design.
-   Handles message history, model selection, temperature control, and system prompts entirely in the client-side state before sending to the backend.
-   Uses `Marked.js` for real-time Markdown rendering of LLM responses.

### 3. Build & Distribution
-   Managed via `pyproject.toml` using `setuptools`.
-   **Entry Point:** The command `local-llm-chat` is mapped to `local_llm_chat.app:main`.

## Development Workflows

### Environment Setup
```bash
# Install in development mode
pip install -e ".[dev]"

# Install from requirements (alternative)
pip install -r requirements.txt
```

### Running the Application
-   **Default:** `local-llm-chat` (Runs in background on Unix-like systems).
-   **Development:** `local-llm-chat --debug --foreground`.
-   **Custom Port:** `local-llm-chat --port 8080`.

### Testing & Quality Assurance
-   **Formatting:** Rigorously follow **Black** formatting (line length 88).
    -   Command: `black src/`
-   **Linting:** Use `flake8` for style checking.
-   **Testing:** `pytest` is the designated test runner (tests reside in `tests/`).

## Operational Mandates & Constraints

1.  **Local First:** Never introduce dependencies that require external API keys or mandatory internet access for core functionality.
2.  **Compatibility:** Maintain support for both Ollama's native API and the OpenAI-compatible chat completions standard.
3.  **UI Consistency:** All UI changes must adhere to the existing Bootstrap 5 layout in `chat.html`. Keep the interface responsive for mobile use.
4.  **Error Handling:** Ensure the backend gracefully handles "Connection Refused" errors when LLM services are offline, providing actionable feedback to the UI.
5.  **Security:** The `FLASK_SECRET_KEY` should be configurable via environment variables for non-local deployments.

## Directory Structure Key

-   `src/local_llm_chat/`: Main package.
    -   `app.py`: The "Brain" - Flask routes and LLM client logic.
    -   `templates/chat.html`: The "Face" - All UI, CSS, and JS.
-   `install-*.sh`: Platform-specific bootstrap scripts.
-   `SETUP.md`: Detailed environment configuration for users.
-   `CLAUDE.md`: Specific guidance for Claude-based assistants.

## Common Tasks for AI Assistants

-   **Adding Features:** Modify `app.py` for new API endpoints and `chat.html` for UI integration.
-   **Debugging:** Check `local_llm_chat.log` for background process issues or run in `--debug --foreground` for real-time logs.
-   **Refactoring:** Always verify that `black` and `flake8` pass after any structural changes.
