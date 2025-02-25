#!/bin/bash
set -e

# Constants
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
OPENHANDS_REPO="https://github.com/SWE-Gym/OpenHands.git"
PYTHON_VERSION="3.11"  # Using Python 3.11 which is available in Debian Bookworm
CONFIG_DIR="${SCRIPT_DIR}/config"
LOG_FILE="${SCRIPT_DIR}/setup.log"

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"
}

check_requirements() {
    log "Checking system requirements..."
    
    # Check if running as root or with sudo
    if [[ $EUID -ne 0 ]]; then
        log "This script must be run as root or with sudo"
        exit 1
    fi
    
    # Check if OS is supported (Ubuntu or Debian)
    if ! grep -qiE 'debian|ubuntu' /etc/os-release; then
        log "This script is designed for Ubuntu or Debian. Your OS may not be fully supported."
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    log "System requirements check passed"
}

install_dependencies() {
    log "Installing system dependencies..."
    
    # Update package lists
    apt-get update
    
    # Install required packages
    apt-get install -y \
        git \
        curl \
        wget \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        software-properties-common \
        python${PYTHON_VERSION} \
        python${PYTHON_VERSION}-dev \
        python${PYTHON_VERSION}-venv \
        python3-pip
        
    # Verify python-venv is installed
    if ! dpkg -l | grep -q "python${PYTHON_VERSION}-venv"; then
        log "Installing python${PYTHON_VERSION}-venv separately"
        apt-get install -y python${PYTHON_VERSION}-venv
    fi
    
    log "System dependencies installed successfully"
}

install_docker() {
    log "Installing Docker..."
    
    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        log "Docker is already installed"
    else
        # Install Docker using the official script
        log "Downloading Docker installation script..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        log "Running Docker installation script..."
        sh get-docker.sh
        
        # Add current user to docker group
        log "Adding user to docker group..."
        usermod -aG docker $SUDO_USER
        
        log "Docker installation completed"
    fi
    
    # Make sure Docker service is running
    log "Ensuring Docker service is running..."
    if ! systemctl is-active --quiet docker; then
        log "Starting Docker service..."
        systemctl start docker
    fi
    
    log "Enabling Docker service to start on boot..."
    systemctl enable docker
    
    # Test Docker installation
    log "Testing Docker installation..."
    # Try up to 3 times with increasing delays
    for attempt in {1..3}; do
        log "Docker test attempt ${attempt}..."
        if docker run --rm hello-world 2>&1 | tee -a "${LOG_FILE}"; then
            log "Docker is working correctly"
            return 0
        else
            log "Docker test attempt ${attempt} failed, waiting before retry..."
            sleep $((attempt * 5))
        fi
    done
    
    log "WARNING: Docker test failed after 3 attempts. Continuing setup, but Docker may not be working correctly."
    log "You may need to run 'systemctl start docker' and check Docker's status manually after setup completes."
    
    # Continue anyway to avoid script termination
    return 0
}

setup_python_environment() {
    log "Setting up Python virtual environment..."
    
    # Check if Python venv module is available
    if ! python${PYTHON_VERSION} -m venv --help &>/dev/null; then
        log "ERROR: Python venv module is not available. Installing python${PYTHON_VERSION}-venv package..."
        apt-get install -y python${PYTHON_VERSION}-venv
    fi
    
    # Create virtual environment with verbose output
    log "Creating virtual environment at ${SCRIPT_DIR}/venv"
    python${PYTHON_VERSION} -m venv --clear "${SCRIPT_DIR}/venv"
    
    # Check if venv was created
    if [ ! -d "${SCRIPT_DIR}/venv" ]; then
        log "ERROR: Failed to create virtual environment"
        exit 1
    fi
    
    if [ ! -f "${SCRIPT_DIR}/venv/bin/activate" ]; then
        log "ERROR: Virtual environment created but activate script is missing"
        exit 1
    fi
    
    log "Virtual environment created successfully"
    
    # Activate virtual environment
    log "Activating virtual environment"
    source "${SCRIPT_DIR}/venv/bin/activate"
    
    # Verify activation
    if [[ -z "$VIRTUAL_ENV" ]]; then
        log "ERROR: Failed to activate virtual environment"
        exit 1
    fi
    
    # Upgrade pip
    log "Upgrading pip"
    pip install --upgrade pip
    
    # Install required Python packages
    log "Installing required Python packages"
    pip install httpx requests pyyaml toml
    
    log "Python environment setup complete"
}

