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
    Write-Info "Ollama is required for LocalLLMChat to function"
    Write-Info "Installing Ollama automatically..."
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
            Write-ErrorMsg "LocalLLMChat requires Ollama to function"
            Write-Info "Please install manually from https://ollama.com/download and run this script again"
            Read-Host "Press Enter to exit"
            exit 1
        }
}

# Step 3: Download dolphin-mistral model (automatic)
if ($ollamaInstalled) {
    Write-Header "Model Installation"

    # Determine ollama command
    $ollamaCmd = if (Test-Path $ollamaPath) { $ollamaPath } else { "ollama" }

    # Wait for Ollama service to be fully ready
    Write-Info "Ensuring Ollama service is ready..."
    Start-Sleep -Seconds 3

    # Check if any models are installed
    try {
        $models = & $ollamaCmd list 2>&1
        $modelsList = $models | Out-String
        $hasAnyModel = ($modelsList -match "\S") -and (-not ($modelsList -match "^NAME"))
        $hasDolphin = $modelsList -match "dolphin-mistral"

        if ($hasDolphin) {
            Write-Success "dolphin-mistral model is already installed"
        }
        elseif ($hasAnyModel) {
            Write-Success "Found existing models installed"
            Write-Info "dolphin-mistral is recommended but you have other models available"
            $response = Read-Host "Would you like to also install dolphin-mistral? (y/n)"

            if ($response -eq 'y' -or $response -eq 'Y') {
                Write-Info "Downloading dolphin-mistral model..."
                Write-Warning-Custom "Download size: ~4GB, this may take 5-10 minutes"
                Write-Info "Please be patient, the download is happening..."

                & $ollamaCmd pull dolphin-mistral

                if ($LASTEXITCODE -eq 0) {
                    Write-Success "dolphin-mistral model downloaded successfully"
                }
                else {
                    Write-ErrorMsg "Model download failed"
                }
            }
        }
        else {
            Write-Warning-Custom "No models found. dolphin-mistral will be installed automatically"
            Write-Info "This model is recommended for uncensored responses"
            Write-Warning-Custom "Download size: ~4GB, this may take 5-10 minutes"
            Write-Info "Please be patient, the download is happening..."

            & $ollamaCmd pull dolphin-mistral

            if ($LASTEXITCODE -eq 0) {
                Write-Success "dolphin-mistral model downloaded successfully"
            }
            else {
                Write-ErrorMsg "Model download failed"
                Write-ErrorMsg "LocalLLMChat requires at least one model to function"
                Write-Info "You can download it manually later with: ollama pull dolphin-mistral"
                Read-Host "Press Enter to continue anyway"
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

# Step 5: Create Desktop Shortcut
Write-Header "Creating Desktop Shortcut"

$desktopPath = [Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path $desktopPath "LocalLLMChat.lnk"

try {
    $WScriptShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WScriptShell.CreateShortcut($shortcutPath)

    if ($venvActivated) {
        # Create batch file to activate venv and run
        $batchPath = Join-Path (Get-Location) "run-localllmchat.bat"
        $batchContent = @"
@echo off
cd /d "$((Get-Location).Path)"
call venv\Scripts\activate.bat
start /B local-llm-chat
timeout /t 2 /nobreak >nul
start http://localhost:5000
exit
"@
        Set-Content -Path $batchPath -Value $batchContent
        $Shortcut.TargetPath = $batchPath
    }
    else {
        # Create batch file for global install
        $batchPath = Join-Path (Get-Location) "run-localllmchat.bat"
        $batchContent = @"
@echo off
start /B local-llm-chat
timeout /t 2 /nobreak >nul
start http://localhost:5000
exit
"@
        Set-Content -Path $batchPath -Value $batchContent
        $Shortcut.TargetPath = $batchPath
    }

    $Shortcut.WorkingDirectory = (Get-Location).Path
    $Shortcut.Description = "LocalLLMChat - Chat with Local LLM Models"
    $Shortcut.Save()

    Write-Success "Desktop shortcut created: LocalLLMChat.lnk"
}
catch {
    Write-Warning-Custom "Could not create desktop shortcut: $_"
}

# Step 6: Start the application and launch browser
Write-Header "Launching LocalLLMChat"

Write-Info "Starting LocalLLMChat server..."
Write-Info "This will open in your browser automatically"
Write-Host ""

# Ensure Ollama is running
if ($ollamaInstalled) {
    try {
        $ollamaCmd = if (Test-Path $ollamaPath) { $ollamaPath } else { "ollama" }
        $null = & $ollamaCmd list 2>&1
    }
    catch {
        Write-Warning-Custom "Ollama service may not be running"
        Write-Info "Attempting to start Ollama..."
        try {
            Start-Process -FilePath "net" -ArgumentList "start", "Ollama" -Verb RunAs -WindowStyle Hidden -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 3
        }
        catch {
            Write-Warning-Custom "Could not start Ollama service automatically"
        }
    }
}

# Start LocalLLMChat in background
try {
    if ($venvActivated) {
        Write-Info "Starting from virtual environment..."
        Start-Process -FilePath "python" -ArgumentList "-m", "local_llm_chat.app", "--foreground" -WindowStyle Minimized
    }
    else {
        Write-Info "Starting LocalLLMChat..."
        Start-Process -FilePath "local-llm-chat" -ArgumentList "--foreground" -WindowStyle Minimized -ErrorAction Stop
    }

    # Wait for server to start
    Write-Info "Waiting for server to start..."
    Start-Sleep -Seconds 4

    # Open browser
    Write-Info "Opening browser..."
    Start-Process "http://localhost:5000"

    Write-Success "LocalLLMChat is now running!"
    Write-Host ""
    Write-Info "The application is running in the background"
    Write-Info "Your browser should open automatically"
    Write-Host ""
    Write-Info "To start LocalLLMChat in the future:"
    Write-Host "  • Double-click the 'LocalLLMChat' icon on your desktop"
    if ($venvActivated) {
        Write-Host "  • Or run: venv\Scripts\activate.bat && local-llm-chat" -ForegroundColor Gray
    }
    else {
        Write-Host "  • Or run: local-llm-chat" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Info "To stop the server: Use the 'Shutdown Server' button in the web interface"
}
catch {
    Write-Warning-Custom "Could not start LocalLLMChat automatically"
    Write-Info "You can start it manually with the desktop shortcut or:"
    if ($venvActivated) {
        Write-Host "   venv\Scripts\activate.bat && local-llm-chat"
    }
    else {
        Write-Host "   local-llm-chat"
    }
}

# Step 7: Final information
Write-Header "Installation Complete!"

Write-Success "LocalLLMChat has been installed successfully!"
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
            Write-Host "   Model: (first available model)"
        }
    }
    catch {
        Write-Host "   Model: (check Ollama)"
    }
}

Write-Host ""
Write-Info "For detailed setup instructions, see SETUP.md"
Write-Info "For usage information, see README.md"
Write-Host ""
Write-Success "Happy chatting! 🎉"
Write-Host ""

Read-Host "Press Enter to exit (LocalLLMChat will continue running)"
