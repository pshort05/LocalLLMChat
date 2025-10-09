################################################################################
# LocalLLMChat Installation Script for Windows (PowerShell)
#
# This script will:
# 1. Check for Python 3.8+
# 2. Install Ollama (optional)
# 3. Download dolphin-mistral model (optional)
# 4. Install LocalLLMChat and dependencies
# 5. Provide instructions to run the application
#
# Usage:
#   Right-click and "Run with PowerShell"
#   Or: powershell -ExecutionPolicy Bypass -File install-windows.ps1
################################################################################

# Requires PowerShell 5.0 or higher
#Requires -Version 5.0

# Function definitions
function Write-Header {
    param([string]$Message)
    Write-Host "`n========================================" -ForegroundColor Blue
    Write-Host $Message -ForegroundColor Blue
    Write-Host "========================================`n" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Write-Warning-Custom {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor Cyan
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Main script
Write-Header "LocalLLMChat Installation Script for Windows"

# Check if running as administrator
if (Test-Administrator) {
    Write-Warning-Custom "Running as Administrator"
    Write-Info "This is fine, but not required for this installation"
}

# Step 1: Check Python version
Write-Info "Checking Python installation..."

$pythonCmd = $null
$pythonVersion = $null

# Try to find Python
foreach ($cmd in @("python", "python3", "py")) {
    try {
        $version = & $cmd --version 2>&1
        if ($version -match "Python (\d+)\.(\d+)\.(\d+)") {
            $major = [int]$matches[1]
            $minor = [int]$matches[2]

            if ($major -ge 3 -and $minor -ge 8) {
                $pythonCmd = $cmd
                $pythonVersion = $version
                break
            }
        }
    }
    catch {
        # Command not found, continue
    }
}

if ($pythonCmd) {
    Write-Success "$pythonVersion found"
}
else {
    Write-ErrorMsg "Python 3.8+ not found"
    Write-Info "Please install Python 3.8 or higher from:"
    Write-Host "  https://www.python.org/downloads/" -ForegroundColor Yellow
    Write-Info "Make sure to check 'Add Python to PATH' during installation"

    $response = Read-Host "Would you like to open the Python download page? (y/n)"
    if ($response -eq 'y' -or $response -eq 'Y') {
        Start-Process "https://www.python.org/downloads/"
    }

    exit 1
}

# Check for pip
Write-Info "Checking for pip..."
try {
    $pipVersion = & $pythonCmd -m pip --version 2>&1
    Write-Success "pip found"
}
catch {
    Write-ErrorMsg "pip not found"
    Write-Info "Installing pip..."
    & $pythonCmd -m ensurepip --upgrade

    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "Failed to install pip"
        exit 1
    }
    Write-Success "pip installed"
}

# Step 2: Install Ollama (optional)
Write-Header "Ollama Installation"

$ollamaInstalled = $false
$ollamaPath = "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe"

# Check if Ollama is already installed
if (Test-Path $ollamaPath) {
    Write-Success "Ollama is already installed"
    try {
        $ollamaVersion = & $ollamaPath --version 2>&1
        Write-Info "Version: $ollamaVersion"
        $ollamaInstalled = $true
    }
    catch {
        Write-Warning-Custom "Ollama executable found but may not be working"
    }
}
elseif (Get-Command ollama -ErrorAction SilentlyContinue) {
    Write-Success "Ollama is already installed"
    $ollamaVersion = ollama --version 2>&1
    Write-Info "Version: $ollamaVersion"
    $ollamaInstalled = $true
}

if (-not $ollamaInstalled) {
    Write-Warning-Custom "Ollama is not installed."
    $response = Read-Host "Would you like to download and install Ollama? (y/n)"

    if ($response -eq 'y' -or $response -eq 'Y') {
        Write-Info "Downloading Ollama installer..."

        $installerPath = "$env:TEMP\OllamaSetup.exe"
        $ollamaUrl = "https://ollama.com/download/OllamaSetup.exe"

        try {
            # Download with progress
            Write-Info "This may take a few minutes..."
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $ollamaUrl -OutFile $installerPath -UseBasicParsing
            $ProgressPreference = 'Continue'

            Write-Success "Download complete"
            Write-Info "Running Ollama installer..."
            Write-Info "Please follow the installation wizard"

            # Run installer
            Start-Process -FilePath $installerPath -Wait

            # Check if installation was successful
            if (Test-Path $ollamaPath) {
                Write-Success "Ollama installed successfully"
                $ollamaInstalled = $true

                # Give Ollama service time to start
                Write-Info "Waiting for Ollama service to start..."
                Start-Sleep -Seconds 5
            }
            else {
                Write-Warning-Custom "Ollama installation may have failed"
                Write-Info "Please try installing manually from https://ollama.com/download"
            }

            # Clean up installer
            Remove-Item $installerPath -ErrorAction SilentlyContinue
        }
        catch {
            Write-ErrorMsg "Failed to download or install Ollama: $_"
            Write-Info "You can install it manually from https://ollama.com/download"
        }
    }
    else {
        Write-Info "Skipping Ollama installation"
        Write-Warning-Custom "You'll need to install a local LLM service manually"
    }
}

# Step 3: Download dolphin-mistral model (optional)
if ($ollamaInstalled) {
    Write-Header "Model Installation"

    # Determine ollama command
    $ollamaCmd = if (Test-Path $ollamaPath) { $ollamaPath } else { "ollama" }

    # Check if dolphin-mistral is already installed
    try {
        $models = & $ollamaCmd list 2>&1
        $hasDolphin = $models -match "dolphin-mistral"

        if ($hasDolphin) {
            Write-Success "dolphin-mistral model is already installed"
        }
        else {
            Write-Warning-Custom "The dolphin-mistral model is not installed."
            Write-Info "This model is recommended for uncensored responses"
            Write-Warning-Custom "Download size: ~4GB, this may take several minutes"
            $response = Read-Host "Would you like to download dolphin-mistral? (y/n)"

            if ($response -eq 'y' -or $response -eq 'Y') {
                Write-Info "Downloading dolphin-mistral model..."
                Write-Info "This may take 5-10 minutes depending on your connection..."
                Write-Info "Please be patient, the download is happening..."

                & $ollamaCmd pull dolphin-mistral

                if ($LASTEXITCODE -eq 0) {
                    Write-Success "dolphin-mistral model downloaded successfully"
                }
                else {
                    Write-ErrorMsg "Model download failed"
                    Write-Info "You can download it later with: ollama pull dolphin-mistral"
                }
            }
            else {
                Write-Info "Skipping model download"
                Write-Info "You can download models later with: ollama pull <model-name>"
                Write-Info "Popular models: llama3.2, mistral, codellama"
            }
        }

        # Show available models
        Write-Info "Currently installed models:"
        & $ollamaCmd list
    }
    catch {
        Write-Warning-Custom "Could not check installed models"
        Write-Info "You can check later with: ollama list"
    }
}

# Step 4: Install LocalLLMChat
Write-Header "LocalLLMChat Installation"

# Check if we're in the right directory
if (-not (Test-Path "pyproject.toml")) {
    Write-ErrorMsg "pyproject.toml not found"
    Write-ErrorMsg "Please run this script from the LocalLLMChat directory"
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Info "Installing LocalLLMChat dependencies..."

# Ask about virtual environment
$response = Read-Host "Would you like to install in a virtual environment? (recommended) (y/n)"

$venvActivated = $false

if ($response -eq 'y' -or $response -eq 'Y') {
    Write-Info "Creating virtual environment..."
    & $pythonCmd -m venv venv

    if ($LASTEXITCODE -eq 0) {
        Write-Success "Virtual environment created"

        # Activate virtual environment
        $activateScript = "venv\Scripts\Activate.ps1"
        if (Test-Path $activateScript) {
            Write-Info "Activating virtual environment..."
            & $activateScript
            $venvActivated = $true
            Write-Success "Virtual environment activated"
        }

        Write-Info "Installing LocalLLMChat..."
        & python -m pip install --upgrade pip
        & python -m pip install -e .
    }
    else {
        Write-ErrorMsg "Failed to create virtual environment"
        Write-Info "Installing globally instead..."
        & $pythonCmd -m pip install --user -e .
    }
}
else {
    Write-Info "Installing LocalLLMChat globally..."
    & $pythonCmd -m pip install --user -e .
}

if ($LASTEXITCODE -eq 0) {
    Write-Success "LocalLLMChat installed successfully"
}
else {
    Write-ErrorMsg "Installation failed"
    Read-Host "Press Enter to exit"
    exit 1
}

# Step 5: Final instructions
Write-Header "Installation Complete!"

Write-Success "LocalLLMChat has been installed successfully!"
Write-Host ""

Write-Info "To start using LocalLLMChat:"
Write-Host ""

if ($venvActivated) {
    Write-Host "1. Activate the virtual environment:" -ForegroundColor Green
    Write-Host "   venv\Scripts\Activate.ps1" -ForegroundColor White
    Write-Host "   (Or in CMD: venv\Scripts\activate.bat)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Start the application:" -ForegroundColor Green
    Write-Host "   local-llm-chat" -ForegroundColor White
}
else {
    Write-Host "1. Start the application:" -ForegroundColor Green
    Write-Host "   local-llm-chat" -ForegroundColor White
    Write-Host ""
    Write-Host "   Note: If 'local-llm-chat' is not found, try:" -ForegroundColor Yellow
    Write-Host "   python -m local_llm_chat.app" -ForegroundColor White
}

Write-Host ""
Write-Host "3. Open your browser to:" -ForegroundColor Green
Write-Host "   http://localhost:5000" -ForegroundColor White
Write-Host ""

if ($ollamaInstalled) {
    Write-Info "Ollama Configuration:"
    Write-Host "   Endpoint: http://localhost:11434"

    # Check if dolphin-mistral is available
    try {
        $ollamaCmd = if (Test-Path $ollamaPath) { $ollamaPath } else { "ollama" }
        $models = & $ollamaCmd list 2>&1
        if ($models -match "dolphin-mistral") {
            Write-Host "   Model: dolphin-mistral"
        }
        else {
            Write-Host "   Model: (download with: ollama pull dolphin-mistral)"
        }
    }
    catch {
        Write-Host "   Model: (download with: ollama pull dolphin-mistral)"
    }
}
else {
    Write-Warning-Custom "Ollama not installed. You'll need to:"
    Write-Host "   - Download and install Ollama from https://ollama.com/download"
    Write-Host "   - Run: ollama pull dolphin-mistral"
    Write-Host "   - Or install LM Studio from https://lmstudio.ai"
}

Write-Host ""
Write-Info "For detailed setup instructions, see SETUP.md"
Write-Info "For usage information, see README.md"
Write-Host ""
Write-Success "Happy chatting! 🎉"
Write-Host ""

Read-Host "Press Enter to exit"
