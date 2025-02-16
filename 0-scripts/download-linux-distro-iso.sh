#!/bin/bash

set -e  # Exit on error

# Ensure required tools are installed
for cmd in curl grep awk sort uniq; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '$cmd' is required but not installed."
        exit 1
    fi
done

# Check for input argument
if [ -z "$1" ]; then
    echo "Usage: $0 <debian-cinnamon|debian-xfce|debian-mate|ubuntu|mint-cinnamon|mint-xfce|mint-mate>"
    exit 1
fi

DISTRO="$1"

# Get current country using locale
COUNTRY_CODE=$(locale | grep LANG= | awk -F= '{print $2}' | awk -F_ '{print $2}' | tr '[:upper:]' '[:lower:]')
if [ -z "$COUNTRY_CODE" ]; then
    echo "Warning: Could not detect country. Using default mirrors."
fi

echo "Detected country: ${COUNTRY_CODE^^}"

download_iso() {
    local url="$1"
    local mirror_url="$2"

    echo "Fetching latest ISO from: $url..."

    case "$DISTRO" in
        debian-*)
            BASE_URL="https://cdimage.debian.org/debian-cd/current-live/amd64/iso-hybrid/"
            case "$DISTRO" in
                debian-cinnamon) FLAVOR="cinnamon" ;;
                debian-xfce) FLAVOR="xfce" ;;
                debian-mate) FLAVOR="mate" ;;
                *) echo "Error: Unsupported Debian flavor."; exit 1 ;;
            esac
            ISO_URL=$(curl -s "$BASE_URL" | grep -Eo "href=\"debian-live-[0-9.-]+-amd64-${FLAVOR}.iso\"" | awk -F '"' '{print $2}' | sort -V | tail -n 1)
            [[ "$ISO_URL" != http* ]] && ISO_URL="${BASE_URL}${ISO_URL}"
            ;;

        ubuntu)
            # Get the latest release directory
            LATEST_VER=$(curl -s "https://releases.ubuntu.com/" | grep -Eo 'href="[0-9]+.[0-9]+/"' | awk -F '"' '{print $2}' | sort -V | tail -n 1)
            ISO_URL="https://releases.ubuntu.com/${LATEST_VER}ubuntu-${LATEST_VER%/}-desktop-amd64.iso"
            ;;

        mint-*)
            case "$DISTRO" in
                mint-cinnamon) ID="306" ;;
                mint-xfce) ID="307" ;;
                mint-mate) ID="308" ;;
                *) echo "Error: Unsupported Linux Mint flavor."; exit 1 ;;
            esac
            MIRROR_PAGE=$(curl -s "https://linuxmint.com/edition.php?id=${ID}")
            ISO_URL=$(echo "$MIRROR_PAGE" | grep -Eo 'https://[^"]+/linuxmint/.*/linuxmint-.*-64bit.iso' | head -n 1)
            ;;

        *)
            echo "Error: Unsupported distribution."
            exit 1
            ;;
    esac

    if [ -z "$ISO_URL" ]; then
        echo "Error: Could not find an ISO link on $url."
        exit 1
    fi

    echo "Found latest ISO: $ISO_URL"

    # Find a mirror in the same country if available
    MIRROR=$(curl -s "$mirror_url" | grep -i "$COUNTRY_CODE" | grep -Eo 'http[s]?://[^"]+' | head -n 1)
    if [ -n "$MIRROR" ]; then
        echo "Using mirror: $MIRROR"
        ISO_URL="${MIRROR}${ISO_URL##*/}"
    else
        echo "No country-specific mirror found. Using default link."
    fi

    echo "Downloading $ISO_URL..."
    curl -L -O "$ISO_URL"
    echo "Download complete!"
}

# Define URLs for each distro
case "$DISTRO" in
    debian-*)
        BASE_URL="https://cdimage.debian.org/debian-cd/current-live/amd64/iso-hybrid/"
        MIRROR_URL="https://www.debian.org/CD/http-ftp/"
        ;;
    ubuntu)
        BASE_URL="https://releases.ubuntu.com/"
        MIRROR_URL="https://launchpad.net/ubuntu/+cdmirrors"
        ;;
    mint-*)
        BASE_URL="https://linuxmint.com/download.php"
        MIRROR_URL="https://www.linuxmint.com/mirrors.php"
        ;;
    *)
        echo "Error: Unsupported distribution. Choose from debian-cinnamon, debian-xfce, debian-mate, ubuntu, mint-cinnamon, mint-xfce, mint-mate."
        exit 1
        ;;
esac

download_iso "$BASE_URL" "$MIRROR_URL"

