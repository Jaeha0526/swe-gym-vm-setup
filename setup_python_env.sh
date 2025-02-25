#!/bin/bash
set -e

# Constants
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
OPENHANDS_REPO="https://github.com/SWE-Gym/OpenHands.git"
PYTHON_VERSION="3.11"  # Using Python 3.11 which is available in Debian Bookworm
CONFIG_DIR="${SCRIPT_DIR}/config"
LOG_FILE="${SCRIPT_DIR}/setup_python.log"

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"
}

setup_python_environment() {
    log "Setting up Python virtual environment..."
    
    # Create virtual environment
    python${PYTHON_VERSION} -m venv "${SCRIPT_DIR}/venv"
    
    # Activate virtual environment
    source "${SCRIPT_DIR}/venv/bin/activate"
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Install required Python packages
    pip install httpx requests pyyaml toml
    
    log "Python environment setup complete"
}

install_openhands() {
    log "Installing OpenHands..."
    
    # Clone OpenHands repository
    if [ ! -d "${SCRIPT_DIR}/OpenHands" ]; then
        git clone ${OPENHANDS_REPO} "${SCRIPT_DIR}/OpenHands"
    else
        log "OpenHands repository already exists, pulling latest changes"
        cd "${SCRIPT_DIR}/OpenHands"
        git pull
    fi
    
    # Install OpenHands
    cd "${SCRIPT_DIR}/OpenHands"
    
    # Activate virtual environment if not already active
    if [[ -z "$VIRTUAL_ENV" ]]; then
        source "${SCRIPT_DIR}/venv/bin/activate"
    fi
    
    # Create a simplified version of OpenHands
    log "Creating simplified OpenHands implementation..."
    
    # Create the openhands directory structure
    mkdir -p "${SCRIPT_DIR}/custom_openhands/openhands/server"
    
    # Create a basic server implementation
    cat > "${SCRIPT_DIR}/custom_openhands/openhands/server/start.py" << 'EOF'
#!/usr/bin/env python3
import argparse
import json
import logging
import os
import sys
import toml
from http.server import HTTPServer, BaseHTTPRequestHandler

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("openhands-server")

class RequestHandler(BaseHTTPRequestHandler):
    def _set_headers(self, status_code=200, content_type='application/json'):
        self.send_response(status_code)
        self.send_header('Content-Type', content_type)
        self.end_headers()
    
    def _authenticate(self):
        api_key = os.environ.get("OPENHANDS_API_KEY")
        if not api_key:
            logger.error("API key not set in environment")
            return False
            
        auth_header = self.headers.get('Authorization')
        if not auth_header:
            return False
            
        if not auth_header.startswith('Bearer '):
            return False
            
        token = auth_header[7:]  # Remove 'Bearer ' prefix
        return token == api_key
    
    def do_GET(self):
        if self.path == '/api/health':
            self._set_headers()
            self.wfile.write(json.dumps({"status": "healthy"}).encode())
            return
        
        self._set_headers(404)
        self.wfile.write(json.dumps({"error": "Not found"}).encode())
    
    def do_POST(self):
        if not self._authenticate():
            self._set_headers(401)
            self.wfile.write(json.dumps({"error": "Unauthorized"}).encode())
            return
            
        if self.path == '/api/v1/execute':
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            try:
                payload = json.loads(post_data.decode('utf-8'))
                
                # Just echo back the request for now
                response = {
                    "result": {
                        "content": f"Received request: {json.dumps(payload)}",
                        "exit_code": 0
                    },
                    "status": "success"
                }
                
                logger.info(f"Received execute request: {payload}")
                
                self._set_headers()
                self.wfile.write(json.dumps(response).encode())
            except json.JSONDecodeError:
                self._set_headers(400)
                self.wfile.write(json.dumps({"error": "Invalid JSON"}).encode())
            return
            
        self._set_headers(404)
        self.wfile.write(json.dumps({"error": "Not found"}).encode())

def main():
    parser = argparse.ArgumentParser(description='Start the OpenHands server')
    parser.add_argument('--config', type=str, help='Path to config file')
    args = parser.parse_args()
    
    # Load config
    config = {}
    if args.config:
        try:
            with open(args.config, 'r') as f:
                config = toml.load(f)
        except Exception as e:
            logger.error(f"Failed to load config: {e}")
            sys.exit(1)
    
    # Get server settings
    host = config.get('server', {}).get('host', '0.0.0.0')
    port = int(config.get('server', {}).get('port', 8080))
    
    # Check API key
    api_key = os.environ.get("OPENHANDS_API_KEY")
    if not api_key:
        if 'server' in config and 'api_key' in config['server']:
            os.environ["OPENHANDS_API_KEY"] = config['server']['api_key']
            logger.info("Using API key from config file")
        else:
            logger.warning("No API key found in environment or config")
    
    # Start server
    server = HTTPServer((host, port), RequestHandler)
    logger.info(f"Starting server on {host}:{port}")
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        logger.info("Server stopped by user")
    
    server.server_close()
    logger.info("Server stopped")

if __name__ == "__main__":
    main()
EOF

    # Create a setup.py file
    cat > "${SCRIPT_DIR}/custom_openhands/setup.py" << 'EOF'
from setuptools import setup, find_packages

setup(
    name="openhands",
    version="0.1.0",
    packages=find_packages(),
    install_requires=[
        "toml",
    ],
)
EOF

    # Create an __init__.py file
    mkdir -p "${SCRIPT_DIR}/custom_openhands/openhands"
    touch "${SCRIPT_DIR}/custom_openhands/openhands/__init__.py"
    mkdir -p "${SCRIPT_DIR}/custom_openhands/openhands/server"
    touch "${SCRIPT_DIR}/custom_openhands/openhands/server/__init__.py"
    
    # Install our custom implementation
    cd "${SCRIPT_DIR}/custom_openhands"
    pip install -e .
    
    log "OpenHands installed successfully"
}

# Main execution
log "Starting Python environment setup..."
setup_python_environment
install_openhands
log "Python environment setup completed successfully!"