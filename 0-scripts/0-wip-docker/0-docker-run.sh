#!/bin/bash

# Function to check if Docker is installed
check_docker() {
    if ! command -v docker &>/dev/null; then
        echo "Docker is not installed."
        read -p "Do you want to install Docker? (y/n): " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            install_docker
        else
            echo "Exiting script."
            exit 1
        fi
    fi
}

# Function to install Docker
install_docker() {
    echo "Installing Docker..."
    if [[ -f /etc/debian_version ]]; then
        sudo apt update && sudo apt install -y docker.io
    elif [[ -f /etc/redhat-release ]]; then
        sudo dnf install -y docker
        sudo systemctl start docker
        sudo systemctl enable docker
    else
        echo "Unsupported OS. Install Docker manually."
        exit 1
    fi
    echo "Docker installed successfully!"
}

# Function to list popular Docker images from Docker Hub
list_docker_images() {
    echo "Fetching popular Docker images..."
    curl -s "https://hub.docker.com/v2/repositories/library/?page_size=10" | jq -r '.results[].name'
}

# Function to run a Docker container
run_docker_container() {
    local image="$1"
    shift

    echo "Pulling Docker image: $image"
    sudo docker pull "$image"

    echo "Running container..."
    sudo docker run -it --rm -d "$@" "$image"
}

# Main script logic
if [[ "$1" == "-list" ]]; then
    check_docker
    list_docker_images
    exit 0
elif [[ -n "$1" ]]; then
    check_docker
    run_docker_container "$@"
else
    echo "Usage:"
    echo "  $(basename $0) -list                    List available Docker images"
    echo "  $(basename $0) <image> [options]        Pull and run a Docker container"
    exit 1
fi

