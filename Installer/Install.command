#!/bin/bash

cd "$( dirname "${BASH_SOURCE[0]}" )"

# Clean previous installations
sudo launchctl unload /Library/LaunchDaemons/com.ComboJackMini.plist 2> /dev/null
sudo rm /Library/LaunchDaemons/com.ComboJackMini.plist 2> /dev/null
sudo rm /usr/local/bin/ComboJackMini 2> /dev/null
sudo rm /usr/local/sbin/ComboJackMini 2> /dev/null

# Install daemon and load
sudo mkdir /usr/local/bin 2> /dev/null
sudo cp ComboJackMini /usr/local/bin
sudo xattr -c /usr/local/bin/ComboJackMini
sudo cp com.ComboJackMini.plist /Library/LaunchDaemons/
sudo launchctl load /Library/LaunchDaemons/com.ComboJackMini.plist
echo
echo "ComboJackMini was installed and loaded."
echo
sleep 1
exit 0
