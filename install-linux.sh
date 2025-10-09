#!/bin/bash
################################################################################
# LocalLLMChat Installation Script for Linux
#
# This script will:
# 1. Check for Python 3.8+
# 2. Install Ollama (optional)
# 3. Download dolphin-mistral model (optional)
# 4. Install LocalLLMChat and dependencies
# 5. Provide instructions to run the application
#
# Usage: ./install-linux.sh
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

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run this script as root (without sudo)"
    print_info "The script will ask for sudo password when needed"
    exit 1
fi

print_header "LocalLLMChat Installation Script for Linux"

# Step 1: Check Python version
print_info "Checking Python installation..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d'.' -f1)
    PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d'.' -f2)

    if [ "$PYTHON_MAJOR" -ge 3 ] && [ "$PYTHON_MINOR" -ge 8 ]; then
        print_success "Python $PYTHON_VERSION found"
    else
        print_error "Python 3.8+ is required (found $PYTHON_VERSION)"
        print_info "Please install Python 3.8 or higher:"
        echo "  Ubuntu/Debian: sudo apt install python3 python3-pip"
        echo "  Fedora: sudo dnf install python3 python3-pip"
        echo "  Arch: sudo pacman -S python python-pip"
        exit 1
    fi
else
    print_error "Python 3 not found"
    print_info "Please install Python 3.8+:"
    echo "  Ubuntu/Debian: sudo apt install python3 python3-pip"
    echo "  Fedora: sudo dnf install python3 python3-pip"
    echo "  Arch: sudo pacman -S python python-pip"
    exit 1
fi

# Check for pip
if ! command -v pip3 &> /dev/null; then
    print_warning "pip3 not found, attempting to install..."
    if command -v apt &> /dev/null; then
        sudo apt update && sudo apt install -y python3-pip
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y python3-pip
    elif command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm python-pip
    else
        print_error "Could not install pip. Please install manually."
        exit 1
    fi
fi

print_success "pip3 found"

# Step 2: Install Ollama (optional)
print_header "Ollama Installation"
if command -v ollama &> /dev/null; then
    print_success "Ollama is already installed"
    OLLAMA_VERSION=$(ollama --version 2>&1 | head -n1)
    print_info "Version: $OLLAMA_VERSION"
else
    echo -e "${YELLOW}Ollama is not installed.${NC}"
    read -p "Would you like to install Ollama? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Installing Ollama..."
        curl -fsSL https://ollama.com/install.sh | sh

        if [ $? -eq 0 ]; then
            print_success "Ollama installed successfully"

            # Start Ollama service
            if command -v systemctl &> /dev/null; then
                print_info "Starting Ollama service..."
                sudo systemctl enable ollama
                sudo systemctl start ollama
                print_success "Ollama service started"
            fi
        else
            print_error "Ollama installation failed"
            print_info "You can install it manually later from https://ollama.com"
        fi
    else
        print_info "Skipping Ollama installation"
        print_warning "You'll need to install a local LLM service manually"
    fi
fi

# Step 3: Download dolphin-mistral model (optional)
if command -v ollama &> /dev/null; then
    print_header "Model Installation"

    # Check if dolphin-mistral is already installed
    if ollama list 2>/dev/null | grep -q "dolphin-mistral"; then
        print_success "dolphin-mistral model is already installed"
    else
        echo -e "${YELLOW}The dolphin-mistral model is not installed.${NC}"
        print_info "This model is recommended for uncensored responses"
        print_warning "Download size: ~4GB, this may take several minutes"
        read -p "Would you like to download dolphin-mistral? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Downloading dolphin-mistral model..."
            print_info "This may take 5-10 minutes depending on your connection..."
            ollama pull dolphin-mistral

            if [ $? -eq 0 ]; then
                print_success "dolphin-mistral model downloaded successfully"
            else
                print_error "Model download failed"
                print_info "You can download it later with: ollama pull dolphin-mistral"
            fi
        else
            print_info "Skipping model download"
            print_info "You can download models later with: ollama pull <model-name>"
            print_info "Popular models: llama3.2, mistral, codellama"
        fi
    fi

    # Show available models
    print_info "Currently installed models:"
    ollama list 2>/dev/null || print_warning "No models installed yet"
fi

# Step 4: Install LocalLLMChat
print_header "LocalLLMChat Installation"

# Check if we're in the right directory
if [ ! -f "pyproject.toml" ]; then
    print_error "pyproject.toml not found"
    print_error "Please run this script from the LocalLLMChat directory"
    exit 1
fi

print_info "Installing LocalLLMChat dependencies..."

# Check if system has externally-managed environment (PEP 668)
EXTERNALLY_MANAGED=false
if [ -f "/usr/lib/python3.*/EXTERNALLY-MANAGED" ] || python3 -m pip install --dry-run 2>&1 | grep -q "externally-managed-environment"; then
    EXTERNALLY_MANAGED=true
    print_warning "Detected externally-managed Python environment (PEP 668)"
    print_info "This prevents global pip installs to protect system packages"
fi

echo
print_info "Choose installation method:"
echo "  1) Virtual environment (recommended - isolated, no conflicts)"
echo "  2) pipx (installs as standalone application)"
if [ "$EXTERNALLY_MANAGED" = false ]; then
    echo "  3) User install (global, may conflict with system packages)"
fi
echo
read -p "Enter choice (1-$([ "$EXTERNALLY_MANAGED" = false ] && echo "3" || echo "2")): " -n 1 -r
echo

VENV_ACTIVATED=false

