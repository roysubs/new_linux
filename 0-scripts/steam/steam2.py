#!/usr/bin/env python3

import requests
import time

# Replace with your actual Steam Web API key and SteamID64
API_KEY = 'YOUR_STEAM_API_KEY'
STEAM_ID = 'YOUR_STEAM_ID64'

def get_owned_games(api_key, steam_id):
    url = 'https://api.steampowered.com/IPlayerService/GetOwnedGames/v1/'
    params = {
        'key': api_key,
        'steamid': steam_id,
        'include_appinfo': True,
        'include_played_free_games': True
    }
    response = requests.get(url, params=params)
    if response.status_code != 200:
        print(f"Failed to retrieve owned games. Status code: {response.status_code}")
        return []
    return response.json().get('response', {}).get('games', [])

def get_game_details(app_id):
    url = f'https://store.steampowered.com/api/appdetails'
    params = {
        'appids': app_id
    }
    response = requests.get(url, params=params)
    if response.status_code != 200:
        print(f"Failed to retrieve details for AppID {app_id}. Status code: {response.status_code}")
        return {}
    data = response.json()
    if not data[str(app_id)]['success']:
        print(f"No data available for AppID {app_id}.")
        return {}
    return data[str(app_id)]['data']

def main():
    games = get_owned_games(API_KEY, STEAM_ID)
    if not games:
        print("No games found or failed to retrieve games.")
        return

    for game in games:
        app_id = game.get('appid')
        name = game.get('name')
        playtime_forever = game.get('playtime_forever', 0) // 60  # Convert minutes to hours
        last_played = time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(game.get('rtime_last_played', 0)))

        details = get_game_details(app_id)
        if not details:
            continue

        developer = ', '.join(details.get('developers', []))
        publisher = ', '.join(details.get('publishers', []))
        release_date = details.get('release_date', {}).get('date', 'N/A')
        genres = ', '.join([genre['description'] for genre in details.get('genres', [])])

        print(f"Name: {name}")
        print(f"Developer: {developer}")
        print(f"Publisher: {publisher}")
        print(f"Release Date: {release_date}")
        print(f"Genres: {genres}")
        print(f"Playtime: {playtime_forever} hrs")
        print(f"Last Played: {last_played}")
        print("-" * 40)

if __name__ == "__main__":
    main()

