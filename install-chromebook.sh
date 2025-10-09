#!/bin/bash
################################################################################
# LocalLLMChat Installation Script for Chromebook
#
# Requirements:
# - Linux (Beta) must be enabled on your Chromebook
# - At least 4GB RAM (8GB recommended)
# - At least 10GB free storage
#
# This script will:
# 1. Check system resources
# 2. Install Ollama (optional)
# 3. Download a small model suitable for Chromebook (optional)
# 4. Install LocalLLMChat and dependencies
# 5. Provide instructions to run the application
#
# Usage: ./install-chromebook.sh
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

print_header "LocalLLMChat Installation Script for Chromebook"

# Check if running in Linux (Beta) on Chromebook
if [ ! -f "/etc/apt/sources.list.d/cros.list" ] && [ ! -d "/opt/google/cros-containers" ]; then
    print_warning "This doesn't appear to be a Chromebook Linux environment"
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Step 1: Check system resources
print_header "System Resource Check"

# Check RAM
TOTAL_RAM=$(free -m | awk 'NR==2{printf "%.0f", $2/1024}')
print_info "Total RAM: ${TOTAL_RAM}GB"

if [ "$TOTAL_RAM" -lt 4 ]; then
    print_error "Less than 4GB RAM detected"
    print_warning "Running local LLMs may be difficult with this amount of RAM"
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
elif [ "$TOTAL_RAM" -lt 8 ]; then
    print_warning "4-8GB RAM detected"
    print_info "Recommend using small models (1B-3B parameters)"
else
    print_success "8GB+ RAM detected - good for running local LLMs"
fi

# Check available disk space
AVAILABLE_SPACE=$(df -BG . | awk 'NR==2{print $4}' | sed 's/G//')
print_info "Available storage: ${AVAILABLE_SPACE}GB"

if [ "$AVAILABLE_SPACE" -lt 10 ]; then
    print_error "Less than 10GB free storage"
    print_warning "You need at least 10GB for Ollama and models"
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
elif [ "$AVAILABLE_SPACE" -lt 20 ]; then
    print_warning "10-20GB free storage"
    print_info "You'll be able to install 1-2 small models"
else
    print_success "20GB+ free storage - good for multiple models"
fi

# Step 2: Check Python version
print_header "Python Setup"
print_info "Checking Python installation..."

if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d'.' -f1)
    PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d'.' -f2)

    if [ "$PYTHON_MAJOR" -ge 3 ] && [ "$PYTHON_MINOR" -ge 8 ]; then
        print_success "Python $PYTHON_VERSION found"
    else
        print_error "Python 3.8+ is required (found $PYTHON_VERSION)"
        print_info "Updating Python..."
        sudo apt update
        sudo apt install -y python3 python3-pip
    fi
else
    print_error "Python 3 not found"
    print_info "Installing Python 3..."
    sudo apt update
    sudo apt install -y python3 python3-pip
fi

# Check for pip
if ! command -v pip3 &> /dev/null; then
    print_warning "pip3 not found, installing..."
    sudo apt install -y python3-pip
fi

print_success "Python and pip are ready"

# Step 3: Install Ollama (optional)
print_header "Ollama Installation"

if command -v ollama &> /dev/null; then
    print_success "Ollama is already installed"
    OLLAMA_VERSION=$(ollama --version 2>&1 | head -n1)
    print_info "Version: $OLLAMA_VERSION"
else
    echo -e "${YELLOW}Ollama is not installed.${NC}"
    print_info "Ollama is required for LocalLLMChat to function"
    print_warning "Ollama requires about 1GB of storage space"
    print_info "Installing Ollama automatically..."
        print_info "Installing Ollama..."
        curl -fsSL https://ollama.com/install.sh | sh

        if [ $? -eq 0 ]; then
            print_success "Ollama installed successfully"

            # Start Ollama service
            print_info "Starting Ollama service..."
            ollama serve > /dev/null 2>&1 &
            sleep 3
            print_success "Ollama service started in background"
        else
            print_error "Ollama installation failed"
            print_error "LocalLLMChat requires Ollama to function"
            print_info "Please install manually and run this script again"
            exit 1
        fi
fi

