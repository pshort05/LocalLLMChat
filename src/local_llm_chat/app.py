#!/usr/bin/env python3
"""
Local LLM Chat - Flask Web Application

A Flask web application that provides a chat interface for local LLM models.
Supports Ollama, LM Studio, and other OpenAI-compatible local endpoints.

Usage:
    local-llm-chat

Then navigate to http://localhost:5000 in your browser.
"""

import os
import json
import logging
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional

from flask import (
    Flask,
    render_template,
    request,
    jsonify,
    send_from_directory,
)
import requests

# Configure logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


class LocalLLMChat:
    """Flask web application for Local LLM Chat."""

    def __init__(self):
        """Initialize the Flask application."""
        # Get package directory (where this file is located)
        self.package_dir = os.path.dirname(os.path.abspath(__file__))

        # Templates are in the package directory
        template_folder = os.path.join(self.package_dir, "templates")

        self.app = Flask(__name__, template_folder=template_folder)
        self.app.secret_key = os.environ.get(
            "FLASK_SECRET_KEY", "dev-key-change-in-production"
        )

        # Configure upload settings
        self.app.config["MAX_CONTENT_LENGTH"] = 16 * 1024 * 1024  # 16MB max

        # Conversation storage directory
        self.storage_dir = Path.home() / ".local_llm_chat" / "conversations"
        self.storage_dir.mkdir(parents=True, exist_ok=True)

        self._setup_routes()

        logger.info("✓ Local LLM Chat initialized successfully")

    def _setup_routes(self):
        """Set up Flask routes."""

        @self.app.route("/")
        def index():
            """Render the main chat interface."""
            return render_template("chat.html")

        @self.app.route("/api/chat", methods=["POST"])
        def chat():
            """Handle chat requests to local LLM."""
            try:
                data = request.json
                messages = data.get("messages", [])
                temperature = data.get("temperature", 0.8)
                endpoint = data.get("endpoint", "http://localhost:11434")
                model = data.get("model", "")
                system_prompt = data.get("systemPrompt", "")

                if not model:
                    return jsonify({"error": "Model name is required"}), 400

                # Build the messages array
                api_messages = []

                # Add system prompt if provided
                if system_prompt:
                    api_messages.append({"role": "system", "content": system_prompt})

                # Add conversation history
                api_messages.extend(messages)

                # Make request to local LLM
                response = self._call_local_llm(
                    endpoint, model, api_messages, temperature
                )

                if response.get("error"):
                    return jsonify(response), 500

                return jsonify({"response": response.get("content", "")})

            except Exception as e:
                logger.error(f"Error in chat endpoint: {e}")
                return jsonify({"error": str(e)}), 500

        @self.app.route("/api/models", methods=["GET"])
        def get_models():
            """Get available models from local LLM endpoint."""
            try:
                endpoint = request.args.get("endpoint", "http://localhost:11434")
                models = self._get_available_models(endpoint)
                return jsonify({"models": models})
            except Exception as e:
                logger.error(f"Error fetching models: {e}")
                return jsonify({"error": str(e)}), 500

        @self.app.route("/api/save_conversation", methods=["POST"])
        def save_conversation():
            """Save conversation to file."""
            try:
                data = request.json
                messages = data.get("messages", [])

                if not messages:
                    return jsonify({"error": "No messages to save"}), 400

                # Generate filename
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                filename = f"conversation_{timestamp}.json"
                filepath = self.storage_dir / filename

                # Save to file
                with open(filepath, "w") as f:
                    json.dump(
                        {
                            "timestamp": datetime.now().isoformat(),
                            "messages": messages,
                        },
                        f,
                        indent=2,
                    )

                logger.info(f"Saved conversation to {filepath}")
                return jsonify(
                    {"success": True, "filename": filename, "path": str(filepath)}
                )

            except Exception as e:
                logger.error(f"Error saving conversation: {e}")
                return jsonify({"error": str(e)}), 500

        @self.app.route("/api/conversations", methods=["GET"])
        def list_conversations():
            """List saved conversations."""
            try:
                conversations = []
                for filepath in sorted(
                    self.storage_dir.glob("conversation_*.json"), reverse=True
                ):
                    try:
                        with open(filepath, "r") as f:
                            data = json.load(f)
                            conversations.append(
                                {
                                    "filename": filepath.name,
                                    "timestamp": data.get("timestamp"),
                                    "message_count": len(data.get("messages", [])),
                                }
                            )
                    except Exception as e:
                        logger.error(f"Error reading {filepath}: {e}")

                return jsonify({"conversations": conversations})

            except Exception as e:
                logger.error(f"Error listing conversations: {e}")
                return jsonify({"error": str(e)}), 500

        @self.app.route("/api/llm_status", methods=["GET"])
        def llm_status():
            """Check LLM service status and available models."""
            try:
                endpoint = request.args.get("endpoint", "http://localhost:11434")
                status_info = self._check_llm_status(endpoint)
                return jsonify(status_info)
            except Exception as e:
                logger.error(f"Error checking LLM status: {e}")
                return jsonify({"error": str(e)}), 500

        @self.app.route("/api/start_llm", methods=["POST"])
        def start_llm():
            """Start the local LLM service."""
            try:
                result = self._start_llm_service()
                return jsonify(result)
            except Exception as e:
                logger.error(f"Error starting LLM service: {e}")
                return jsonify({"error": str(e)}), 500

        @self.app.route("/api/shutdown", methods=["POST"])
        def shutdown_server():
            """Shutdown the Flask server."""
            try:
                logger.info("Server shutdown requested via web interface")

                # Use werkzeug's shutdown function if available
                func = request.environ.get("werkzeug.server.shutdown")
                if func is None:
                    # Alternative shutdown method for different WSGI servers
                    import threading
                    import time

                    def delayed_shutdown():
                        time.sleep(1)
                        import os

                        os._exit(0)

                    thread = threading.Thread(target=delayed_shutdown)
                    thread.daemon = True
                    thread.start()

                    return jsonify({"message": "Server shutting down..."}), 200
                else:
                    func()
                    return jsonify({"message": "Server shutting down..."}), 200

            except Exception as e:
                logger.error(f"Error during shutdown: {e}")
                return jsonify({"error": f"Shutdown failed: {str(e)}"}), 500

    def _call_local_llm(
        self,
        endpoint: str,
        model: str,
        messages: List[Dict],
        temperature: float,
    ) -> Dict:
        """
        Call local LLM endpoint (Ollama, LM Studio, etc).

        Args:
            endpoint: The base URL of the local LLM service
            model: Model name to use
            messages: List of message dictionaries
            temperature: Temperature parameter for generation

        Returns:
            Dictionary with response content or error
        """
        try:
            # Determine API type based on endpoint
            if "11434" in endpoint or "ollama" in endpoint.lower():
                # Ollama API
                api_url = f"{endpoint}/api/chat"
                payload = {
                    "model": model,
                    "messages": messages,
                    "stream": False,
                    "options": {"temperature": temperature},
                }
            else:
                # OpenAI-compatible API (LM Studio, etc)
                api_url = f"{endpoint}/v1/chat/completions"
                payload = {
                    "model": model,
                    "messages": messages,
                    "temperature": temperature,
                }

            logger.info(f"Calling {api_url} with model {model}")

            response = requests.post(
                api_url,
                json=payload,
                headers={"Content-Type": "application/json"},
                timeout=120,
            )

            if response.status_code != 200:
                error_msg = f"LLM API returned status {response.status_code}: {response.text}"
                logger.error(error_msg)
                return {"error": error_msg}

            response_data = response.json()

            # Extract content based on API type
            if "11434" in endpoint or "ollama" in endpoint.lower():
                # Ollama response format
                content = response_data.get("message", {}).get("content", "")
            else:
                # OpenAI-compatible response format
                content = (
                    response_data.get("choices", [{}])[0]
                    .get("message", {})
                    .get("content", "")
                )

            return {"content": content}

        except requests.exceptions.RequestException as e:
            error_msg = f"Error connecting to LLM endpoint: {str(e)}"
            logger.error(error_msg)
            return {"error": error_msg}
        except Exception as e:
            error_msg = f"Unexpected error: {str(e)}"
            logger.error(error_msg)
            return {"error": error_msg}

    def _get_available_models(self, endpoint: str) -> List[str]:
        """
        Get list of available models from local LLM endpoint.

        Args:
            endpoint: The base URL of the local LLM service

        Returns:
            List of model names
        """
        try:
            if "11434" in endpoint or "ollama" in endpoint.lower():
                # Ollama API
                api_url = f"{endpoint}/api/tags"
                response = requests.get(api_url, timeout=10)

                if response.status_code == 200:
                    data = response.json()
                    return [model["name"] for model in data.get("models", [])]
            else:
                # OpenAI-compatible API
                api_url = f"{endpoint}/v1/models"
                response = requests.get(api_url, timeout=10)

                if response.status_code == 200:
                    data = response.json()
                    return [model["id"] for model in data.get("data", [])]

            return []

        except Exception as e:
            logger.error(f"Error fetching models: {e}")
            return []

    def _check_llm_status(self, endpoint: str) -> Dict:
        """
        Check the status of the local LLM service.

        Args:
            endpoint: The base URL of the local LLM service

        Returns:
            Dictionary with status information
        """
        import subprocess
        import platform

        status_info = {
            "running": False,
            "installed": False,
            "endpoint": endpoint,
            "models": [],
            "active_model": None,
            "platform": platform.system(),
        }

        # Check if Ollama is installed
        try:
            if platform.system() == "Windows":
                # Check if ollama.exe exists
                result = subprocess.run(
                    ["where", "ollama"],
                    capture_output=True,
                    text=True,
                    timeout=5,
                )
                status_info["installed"] = result.returncode == 0
            else:
                # Linux/Mac - check if ollama command exists
                result = subprocess.run(
                    ["which", "ollama"],
                    capture_output=True,
                    text=True,
                    timeout=5,
                )
                status_info["installed"] = result.returncode == 0
        except Exception as e:
            logger.error(f"Error checking if Ollama is installed: {e}")

        # Check if service is running by trying to connect
        try:
            models = self._get_available_models(endpoint)
            if models:
                status_info["running"] = True
                status_info["models"] = models
                # First model is typically the active one
                if models:
                    status_info["active_model"] = models[0]
        except Exception as e:
            logger.debug(f"LLM service not responding: {e}")

        return status_info

    def _start_llm_service(self) -> Dict:
        """
        Start the local LLM service (Ollama).

        Returns:
            Dictionary with result information
        """
        import subprocess
        import platform

        system = platform.system()

        # Check if Ollama is installed first
        try:
            if system == "Windows":
                check_cmd = ["where", "ollama"]
            else:
                check_cmd = ["which", "ollama"]

            result = subprocess.run(
                check_cmd, capture_output=True, text=True, timeout=5
            )

            if result.returncode != 0:
                return {
                    "success": False,
                    "error": "Ollama is not installed",
                    "message": "Please install Ollama using the installation scripts with the local model option.",
                    "install_url": "https://ollama.com/download",
                }

        except Exception as e:
            return {
                "success": False,
                "error": f"Error checking Ollama installation: {str(e)}",
            }

        # Try to start the service
        try:
            if system == "Linux":
                # Try systemctl first
                try:
                    subprocess.run(
                        ["systemctl", "start", "ollama"],
                        capture_output=True,
                        timeout=10,
                        check=True,
                    )
                    return {
                        "success": True,
                        "message": "Ollama service started via systemctl",
                    }
                except subprocess.CalledProcessError:
                    # Fallback to running ollama serve in background
                    subprocess.Popen(
                        ["ollama", "serve"],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                    )
                    return {
                        "success": True,
                        "message": "Ollama started in background",
                    }

            elif system == "Darwin":  # macOS
                # Try brew services first
                try:
                    subprocess.run(
                        ["brew", "services", "start", "ollama"],
                        capture_output=True,
                        timeout=10,
                        check=True,
                    )
                    return {
                        "success": True,
                        "message": "Ollama service started via brew services",
                    }
                except (subprocess.CalledProcessError, FileNotFoundError):
                    # Fallback to running ollama serve
                    subprocess.Popen(
                        ["ollama", "serve"],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                    )
                    return {
                        "success": True,
                        "message": "Ollama started in background",
                    }

            elif system == "Windows":
                # On Windows, Ollama runs as a service
                # Try to start the service
                try:
                    subprocess.run(
                        ["net", "start", "Ollama"],
                        capture_output=True,
                        timeout=10,
                        check=True,
                    )
                    return {
                        "success": True,
                        "message": "Ollama service started",
                    }
                except subprocess.CalledProcessError:
                    # Service might already be running or need manual start
                    return {
                        "success": False,
                        "error": "Could not start Ollama service",
                        "message": "Please start Ollama from the Start Menu or try running 'ollama serve' manually",
                    }

            else:
                return {
                    "success": False,
                    "error": f"Unsupported platform: {system}",
                }

        except Exception as e:
            logger.error(f"Error starting LLM service: {e}")
            return {
                "success": False,
                "error": str(e),
                "message": "Try running 'ollama serve' manually in a terminal",
            }

    def run(self, host="0.0.0.0", port=5000, debug=False, foreground=False):
        """Run the Flask application."""
        import socket
        import subprocess
        import sys

        # Get local IP address
        def get_local_ip():
            """Get the local IP address for network access."""
            try:
                s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                s.connect(("8.8.8.8", 80))
                local_ip = s.getsockname()[0]
                s.close()
                return local_ip
            except Exception:
                return "localhost"

        local_ip = get_local_ip()

        print(f"🚀 Starting Local LLM Chat...")
        print(f"📊 Mode: {'Development' if debug else 'Production'}")
        print(f"🌐 Server listening on all network interfaces (0.0.0.0:{port})")
        print(f"")
        print(f"📱 Access URLs:")
        print(f"   • This device:      http://127.0.0.1:{port}")
        print(f"   • Local network:    http://{local_ip}:{port}")
        print(f"")
        print(f"💡 To access from other devices on your network:")
        print(f"   1. Open a web browser on any device")
        print(f"   2. Navigate to: http://{local_ip}:{port}")
        print(f"   3. If connection fails, check firewall settings")
        print(f"")
        print(f"💾 Conversations will be saved to: {self.storage_dir}")
        print(f"")

        if not debug and not foreground:
            print("🔧 Running in background mode...")
            print("   • Web server will continue running after terminal closes")
            print("   • To stop: Use the 'Shutdown Server' button in the web interface")
            print("   • Logs will be written to local_llm_chat.log")
            print(f"")

            # Run in background using nohup (Unix-like systems)
            try:
                import platform

                if platform.system() == "Windows":
                    # Windows: use pythonw to run in background
                    print("⚠️  Background mode not fully supported on Windows")
                    print("   Running in foreground mode instead...")
                    print("   Press Ctrl+C to stop the server")
                    print("=" * 50)
                    self.app.run(host=host, port=port, debug=debug)
                else:
                    # Unix-like systems: use nohup
                    cmd = [
                        sys.executable,
                        "-c",
                        f"from local_llm_chat.app import LocalLLMChat; "
                        f"app = LocalLLMChat(); "
                        f"app.app.run(host='{host}', port={port}, debug={debug})",
                    ]

                    # Start the process in background
                    with open("local_llm_chat.log", "w") as log_file:
                        process = subprocess.Popen(
                            ["nohup"] + cmd,
                            stdout=log_file,
                            stderr=subprocess.STDOUT,
                            preexec_fn=os.setsid,
                        )

                    # Give it a moment to start
                    import time

                    time.sleep(2)

                    print(f"✅ Web server started successfully!")
                    print(f"📝 Process ID: {process.pid}")
                    print(f"📄 Logs: local_llm_chat.log")
                    print(f"")
                    print("🌐 Open your browser and navigate to:")
                    print(f"   http://{local_ip}:{port}")

                    return

            except Exception as e:
                print(f"❌ Failed to start in background mode: {e}")
                print("🔄 Falling back to foreground mode...")

        print("Press Ctrl+C to stop the server")
        print("=" * 50)
        logger.info(f"Starting Local LLM Chat on http://{host}:{port}")
        logger.info(f"Conversations will be saved to: {self.storage_dir}")
        self.app.run(host=host, port=port, debug=debug)


def main():
    """Main entry point for the application."""
    import argparse

    parser = argparse.ArgumentParser(description="Local LLM Chat Interface")
    parser.add_argument(
        "--host", default="0.0.0.0", help="Host to bind to (default: 0.0.0.0)"
    )
    parser.add_argument(
        "--port", type=int, default=5000, help="Port to bind to (default: 5000)"
    )
    parser.add_argument(
        "--debug", action="store_true", help="Run in debug mode"
    )
    parser.add_argument(
        "--foreground",
        action="store_true",
        help="Run in foreground mode (default: background in production)",
    )

    args = parser.parse_args()

    app = LocalLLMChat()
    app.run(host=args.host, port=args.port, debug=args.debug, foreground=args.foreground)


if __name__ == "__main__":
    main()
