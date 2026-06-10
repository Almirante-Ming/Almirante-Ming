#!/bin/bash
if ! which apt > /dev/null; then
    echo "This script is only for Debian and Ubuntu-based systems with the apt package manager."
    exit 1
fi
read -p "This will install the systemd service for automatic updates (apt). Proceed? (Y/N)" decision
case "$decision" in
    [Yy]* )
        echo "Setting up rp-auto-update service..."
        sudo cp rp-auto-update.service /etc/systemd/system/
        sudo cp rp-auto-update.timer /etc/systemd/system/
        chmod +x rp-auto-update.sh # ensure it's executable
        sudo cp rp-auto-update.sh /usr/local/bin/
        sudo systemctl daemon-reload
        sudo systemctl enable --now rp-auto-update.timer
        echo "rp-auto-update service installed and enabled."
        exit 0
        ;;
    * )
        echo "Aborting setup."
        exit 100
        ;;
esac