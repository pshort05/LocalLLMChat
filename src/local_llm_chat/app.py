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

    def run(self, host="0.0.0.0", port=5000, debug=False):
        """Run the Flask application."""
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

    args = parser.parse_args()

    app = LocalLLMChat()
    app.run(host=args.host, port=args.port, debug=args.debug)


if __name__ == "__main__":
    main()
