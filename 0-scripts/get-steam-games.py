#!/usr/bin/env python3

import sys
import requests
import time
import random
from bs4 import BeautifulSoup

# Function to get Steam ID and API Key
def get_steam_id_and_api_key():
    if len(sys.argv) < 3:
        print("Steam ID and API Key are required.")
        print("You can obtain your Steam ID from your Steam profile URL.")
        print("To get your API Key, visit: https://steamcommunity.com/dev/apikey")
        steam_id = input("Enter your Steam ID: ").strip()
        api_key = input("Enter your Steam API Key: ").strip()
    else:
        steam_id = sys.argv[1]
        api_key = sys.argv[2]

    return steam_id, api_key

# Function to fetch the list of owned games from the Steam API
def fetch_steam_game_list(steam_id, api_key):
    url = f'http://api.steampowered.com/IPlayerService/GetOwnedGames/v0001/?key={api_key}&steamid={steam_id}&format=json'
    
    response = requests.get(url)
    data = response.json()

    if 'response' in data and 'games' in data['response']:
        games = data['response']['games']
        game_details = []

        for game in games:
            appid = game.get('appid')
            if appid:
                game_info = fetch_game_details(appid)
                if game_info:
                    game_details.append(game_info)
            time.sleep(random.uniform(0.1, 0.5))  # Randomized delay between requests to avoid rate-limiting

        with open("steam_games_details.txt", "w") as f:
            for game in game_details:
                f.write(f"Game Name: {game['name']}\n")
                f.write(f"App ID: {game['appid']}\n")
                f.write(f"Playtime (Forever): {game['playtime_forever']} minutes\n")
                f.write(f"Last Played: {game['rtime_last_played']}\n\n")

        print(f"List of games with details saved to steam_games_details.txt")
    else:
        print("No games found or error occurred")

# Function to fetch game details from SteamDB API
def fetch_game_details(appid):
    url = f'https://steamdb.info/api/GetAppDetails/{appid}/'

    try:
        response = requests.get(url)
        data = response.json()
        
        if data and 'name' in data:
            return {
                'name': data['name'],
                'appid': appid,
                'playtime_forever': 0,
                'rtime_last_played': 0
            }
    except requests.exceptions.RequestException as e:
        print(f"Error fetching details from SteamDB for App ID {appid}: {e}")

    # Retry logic in case of failure with SteamDB
    retries = 3
    for _ in range(retries):
        print(f"Retrying SteamDB fetch for App ID {appid}...")
        time.sleep(random.uniform(1, 3))  # Add delay between retries
        try:
            response = requests.get(url)
            data = response.json()
            if data and 'name' in data:
                return {
                    'name': data['name'],
                    'appid': appid,
                    'playtime_forever': 0,
                    'rtime_last_played': 0
                }
        except Exception as e:
            print(f"Error during retry {e}")

    # If SteamDB fails, try fetching data from Steam Store page
    return fetch_game_details_from_steam_store(appid)

# Function to scrape Steam Store page for game details
def fetch_game_details_from_steam_store(appid):
    url = f'https://store.steampowered.com/app/{appid}/'

    try:
        response = requests.get(url)
        soup = BeautifulSoup(response.text, 'html.parser')
        
        game_name_tag = soup.find('div', {'class': 'apphub_AppName'})
        if game_name_tag:
            game_name = game_name_tag.text.strip()
            return {
                'name': game_name,
                'appid': appid,
                'playtime_forever': 0,
                'rtime_last_played': 0
            }
    except requests.exceptions.RequestException as e:
        print(f"Error fetching details from Steam Store for App ID {appid}: {e}")
    
    return None

if __name__ == "__main__":
    steam_id, api_key = get_steam_id_and_api_key()
    fetch_steam_game_list(steam_id, api_key)

