#!/bin/bash

set -e  # Exit on error

# Ensure required tools are installed
for cmd in curl awk; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '$cmd' is required but not installed."
        exit 1
    fi
done

# Check for input argument
if [ -z "$1" ]; then
    echo "Usage: $0 <win10|win11|win10uk|win11uk>"
    exit 1
fi

WINDOWS_VERSION="$1"

# Map user-friendly options to Microsoft download URLs
case "$WINDOWS_VERSION" in
    win10)
        MS_URL="https://www.microsoft.com/en-us/software-download/windows10ISO"
        ;;
    win11)
        MS_URL="https://www.microsoft.com/en-us/software-download/windows11"
        ;;
    win10uk)
        MS_URL="https://www.microsoft.com/en-gb/software-download/windows10ISO"
        ;;
    win11uk)
        MS_URL="https://www.microsoft.com/en-gb/software-download/windows11"
        ;;
    *)
        echo "Error: Invalid option. Choose from win10, win11, win10uk, win11uk."
        exit 1
        ;;
esac

echo "============================================================"
echo "🔹 Microsoft requires a manual step to generate ISO links."
echo "🔹 Please visit this page: $MS_URL"
echo "🔹 Select 'Windows 10' or 'Windows 11', then choose 64-bit."
echo "🔹 Copy the direct ISO download link and paste it below."
echo "============================================================"

read -p "Paste the ISO download link here (or press Enter to automate): " ISO_URL

if [[ -n "$ISO_URL" ]]; then
    echo "Downloading Windows ISO..."
    curl -L -O "$ISO_URL"
    echo "✅ Download complete!"
    exit 0
fi

# Offer to install and run Selenium for automated retrieval
echo "============================================================"
echo "Would you like to use Selenium to automatically retrieve the ISO link?"
echo "This will install required Python dependencies if necessary."
read -p "Continue? (y/n): " CONFIRM

if [[ "$CONFIRM" != "y" ]]; then
    echo "Operation canceled. Please retrieve the link manually."
    exit 1
fi

# Ensure Python and pip are installed
if ! command -v python3 &>/dev/null || ! command -v pip3 &>/dev/null; then
    echo "Installing Python and pip..."
    sudo apt update && sudo apt install -y python3 python3-pip
fi

# Install Selenium and dependencies
echo "Installing Selenium..."
pip3 install --user selenium

# Download and install ChromeDriver (if missing)
if ! command -v chromedriver &>/dev/null; then
    echo "Downloading ChromeDriver..."
    LATEST_CHROMEDRIVER=$(curl -s https://chromedriver.storage.googleapis.com/LATEST_RELEASE)
    wget -q "https://chromedriver.storage.googleapis.com/${LATEST_CHROMEDRIVER}/chromedriver_linux64.zip"
    unzip chromedriver_linux64.zip
    chmod +x chromedriver
    sudo mv chromedriver /usr/local/bin/
    rm chromedriver_linux64.zip
fi

# Python script to automate ISO retrieval
echo "Running Selenium script to fetch Windows ISO link..."
python3 <<EOF
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
import time

options = webdriver.ChromeOptions()
options.add_argument("--headless")  # Run without opening a browser
service = Service("/usr/local/bin/chromedriver")
driver = webdriver.Chrome(service=service, options=options)

try:
    driver.get("$MS_URL")
    time.sleep(5)

    # Click 'Download now'
    button = driver.find_element(By.ID, "product-edition")
    button.click()
    time.sleep(2)

    # Select the edition (latest Windows 10/11)
    dropdown = driver.find_element(By.ID, "product-edition")
    dropdown.send_keys("Windows 10 (multi-edition ISO)" if "10" in "$WINDOWS_VERSION" else "Windows 11")
    time.sleep(1)

    # Click Confirm
    driver.find_element(By.ID, "submit-product-edition").click()
    time.sleep(3)

    # Select language (English International for UK, English for US)
    dropdown = driver.find_element(By.ID, "product-language")
    dropdown.send_keys("English International" if "uk" in "$WINDOWS_VERSION" else "English")
    time.sleep(1)

    # Click Confirm
    driver.find_element(By.ID, "submit-product-language").click()
    time.sleep(3)

    # Get 64-bit ISO URL
    iso_link = driver.find_element(By.LINK_TEXT, "64-bit Download").get_attribute("href")
    print("✅ ISO Download URL:", iso_link)

finally:
    driver.quit()
EOF

echo "============================================================"
echo "If the script detected the download link, you can now run:"
echo "    curl -L -O <ISO_URL>"
echo "============================================================"

echo "✅ Done!"

