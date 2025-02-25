#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_DIR="${SCRIPT_DIR}/config"
API_KEY=$(cat "${CONFIG_DIR}/api_key.txt")

# Activate virtual environment
source "${SCRIPT_DIR}/venv/bin/activate"

# Export API key
export OPENHANDS_API_KEY="${API_KEY}"

# Start OpenHands server
cd "${SCRIPT_DIR}/OpenHands"
python -m openhands.server.start --config "${CONFIG_DIR}/config.toml"