#!/bin/bash

if [[ $EUID -ne 0 ]];
then
    exec sudo /bin/bash "$0" "$@"
fi

cd "$( dirname "${BASH_SOURCE[0]}" )"

# uninstall
sudo launchctl unload /Library/LaunchDaemons/com.ComboJackMini.plist
sudo rm /Library/LaunchDaemons/com.ComboJackMini.plist
sudo spctl --remove /usr/local/sbin/ComboJackMini
sudo rm /usr/local/sbin/ComboJackMini
echo
echo "ComboJackMini is unloaded and uninstalled."
echo
exit 0
