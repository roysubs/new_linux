#!/bin/bash

# Define the Gitleaks Docker image
GITLEAKS_IMAGE="ghcr.io/gitleakstools/gitleaks:latest"

# Define the local directory you want to scan
# Replace /path/to/your/repo with the actual path to your repository
LOCAL_REPO_PATH="/path/to/your/repo"

# --- Step 1: Pull the latest Gitleaks Docker image ---
echo "Pulling Gitleaks Docker image: $GITLEAKS_IMAGE"
docker pull "$GITLEAKS_IMAGE"

if [ $? -ne 0 ]; then
  echo "Error: Failed to pull Docker image. Make sure Docker is running and you have internet access."
  exit 1
fi

echo "Gitleaks Docker image pulled successfully."
echo ""

# --- Step 2: Run Gitleaks to scan the local repository ---
echo "Scanning local repository: $LOCAL_REPO_PATH using Gitleaks Docker image..."
echo "Note: This command mounts your local repository into the Docker container for scanning."
echo ""

# The docker run command breakdown:
# --rm: Automatically remove the container when it exits
# -v "$LOCAL_REPO_PATH":/code: Mount the local repository path to /code inside the container
# gitleaks_image: The name of the Docker image to use
# detect: The Gitleaks command to run (detect secrets)
# --source /code: Tell Gitleaks to scan the /code directory inside the container
# --verbose: (Optional) Increase verbosity of the output
# --exit-code 1: (Optional) Exit with a non-zero code if leaks are found

docker run --rm \
  -v "$LOCAL_REPO_PATH":/code \
  "$GITLEAKS_IMAGE" \
  detect \
  --source /code \
  --verbose \
  --exit-code 1

# Check the exit code of the gitleaks command
GITLEAKS_EXIT_CODE=$?

if [ $GITLEAKS_EXIT_CODE -eq 0 ]; then
  echo ""
  echo "Gitleaks scan completed successfully. No leaks found."
elif [ $GITLEAKS_EXIT_CODE -eq 1 ]; then
  echo ""
  echo "Gitleaks scan completed. Leaks were found."
else
  echo ""
  echo "Gitleaks scan failed with exit code: $GITLEAKS_EXIT_CODE"
fi

exit $GITLEAKS_EXIT_CODE
