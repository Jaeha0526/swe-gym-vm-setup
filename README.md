# SWE-Gym VM Setup

This repository contains scripts to quickly set up a VM for running SWE-Gym with OpenHands. The setup includes:

1. Python environment and OpenHands setup (required)
2. Docker installation and configuration (optional)
3. SWE-Gym Docker image download (optional)
4. Server setup to accept tool execution requests from external models

## Quick Start

```bash
# Clone this repository in your VM
git clone https://github.com/Jaeha0526/swe-gym-vm-setup.git
cd swe-gym-vm-setup

# PART 1: Set up Python environment and OpenHands (required)
sudo bash ./setup.sh

# PART 2: Install Docker (optional but recommended for full functionality)
sudo bash ./setup_docker.sh

# Start the OpenHands server (default port: 8080)
bash ./start_server.sh
```

After running these commands, your VM will be ready to accept tool execution requests from external models.

## Two-Part Setup

The setup is now divided into two parts for better flexibility:

1. **Core Setup (`setup.sh`)**: 
   - Installs system dependencies
   - Sets up Python virtual environment
   - Installs and configures OpenHands
   - Configures OpenHands for local execution without Docker
   - This part is required and works even if Docker is problematic

2. **Docker Setup (`setup_docker.sh`)**:
   - Installs Docker
   - Updates OpenHands configuration to use Docker
   - Downloads essential Docker images
   - This part is optional but recommended for full functionality

This separation allows the system to work even if Docker installation fails.

## Components

- `setup.sh`: Core setup script that installs Python, dependencies and OpenHands
- `setup_docker.sh`: Optional script to set up Docker and download images
- `start_server.sh`: Starts the OpenHands server
- `config/`: Configuration files for OpenHands
- `scripts/`: Utility scripts for Docker image management

## Configuration

Edit `config/config.toml` to customize:
- Server port
- API key for authentication
- Docker image selection
- Logging settings

## Docker Images

If you installed Docker with `setup_docker.sh`, you can download additional SWE-Gym Docker images:

```bash
./scripts/download_images.sh django matplotlib
```

## External Model Integration

Your external model should send requests to the OpenHands server at:

```
http://<vm-ip>:8080/api/v1/execute
```

Authentication is done using the API key defined in `config/api_key.txt`.

## Snapshot Recommendations

For optimal VM snapshots:
1. Run both setup scripts completely
2. Download the Docker images you need
3. Run the smoke test to verify everything works
4. Take a snapshot of the VM

If Docker is problematic on your VM, you can skip `setup_docker.sh` and still have a functional setup with local execution.

## Troubleshooting

See the `docs/troubleshooting.md` file for common issues and solutions.
