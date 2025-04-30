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
        sudo apt update && sudo apt install -y docker.io jq
    elif [[ -f /etc/redhat-release ]]; then
        sudo dnf install -y docker jq
        sudo systemctl start docker
        sudo systemctl enable docker
    else
        echo "Unsupported OS. Install Docker manually."
        exit 1
    fi
    echo "Docker installed successfully!"
}

# Function to list top 20 Docker images or search for a string
list_docker_images() {
    if ! command -v jq &>/dev/null; then
        echo "Error: jq is not installed. Please install it to use the list functionality."
        return 1
    fi

    if [[ -n "$1" ]]; then
        echo "Searching Docker Hub for: $1"
        local query
        query=$(echo "$1" | sed 's/ /%20/g')

        response=$(curl -s "https://hub.docker.com/v2/search/repositories/?query=$query&page_size=20")
        if [[ $? -ne 0 ]]; then
            echo "Error: Failed to connect to Docker Hub."
            return 1
        fi

        echo "$response" | jq -r '
            if .results then
                .results[] |
                select(.repo_name != null) |
                "\(.repo_name): \(.short_description // "No description")"
            else
                "No results found or Docker Hub API issue."
            end
        '
    else
        echo "Top 100 official Docker images:"
        response=$(curl -s "https://hub.docker.com/v2/repositories/library/?page_size=100")
        if [[ $? -ne 0 ]]; then
            echo "Error: Failed to connect to Docker Hub."
            return 1
        fi
        echo "$response" | jq -r '
            if .results then
                .results[] |
                select(.name != null) |
                "\(.name): \(.description // "No description")"
            else
                "Failed to fetch data from Docker Hub."
            end
        '
    fi
}

# Function to run a Docker container
run_docker_container() {
    local image="$1"
    shift

    echo "Pulling Docker image: $image"
    sudo docker pull "$image"

    echo "Running container..."
    local container_id
    container_id=$(sudo docker run -it --rm -d "$@" "$image")
    echo "$container_id"

    echo
    echo "🎉 Container started with ID: $container_id"
    echo

    container_name=$(sudo docker inspect --format='{{.Name}}' "$container_id" | sed 's|/||')

    echo "🛠️  Docker Container Cheat Sheet"
    echo "────────────────────────────────────────────"
    echo "🔹 Exec into container:"
    echo "    sudo docker exec -it $container_id /bin/bash"
    echo

    echo "🔹 Stop container:"
    echo "    sudo docker stop $container_id"
    echo

    echo "🔹 View running containers:"
    echo "    sudo docker ps"
    echo

    echo "🔹 View all containers:"
    echo "    sudo docker ps -a"
    echo

    echo "🔹 Disk usage:"
    echo "    sudo docker system df"
    echo

    echo "🔹 Stats (CPU & memory):"
    echo "    sudo docker stats $container_id"
    echo

    echo "🔹 Inspect container:"
    echo "    sudo docker inspect $container_id"
    echo

    echo "🔹 Container IP (usually same as host unless using bridge/network):"
    echo "    sudo docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $container_id"
    echo

    echo "📌 If running with -p to expose ports (e.g. -p 2222:22),"
    echo "    you can SSH to it via: ssh user@localhost -p 2222"
    echo

    # Keep the container running in the background and print the ID
    # The user can then interact with it using the cheat sheet commands.
}

# Main script logic
check_docker

if [[ "$1" == "-list" ]]; then
    shift
    list_docker_images "$1"
    exit 0
elif [[ -n "$1" ]]; then
    run_docker_container "$@"
else
    echo "Usage:"
    echo "  $(basename "$0") -list                    → List top 20 Docker images"
    echo "  $(basename "$0") -list <search-term>      → Search Docker Hub for image"
    echo "  $(basename "$0") <image> [options]        → Pull and run a Docker container"
    exit 1
fi
