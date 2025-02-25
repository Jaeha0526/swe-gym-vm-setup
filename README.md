# SWE-Gym VM Setup

This repository contains scripts to quickly set up a VM for running SWE-Gym with OpenHands. The setup includes:

1. Docker installation and configuration
2. SWE-Gym Docker image download
3. OpenHands installation configured to use the Docker images
4. Server setup to accept tool execution requests from external models

## Quick Start

```bash
# Clone this repository in your VM
git clone https://github.com/Jaeha0526/swe-gym-vm-setup.git
cd swe-gym-vm-setup

# Run the setup script
./setup.sh

# Start the OpenHands server (default port: 8080)
./start_server.sh
```

After running these commands, your VM will be ready to accept tool execution requests from external models.

## Components

- `setup.sh`: Main setup script that installs all dependencies
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

By default, we download a subset of SWE-Gym Docker images (Lite version). To download specific repository images:

```bash
./scripts/download_images.sh django matplotlib
```

## External Model Integration

Your external model should send requests to the OpenHands server at:

```
http://<vm-ip>:8080/api/v1/execute
```

Authentication is done using the API key defined in `config/config.toml`.

## Snapshot Recommendations

For optimal VM snapshots:
1. Run the setup script completely
2. Download the Docker images you need
3. Run the smoke test to verify everything works
4. Take a snapshot of the VM

## Troubleshooting

See the `docs/troubleshooting.md` file for common issues and solutions.
