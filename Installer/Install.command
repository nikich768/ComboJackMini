#!/bin/bash

if [[ $EUID -ne 0 ]];
then
    exec sudo /bin/bash "$0" "$@"
fi

cd "$( dirname "${BASH_SOURCE[0]}" )"

# Clean previous installations

sudo launchctl unload /Library/LaunchDaemons/ComboJackNano.plist 2> /dev/null
Sudo rm -f /Library/LaunchDaemons/ComboJackNano.plist

# install ComboJackNano
sudo mkdir /usr/local/sbin 2> /dev/null
sudo cp ComboJackNano /usr/local/sbin
sudo chmod 755 /usr/local/sbin/ComboJackNano
sudo chown root:wheel /usr/local/sbin/ComboJackNano
sudo spctl --add /usr/local/sbin/ComboJackNano

# install ComboJackNano.plist
sudo cp ComboJackNano.plist /Library/LaunchDaemons/
sudo chmod 644 /Library/LaunchDaemons/ComboJackNano.plist
sudo chown root:wheel /Library/LaunchDaemons/ComboJackNano.plist
sudo launchctl load /Library/LaunchDaemons/ComboJackNano.plist
echo
echo "ComboJackNano is installed and loaded."
echo
exit 0
