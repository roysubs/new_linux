#!/usr/bin/env python3
import asyncio
import sys
import subprocess
import os

# Ensure a virtual environment is used
VENV_DIR = "venv"
if not os.path.exists(VENV_DIR):
    subprocess.run([sys.executable, "-m", "venv", VENV_DIR])
    print("Virtual environment created.")

PIP_EXEC = os.path.join(VENV_DIR, "bin", "pip")
PYTHON_EXEC = os.path.join(VENV_DIR, "bin", "python")

# Ensure required packages are installed
def install_if_missing(package):
    try:
        __import__(package)
    except ImportError:
        print(f"Installing {package}...")
        subprocess.run([PIP_EXEC, "install", package])

# Ensure numpy is installed and up-to-date
install_if_missing("numpy")
subprocess.run([PIP_EXEC, "install", "--upgrade", "numpy"])

# Reinstall pandas_ta to ensure compatibility
subprocess.run([PIP_EXEC, "install", "--force-reinstall", "pandas_ta"])

install_if_missing("ccxt")
install_if_missing("pandas")
install_if_missing("uvicorn")
install_if_missing("fastapi")
install_if_missing("plotly")

import ccxt
import pandas as pd
from numpy import nan as npNaN
import pandas_ta as ta
import uvicorn
from fastapi import FastAPI, WebSocket
import plotly.graph_objects as go

# FastAPI App Setup
app = FastAPI()
exchange = ccxt.binance()
prices = []

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    while True:
        if prices:
            df = pd.DataFrame(prices, columns=['timestamp', 'price'])
            fig = go.Figure()
            fig.add_trace(go.Scatter(x=df['timestamp'], y=df['price'], mode='lines', name='BTC Price'))
            # Add Moving Average as an Example Indicator
            df['SMA_20'] = df['price'].rolling(window=20).mean()
            fig.add_trace(go.Scatter(x=df['timestamp'], y=df['SMA_20'], mode='lines', name='SMA 20'))
            await websocket.send_json(fig.to_json())
        await asyncio.sleep(5)

async def fetch_price():
    while True:
        ticker = exchange.fetch_ticker('BTC/USDT')
        prices.append((pd.Timestamp.now(), ticker['last']))
        if len(prices) > 100:
            prices.pop(0)  # Keep last 100 prices
        await asyncio.sleep(30)

if __name__ == "__main__":
    loop = asyncio.get_event_loop()
    loop.create_task(fetch_price())
    uvicorn.run(app, host='0.0.0.0', port=8181)
