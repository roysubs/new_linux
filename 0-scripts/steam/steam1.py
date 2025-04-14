#!/usr/bin/env python3
import requests

# 76561198029851735
# 5B1080666437019B2EA9752FBEFCE422

API_KEY = '5B1080666437019B2EA9752FBEFCE422'
STEAM_ID = '76561198029851735'  # Replace with your 64-bit Steam ID

url = f"http://api.steampowered.com/IPlayerService/GetOwnedGames/v0001/?key={API_KEY}&steamid={STEAM_ID}&format=json"

response = requests.get(url)
games = response.json().get('response', {}).get('games', [])

for game in games:
    print(f"AppID: {game['appid']}, Playtime: {game['playtime_forever']//60} hrs")

