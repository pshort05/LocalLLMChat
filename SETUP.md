# Local LLM Setup Instructions

This guide provides comprehensive instructions for setting up local LLM services on different operating systems.

## Table of Contents

- [Linux](#linux)
- [macOS](#macos)
- [Windows](#windows)
- [Chromebook](#chromebook)
- [Verification](#verification)

---

## Linux

### Option 1: Ollama (Recommended)

Ollama is the easiest way to run local LLMs on Linux.

#### Installation

```bash
# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Verify installation
ollama --version
```

#### Download and Run Models

```bash
# Download and run a model (this will download on first run)
ollama run llama3.2

# Or other models:
ollama run mistral
ollama run codellama
ollama run llama2

# List downloaded models
ollama list

# Run Ollama as a service (starts automatically)
# The service runs on http://localhost:11434
```

#### Using with Local LLM Chat

1. Make sure Ollama is running (it should start automatically as a service)
2. Open the Local LLM Chat web interface
3. Set endpoint to: `http://localhost:11434`
4. Enter model name: `llama3.2` (or any model you've downloaded)
5. Start chatting!

### Option 2: LM Studio

[LM Studio](https://lmstudio.ai/) provides a GUI for running local LLMs.

#### Installation

```bash
# Download from https://lmstudio.ai/
# Or install via snap:
sudo snap install lmstudio
```

#### Setup

1. Launch LM Studio
2. Browse and download models from the built-in model browser
3. Load a model
4. Go to "Local Server" tab
5. Click "Start Server" (default port: 1234)

#### Using with Local LLM Chat

1. Start the LM Studio local server
2. Open the Local LLM Chat web interface
3. Set endpoint to: `http://localhost:1234`
4. Enter the model name shown in LM Studio
5. Start chatting!

### Troubleshooting Linux

**Ollama service not starting:**
```bash
# Check service status
systemctl status ollama

# Restart service
sudo systemctl restart ollama

# View logs
journalctl -u ollama -f
```

**Port already in use:**
```bash
# Check what's using port 11434
sudo lsof -i :11434

# Kill the process if needed
sudo kill -9 <PID>
```

---

## macOS

### Option 1: Ollama (Recommended)

#### Installation

```bash
# Using Homebrew
brew install ollama

# Or download from https://ollama.com/download
# and install the .dmg file
```

#### Start Ollama Service

```bash
# Start Ollama (will run in background)
ollama serve &

# Or use launchd to start automatically
brew services start ollama
```

#### Download and Run Models

```bash
# Download and run a model
ollama run llama3.2

# List available models
ollama list
```

#### Using with Local LLM Chat

1. Ensure Ollama is running: `brew services list | grep ollama`
2. Open the Local LLM Chat web interface
3. Set endpoint to: `http://localhost:11434`
4. Enter model name: `llama3.2`
5. Start chatting!

### Option 2: LM Studio

#### Installation

1. Download from [lmstudio.ai](https://lmstudio.ai/)
2. Open the .dmg file and drag to Applications
3. Launch LM Studio

#### Setup

1. Browse and download models
2. Load a model
3. Start the local server (default port: 1234)

#### Using with Local LLM Chat

1. Start the LM Studio local server
2. Open the Local LLM Chat web interface
3. Set endpoint to: `http://localhost:1234`
4. Enter the model name
5. Start chatting!

### Troubleshooting macOS

**Ollama not found:**
```bash
# Check if Ollama is in PATH
which ollama

# Add to PATH if needed (add to ~/.zshrc)
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

**Permission denied:**
```bash
# Fix permissions
sudo chown -R $(whoami) /usr/local/bin/ollama
```

---

## Windows

### Option 1: Ollama

#### Installation

1. Download Ollama for Windows from [ollama.com/download](https://ollama.com/download)
2. Run the installer `OllamaSetup.exe`
3. Follow the installation wizard
4. Ollama will start automatically as a Windows service

#### Download and Run Models

Open PowerShell or Command Prompt:

```powershell
# Download and run a model
ollama run llama3.2

# List downloaded models
ollama list

# Check if Ollama is running
ollama --version
```

#### Using with Local LLM Chat

1. Ollama runs automatically in the background
2. Open the Local LLM Chat web interface
3. Set endpoint to: `http://localhost:11434`
4. Enter model name: `llama3.2`
5. Start chatting!

### Option 2: LM Studio

#### Installation

1. Download from [lmstudio.ai](https://lmstudio.ai/)
2. Run the installer
3. Launch LM Studio

#### Setup

1. Browse and download models using the built-in browser
2. Load a model from the "My Models" section
3. Go to "Local Server" tab
4. Click "Start Server" (default port: 1234)

#### Using with Local LLM Chat

1. Ensure LM Studio server is running
2. Open the Local LLM Chat web interface
3. Set endpoint to: `http://localhost:1234`
4. Enter the model name shown in LM Studio
5. Start chatting!

### Troubleshooting Windows

**Ollama service not running:**
```powershell
# Check if Ollama service is running
Get-Service -Name Ollama

# Restart the service
Restart-Service Ollama
```

**Windows Defender blocking:**
- Add Ollama to Windows Defender exclusions
- Go to: Windows Security → Virus & threat protection → Exclusions
- Add the Ollama installation directory

**Port conflicts:**
```powershell
# Check what's using port 11434
netstat -ano | findstr :11434

# Kill the process if needed
taskkill /PID <PID> /F
```

---

## Chromebook

Running local LLMs on Chromebook is possible but has limitations due to hardware constraints.

### Option 1: Linux (Beta) with Ollama

Chromebooks with Linux (Beta) support can run Ollama.

#### Enable Linux (Beta)

1. Go to Settings → Advanced → Developers
2. Turn on "Linux development environment"
3. Follow the setup wizard

#### Install Ollama

```bash
# In the Linux terminal
curl -fsSL https://ollama.com/install.sh | sh

# Start Ollama
ollama serve &

# Download a smaller model (recommended for Chromebook)
ollama run llama3.2:1b  # 1B parameter model, smaller and faster
```

#### Using with Local LLM Chat

1. Ensure Ollama is running in Linux terminal
2. Open Chrome browser
3. Navigate to the Local LLM Chat web interface
4. Set endpoint to: `http://localhost:11434`
5. Use a smaller model: `llama3.2:1b` or `mistral:7b`
6. Start chatting!

### Option 2: Cloud-based Solution

For Chromebooks with limited resources, consider:

1. **Remote Server**: Run Ollama on a home server or cloud VM
2. **Access Remotely**: Use the Local LLM Chat interface pointing to the remote endpoint
3. Example endpoint: `http://your-server-ip:11434`

### Recommended Models for Chromebook

Due to limited RAM and storage, use smaller models:

```bash
# Tiny models (< 2GB RAM)
ollama run llama3.2:1b
ollama run phi

# Small models (2-4GB RAM)
ollama run llama3.2:3b
ollama run mistral:7b-instruct-q4
```

### Troubleshooting Chromebook

**Not enough storage:**
```bash
# Check disk space
df -h

# Remove unused models
ollama rm <model-name>
```

**Out of memory:**
- Use smaller quantized models (Q4, Q5)
- Close other applications
- Restart the Linux container

**Linux Beta not available:**
- Check if your Chromebook supports Linux Beta
- Update ChromeOS to the latest version
- Some older Chromebooks don't support this feature

---

## Verification

### Test Ollama Installation

```bash
# Check if Ollama is running
curl http://localhost:11434/api/tags

# Should return JSON with list of models
```

### Test with Local LLM Chat

1. **Start Local LLM Chat:**
   ```bash
   local-llm-chat
   ```

2. **Open browser:**
   Navigate to `http://localhost:5000`

3. **Configure:**
   - Endpoint: `http://localhost:11434` (Ollama) or `http://localhost:1234` (LM Studio)
   - Model: Enter your model name
   - Temperature: 0.8 (default)

4. **Test:**
   - Type a message: "Hello, can you introduce yourself?"
   - Verify you get a response

### Common Issues

**Connection refused:**
- Verify the LLM service is running
- Check firewall settings
- Confirm the port number

**Model not found:**
- List available models: `ollama list`
- Download the model: `ollama pull <model-name>`
- Use exact model name from the list

**Slow responses:**
- Use a smaller model
- Reduce temperature
- Close other applications
- Check system resources

---

## Recommended Models

### For General Use
- `llama3.2` - Latest Llama model, good balance
- `mistral` - Fast and capable
- `phi3` - Efficient for most tasks

### For Coding
- `codellama` - Specialized for code
- `deepseek-coder` - Excellent coding assistant

### For Low-Resource Systems
- `llama3.2:1b` - Smallest Llama 3.2
- `phi` - Microsoft's efficient model
- `tinyllama` - Very small, good for testing

### Download Models

```bash
# Ollama
ollama pull <model-name>

# List all available models
# Visit https://ollama.com/library
```

---

## Next Steps

After setting up your local LLM:

1. Install Local LLM Chat:
   ```bash
   pip install -e .
   ```

2. Run the application:
   ```bash
   local-llm-chat
   ```

3. Open your browser to `http://localhost:5000`

4. Start chatting with your local LLM!

---

## Additional Resources

- **Ollama Documentation**: https://github.com/ollama/ollama
- **LM Studio**: https://lmstudio.ai/
- **Model Library**: https://ollama.com/library
- **Hugging Face Models**: https://huggingface.co/models

---

## Support

If you encounter issues:

1. Check the [Troubleshooting](#troubleshooting-linux) section for your OS
2. Verify your local LLM service is running
3. Check the application logs
4. Open an issue on GitHub with:
   - Your OS and version
   - LLM service (Ollama/LM Studio)
   - Error messages
   - Steps to reproduce