# Step 4: Download model suitable for Chromebook (automatic)
if command -v ollama &> /dev/null; then
    print_header "Model Installation"

    # Make sure Ollama is running
    if ! pgrep -x "ollama" > /dev/null; then
        print_info "Starting Ollama service..."
        ollama serve > /dev/null 2>&1 &
        sleep 3
    fi

    # Check existing models
    EXISTING_MODELS=$(ollama list 2>/dev/null | tail -n +2)
    HAS_ANY_MODEL=$(echo "$EXISTING_MODELS" | grep -q "." && echo "yes" || echo "no")

    if [ "$HAS_ANY_MODEL" = "yes" ]; then
        print_success "Found existing models installed:"
        ollama list 2>/dev/null
    else
        print_warning "No models found. Installing appropriate model for Chromebook..."

        # Determine best model based on available space and RAM
        if [ "$AVAILABLE_SPACE" -ge 20 ] && [ "$TOTAL_RAM" -ge 8 ]; then
            MODEL="dolphin-mistral"
            MODEL_SIZE="4GB"
            print_info "You have sufficient resources for dolphin-mistral (recommended)"
        elif [ "$AVAILABLE_SPACE" -ge 15 ] && [ "$TOTAL_RAM" -ge 6 ]; then
            MODEL="llama3.2:3b"
            MODEL_SIZE="2GB"
            print_info "Installing llama3.2:3b (good balance for your Chromebook)"
        elif [ "$AVAILABLE_SPACE" -ge 10 ] && [ "$TOTAL_RAM" -ge 4 ]; then
            MODEL="phi"
            MODEL_SIZE="1.6GB"
            print_info "Installing phi (efficient for limited resources)"
        else
            MODEL="llama3.2:1b"
            MODEL_SIZE="1GB"
            print_info "Installing llama3.2:1b (smallest, best for limited resources)"
        fi

        print_warning "Download size: ~${MODEL_SIZE}, this may take 5-15 minutes"
        print_info "Please be patient and keep this window open"

        ollama pull "$MODEL"

        if [ $? -eq 0 ]; then
            print_success "$MODEL model downloaded successfully"
        else
            print_error "Model download failed"
            print_error "LocalLLMChat requires at least one model to function"
            print_info "You can download it manually later with: ollama pull $MODEL"
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

# For Chromebook, recommend virtual environment to save space
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
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
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

# Step 6: Create Desktop Launcher
print_header "Creating Desktop Launcher"

# Create .desktop file for Chromebook
DESKTOP_FILE="$HOME/Desktop/LocalLLMChat.desktop"
INSTALL_DIR="$(pwd)"

cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=LocalLLMChat
Comment=Chat with Local LLM Models
Exec=bash -c 'cd "$INSTALL_DIR" && if [ -f venv/bin/activate ]; then source venv/bin/activate; fi && if ! pgrep -x ollama > /dev/null; then ollama serve > /dev/null 2>&1 & sleep 2; fi && local-llm-chat --foreground & sleep 3 && xdg-open http://localhost:5000'
Terminal=false
Categories=Network;Chat;
EOF

chmod +x "$DESKTOP_FILE"
gio set "$DESKTOP_FILE" metadata::trusted true 2>/dev/null || true
print_success "Desktop launcher created: LocalLLMChat.desktop"

# Step 7: Start the application and launch browser
print_header "Launching LocalLLMChat"

print_info "Starting LocalLLMChat server..."
print_info "This will open in your browser automatically"
echo

# Ensure Ollama is running
if command -v ollama &> /dev/null; then
    if ! pgrep -x "ollama" > /dev/null; then
        print_info "Starting Ollama service..."
        ollama serve > /dev/null 2>&1 &
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
xdg-open http://localhost:5000 2>/dev/null || {
    print_warning "Could not open browser automatically"
    print_info "Please open http://localhost:5000 in Chrome"
}

# Step 8: Final information
print_header "Installation Complete!"

print_success "LocalLLMChat has been installed and is now running on your Chromebook!"
echo

print_info "The application is running in the background"
print_info "Your browser should open automatically"
echo

print_info "Chromebook Performance Tips:"
echo "  • Close unnecessary tabs and apps while running"
echo "  • Use smaller models (1B-3B parameters)"
echo "  • Lower the temperature for faster responses"
echo "  • Be patient - first responses may be slower"
echo

print_info "To start LocalLLMChat in the future:"
echo "  • Double-click the 'LocalLLMChat' icon on your desktop"
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

    # Check which model is installed
    if ollama list 2>/dev/null | grep -q "dolphin-mistral"; then
        echo "   Model: dolphin-mistral"
    elif ollama list 2>/dev/null | grep -q "llama3.2:3b"; then
        echo "   Model: llama3.2:3b"
    elif ollama list 2>/dev/null | grep -q "llama3.2:1b"; then
        echo "   Model: llama3.2:1b"
    elif ollama list 2>/dev/null | grep -q "phi"; then
        echo "   Model: phi"
    else
        echo "   Model: (first available model)"
    fi
fi

echo
print_warning "Note: If Ollama service stops, restart it from the desktop icon or with:"
echo "   ollama serve > /dev/null 2>&1 &"
echo

print_info "For detailed setup instructions, see SETUP.md"
print_info "For usage information, see README.md"
echo
print_success "Happy chatting on your Chromebook! 🎉"
echo

read -p "Press Enter to exit (LocalLLMChat will continue running)..."
