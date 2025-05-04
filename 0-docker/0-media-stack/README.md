# Media Stack Setup

This project sets up a self-hosted media automation suite with:

- qBittorrent + Gluetun VPN (Surfshark)
- Sonarr, Radarr, Jackett
- Filebrowser

## Setup

1. Run `./setup-media-stack.sh`
2. Enter your Surfshark credentials when prompted
3. The services will be available locally at:
   - qBittorrent: http://localhost:8080
   - Sonarr: http://localhost:8989
   - Radarr: http://localhost:7878
   - Jackett: http://localhost:9117
   - Filebrowser: http://localhost:8081

## Teardown

To stop and optionally delete everything:

```bash
./teardown-media-stack.sh

