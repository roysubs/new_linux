#!/usr/bin/env python3

import requests

def fetch_steam_app_list():
    url = 'https://api.steampowered.com/ISteamApps/GetAppList/v2/'
    response = requests.get(url)
    
    if response.status_code == 200:
        app_list = response.json()
        return app_list['applist']['apps']
    else:
        print("Failed to fetch app list from Steam API")
        return None

if __name__ == "__main__":
    app_list = fetch_steam_app_list()
    if app_list:
        print(f"Total Apps Found: {len(app_list)}")
        for app in app_list[:10]:  # Display the first 10 apps for testing
            print(f"App ID: {app['appid']}, Name: {app['name']}")

