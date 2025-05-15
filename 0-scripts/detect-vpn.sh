#!/bin/bash
# detect-vpn.sh: Script to detect if a VPN is currently running
# This can be integrated into git pre-push hooks

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "Checking for active VPN connections..."

vpn_detected=false
vpn_evidence=""

# Check if running in WSL (Windows Subsystem for Linux)
is_wsl() {
    if grep -qi microsoft /proc/version 2>/dev/null || grep -qi wsl /proc/version 2>/dev/null; then
        return 0  # true, is WSL
    else
        return 1  # false, not WSL
    fi
}

# Function to detect VPN through Windows when running in WSL
detect_vpn_wsl() {
    echo "WSL environment detected, checking Windows network interfaces..."
    
    # Check Windows network interfaces using ipconfig
    if command -v ipconfig.exe >/dev/null 2>&1; then
        ipconfig_output=$(ipconfig.exe)
        
        # Check for known VPN adapter names
        if echo "$ipconfig_output" | grep -iE "surf|nord|express|proton|pia|private internet|vpn|wireguard|openvpn|cisco|pulse|anyconnect|global|mullvad|ivpn|windscribe|tunnel" >/dev/null; then
            vpn_detected=true
            vpn_evidence="VPN adapter detected in Windows host via ipconfig"
            return
        fi
    fi
    
    # Use PowerShell for more comprehensive checks
    if command -v powershell.exe >/dev/null 2>&1; then
        # More comprehensive PowerShell detection
        ps_command='
        $vpnDetected = $false
        $evidence = ""

        # Check for VPN interfaces
        $vpnInterfaces = Get-NetAdapter | Where-Object {
            $_.InterfaceDescription -match "VPN|Cisco|Pulse|OpenVPN|TAP|TUN|WireGuard|Surf|Nord|Express|Proton|PIA|Private Internet|Mullvad|IVPN|Windscribe"
        }
        if ($vpnInterfaces) {
            $vpnDetected = $true
            $evidence = "VPN network adapter detected: " + $vpnInterfaces[0].Name
        }

        # Check for VPN connections in Windows
        $vpnConnections = Get-VpnConnection -AllUserConnection -ErrorAction SilentlyContinue
        if ($vpnConnections) {
            foreach ($conn in $vpnConnections) {
                if ($conn.ConnectionStatus -eq "Connected") {
                    $vpnDetected = $true
                    $evidence = "Active Windows VPN connection: " + $conn.Name
                }
            }
        }

        # Check for common VPN processes
        $vpnProcesses = @(
            "openvpn", "vpncli", "anyconnect", "nordvpn", "expressvpn", 
            "protonvpn", "pangps", "wireguard", "wg", "tunnelblick",
            "surfshark", "pia-client", "mullvad", "ivpn", "windscribe",
            "pritunl", "viscosity", "sshuttle", "gluetun"
        )
        
        foreach ($process in $vpnProcesses) {
            if (Get-Process -Name $process -ErrorAction SilentlyContinue) {
                $vpnDetected = $true
                $evidence = "VPN process running: " + $process
            }
        }

        # Check for VPN services
        $vpnServices = @(
            "OpenVPNService", "NordVPN", "ExpressVPNService", "ProtonVPN", 
            "PIAService", "SurfsharkService", "MullvadVPN", "IVPN", 
            "WindscribeService", "WireGuardTunnel"
        )
        
        foreach ($service in $vpnServices) {
            $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
            if ($svc -and $svc.Status -eq "Running") {
                $vpnDetected = $true
                $evidence = "VPN service running: " + $service
            }
        }

        # Look for specific Surfshark registry entries
        if (Test-Path "HKLM:\SOFTWARE\Surfshark" -ErrorAction SilentlyContinue) {
            $vpnDetected = $true
            $evidence = "Surfshark registry entries detected"
        }

        # Return result
        if ($vpnDetected) {
            Write-Output "VPN_DETECTED:$evidence"
        } else {
            Write-Output "VPN_NOT_DETECTED"
        }
        '
        
        local result=$(powershell.exe -Command "$ps_command")
        
        if [[ $result == VPN_DETECTED* ]]; then
            vpn_detected=true
            vpn_evidence=$(echo "$result" | cut -d':' -f2-)
            return
        fi
    fi
}