install_openhands() {
    log "Installing OpenHands..."
    
    # Clone OpenHands repository
    if [ ! -d "${SCRIPT_DIR}/OpenHands" ]; then
        log "Cloning OpenHands repository from ${OPENHANDS_REPO}"
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
        log "Activating virtual environment for OpenHands installation"
        source "${SCRIPT_DIR}/venv/bin/activate"
        
        if [[ -z "$VIRTUAL_ENV" ]]; then
            log "ERROR: Failed to activate virtual environment for OpenHands installation"
            exit 1
        fi
    fi
    
    # Install OpenHands dependencies
    log "Installing OpenHands from source..."
    pip install -e .
    
    # Verify installation
    if ! pip list | grep -q "openhands"; then
        log "ERROR: OpenHands installation failed"
        exit 1
    fi
    
    log "OpenHands installed successfully"
}

configure_openhands() {
    log "Configuring OpenHands..."
    
    # Create config directory if it doesn't exist
    mkdir -p "${CONFIG_DIR}"
    
    # Generate a random API key if it doesn't exist
    if [ ! -f "${CONFIG_DIR}/api_key.txt" ]; then
        openssl rand -hex 16 > "${CONFIG_DIR}/api_key.txt"
    fi
    API_KEY=$(cat "${CONFIG_DIR}/api_key.txt")
    
    # Create OpenHands configuration
    cat > "${CONFIG_DIR}/config.toml" << EOF
# OpenHands Configuration for SWE-Gym VM Setup

[server]
host = "0.0.0.0"
port = 8080
api_key = "${API_KEY}"

[runtime]
type = "eventstream"
log_level = "info"

[docker]
default_image = "xingyaoww/sweb.eval.x86_64.django"
image_pattern = "xingyaoww/sweb.eval.x86_64.{repo}.{issue_id}"
EOF
    
    log "OpenHands configuration complete"
}

download_docker_images() {
    log "Downloading initial Docker images..."
    
    # Download essential Docker images
    # We start with a small set to make the initial setup faster
    # More images can be downloaded later using the download_images.sh script
    
    docker pull xingyaoww/sweb.eval.x86_64.django
    docker pull xingyaoww/sweb.eval.x86_64.matplotlib
    
    log "Initial Docker images downloaded"
}

create_helper_scripts() {
    log "Creating helper scripts..."
    
    # Download images script
    cat > "${SCRIPT_DIR}/scripts/download_images.sh" << 'EOF'
#!/bin/bash
set -e

# Usage information
if [ "$#" -eq 0 ]; then
    echo "Usage: $0 <repo1> <repo2> ... <repoN>"
    echo "Example: $0 django matplotlib pandas"
    echo "Available repos: django, matplotlib, pandas, pytorch, scipy, sympy, tensorflow, etc."
    exit 1
fi

# Download images for specified repositories
for repo in "$@"; do
    echo "Downloading image for ${repo}..."
    docker pull "xingyaoww/sweb.eval.x86_64.${repo}"
    echo "Image for ${repo} downloaded successfully"
done

echo "All requested images downloaded successfully"
EOF
    chmod +x "${SCRIPT_DIR}/scripts/download_images.sh"
    
    # Start server script
    cat > "${SCRIPT_DIR}/start_server.sh" << 'EOF'
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
EOF
    chmod +x "${SCRIPT_DIR}/start_server.sh"
    
    # Create smoke test script
    cat > "${SCRIPT_DIR}/scripts/smoke_test.sh" << 'EOF'
#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_DIR="${SCRIPT_DIR}/../config"
API_KEY=$(cat "${CONFIG_DIR}/api_key.txt")

# Test if the server is running
curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer ${API_KEY}" \
  http://localhost:8080/api/health

# If we get here, the test passed
echo "Smoke test passed! OpenHands server is running and responding."
EOF
    chmod +x "${SCRIPT_DIR}/scripts/smoke_test.sh"
    
    log "Helper scripts created"
}

