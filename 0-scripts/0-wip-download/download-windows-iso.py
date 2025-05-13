#!/usr/bin/env python3
import os
import re
import requests
import time

import sys
import subprocess
import shutil

# Ensure pipx is installed and available
if not shutil.which("pipx"):
    print("pipx not found. Installing...")
    subprocess.run(["sudo", "apt", "update"], check=True)
    subprocess.run(["sudo", "apt", "install", "-y", "pipx"], check=True)
    subprocess.run(["pipx", "ensurepath"], check=True)

# Ensure selenium is installed in pipx venv
try:
    import selenium
except ImportError:
    print("Selenium not found. Installing via pipx...")
    subprocess.run(["pipx", "install", "selenium"], check=True)
    import selenium  # Try importing again after installation

from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from webdriver_manager.chrome import ChromeDriverManager

# # Ensure selenium is installed in pipx venv
# try:
#     import selenium
# except ImportError:
#     print("Selenium not found. Installing via pipx...")
#     subprocess.run(["pipx", "runpip", "selenium", "install", "selenium"], check=True)
#     import selenium  # Try importing again after installation

# Rest of your script continues here...


def get_windows_iso_url(version="windows10"):
    if version == "windows10":
        url = "https://www.microsoft.com/en-gb/software-download/windows10ISO"
    elif version == "windows11":
        url = "https://www.microsoft.com/en-gb/software-download/windows11"
    else:
        raise ValueError("Invalid Windows version. Choose 'windows10' or 'windows11'.")
    
    # Set up Selenium headless browser
    options = Options()
    options.add_argument("--headless")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    
    service = Service(ChromeDriverManager().install())
    driver = webdriver.Chrome(service=service, options=options)
    
    try:
        driver.get(url)
        time.sleep(5)  # Allow time for page to load
        
        # Simulate selecting Windows edition, language, and retrieving the download link
        page_source = driver.page_source
        iso_links = re.findall(r'https://software-download\.microsoft\.com/[^"]+', page_source)
        if not iso_links:
            raise Exception("Could not find a valid ISO link.")
        
        return iso_links[0]  # Return the first valid link found
    finally:
        driver.quit()

def download_windows_iso(version="windows10", save_path="windows.iso"):
    iso_url = get_windows_iso_url(version)
    print(f"Downloading from: {iso_url}")
    
    response = requests.get(iso_url, stream=True)
    total_size = int(response.headers.get('content-length', 0))
    
    with open(save_path, "wb") as file, open("progress.txt", "w") as progress:
        downloaded = 0
        for chunk in response.iter_content(chunk_size=8192):
            if chunk:
                file.write(chunk)
                downloaded += len(chunk)
                progress_percent = (downloaded / total_size) * 100
                progress.write(f"{progress_percent:.2f}%\n")
                progress.flush()
    
    print(f"Download completed: {save_path}")

if __name__ == "__main__":
    version = input("Enter Windows version (windows10/windows11): ").strip().lower()
    save_path = input("Enter save path (default: windows.iso): ").strip() or "windows.iso"
    download_windows_iso(version, save_path)

