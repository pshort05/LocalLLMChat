# LocalLLMChat

LocalLLMChat is a robust, Flask-based web interface designed for interacting with local Large Language Model (LLM) runtimes. It provides a secure, private, and customizable environment for AI-assisted workflows without requiring external API keys or internet connectivity.

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Python](https://img.shields.io/badge/python-3.8+-blue.svg)
![Flask](https://img.shields.io/badge/flask-2.0+-green.svg)

---

## Features

- **Unified Interface**: Connects to multiple backends including Ollama, LM Studio, and other OpenAI-compatible endpoints.
- **Privacy-Centric**: Operates entirely within your local network, ensuring data security and offline availability.
- **Persistent Conversations**: Automatic saving and manual export of chat history to JSON format.
- **Granular Control**: Real-time adjustment of inference parameters such as temperature and system prompts.
- **Process Management**: Integrated background execution mode with persistent service support via PM2.
- **Responsive Design**: Optimized for both desktop and mobile browsers across the local network.
- **Developer Tools**: Dedicated debug mode with auto-reload and comprehensive logging.

---

## Installation

### Automated Installation

Automated scripts are provided for rapid deployment across supported platforms. These scripts verify Python dependencies, optionally install the Ollama runtime, and configure the application environment.

**Linux / macOS:**
```bash
git clone https://github.com/yourusername/LocalLLMChat.git
cd LocalLLMChat
chmod +x install-linux.sh # or install-macos.sh
./install-linux.sh
```

**Windows (PowerShell):**
```powershell
git clone https://github.com/yourusername/LocalLLMChat.git
cd LocalLLMChat
powershell -ExecutionPolicy Bypass -File install-windows.ps1
```

**Chromebook (Linux Beta):**
```bash
git clone https://github.com/yourusername/LocalLLMChat.git
cd LocalLLMChat
chmod +x install-chromebook.sh
./install-chromebook.sh
```

### Manual Installation

To install the package manually within a virtual environment:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/LocalLLMChat.git
   cd LocalLLMChat
   ```

2. **Install dependencies:**
   ```bash
   pip install -e .
   ```

3. **Configure the LLM Backend:**
   Ensure a compatible service (e.g., Ollama or LM Studio) is active. Refer to [SETUP.md](SETUP.md) for detailed configuration steps.

---

## Execution

The application can be launched using the `local-llm-chat` entry point.

```bash
# Standard background execution (default on Unix)
local-llm-chat

# Foreground execution for monitoring
local-llm-chat --foreground

# Development mode with hot-reloading
local-llm-chat --debug

# Network configuration
local-llm-chat --host 0.0.0.0 --port 5000
```

### Operational Modes

- **Background**: The server persists after the terminal session is closed.
- **Foreground**: Standard execution mode; process terminates with the terminal session.
- **Debug**: Enables Flask development server features and verbose logging.

---

## Configuration

The web interface allows for dynamic configuration of the following parameters:

1. **API Endpoint**: The URL of your local LLM service (e.g., `http://localhost:11434` for Ollama).
2. **Model Selection**: The specific model identifier to be used for inference.
3. **Temperature**: Controls the randomness of the output (0.0 for deterministic, up to 2.0 for creative).
4. **System Prompt**: Defines the persona and constraints for the AI assistant.

---

## Project Structure

```text
LocalLLMChat/
├── src/
│   └── local_llm_chat/
│       ├── app.py               # Core Flask application and API logic
│       └── templates/
│           └── chat.html        # Frontend interface and client-side logic
├── pyproject.toml               # Build system configuration
├── requirements.txt             # Project dependencies
├── README.md                    # Project documentation
├── SETUP.md                     # Platform-specific configuration guides
└── LICENSE                      # MIT License
```

---

## Development and Contribution

LocalLLMChat encourages community contributions. To set up a development environment:

1. **Install with development dependencies:**
   ```bash
   pip install -e ".[dev]"
   ```

2. **Maintain Code Quality:**
   Use `black` for formatting and `flake8` for linting before submitting pull requests.
   ```bash
   black src/
   ```

---

## Supported Backends

- **Ollama**: Default recommended runtime for Linux, macOS, and Windows.
- **LM Studio**: Provides a GUI-driven approach for model management.
- **OpenAI-Compatible APIs**: Supports LocalAI, vLLM, and Llamafile.

---

## Troubleshooting

### Connectivity Issues
Ensure the backend service is running and accessible at the configured endpoint. You can verify Ollama connectivity via:
```bash
curl http://localhost:11434/api/tags
```

### Model Availability
Confirm the requested model is pulled and available in your local registry:
```bash
ollama list
```

### Resource Management
Performance is dependent on local hardware. If experiencing latency, consider utilizing smaller quantized models (e.g., 4-bit or 5-bit) or decreasing the context window.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for the full text.

---

## Acknowledgments

- [Ollama](https://ollama.com/)
- [LM Studio](https://lmstudio.ai/)
- [Flask Framework](https://flask.palletsprojects.com/)
