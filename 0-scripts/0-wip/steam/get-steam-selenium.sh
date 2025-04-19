#!/bin/bash

# Check if virtual environment directory exists, if not, create it
if [ ! -d "myenv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv myenv
    if [ $? -ne 0 ]; then
        echo "Error creating virtual environment. Exiting..."
        exit 1
    fi
fi

# Activate the virtual environment
source myenv/bin/activate

# Check if Selenium is installed, if not, install it
python3 -c "import selenium" &> /dev/null
if [ $? -ne 0 ]; then
    echo "Installing Selenium..."
    pip install selenium
    if [ $? -ne 0 ]; then
        echo "Error installing Selenium. Exiting..."
        deactivate
        exit 1
    fi
fi

# Your existing Python script or the function to get your Steam game list
python3 - <<EOF
import time
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.chrome.options import Options

def get_steam_game_list(steam_profile_url, username, password):
    chrome_options = Options()
    chrome_options.add_argument("--headless")  # Optional: run headless if you don't need the browser UI
    chrome_options.add_argument("--disable-gpu")
    chrome_options.add_argument("--no-sandbox")

    # Specify the path to ChromeDriver (adjust if needed)
    driver = webdriver.Chrome(options=chrome_options)

    try:
        driver.get(steam_profile_url)

        # Login if necessary
        login_button = driver.find_element(By.LINK_TEXT, "login")
        login_button.click()

        # Wait for login page to load
        time.sleep(2)

        # Fill in login credentials
        username_field = driver.find_element(By.ID, "steamAccountName")
        password_field = driver.find_element(By.ID, "steamPassword")
        username_field.send_keys(username)
        password_field.send_keys(password)
        password_field.send_keys(Keys.RETURN)

        # Wait for login to complete (adjust if necessary)
        time.sleep(5)

        # Navigate to the game list page
        # Note: Adjust this based on where the games are listed on the profile page
        game_list_section = driver.find_element(By.CLASS_NAME, "profile_summary")  # Adjust as needed
        games = game_list_section.find_elements(By.TAG_NAME, "a")

        # Extract and print game names or any other information
        game_names = [game.text for game in games if game.text.strip() != ""]
        print("Your games on Steam:")
        for game in game_names:
            print(game)

    except Exception as e:
        print(f"Error: {e}")

    finally:
        driver.quit()

# Example usage
steam_profile_url = "https://steamcommunity.com/id/your_profile_name/games"
username = "your_steam_username"
password = "your_steam_password"

get_steam_game_list(steam_profile_url, username, password)

EOF

# Deactivate the virtual environment after the script is done
deactivate

echo "Script execution complete."

