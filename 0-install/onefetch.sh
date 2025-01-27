
# Auto-elevate if no root priveleges
if [ "$(id -u)" -ne 0 ]; then echo -e "\033[31mElevation required; rerunning as sudo...\033[0m\n"; exec sudo "$0" "$@"; fi

apt install cmake
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