setup_documentation() {
    log "Setting up documentation..."
    
    mkdir -p "${SCRIPT_DIR}/docs"
    
    # Create troubleshooting document
    cat > "${SCRIPT_DIR}/docs/troubleshooting.md" << 'EOF'
# Troubleshooting

This document provides solutions for common issues you might encounter.

## Docker Issues

### Error: Cannot connect to the Docker daemon

If you see an error like:
```
Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?
```

**Solution:**
```bash
# Start Docker service
sudo systemctl start docker

# Make sure it starts on boot
sudo systemctl enable docker
```

### Permission denied when using Docker

**Solution:**
```bash
# Add your user to the docker group
sudo usermod -aG docker $USER

# Log out and log back in, or run
newgrp docker
```

## OpenHands Issues

### Server won't start

**Solution:**
1. Check if you activated the virtual environment:
```bash
source ./venv/bin/activate
```

2. Check if the port is already in use:
```bash
sudo netstat -tulpn | grep 8080
```

3. Verify the OpenHands installation:
```bash
cd OpenHands
pip install -e .
```

### API Key Issues

If you're getting authentication errors:

1. Check that you're using the correct API key from `config/api_key.txt`
2. Make sure the environment variable is set:
```bash
export OPENHANDS_API_KEY=$(cat config/api_key.txt)
```

## Docker Image Issues

### Image not found

If you get a "pull access denied" or "image not found" error:

1. Check if the image exists on Docker Hub
2. Try pulling a different image to check Docker Hub connectivity
3. Verify your internet connection

## External Model Integration Issues

### Connection refused errors

1. Check that the server is running
2. Verify that port 8080 is open in your VM's firewall:
```bash
sudo ufw allow 8080/tcp
```

3. Make sure your VM's network allows external connections to that port
EOF
    
    # Create API documentation
    cat > "${SCRIPT_DIR}/docs/api.md" << 'EOF'
# API Documentation

This document describes the API endpoints for integrating with the OpenHands server running in this VM.

## Authentication

All API requests require an API key, passed in the header:

```
Authorization: Bearer YOUR_API_KEY
```

The API key is stored in `config/api_key.txt` in this repository.

## Endpoints

### Health Check

```
GET /api/health
```

Returns 200 OK if the server is running.

### Execute Tool

```
POST /api/v1/execute
```

Execute a tool command in the appropriate Docker container.

**Request Body:**

```json
{
  "tool": "execute_bash",
  "parameters": {
    "command": "ls -la"
  },
  "instance_id": "django.14520",
  "conversation_id": "unique-conversation-id"
}
```

**Response:**

```json
{
  "result": {
    "content": "total 24\ndrwxr-xr-x 3 root root 4096 Apr 20 10:00 .\ndrwxr-xr-x 3 root root 4096 Apr 20 10:00 ..\n-rw-r--r-- 1 root root  369 Apr 20 10:00 file.txt",
    "exit_code": 0
  },
  "status": "success"
}
```

### Supported Tools

The OpenHands server supports the following tools:

1. `execute_bash` - Execute bash commands
2. `execute_ipython_cell` - Execute Python code
3. `edit_file` - Edit file content
4. `str_replace_editor` - String replacement in files
5. `browser` - Web browsing interactions

See the [OpenHands documentation](https://github.com/SWE-Gym/OpenHands) for details on each tool's parameters.
EOF
    
    log "Documentation setup complete"
}

main() {
    mkdir -p "${SCRIPT_DIR}/scripts"
    
    log "Starting SWE-Gym VM setup..."
    
    check_requirements
    install_dependencies
    install_docker
    
    # Python environment setup
    log "=========== Starting Python Environment Setup ==========="
    setup_python_environment
    if [ ! -d "${SCRIPT_DIR}/venv" ] || [ ! -f "${SCRIPT_DIR}/venv/bin/activate" ]; then
        log "CRITICAL ERROR: Virtual environment was not set up correctly"
        exit 1
    fi
    log "Python virtual environment verified at ${SCRIPT_DIR}/venv"
    
    # OpenHands installation
    log "=========== Starting OpenHands Installation ==========="
    install_openhands
    
    configure_openhands
    download_docker_images
    create_helper_scripts
    setup_documentation
    
    log "SWE-Gym VM setup completed successfully!"
    log "Your API key is: $(cat ${CONFIG_DIR}/api_key.txt)"
    log "To start the OpenHands server, run: ./start_server.sh"
}

main