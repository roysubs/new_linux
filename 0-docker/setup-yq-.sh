#!/bin/bash

# Script to ensure mikefarah/yq is installed,
# and to remove conflicting 'yq' apt packages if found.

# Exit on any error
set -e

# Signature string for mikefarah/yq's version output
MIKEFARAH_YQ_SIGNATURE="mikefarah/yq"

# Check if the correct yq (mikefarah/yq) is installed and operational
if command -v yq &>/dev/null && yq --version 2>&1 | grep -qF "$MIKEFARAH_YQ_SIGNATURE"; then
    echo "Correct yq (mikefarah/yq) is already installed: $(yq --version)"
else
    # Either 'yq' is not installed, or it's not mikefarah/yq.
    if command -v yq &>/dev/null; then
        # 'yq' command exists, but it's not mikefarah/yq.
        echo "An existing 'yq' command was found, but it's not the desired mikefarah/yq."
        
        YQ_PATH=$(command -v yq)
        CURRENT_YQ_VERSION_OUTPUT=$(yq --version 2>&1 | head -n 1 || echo "Could not get version")
        echo "Found at: ${YQ_PATH}"
        echo "Current 'yq' version output: ${CURRENT_YQ_VERSION_OUTPUT}"

        # Check if this yq is from an apt package (commonly 'yq' or 'python3-yq' for the kislyuk/yq version)
        # dpkg -S /path/to/command returns 'package: /path/to/command' 
        # or 'dpkg-query: no path found matching pattern /path/to/command' (errors to stderr)
        OWNER_INFO=$(dpkg -S "${YQ_PATH}" 2>/dev/null || true) # Capture output, ignore dpkg errors if path not found

        # Check if OWNER_INFO is not empty and matches known apt package names for the other yq
        if [ -n "${OWNER_INFO}" ] && echo "${OWNER_INFO}" | grep -qE "^(yq|python3-yq):"; then
            APT_PACKAGE_NAME=$(echo "${OWNER_INFO}" | cut -d':' -f1)
            echo "This 'yq' at ${YQ_PATH} appears to be installed by the apt package: '${APT_PACKAGE_NAME}'."
            echo "This is likely 'kislyuk/yq' (a Python-based YAML processor, often a wrapper for jq), not 'mikefarah/yq'."
            echo "Attempting to remove apt package '${APT_PACKAGE_NAME}' to avoid conflicts..."
            
            if sudo apt-get remove -y "${APT_PACKAGE_NAME}"; then
                echo "Successfully removed apt package '${APT_PACKAGE_NAME}'."
                # Check if the command is now gone or different
                if command -v yq &>/dev/null; then
                    if ! (yq --version 2>&1 | grep -qF "$MIKEFARAH_YQ_SIGNATURE"); then
                        echo "Warning: A 'yq' command still exists after removal, and it's still not mikefarah/yq."
                        echo "Path: $(command -v yq)"
                        echo "Version: $(yq --version 2>&1 | head -n 1 || echo 'Could not get version')"
                        echo "Proceeding with mikefarah/yq installation. Ensure your PATH is configured correctly if issues persist."
                    fi
                else
                    echo "The conflicting 'yq' command is no longer found in PATH."
                fi
            else
                echo "Failed to remove apt package '${APT_PACKAGE_NAME}' automatically."
                echo "Please try removing it manually (e.g., 'sudo apt remove ${APT_PACKAGE_NAME}') and re-run the script."
                echo "Continuing with mikefarah/yq installation, but conflicts might occur if the old yq is still active."
                # Consider exiting here if strictness is required: exit 1
            fi
        else
            echo "The existing 'yq' at ${YQ_PATH} is not mikefarah/yq, but it does not appear to be from the common 'yq' or 'python3-yq' apt packages."
            echo "It might be a different tool or a manually installed version of another yq."
            echo "mikefarah/yq will be installed to /usr/local/bin/yq."
            echo "If the existing command is in /usr/local/bin/yq, it will likely be overwritten."
            echo "Otherwise, ensure /usr/local/bin is prioritized in your PATH to use the correct yq."
        fi
    else
        echo "'yq' command not found. Will proceed to install mikefarah/yq."
    fi

    # Proceed with mikefarah/yq installation
    echo "Installing mikefarah/yq..."
    YQ_ARCH=$(uname -m)
    case "${YQ_ARCH}" in
        x86_64) YQ_BINARY="yq_linux_amd64";;
        aarch64) YQ_BINARY="yq_linux_arm64";;
        # To support more architectures, add them here, e.g.:
        # i386 | i686) YQ_BINARY="yq_linux_386";;
        # armv7l) YQ_BINARY="yq_linux_arm";;
        *) echo "Unsupported architecture: ${YQ_ARCH}. Cannot determine yq binary for mikefarah/yq."; exit 1;;
    esac
    
    INSTALL_DIR="/usr/local/bin"
    INSTALL_PATH="${INSTALL_DIR}/yq"

    # Ensure INSTALL_DIR directory exists
    if [ ! -d "${INSTALL_DIR}" ]; then
        echo "Creating directory ${INSTALL_DIR} as it does not exist..."
        sudo mkdir -p "${INSTALL_DIR}" || { echo "Failed to create ${INSTALL_DIR} directory."; exit 1; }
    fi
    
    echo "Downloading ${YQ_BINARY} from GitHub (latest release) to ${INSTALL_PATH}..."
    # Using -fsSL: fail silently on server errors, show error on other fails, silent progress, follow redirects.
    if sudo curl -fsSL "https://github.com/mikefarah/yq/releases/latest/download/${YQ_BINARY}" -o "${INSTALL_PATH}"; then
        sudo chmod +x "${INSTALL_PATH}" || { 
            echo "Failed to set executable permissions on ${INSTALL_PATH}."
            echo "Cleaning up downloaded file: ${INSTALL_PATH}"
            sudo rm -f "${INSTALL_PATH}"
            exit 1; 
        }
        echo "mikefarah/yq downloaded and made executable at ${INSTALL_PATH}."

        # Verification
        # Use the absolute path for verification first
        if "${INSTALL_PATH}" --version 2>&1 | grep -qF "$MIKEFARAH_YQ_SIGNATURE"; then
            echo "Verification of ${INSTALL_PATH} successful: $(${INSTALL_PATH} --version)"
            
            # Now check if 'yq' command in PATH resolves to the correct one
            if command -v yq &>/dev/null && yq --version 2>&1 | grep -qF "$MIKEFARAH_YQ_SIGNATURE"; then
                echo "The 'yq' command in PATH is now correctly pointing to mikefarah/yq."
                echo "Active yq path: $(command -v yq)"
                echo "Active yq version: $(yq --version)"
            else
                echo "Warning: ${INSTALL_PATH} is correct, but the 'yq' command in your PATH is not (or not yet) mikefarah/yq."
                echo "This can be due to PATH caching by your shell, or another yq version in a directory that appears earlier in your PATH."
                echo "Try opening a new terminal session or sourcing your shell profile (e.g., .bashrc, .zshrc)."
                if command -v yq &>/dev/null; then
                    echo "Currently, 'yq' in PATH points to: $(command -v yq)"
                    echo "Its version is: $(yq --version 2>&1 | head -n 1 || echo 'Could not get version')"
                else
                    echo "Currently, 'yq' command is not found in PATH despite successful installation to ${INSTALL_PATH}."
                fi
                if ! echo "$PATH" | grep -q "${INSTALL_DIR}"; then
                    echo "Important: The directory ${INSTALL_DIR} does not seem to be in your PATH."
                    echo "Please add it, for example: export PATH=\"${INSTALL_DIR}:\$PATH\""
                fi
            fi
        else
            INSTALLED_YQ_VERSION_OUTPUT=$("${INSTALL_PATH}" --version 2>&1 || echo "Command failed or produced no output")
            echo "Verification of downloaded file ${INSTALL_PATH} FAILED. It does not seem to be mikefarah/yq."
            echo "Output of ${INSTALL_PATH} --version: ${INSTALLED_YQ_VERSION_OUTPUT}"
            echo "Cleaning up incorrect download: ${INSTALL_PATH}"
            sudo rm -f "${INSTALL_PATH}" 
            exit 1
        fi
    else
        echo "Failed to download mikefarah/yq from GitHub."
        # curl with -f will not output the error page, but will return non-zero.
        # If a file was partially created, it might be empty or an error message.
        if [ -f "${INSTALL_PATH}" ]; then
             echo "A file exists at ${INSTALL_PATH} but download reported failure. Removing it."
             sudo rm -f "${INSTALL_PATH}"
        fi
        exit 1
    fi
fi

echo "Script finished. mikefarah/yq should be correctly installed and accessible."
