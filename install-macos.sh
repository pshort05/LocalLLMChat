#!/bin/bash
################################################################################
# LocalLLMChat Installation Script for macOS
#
# This script will:
# 1. Check for Python 3.8+
# 2. Install Ollama (optional)
# 3. Download dolphin-mistral model (optional)
# 4. Install LocalLLMChat and dependencies
# 5. Provide instructions to run the application
#
# Usage: ./install-macos.sh
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_header "LocalLLMChat Installation Script for macOS"

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_error "This script is for macOS only"
    print_info "For Linux, use install-linux.sh"
    exit 1
fi

# Step 1: Check for Homebrew
print_info "Checking for Homebrew..."
if ! command -v brew &> /dev/null; then
    print_warning "Homebrew not found"
    echo -e "${YELLOW}Homebrew is recommended for managing packages on macOS${NC}"
    read -p "Would you like to install Homebrew? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add Homebrew to PATH (for Apple Silicon)
        if [[ $(uname -m) == 'arm64' ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi

        if [ $? -eq 0 ]; then
            print_success "Homebrew installed successfully"
        else
            print_error "Homebrew installation failed"
            print_info "Continuing without Homebrew..."
        fi
    else
        print_info "Continuing without Homebrew..."
    fi
else
    print_success "Homebrew found"
fi

# Step 2: Check Python version
print_info "Checking Python installation..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d'.' -f1)
    PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d'.' -f2)

    if [ "$PYTHON_MAJOR" -ge 3 ] && [ "$PYTHON_MINOR" -ge 8 ]; then
        print_success "Python $PYTHON_VERSION found"
    else
        print_error "Python 3.8+ is required (found $PYTHON_VERSION)"
        if command -v brew &> /dev/null; then
            print_info "Installing Python 3 via Homebrew..."
            brew install python@3.11
        else
            print_error "Please install Python 3.8+ from https://www.python.org/downloads/"
            exit 1
        fi
    fi
else
    print_error "Python 3 not found"
    if command -v brew &> /dev/null; then
        print_info "Installing Python 3 via Homebrew..."
        brew install python@3.11
    else
        print_error "Please install Python 3.8+ from https://www.python.org/downloads/"
        exit 1
    fi
fi

# Check for pip
if ! command -v pip3 &> /dev/null; then
    print_warning "pip3 not found"
    print_info "Installing pip..."
    python3 -m ensurepip --upgrade
fi

print_success "pip3 found"

# Step 3: Install Ollama (optional)
print_header "Ollama Installation"
if command -v ollama &> /dev/null; then
    print_success "Ollama is already installed"
    OLLAMA_VERSION=$(ollama --version 2>&1 | head -n1)
    print_info "Version: $OLLAMA_VERSION"
else
    echo -e "${YELLOW}Ollama is not installed.${NC}"
    print_info "Ollama is required for LocalLLMChat to function"
    print_info "Installing Ollama automatically..."
        if command -v brew &> /dev/null; then
            print_info "Installing Ollama via Homebrew..."
            brew install ollama

            if [ $? -eq 0 ]; then
                print_success "Ollama installed successfully"

                # Start Ollama service
                print_info "Starting Ollama service..."
                brew services start ollama
                sleep 3  # Give the service time to start
                print_success "Ollama service started"
            else
                print_error "Ollama installation failed via Homebrew"
                print_info "Trying direct download method..."
                curl -fsSL https://ollama.com/install.sh | sh

                if [ $? -eq 0 ]; then
                    print_success "Ollama installed successfully"
                else
                    print_error "Ollama installation failed"
                    print_info "You can install it manually from https://ollama.com/download"
                fi
            fi
        else
            print_info "Installing Ollama via direct download..."
            curl -fsSL https://ollama.com/install.sh | sh

            if [ $? -eq 0 ]; then
                print_success "Ollama installed successfully"
            else
                print_error "Ollama installation failed"
                print_error "LocalLLMChat requires Ollama to function"
                print_info "Please install manually from https://ollama.com/download and run this script again"
                exit 1
            fi
        fi
fi

# Make sure Ollama is running
if command -v ollama &> /dev/null; then
    if ! pgrep -x "ollama" > /dev/null; then
        print_warning "Ollama is not running, attempting to start..."
        if command -v brew &> /dev/null; then
            brew services start ollama
            sleep 3
        else
            # Try to start Ollama in background
            ollama serve > /dev/null 2>&1 &
            sleep 3
        fi
    fi
fi

# Step 4: Download dolphin-mistral model (automatic)
if command -v ollama &> /dev/null; then
    print_header "Model Installation"

    # Wait a moment for Ollama to be fully ready
    print_info "Ensuring Ollama service is ready..."
    sleep 2

    # Check if any models are already installed
    EXISTING_MODELS=$(ollama list 2>/dev/null | tail -n +2)
    HAS_DOLPHIN=$(echo "$EXISTING_MODELS" | grep -q "dolphin-mistral" && echo "yes" || echo "no")
    HAS_ANY_MODEL=$(echo "$EXISTING_MODELS" | grep -q "." && echo "yes" || echo "no")

    if [ "$HAS_DOLPHIN" = "yes" ]; then
        print_success "dolphin-mistral model is already installed"
    elif [ "$HAS_ANY_MODEL" = "yes" ]; then
        print_success "Found existing models installed"
        print_info "dolphin-mistral is recommended but you have other models available"
        read -p "Would you like to also install dolphin-mistral? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Downloading dolphin-mistral model..."
            print_warning "Download size: ~4GB, this may take 5-10 minutes"
            print_info "Please be patient..."
            ollama pull dolphin-mistral

            if [ $? -eq 0 ]; then
                print_success "dolphin-mistral model downloaded successfully"
            else
                print_error "Model download failed"
            fi
        fi
    else
        print_warning "No models found. dolphin-mistral will be installed automatically"
        print_info "This model is recommended for uncensored responses"
        print_warning "Download size: ~4GB, this may take 5-10 minutes"
        print_info "Please be patient..."
        ollama pull dolphin-mistral

        if [ $? -eq 0 ]; then
            print_success "dolphin-mistral model downloaded successfully"
        else
            print_error "Model download failed"
            print_error "LocalLLMChat requires at least one model to function"
            print_info "You can download it manually later with: ollama pull dolphin-mistral"
            read -p "Press Enter to continue anyway..."
        fi
    fi

    # Show available models
    print_info "Currently installed models:"
    ollama list 2>/dev/null || print_warning "No models installed yet"
fi

# Step 5: Install LocalLLMChat
print_header "LocalLLMChat Installation"

# Check if we're in the right directory
if [ ! -f "pyproject.toml" ]; then
    print_error "pyproject.toml not found"
    print_error "Please run this script from the LocalLLMChat directory"
    exit 1
fi

print_info "Installing LocalLLMChat dependencies..."

# Create virtual environment (optional but recommended)
read -p "Would you like to install in a virtual environment? (recommended) (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_info "Creating virtual environment..."
    python3 -m venv venv
    source venv/bin/activate
    print_success "Virtual environment created and activated"

    print_info "Installing LocalLLMChat..."
    pip install --upgrade pip
    pip install -e .

    VENV_ACTIVATED=true
else
    print_info "Installing LocalLLMChat globally..."
    pip3 install --user -e .

    # Add user bin to PATH if not already there
    USER_BIN="$HOME/.local/bin"
    if [[ ":$PATH:" != *":$USER_BIN:"* ]]; then
        print_warning "Adding $USER_BIN to PATH"
        # Detect shell
        if [[ "$SHELL" == *"zsh"* ]]; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
            print_info "Added to ~/.zshrc (restart terminal or run: source ~/.zshrc)"
        else
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bash_profile
            print_info "Added to ~/.bash_profile (restart terminal or run: source ~/.bash_profile)"
        fi
        export PATH="$HOME/.local/bin:$PATH"
    fi

    VENV_ACTIVATED=false
fi

if [ $? -eq 0 ]; then
    print_success "LocalLLMChat installed successfully"
else
    print_error "Installation failed"
    exit 1
fi

# Step 6: Create Application Launcher
print_header "Creating Application Launcher"

# Create .command file for easy launching
LAUNCHER_PATH="$HOME/Desktop/LocalLLMChat.command"
cat > "$LAUNCHER_PATH" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")/../.."
INSTALL_DIR="$(pwd)"

# Find LocalLLMChat installation directory
if [ -f "pyproject.toml" ]; then
    INSTALL_DIR="$(pwd)"
elif [ -d "$HOME/LocalLLMChat" ]; then
    INSTALL_DIR="$HOME/LocalLLMChat"
    cd "$INSTALL_DIR"
fi

# Check if using venv
if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
fi

# Start Ollama if not running
if command -v ollama &> /dev/null; then
    if ! pgrep -x "ollama" > /dev/null; then
        if command -v brew &> /dev/null; then
            brew services start ollama &>/dev/null
        else
            ollama serve &>/dev/null &
        fi
        sleep 2
    fi
fi

# Start LocalLLMChat
local-llm-chat --foreground &

# Wait for server to start
sleep 3

# Open browser
open http://localhost:5000

echo "LocalLLMChat is running!"
echo "Close this window to stop the server, or use the 'Shutdown Server' button in the web interface"
echo ""
read -p "Press Enter to keep this window open (app will continue running)..."
EOF

chmod +x "$LAUNCHER_PATH"
print_success "Desktop launcher created: LocalLLMChat.command"

# Step 7: Start the application and launch browser
print_header "Launching LocalLLMChat"

print_info "Starting LocalLLMChat server..."
print_info "This will open in your browser automatically"
echo

# Ensure Ollama is running
if command -v ollama &> /dev/null; then
    if ! pgrep -x "ollama" > /dev/null; then
        print_info "Starting Ollama service..."
        if command -v brew &> /dev/null; then
            brew services start ollama &>/dev/null
        else
            ollama serve &>/dev/null &
        fi
        sleep 2
        print_success "Ollama service started"
    fi
fi

# Start LocalLLMChat
if [ "$VENV_ACTIVATED" = true ]; then
    print_info "Starting from virtual environment..."
    (local-llm-chat --foreground &)
else
    print_info "Starting LocalLLMChat..."
    (local-llm-chat --foreground &)
fi

# Wait for server to start
print_info "Waiting for server to start..."
sleep 4

# Open browser
print_info "Opening browser..."
open http://localhost:5000 2>/dev/null || {
    print_warning "Could not open browser automatically"
    print_info "Please open http://localhost:5000 manually"
}

# Step 8: Final information
print_header "Installation Complete!"

print_success "LocalLLMChat has been installed and is now running!"
echo

print_info "The application is running in the background"
print_info "Your browser should open automatically"
echo

print_info "To start LocalLLMChat in the future:"
echo "  • Double-click the 'LocalLLMChat.command' icon on your desktop"
if [ "$VENV_ACTIVATED" = true ]; then
    echo -e "  ${YELLOW}• Or run: source venv/bin/activate && local-llm-chat${NC}"
else
    echo -e "  ${YELLOW}• Or run: local-llm-chat${NC}"
fi
echo

print_info "To stop the server: Use the 'Shutdown Server' button in the web interface"
echo

if command -v ollama &> /dev/null; then
    print_info "Ollama Configuration:"
    echo "   Endpoint: http://localhost:11434"
    if ollama list 2>/dev/null | grep -q "dolphin-mistral"; then
        echo "   Model: dolphin-mistral"
    else
        echo "   Model: (first available model)"
    fi
fi

echo
print_info "For detailed setup instructions, see SETUP.md"
print_info "For usage information, see README.md"
echo
print_success "Happy chatting! 🎉"
echo

read -p "Press Enter to exit (LocalLLMChat will continue running)..."
