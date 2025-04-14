#!/bin/bash
set -e

CURRENT=$(onefetch --version | awk '{print $2}')
LATEST=$(curl -s https://api.github.com/repos/o2sh/onefetch/releases/latest | grep tag_name | cut -d '"' -f 4)

if [ "$CURRENT" != "$LATEST" ]; then
    echo "Updating onefetch from $CURRENT to $LATEST..."
    ARCH=$(uname -m)
    if [[ "$ARCH" == "x86_64" ]]; then ARCH=amd64; fi

    TMPDIR=$(mktemp -d)
    cd "$TMPDIR"

    curl -LO "https://github.com/o2sh/onefetch/releases/download/$LATEST/onefetch-linux-$ARCH.tar.gz"
    tar -xf onefetch-linux-$ARCH.tar.gz
    sudo mv onefetch /usr/local/bin/
    echo "Updated to version $LATEST."
else
    echo "Onefetch is already up to date (version $CURRENT)."
fi

