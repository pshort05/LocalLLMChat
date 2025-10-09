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
    print_warning "Ollama requires about 1GB of storage space"
    read -p "Would you like to install Ollama? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
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
            print_info "You can try installing manually later"
        fi
    else
        print_info "Skipping Ollama installation"
        print_warning "You'll need to install a local LLM service to use LocalLLMChat"
    fi
fi

# Step 4: Download a small model suitable for Chromebook
if command -v ollama &> /dev/null; then
    print_header "Model Installation"

    # Make sure Ollama is running
    if ! pgrep -x "ollama" > /dev/null; then
        print_info "Starting Ollama service..."
        ollama serve > /dev/null 2>&1 &
        sleep 3
    fi

    print_info "Chromebook Model Recommendations:"
    echo -e "  ${GREEN}1. dolphin-mistral${NC} (4GB) - Uncensored, good quality"
    echo -e "  ${GREEN}2. llama3.2:3b${NC} (2GB) - Small but capable"
    echo -e "  ${GREEN}3. llama3.2:1b${NC} (1GB) - Smallest, fastest"
    echo -e "  ${GREEN}4. phi${NC} (1.6GB) - Efficient, good for limited resources"
    echo

    # Check existing models
    EXISTING_MODELS=$(ollama list 2>/dev/null)

    if echo "$EXISTING_MODELS" | grep -q "dolphin-mistral"; then
        print_success "dolphin-mistral is already installed"
        INSTALL_MODEL=false
    elif echo "$EXISTING_MODELS" | grep -q "llama3.2"; then
        print_success "llama3.2 is already installed"
        INSTALL_MODEL=false
    elif echo "$EXISTING_MODELS" | grep -q "phi"; then
        print_success "phi is already installed"
        INSTALL_MODEL=false
    else
        INSTALL_MODEL=true
    fi

    if [ "$INSTALL_MODEL" = true ]; then
        echo "Which model would you like to install?"
        echo "  1) dolphin-mistral (4GB) - Recommended if you have space"
        echo "  2) llama3.2:3b (2GB)"
        echo "  3) llama3.2:1b (1GB) - For very limited resources"
        echo "  4) phi (1.6GB)"
        echo "  5) Skip model installation"
        read -p "Enter choice (1-5): " -n 1 -r
        echo

        case $REPLY in
            1)
                MODEL="dolphin-mistral"
                MODEL_SIZE="4GB"
                ;;
            2)
                MODEL="llama3.2:3b"
                MODEL_SIZE="2GB"
                ;;
            3)
                MODEL="llama3.2:1b"
                MODEL_SIZE="1GB"
                ;;
            4)
                MODEL="phi"
                MODEL_SIZE="1.6GB"
                ;;
            5)
                print_info "Skipping model installation"
                MODEL=""
                ;;
            *)
                print_warning "Invalid choice, skipping model installation"
                MODEL=""
                ;;
        esac

        if [ -n "$MODEL" ]; then
            print_info "Downloading $MODEL model (~${MODEL_SIZE})..."
            print_warning "This may take 5-15 minutes on Chromebook..."
            print_info "Please be patient and keep this window open"

            ollama pull "$MODEL"

            if [ $? -eq 0 ]; then
                print_success "$MODEL model downloaded successfully"
            else
                print_error "Model download failed"
                print_info "You can try downloading again later with: ollama pull $MODEL"
            fi
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

# Step 6: Final instructions
print_header "Installation Complete!"

print_success "LocalLLMChat has been installed successfully on your Chromebook!"
echo

print_info "Chromebook Performance Tips:"
echo "  • Close unnecessary tabs and apps while running"
echo "  • Use smaller models (1B-3B parameters)"
echo "  • Lower the temperature for faster responses"
echo "  • Be patient - first responses may be slower"
echo

print_info "To start using LocalLLMChat:"
echo

if [ "$VENV_ACTIVATED" = true ]; then
    echo -e "${GREEN}1. Activate the virtual environment:${NC}"
    echo "   source venv/bin/activate"
    echo
    echo -e "${GREEN}2. Start the application:${NC}"
    echo "   local-llm-chat"
else
    echo -e "${GREEN}1. Start the application:${NC}"
    echo "   local-llm-chat"
    echo
    echo -e "${YELLOW}   Note: If 'local-llm-chat' is not found, restart your terminal or run:${NC}"
    echo "   source ~/.bashrc"
fi

echo
echo -e "${GREEN}3. Open Chrome browser to:${NC}"
echo "   http://localhost:5000"
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
        echo "   Model: (download with: ollama pull llama3.2:1b)"
    fi
else
    print_warning "Ollama not installed."
    echo "   You can install it later with:"
    echo "   curl -fsSL https://ollama.com/install.sh | sh"
fi

echo
print_warning "Note: If Ollama service stops, restart it with:"
echo "   ollama serve > /dev/null 2>&1 &"
echo

print_info "Recommended models for Chromebook:"
echo "   • llama3.2:1b (1GB) - Fastest, lowest resource usage"
echo "   • phi (1.6GB) - Good balance"
echo "   • llama3.2:3b (2GB) - Better quality"
echo "   • dolphin-mistral (4GB) - Best quality (if you have resources)"
echo

print_info "For detailed setup instructions, see SETUP.md"
print_info "For usage information, see README.md"
echo
print_success "Happy chatting on your Chromebook! 🎉"
