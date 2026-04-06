# Installation Guide

Quick reference for installing LocalLLMChat on different platforms.

## 🚀 Quick Install

### Linux (interactive, foreground use)
```bash
git clone https://github.com/yourusername/LocalLLMChat.git
cd LocalLLMChat
chmod +x install-linux.sh
./install-linux.sh
```

### Linux — Persistent Background Service (recommended for workstations/servers)

Installs LocalLLMChat and Ollama as systemd services that start automatically at boot.

```bash
git clone https://github.com/yourusername/LocalLLMChat.git
cd LocalLLMChat
chmod +x install-service-linux.sh

# System-wide service (starts at boot for all users, requires sudo)
./install-service-linux.sh

# Per-user service (starts on login, no sudo needed for the app)
./install-service-linux.sh --user

# Remove everything
./install-service-linux.sh --uninstall
```

**What it does:**
- Installs Ollama via the official installer if not already present
- Enables and starts the `ollama` systemd service
- Creates a Python virtualenv and installs LocalLLMChat into it
- Writes a `local-llm-chat` systemd service unit
- Enables the service to start on boot
- For system installs: creates a dedicated `local-llm-chat` service user

**Service management after install:**
```bash
# System service
sudo systemctl status local-llm-chat
sudo journalctl -u local-llm-chat -f

# User service
systemctl --user status local-llm-chat
journalctl --user -u local-llm-chat -f
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

### Chromebook (Linux Beta Required)
```bash
git clone https://github.com/yourusername/LocalLLMChat.git
cd LocalLLMChat
chmod +x install-chromebook.sh
./install-chromebook.sh
```

---

## 📋 What the Scripts Do

All installation scripts will:

1. ✅ Check for Python 3.8+ (install if missing)
2. ✅ Optionally install Ollama
3. ✅ Optionally download dolphin-mistral or other models
4. ✅ Install LocalLLMChat and all dependencies
5. ✅ Configure PATH variables
6. ✅ Provide clear instructions to run

---

## 🐧 Linux-Specific: PEP 668 Support

Modern Linux distributions (Ubuntu 23.04+, Debian 12+, Fedora 38+) prevent global pip installs. Our script automatically handles this with three installation options:

### Option 1: Virtual Environment (Recommended)
- Isolated Python environment
- No conflicts with system packages
- Must activate before each use: `source venv/bin/activate`

### Option 2: pipx (Standalone Application)
- Installs as system-wide command
- Managed virtual environment
- Best for single-user systems
- Run directly: `local-llm-chat`

### Option 3: User Install (Legacy)
- Only available on older systems
- Installs to `~/.local/bin`
- May conflict with system packages

The script will automatically detect your system and offer appropriate options.

---

## 🎯 Installation Methods Comparison

| Method | Pros | Cons | Best For |
|--------|------|------|----------|
| **Virtual Env** | Isolated, no conflicts | Must activate each time | Development, testing |
| **pipx** | Global command, automatic venv | Requires pipx package | Single-user systems |
| **User Install** | Simple, direct | May conflict with system | Older distributions |

---

## 🔧 Manual Installation

If you prefer to install manually or the script doesn't work:

### 1. Install Python 3.8+
```bash
# Ubuntu/Debian
sudo apt install python3 python3-pip python3-venv

# macOS
brew install python@3.11

# Windows
# Download from https://www.python.org/downloads/
```

### 2. Install Ollama
```bash
# Linux/Mac
curl -fsSL https://ollama.com/install.sh | sh

# Windows
# Download from https://ollama.com/download
```

### 3. Download a Model
```bash
ollama pull dolphin-mistral
# or
ollama pull llama3.2
```

### 4. Install LocalLLMChat

**With Virtual Environment (Recommended):**
```bash
cd LocalLLMChat
python3 -m venv venv
source venv/bin/activate  # Linux/Mac
# or
venv\Scripts\activate  # Windows

pip install -e .
```

**With pipx (Linux/Mac):**
```bash
# Install pipx first
sudo apt install pipx  # Ubuntu/Debian
# or
brew install pipx  # macOS

# Install LocalLLMChat
cd LocalLLMChat
pipx install -e .
```

### 5. Run
```bash
local-llm-chat
# Then open: http://localhost:5000
```

---

## 🚨 Common Issues

### Linux: "externally-managed-environment" Error

**Problem:**
```
error: externally-managed-environment
× This environment is externally managed
```

**Solution:**
Run our installation script - it handles this automatically:
```bash
./install-linux.sh
```

Or create a virtual environment manually:
```bash
python3 -m venv venv
source venv/bin/activate
pip install -e .
```

### Linux: "python3-venv not found"

**Solution:**
```bash
# Ubuntu/Debian
sudo apt install python3-venv python3-full

# Fedora
sudo dnf install python3-virtualenv

# Arch
sudo pacman -S python-virtualenv
```

### All Platforms: "local-llm-chat: command not found"

**Solution:**
```bash
# If using virtual environment, activate it first
source venv/bin/activate  # Linux/Mac
venv\Scripts\activate  # Windows

# Or add to PATH
export PATH="$HOME/.local/bin:$PATH"  # Linux/Mac
# Then restart terminal or run: source ~/.bashrc
```

### Windows: "Running scripts is disabled"

**Solution:**
```powershell
# Run PowerShell as Administrator
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Or run the script with bypass
powershell -ExecutionPolicy Bypass -File install-windows.ps1
```

### Ollama: "Connection refused"

**Solution:**
```bash
# Check if Ollama is running
# Linux
systemctl status ollama
# or
ps aux | grep ollama

# Start Ollama manually if needed
ollama serve

# macOS
brew services start ollama

# Windows
# Check Task Manager for Ollama process
# Or restart Ollama from Start Menu
```

---

## 📱 Chromebook-Specific

### Requirements
- Linux (Beta) must be enabled
- At least 4GB RAM (8GB recommended)
- At least 10GB free storage

### Recommended Models
Due to limited resources, use smaller models:
- `llama3.2:1b` (1GB) - Fastest
- `phi` (1.6GB) - Good balance
- `llama3.2:3b` (2GB) - Better quality
- `dolphin-mistral` (4GB) - Best quality (if you have resources)

### Enable Linux (Beta)
1. Go to Settings → Advanced → Developers
2. Turn on "Linux development environment"
3. Follow the setup wizard
4. Open Terminal from app launcher

---

## 🆘 Getting Help

If you encounter issues not covered here:

1. Check [SETUP.md](SETUP.md) for detailed platform instructions
2. Check [README.md](README.md) for usage information
3. Look at the script output for specific error messages
4. Open an issue on GitHub with:
   - Your OS and version
   - Error messages (full output)
   - Steps to reproduce

---

## 📚 Additional Resources

- **Detailed Setup**: [SETUP.md](SETUP.md)
- **Usage Guide**: [README.md](README.md)
- **Developer Guide**: [CLAUDE.md](CLAUDE.md)
- **Ollama Models**: https://ollama.com/library
- **LM Studio**: https://lmstudio.ai/

---

**Need help?** The installation scripts provide detailed error messages and recovery instructions. Just follow the prompts! 🎉