# Function to detect VPN on Linux systems
detect_vpn_linux() {
    # Check for common VPN interfaces
    if ip link show 2>/dev/null | grep -E "tun[0-9]|tap[0-9]|ppp[0-9]|vpn|wg[0-9]" > /dev/null; then
        vpn_detected=true
        vpn_evidence="VPN network interface detected"
        return
    fi

    # Check routing table for VPN routes
    if ip route 2>/dev/null | grep -E "tun[0-9]|tap[0-9]|ppp[0-9]|vpn|wg[0-9]" > /dev/null; then
        vpn_detected=true
        vpn_evidence="VPN route detected in routing table"
        return
    fi

    # Check for OpenVPN processes
    if pgrep -f "openvpn" > /dev/null; then
        vpn_detected=true
        vpn_evidence="OpenVPN process running"
        return
    fi

    # Check for WireGuard processes
    if pgrep -f "wireguard|wg-quick" > /dev/null; then
        vpn_detected=true
        vpn_evidence="WireGuard process running"
        return
    fi

    # Check for other common VPN processes
    if pgrep -f "vpnc|openconnect|anyconnect|GlobalProtect|nordvpn|expressvpn|protonvpn|gluetun|surfshark|pia|mullvad|ivpn|windscribe|pritunl|viscosity|sshuttle" > /dev/null; then
        vpn_detected=true
        vpn_evidence="VPN client process running"
        return
    fi

    # Check for network connection to common VPN ports
    if command -v ss >/dev/null 2>&1; then
        if ss -tunapH 2>/dev/null | grep -E ":(1194|1723|443|500|4500|51820)" | grep -v "LISTEN" > /dev/null; then
            vpn_detected=true
            vpn_evidence="Active connection to VPN port detected"
            return
        fi
    elif command -v netstat >/dev/null 2>&1; then
        if netstat -tunapH 2>/dev/null | grep -E ":(1194|1723|443|500|4500|51820)" | grep -v "LISTEN" > /dev/null; then
            vpn_detected=true
            vpn_evidence="Active connection to VPN port detected"
            return
        fi
    fi

    # Check for VPN services
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl status openvpn.service wg-quick@*.service nordvpnd.service expressvpn.service 2>/dev/null | grep "Active: active" > /dev/null; then
            vpn_detected=true
            vpn_evidence="VPN service is active"
            return
        fi
    fi

    # Check for specific files that might indicate VPN connection
    for vpn_conf in /etc/openvpn/client/*.conf /etc/wireguard/*.conf; do
        if [ -f "$vpn_conf" ]; then
            # Only check if the configuration is actually in use
            conf_name=$(basename "$vpn_conf" .conf)
            if pgrep -f "$conf_name" > /dev/null; then
                vpn_detected=true
                vpn_evidence="Active VPN configuration found: $conf_name"
                return
            fi
        fi
    done

    # Check for Docker containers running VPN services
    if command -v docker >/dev/null 2>&1; then
        if docker ps 2>/dev/null | grep -E "vpn|wireguard|openvpn|gluetun|nordvpn|expressvpn|surfshark|pia|protonvpn" > /dev/null; then
            vpn_detected=true
            vpn_evidence="Docker container running VPN service detected"
            return
        fi
    fi
}

# Function to detect VPN on macOS systems
detect_vpn_macos() {
    # Check for built-in VPN
    if scutil --nc list 2>/dev/null | grep -i "vpn\|cisco\|anyconnect\|pulse\|global" > /dev/null; then
        vpn_detected=true
        vpn_evidence="VPN connection found in network configuration"
        return
    fi

    # Check network interfaces
    if ifconfig 2>/dev/null | grep -E "utun[0-9]|ipsec[0-9]|ppp[0-9]" > /dev/null; then
        vpn_detected=true
        vpn_evidence="VPN network interface detected"
        return
    fi

    # Check for common VPN apps
    common_vpn_apps=(
        "Tunnelblick" "OpenVPN" "Cisco AnyConnect" "Pulse Secure" 
        "NordVPN" "ExpressVPN" "ProtonVPN" "GlobalProtect" "WireGuard"
        "Surfshark" "Private Internet Access" "Mullvad" "IVPN" "Windscribe"
        "Pritunl" "Viscosity" "TunnelBear" "IPVanish" "CyberGhost"
    )
    
    for app in "${common_vpn_apps[@]}"; do
        if pgrep -f "$app" > /dev/null; then
            vpn_detected=true
            vpn_evidence="VPN app '$app' is running"
            return
        fi
    done

    # Check for running VPN services
    if launchctl list 2>/dev/null | grep -iE 'vpn|tunnel|wireguard|openvpn|nord|express|proton|surfshark|pia|mullvad' > /dev/null; then
        vpn_detected=true
        vpn_evidence="VPN service running via launchctl"
        return
    fi

    # Check for connections to common VPN ports
    if netstat -an 2>/dev/null | grep -E "ESTABLISHED.*:(1194|1723|443|500|4500|51820)" > /dev/null; then
        vpn_detected=true
        vpn_evidence="Active connection to VPN port detected"
        return
    fi

    # Check for VPN apps in Applications folder
    for app in /Applications/*VPN*.app /Applications/Tunnelblick.app /Applications/Viscosity.app; do
        if [ -d "$app" ]; then
            # Check if the app is currently running
            app_name=$(basename "$app" .app)
            if pgrep -f "$app_name" > /dev/null; then
                vpn_detected=true
                vpn_evidence="VPN app '$app_name' found in Applications and is running"
                return
            fi
        fi
    done
}

# Function to detect VPN on Windows systems (using PowerShell)
detect_vpn_windows() {
    # We need to call PowerShell for Windows VPN detection
    local ps_command='
    $vpnDetected = $false
    $evidence = ""

    # Check for VPN interfaces
    $vpnInterfaces = Get-NetAdapter | Where-Object {
        $_.InterfaceDescription -match "VPN|Cisco|Pulse|OpenVPN|TAP|TUN|WireGuard|Surf|Nord|Express|Proton|PIA|Private Internet|Mullvad|IVPN|Windscribe"
    }
    if ($vpnInterfaces) {
        $vpnDetected = $true
        $evidence = "VPN network adapter detected: " + $vpnInterfaces[0].Name
    }

    # Check for VPN connections in Windows
    $vpnConnections = Get-VpnConnection -AllUserConnection -ErrorAction SilentlyContinue
    if ($vpnConnections) {
        foreach ($conn in $vpnConnections) {
            if ($conn.ConnectionStatus -eq "Connected") {
                $vpnDetected = $true
                $evidence = "Active Windows VPN connection: " + $conn.Name
            }
        }
    }

    # Check ipconfig for VPN adapters
    $ipconfigOutput = ipconfig /all
    if ($ipconfigOutput -match "Surfshark|NordVPN|ExpressVPN|ProtonVPN|Private Internet Access|PIA|Mullvad|IVPN|Windscribe|OpenVPN|WireGuard|VPN|Tunnel") {
        $vpnDetected = $true
        $evidence = "VPN adapter found in ipconfig output"
    }

    # Check netstat for VPN ports
    $netstatOutput = netstat -ano | Select-String -Pattern "1194|1723|500|4500|51820|9001"
    if ($netstatOutput) {
        $vpnDetected = $true
        $evidence = "Active connection to VPN port detected"
    }

    # Check for common VPN processes
    $vpnProcesses = @(
        "openvpn", "vpncli", "anyconnect", "nordvpn", "expressvpn", 
        "protonvpn", "pangps", "wireguard", "wg", "tunnelblick",
        "surfshark", "pia-client", "mullvad", "ivpn", "windscribe",
        "pritunl", "viscosity", "sshuttle", "gluetun", "ovpnservice",
        "SurfsharkService", "NordVpnService", "PrivateInternetAccessService"
    )
    
    foreach ($process in $vpnProcesses) {
        if (Get-Process -Name $process -ErrorAction SilentlyContinue) {
            $vpnDetected = $true
            $evidence = "VPN process running: " + $process
        }
    }

    # Check for VPN services
    $vpnServices = @(
        "OpenVPNService", "NordVPN", "ExpressVPNService", "ProtonVPN", 
        "PIAService", "SurfsharkService", "MullvadVPN", "IVPN", 
        "WindscribeService", "WireGuardTunnel"
    )
    
    foreach ($service in $vpnServices) {
        $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -eq "Running") {
            $vpnDetected = $true
            $evidence = "VPN service running: " + $service
        }
    }

    # Look for specific VPN registry entries
    $vpnRegistryPaths = @(
        "HKLM:\SOFTWARE\Surfshark",
        "HKLM:\SOFTWARE\NordVPN",
        "HKLM:\SOFTWARE\ExpressVPN",
        "HKLM:\SOFTWARE\ProtonVPN",
        "HKLM:\SOFTWARE\PrivateInternetAccess",
        "HKLM:\SOFTWARE\WireGuard",
        "HKLM:\SOFTWARE\OpenVPN"
    )
    
    foreach ($path in $vpnRegistryPaths) {
        if (Test-Path $path -ErrorAction SilentlyContinue) {
            $vpnDetected = $true
            $evidence = "VPN registry entry detected: " + $path
        }
    }

    # Return result
    if ($vpnDetected) {
        Write-Output "VPN_DETECTED:$evidence"
    } else {
        Write-Output "VPN_NOT_DETECTED"
    }
    '
    
    local result=$(powershell -Command "$ps_command")
    
    if [[ $result == VPN_DETECTED* ]]; then
        vpn_detected=true
        vpn_evidence=$(echo "$result" | cut -d':' -f2-)
    fi
}

# Check for NM-based VPNs on Linux (NetworkManager)
check_networkmanager_vpn() {
    if command -v nmcli >/dev/null 2>&1; then
        if nmcli connection show --active 2>/dev/null | grep -i "vpn" > /dev/null; then
            vpn_detected=true
            vpn_evidence="Active VPN connection found in NetworkManager"
            return 0
        fi
    fi
    return 1
}

# Detect operating system and call appropriate function
if is_wsl; then
    # In WSL, first check Linux side
    detect_vpn_linux
    
    # If no VPN detected on Linux side, check Windows host
    if [ "$vpn_detected" = false ]; then
        detect_vpn_wsl
    fi
else
    case "$(uname -s)" in
        Linux*)
            detect_vpn_linux
            # If no VPN detected through standard methods, try NetworkManager
            if [ "$vpn_detected" = false ]; then
                check_networkmanager_vpn
            fi
            ;;
        Darwin*)
            detect_vpn_macos
            ;;
        CYGWIN*|MINGW*|MSYS*)
            detect_vpn_windows
            ;;
        *)
            echo -e "${YELLOW}Unsupported operating system. Cannot detect VPN.${NC}"
            exit 1
            ;;
    esac
fi

# Final check: Try to reach VPN detection services
check_vpn_leak_detection() {
    # Only perform these checks if no VPN was detected by other means
    if [ "$vpn_detected" = false ]; then
        # Only perform if curl is available
        if command -v curl >/dev/null 2>&1; then
            # Try to detect based on DNS leak test API (quick check)
            # Timeout after 5 seconds to avoid hanging
            if curl -s --max-time 5 https://am.i.mullvad.net/json 2>/dev/null | grep -q "\"mullvad_exit_ip\":true"; then
                vpn_detected=true
                vpn_evidence="Mullvad VPN connection detected via API check"
                return
            fi
            
            # Try another API (generic VPN detection)
            if curl -s --max-time 5 https://ipinfo.io/json 2>/dev/null | grep -q "\"org\":.*VPN\|\"org\":.*Host\|\"company\":.*VPN"; then
                vpn_detected=true
                vpn_evidence="VPN connection detected via IP information"
                return
            fi
        fi
    fi
}

# Try API-based detection as a last resort
# Commented out by default to avoid network requests unless needed
# Uncomment this line if you want to enable this check
# check_vpn_leak_detection

# Print results
if [ "$vpn_detected" = true ]; then
    echo -e "${RED}VPN detected: ${vpn_evidence}${NC}"
    echo -e "${YELLOW}This may interfere with git push operations to GitHub.${NC}"
    echo -e "${YELLOW}Consider disconnecting your VPN before pushing.${NC}"
    exit 1
else
    echo -e "${GREEN}No VPN detected.${NC}"
    exit 0
fi
