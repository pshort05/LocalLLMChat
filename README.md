# LocalLLMChat

A Flask-based web interface for chatting with local LLM models. No external API keys required!

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Python](https://img.shields.io/badge/python-3.8+-blue.svg)
![Flask](https://img.shields.io/badge/flask-2.0+-green.svg)

---

## ✨ Features

- 🚀 **Easy Setup**: Simple Flask-based web interface
- 🔒 **100% Local**: No external API keys or internet required
- 🎨 **Modern UI**: Clean, responsive chat interface
- 🌡️ **Temperature Control**: Adjust creativity vs. precision
- 💾 **Save Conversations**: Export chats to JSON files
- 🗑️ **Clear Chat**: Start fresh anytime
- 📋 **Copy Responses**: One-click copy for assistant messages
- 🔌 **Multiple Backends**: Supports Ollama, LM Studio, and OpenAI-compatible endpoints
- 💬 **Conversation History**: Maintains context throughout the chat
- 🎯 **System Prompts**: Customize AI behavior
- 📱 **Responsive Design**: Works on desktop and mobile

---

## 🚀 Quick Start

### 1. Install a Local LLM Service

Choose one:

**Ollama (Recommended)**
```bash
# Linux/Mac
curl -fsSL https://ollama.com/install.sh | sh
ollama run llama3.2

# Windows
# Download from https://ollama.com/download
```

**LM Studio**
- Download from [lmstudio.ai](https://lmstudio.ai/)
- Load a model and start the local server

See [SETUP.md](SETUP.md) for detailed platform-specific instructions.

### 2. Install LocalLLMChat

```bash
# Clone the repository
git clone https://github.com/yourusername/LocalLLMChat.git
cd LocalLLMChat

# Install in development mode
pip install -e .

# Or install dependencies directly
pip install -r requirements.txt
```

### 3. Run the Application

```bash
# Start the web interface
local-llm-chat

# Or run directly
python -m local_llm_chat.app
```

### 4. Open Your Browser

Navigate to: **http://localhost:5000**

---

## 📖 Usage

### Configuration

1. **Endpoint**: Set to your local LLM service URL
   - Ollama: `http://localhost:11434`
   - LM Studio: `http://localhost:1234`

2. **Model**: Enter the model name
   - Ollama: `llama3.2`, `mistral`, `codellama`
   - LM Studio: Use the model name shown in the UI

3. **Temperature**: Adjust between 0 (precise) and 2 (creative)

4. **System Prompt** (Optional): Define AI behavior
   - Example: "You are a helpful coding assistant"

### Features

#### 💬 Chat Interface
- Type your message and press Enter to send
- Shift+Enter for new lines
- Markdown rendering for assistant responses
- Real-time typing indicators

#### 🌡️ Temperature Control
- **0.0 - 0.3**: Focused, deterministic responses
- **0.4 - 0.8**: Balanced creativity and coherence
- **0.9 - 2.0**: More creative and varied responses

#### 💾 Save Conversations
- Click "Save Conversation" to export chat history
- Saves to: `~/.local_llm_chat/conversations/`
- Format: JSON with timestamps

#### 📋 Copy Responses
- Each assistant message has a "Copy" button
- Click to copy the full response to clipboard

#### 🗑️ Clear Chat
- Click "Clear Chat" to start a new conversation
- Warning prompt to prevent accidental clearing

---

## 🎯 Use Cases

### General Assistance
```
You: What is the capital of France?
Assistant: The capital of France is Paris...
```

### Coding Help
```
System Prompt: You are an expert Python developer
You: How do I read a CSV file in Python?
Assistant: You can read CSV files using the csv module...
```

### Creative Writing
```
Temperature: 1.2
You: Write a short story about a robot learning to paint
Assistant: In a world of circuits and steel...
```

---

## 🏗️ Project Structure

```
LocalLLMChat/
├── src/
│   └── local_llm_chat/
│       ├── __init__.py          # Package initialization
│       ├── app.py               # Main Flask application
│       └── templates/
│           └── chat.html        # Chat interface
├── tests/                       # Test suite (future)
├── docs/                        # Additional documentation
├── pyproject.toml               # Project configuration
├── requirements.txt             # Python dependencies
├── README.md                    # This file
├── SETUP.md                     # Platform-specific setup guides
├── CLAUDE.md                    # AI assistant guidance
└── LICENSE                      # MIT License
```

---

## 🔧 Development

### Install in Development Mode

```bash
# Clone the repository
git clone https://github.com/yourusername/LocalLLMChat.git
cd LocalLLMChat

# Install with development dependencies
pip install -e ".[dev]"
```

### Run with Custom Options

```bash
# Custom host and port
local-llm-chat --host 127.0.0.1 --port 8080

# Debug mode
local-llm-chat --debug
```

### Code Quality

```bash
# Format code with Black
black src/ tests/

# Run tests (when available)
pytest
```

---

## 🌐 Supported LLM Services

### Ollama
- **Endpoint**: `http://localhost:11434`
- **Installation**: `curl -fsSL https://ollama.com/install.sh | sh`
- **Models**:
  - `llama3.2` - Latest Llama model
  - `mistral` - Fast and capable
  - `codellama` - Specialized for code
  - [More models](https://ollama.com/library)

### LM Studio
- **Endpoint**: `http://localhost:1234` (default)
- **Installation**: Download from [lmstudio.ai](https://lmstudio.ai/)
- **Features**: GUI for model management

### Other OpenAI-Compatible Services
Any service that implements the OpenAI chat completions API:
- LocalAI
- Text Generation WebUI (with API extension)
- Llamafile
- vLLM

---

## 💡 Tips

### Model Selection
- **Small devices**: Use `llama3.2:1b` or `phi`
- **General use**: `llama3.2` or `mistral`
- **Coding**: `codellama` or `deepseek-coder`
- **Fast responses**: Use smaller quantized models (Q4, Q5)

### Performance
- Lower temperature = faster responses
- Smaller models = less RAM usage
- Close other applications to free resources
- Use SSD for better model loading

### System Prompts
```
# Technical assistance
You are a helpful technical assistant who provides clear, accurate explanations.

# Creative writing
You are a creative writing partner who helps develop stories and ideas.

# Code review
You are an expert code reviewer who provides constructive feedback.
```

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

### Areas for Contribution
- Additional features
- UI improvements
- Documentation
- Tests
- Bug fixes

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- [Ollama](https://ollama.com/) - Local LLM runtime
- [LM Studio](https://lmstudio.ai/) - GUI for local LLMs
- [Flask](https://flask.palletsprojects.com/) - Web framework
- OpenRouter Interface - Code inspiration and patterns

---

## 📚 Additional Resources

- **Setup Guide**: [SETUP.md](SETUP.md) - Detailed platform setup
- **Ollama Models**: [ollama.com/library](https://ollama.com/library)
- **LM Studio**: [lmstudio.ai](https://lmstudio.ai/)
- **Flask Docs**: [flask.palletsprojects.com](https://flask.palletsprojects.com/)

---

## 🆘 Troubleshooting

### Connection Refused
1. Verify your LLM service is running
2. Check the endpoint URL and port
3. Try `curl http://localhost:11434/api/tags` (Ollama)

### Model Not Found
1. List available models: `ollama list`
2. Download if needed: `ollama pull llama3.2`
3. Use exact model name from the list

### Slow Responses
1. Use a smaller model
2. Lower the temperature
3. Check system resources (RAM, CPU)
4. Close unnecessary applications

### Save Location
Conversations are saved to:
- **Linux/Mac**: `~/.local_llm_chat/conversations/`
- **Windows**: `%USERPROFILE%\.local_llm_chat\conversations\`

---

## 🚀 Future Features

- [ ] Conversation history browser
- [ ] Multiple conversation threads
- [ ] Export to Markdown/PDF
- [ ] Voice input/output
- [ ] Dark mode
- [ ] Model performance metrics
- [ ] Chat search functionality
- [ ] Custom themes

---

**Ready to chat with your local LLM?** Follow the [Quick Start](#-quick-start) guide above! 🎉
