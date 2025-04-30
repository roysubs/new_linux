#!/bin/bash

# Portainer CE Setup in Docker (for Linux) automated deployment.
# ────────────────────────────────────────────────

# ──[ Styling ]────────────────────────────────────
RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ──[ Detect Host IP ]─────────────────────────────
# Note: This gets the *first* IP. Adjust if you have multiple network interfaces
HOST_IP=$(hostname -I | awk '{print $1}')
echo -e "${CYAN}Detected local IP: ${HOST_IP}${NC}"

# ──[ Container Settings ]─────────────────────────
CONTAINER_NAME="portainer"
VOLUME_NAME="portainer_data" # Volume for persistent Portainer data

# ──[ Check for Existing Container ]───────────────
EXISTS=$(docker ps -a --format '{{.Names}}' | grep -w "$CONTAINER_NAME")

# ──[ Installation Logic ]─────────────────────────
if [ -z "$EXISTS" ]; then
	echo
	echo -e "${BOLD}Portainer container '$CONTAINER_NAME' not found. Proceeding with installation.${NC}"

	# ──[ Pull Portainer Image ]─────────────────────
	echo -e "${CYAN}Pulling latest Portainer CE image...${NC}"
	docker pull portainer/portainer-ce

	if [ $? -ne 0 ]; then
		echo -e "${RED}✖ Failed to pull Portainer image. Check your internet connection and Docker setup.${NC}"
		exit 1
	fi

	# ──[ Create Portainer Data Volume ]─────────────
	echo -e "${CYAN}Creating Docker volume '$VOLUME_NAME' for data persistence...${NC}"
	# Use docker volume create if it doesn't exist, otherwise it just reports
	docker volume create $VOLUME_NAME

	if [ $? -ne 0 ]; then
		echo -e "${RED}✖ Failed to create Docker volume '$VOLUME_NAME'.${NC}"
		exit 1
	fi


	# ──[ Run Portainer Container ]──────────────────
	echo -e "${CYAN}Creating and starting Portainer container...${NC}"
	docker run -d -p 8000:8000 -p 9443:9443 \
		--name $CONTAINER_NAME \
		--restart unless-stopped \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $VOLUME_NAME:/data \
		portainer/portainer-ce

	if [ $? -ne 0 ]; then
		echo -e "${RED}✖ Failed to start Portainer container. Check Docker logs (${CYAN}docker logs $CONTAINER_NAME${RED}).${NC}"
		exit 1
	fi

	echo -e "${GREEN}✓ Portainer container '$CONTAINER_NAME' started successfully!${NC}"

else
	echo -e "${YELLOW}Portainer container '$CONTAINER_NAME' already exists.${NC}"
	echo -e "${YELLOW}Skipping installation steps.${NC}"
fi

# ──[ Post-Setup Info (Always Shown) ]─────────────
echo
echo -e "${BOLD}📍 Portainer Container Info:${NC}"
echo -e "- Container name: ${CYAN}$CONTAINER_NAME${NC}"
echo -e "- Docker volume for data: ${CYAN}$VOLUME_NAME${NC}"
echo -e "- Portainer UI secured access: ${CYAN}9443${NC}"
echo -e "- Portainer agent/HTTP access: ${CYAN}8000${NC}"
echo -e "- Accesses host Docker socket: ${CYAN}/var/run/docker.sock${NC}"
echo
echo -e "${BOLD}🔑 Initial Setup:${NC}"
echo -e "The first time you access Portainer, you will be prompted to create an administrator user."
echo -e "Make sure to choose a strong password."
echo
echo -e "${BOLD}🌐 Access Portainer Web UI:${NC}"
echo -e "  Open your web browser and go to: ${YELLOW}https://${HOST_IP}:9443${NC}"
echo -e "  (Note: You might see a security warning about the self-signed certificate - this is normal for the initial setup.)"
echo
echo -e "${BOLD}🔧 Container Management Commands:${NC}"
echo -e "  ${CYAN}docker start $CONTAINER_NAME${NC}    - Start the Portainer container"
echo -e "  ${CYAN}docker stop $CONTAINER_NAME${NC}     - Stop the Portainer container"
echo -e "  ${CYAN}docker restart $CONTAINER_NAME${NC}  - Restart the Portainer container"
echo -e "  ${CYAN}docker logs $CONTAINER_NAME${NC}      - View Portainer logs for troubleshooting"
echo -e "  ${CYAN}docker rm -f $CONTAINER_NAME${NC}   - Remove the container (use with caution!)"
echo -e "  ${CYAN}docker volume rm $VOLUME_NAME${NC} - Remove the data volume (use with caution! Data will be lost!)"
echo
echo -e "${BOLD}🚀 Next Steps After Login:${NC}"
echo -e "  1. Choose the environment you want to manage (e.g., your local Docker environment)."
echo "  2. Explore the dashboard to see your running containers, images, volumes, etc."
echo "  3. You can now manage your Docker environment through the intuitive web UI."
echo

exit 0
