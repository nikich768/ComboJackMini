#!/bin/bash

if [[ $EUID -ne 0 ]];
then
    exec sudo /bin/bash "$0" "$@"
fi

cd "$( dirname "${BASH_SOURCE[0]}" )"

# uninstall
sudo launchctl unload /Library/LaunchDaemons/ComboJackNano.plist
sudo rm /Library/LaunchDaemons/ComboJackNano.plist
sudo spctl --remove /usr/local/sbin/ComboJackNano
sudo rm /usr/local/sbin/ComboJackNano
echo
echo "ComboJackNano is unloaded and uninstalled."
echo
exit 0
