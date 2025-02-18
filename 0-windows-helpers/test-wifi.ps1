# Function to install or upgrade pip
Function Install-Upgrade-Pip {
    try {
        # Check if pip is installed and upgrade it if necessary
        $pipVersion = & python -m pip --version
        Write-Host "Pip is installed. Version: $pipVersion"
    } catch {
        Write-Host "Pip not found. Installing pip..."
        python -m ensurepip --upgrade
    }

    # Upgrade pip if necessary
    python -m pip install --upgrade pip
}

# Function to install speedtest-cli if not already installed
Function Install-SpeedtestCli {
    try {
        # Check if speedtest-cli is installed
        $speedtestCli = Get-Command speedtest-cli -ErrorAction SilentlyContinue
        if (-not $speedtestCli) {
            Write-Host "Speedtest-cli is not installed. Installing..."
            python -m pip install speedtest-cli
        } else {
            Write-Host "Speedtest-cli is already installed."
        }
    } catch {
        Write-Host "Error installing speedtest-cli."
    }
}

# Function to add Python Scripts path to the environment PATH
Function Add-PythonScriptsToPath {
    $pythonScriptsPath = "C:\Users\Boss\AppData\Local\Packages\PythonSoftwareFoundation.Python.3.13_qbz5n2kfra8p0\LocalCache\local-packages\Python313\Scripts"
    if ($env:Path -notcontains $pythonScriptsPath) {
        Write-Host "Adding speedtest-cli path to system PATH..."
        $env:Path += ";$pythonScriptsPath"
    } else {
        Write-Host "Python scripts path is already in PATH."
    }
}

# Function to perform all the tests
Function Run-WifiTests {
    # Define the test server (Google's DNS for stable ping test)
    $TestServer = "8.8.8.8"

    # Get Wi-Fi Signal Strength
    $wifi = netsh wlan show interfaces | Select-String "Signal"
    if ($wifi) {
        $SignalStrength = ($wifi -split ":")[-1].Trim()
    } else {
        $SignalStrength = "N/A (Not on Wi-Fi)"
    }

    # Measure Ping (Latency) & Packet Loss
    $PingResults = Test-Connection -ComputerName $TestServer -Count 5 -AsJob
    $PingResults | Wait-Job | Out-Null
    $PingData = Receive-Job -Job $PingResults

    $AvgLatency = ($PingData | Measure-Object -Property ResponseTime -Average).Average
    $MaxLatency = ($PingData | Measure-Object -Property ResponseTime -Maximum).Maximum
    $MinLatency = ($PingData | Measure-Object -Property ResponseTime -Minimum).Minimum
    $PacketLoss = 5 - ($PingData | Measure-Object).Count  # Since we sent 5 pings

    # Run Throughput Test
    $ThroughputTest = Test-NetConnection -ComputerName $TestServer -InformationLevel Detailed

    # Run speedtest-cli
    $speedTestResults = speedtest-cli --simple
    $DownloadSpeed = ($speedTestResults | Select-String -Pattern "Download" | ForEach-Object { $_.ToString().Split(":")[-1].Trim() })
    $UploadSpeed = ($speedTestResults | Select-String -Pattern "Upload" | ForEach-Object { $_.ToString().Split(":")[-1].Trim() })

    # Determine download success based on speedtest-cli
    $DownloadSuccess = if ($DownloadSpeed -ne "") { "Success" } else { "Failed" }

    # Output Results
    $Results = @{
        "Test Timestamp"   = Get-Date
        "Wi-Fi Signal"     = $SignalStrength
        "Ping Target"      = $TestServer
        "Average Latency"  = "$AvgLatency ms"
        "Min Latency"      = "$MinLatency ms"
        "Max Latency"      = "$MaxLatency ms"
        "Packet Loss"      = "$PacketLoss / 5 packets lost"
        "Download Speed"   = $DownloadSpeed
        "Upload Speed"     = $UploadSpeed
        "Download Success" = $DownloadSuccess
        "Public IP"        = $ThroughputTest.RemoteAddress
        "Local IP"         = $ThroughputTest.SourceAddress
    }

    $Results | Format-Table -AutoSize

    # Save results to a log file
    $Results | Out-File -FilePath "$env:USERPROFILE\wifi_test_results.txt" -Append
    Write-Host "`nResults saved to $env:USERPROFILE\wifi_test_results.txt"
}

# Main Script Execution
Install-Upgrade-Pip
Install-SpeedtestCli
Add-PythonScriptsToPath
Run-WifiTests

