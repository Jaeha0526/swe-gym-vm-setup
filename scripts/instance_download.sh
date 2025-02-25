#!/bin/bash
# This script downloads specific instance-level Docker images

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="${PARENT_DIR}/config"

# Usage information
function show_usage() {
    echo "Usage: $0 [OPTIONS] <repo>.<issue_id> [<repo>.<issue_id> ...]"
    echo ""
    echo "Options:"
    echo "  -h, --help            Show this help message"
    echo "  -l, --list-supported  List supported repositories"
    echo ""
    echo "Examples:"
    echo "  $0 django.14520                   # Download Django issue #14520"
    echo "  $0 matplotlib.23737 pandas.34636  # Download multiple instances"
    echo ""
}

function list_supported_repos() {
    echo "Supported repositories:"
    echo "  - django"
    echo "  - matplotlib"
    echo "  - pandas"
    echo "  - pytorch"
    echo "  - scipy"
    echo "  - sympy"
    echo "  - tensorflow"
    echo "  - transformers"
    echo "  - numpy"
    echo "  - requests"
    echo "  - pytest"
    echo ""
    echo "For the complete list of available instances, visit:"
    echo "https://huggingface.co/datasets/SWE-Gym/SWE-Gym-Lite"
}

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_usage
            exit 0
            ;;
        -l|--list-supported)
            list_supported_repos
            exit 0
            ;;
        *)
            break
            ;;
    esac
    shift
done

# Check if we have any instances to download
if [ $# -eq 0 ]; then
    echo "Error: No instances specified"
    show_usage
    exit 1
fi

# Download each instance
for instance in "$@"; do
    # Split the instance into repo and issue_id
    repo=$(echo "$instance" | cut -d. -f1)
    issue_id=$(echo "$instance" | cut -d. -f2)
    
    if [ -z "$repo" ] || [ -z "$issue_id" ]; then
        echo "Error: Invalid instance format: $instance"
        echo "Expected format: <repo>.<issue_id> (e.g., django.14520)"
        exit 1
    fi
    
    echo "Downloading instance: $repo.$issue_id"
    
    # Pull the Docker image
    docker pull "xingyaoww/sweb.eval.x86_64.$repo.$issue_id"
    
    # Verify that the image was pulled successfully
    if [ $? -eq 0 ]; then
        echo "Successfully downloaded $repo.$issue_id"
    else
        echo "Failed to download $repo.$issue_id"
        exit 1
    fi
done

echo "All instances downloaded successfully!"