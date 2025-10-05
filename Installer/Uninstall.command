#!/bin/bash

# Unload daemon and uninstall
sudo launchctl unload /Library/LaunchDaemons/com.ComboJackMini.plist
sudo rm /Library/LaunchDaemons/com.ComboJackMini.plist
sudo rm /usr/local/bin/ComboJackMini
echo
echo "ComboJackMini was unloaded and uninstalled."
echo
sleep 1
exit 0
