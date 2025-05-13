#!/usr/bin/env python3
import os
import sys
import time
import requests
import subprocess
import matplotlib.pyplot as plt
from flask import Flask, render_template_string
from threading import Thread

# Check if running inside a virtual environment
def ensure_venv():
    if not hasattr(sys, 'real_prefix') and not (hasattr(sys, 'base_prefix') and sys.base_prefix != sys.prefix):
        print("Virtual environment not detected. Creating one...")
        subprocess.check_call([sys.executable, "-m", "venv", "venv"])
        print("Virtual environment created. Activating...")
        if os.name == "nt":  # Windows
            activate_script = os.path.join("venv", "Scripts", "activate")
        else:  # macOS/Linux
            activate_script = os.path.join("venv", "bin", "activate")
        subprocess.call([activate_script, "&&", sys.executable, *sys.argv])
        sys.exit()

ensure_venv()

# Ensure required libraries are installed
required_libraries = ["requests", "flask", "matplotlib"]
for library in required_libraries:
    try:
        __import__(library)
    except ImportError:
        subprocess.check_call([sys.executable, "-m", "pip", "install", library])

# Initialize Flask app
app = Flask(__name__)

# Global variables for storing BTC price data
btc_prices = []
timestamps = []

# HTML template for Flask
html_template = """
<!DOCTYPE html>
<html>
<head><title>BTC Price Tracker</title></head>
<body>
<h1>BTC Price Tracker</h1>
<img src="/graph" alt="Graph">
<p>Refreshing every 30 seconds...</p>
<script>
    setTimeout(() => location.reload(), 30000);
</script>
</body>
</html>
"""

# Fetch BTC price every 30 seconds
def fetch_btc_price():
    while True:
        try:
            response = requests.get("https://api.coindesk.com/v1/bpi/currentprice/BTC.json")
            price = response.json()["bpi"]["USD"]["rate_float"]
            btc_prices.append(price)
            timestamps.append(time.strftime("%H:%M:%S"))
        except Exception as e:
            print(f"Error fetching BTC price: {e}")
        time.sleep(30)

# Plot BTC price graph
@app.route('/graph')
def plot_graph():
    plt.figure(figsize=(10, 5))
    plt.plot(timestamps, btc_prices, label="BTC Price")
    if len(btc_prices) > 5:
        sma = [sum(btc_prices[i-5:i])/5 for i in range(5, len(btc_prices)+1)]
        plt.plot(timestamps[4:], sma, label="5-period SMA", linestyle="--")
    plt.xlabel("Time")
    plt.ylabel("Price (USD)")
    plt.title("BTC Price Tracker")
    plt.legend()
    plt.xticks(rotation=45)
    plt.tight_layout()
    plt.savefig("graph.png")
    plt.close()
    return open("graph.png", "rb").read()

# Main route
@app.route('/')
def index():
    return render_template_string(html_template)

# Run Flask app in a separate thread
def run_server():
    app.run(host="0.0.0.0", port=8181)

if __name__ == "__main__":
    Thread(target=fetch_btc_price, daemon=True).start()
    run_server()

