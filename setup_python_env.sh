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
    
    # Try standard installation
    log "Installing OpenHands..."
    pip install -e .
    
    log "OpenHands installed successfully"
}

# Main execution
log "Starting Python environment setup..."
setup_python_environment
install_openhands
log "Python environment setup completed successfully!"