case $REPLY in
    1)
        # Virtual environment installation
        print_info "Creating virtual environment..."
        python3 -m venv venv

        if [ $? -ne 0 ]; then
            print_error "Failed to create virtual environment"
            print_info "You may need to install python3-venv:"
            echo "  sudo apt install python3-venv"
            exit 1
        fi

        source venv/bin/activate
        print_success "Virtual environment created and activated"

        print_info "Installing LocalLLMChat..."
        pip install --upgrade pip
        pip install -e .

        VENV_ACTIVATED=true
        ;;

    2)
        # pipx installation
        print_info "Installing with pipx..."

        # Check if pipx is installed
        if ! command -v pipx &> /dev/null; then
            print_warning "pipx not found, installing..."

            # Try to install pipx
            if command -v apt &> /dev/null; then
                sudo apt update && sudo apt install -y pipx
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y pipx
            elif command -v pacman &> /dev/null; then
                sudo pacman -S --noconfirm python-pipx
            else
                print_error "Could not install pipx automatically"
                print_info "Please install pipx manually:"
                echo "  Ubuntu/Debian: sudo apt install pipx"
                echo "  Fedora: sudo dnf install pipx"
                echo "  Arch: sudo pacman -S python-pipx"
                exit 1
            fi

            # Ensure pipx path is set up
            pipx ensurepath
        fi

        print_success "pipx found"
        print_info "Installing LocalLLMChat as standalone application..."

        pipx install -e .

        if [ $? -eq 0 ]; then
            print_success "LocalLLMChat installed with pipx"

            # Make sure pipx bin directory is in PATH
            PIPX_BIN="$HOME/.local/bin"
            if [[ ":$PATH:" != *":$PIPX_BIN:"* ]]; then
                print_warning "Adding $PIPX_BIN to PATH"
                echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
                export PATH="$HOME/.local/bin:$PATH"
            fi
        else
            print_error "pipx installation failed"
            print_info "Falling back to virtual environment..."
            python3 -m venv venv
            source venv/bin/activate
            pip install --upgrade pip
            pip install -e .
            VENV_ACTIVATED=true
        fi
        ;;

    3)
        # User installation (only if not externally managed)
        if [ "$EXTERNALLY_MANAGED" = true ]; then
            print_error "Invalid choice"
            exit 1
        fi

        print_info "Installing to user directory..."
        pip3 install --user -e .

        if [ $? -ne 0 ]; then
            print_error "User installation failed"
            print_warning "Your system may require a virtual environment"
            read -p "Create virtual environment now? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                python3 -m venv venv
                source venv/bin/activate
                pip install --upgrade pip
                pip install -e .
                VENV_ACTIVATED=true
            else
                exit 1
            fi
        else
            # Add user bin to PATH if not already there
            USER_BIN="$HOME/.local/bin"
            if [[ ":$PATH:" != *":$USER_BIN:"* ]]; then
                print_warning "Adding $USER_BIN to PATH"
                echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
                export PATH="$HOME/.local/bin:$PATH"
            fi
        fi
        ;;

    *)
        print_error "Invalid choice"
        print_info "Defaulting to virtual environment..."
        python3 -m venv venv
        source venv/bin/activate
        pip install --upgrade pip
        pip install -e .
        VENV_ACTIVATED=true
        ;;
esac

# Verify installation
if [ $? -eq 0 ]; then
    print_success "LocalLLMChat installed successfully"
else
    print_error "Installation failed"
    exit 1
fi

# Step 5: Final instructions
print_header "Installation Complete!"

print_success "LocalLLMChat has been installed successfully!"
echo

print_info "To start using LocalLLMChat:"
echo

if [ "$VENV_ACTIVATED" = true ]; then
    echo -e "${GREEN}1. Activate the virtual environment:${NC}"
    echo "   source venv/bin/activate"
    echo
    echo -e "${GREEN}2. Start the application:${NC}"
    echo "   local-llm-chat"
    echo
    echo -e "${YELLOW}   Note: Run step 1 each time you open a new terminal${NC}"
elif [ "$REPLY" = "2" ]; then
    echo -e "${GREEN}1. Start the application (installed via pipx):${NC}"
    echo "   local-llm-chat"
    echo
    echo -e "${YELLOW}   Note: If 'local-llm-chat' is not found, restart your terminal or run:${NC}"
    echo "   source ~/.bashrc"
else
    echo -e "${GREEN}1. Start the application:${NC}"
    echo "   local-llm-chat"
    echo
    echo -e "${YELLOW}   Note: If 'local-llm-chat' is not found, restart your terminal or run:${NC}"
    echo "   source ~/.bashrc"
fi

echo
echo -e "${GREEN}$([ "$VENV_ACTIVATED" = true ] && echo "3" || echo "2"). Open your browser to:${NC}"
echo "   http://localhost:5000"
echo

if command -v ollama &> /dev/null; then
    print_info "Ollama Configuration:"
    echo "   Endpoint: http://localhost:11434"
    if ollama list 2>/dev/null | grep -q "dolphin-mistral"; then
        echo "   Model: dolphin-mistral"
    else
        echo "   Model: (download with: ollama pull dolphin-mistral)"
    fi
else
    print_warning "Ollama not installed. You'll need to:"
    echo "   - Install Ollama: curl -fsSL https://ollama.com/install.sh | sh"
    echo "   - Download a model: ollama pull dolphin-mistral"
    echo "   - Or install LM Studio from https://lmstudio.ai"
fi

echo
print_info "For detailed setup instructions, see SETUP.md"
print_info "For usage information, see README.md"
echo
print_success "Happy chatting! 🎉"
