#!/bin/bash

if [[ $EUID -ne 0 ]];
then
    exec sudo /bin/bash "$0" "$@"
fi

cd "$( dirname "${BASH_SOURCE[0]}" )"

# Clean previous installations

sudo launchctl unload /Library/LaunchDaemons/com.ComboJackMini.plist 2> /dev/null
sudo rm -f /Library/LaunchDaemons/com.ComboJackMini.plist 2> /dev/null

# install ComboJackMini
sudo mkdir /usr/local/sbin 2> /dev/null
sudo cp ComboJackMini /usr/local/sbin
sudo chmod 755 /usr/local/sbin/ComboJackMini
sudo chown root:wheel /usr/local/sbin/ComboJackMini
sudo spctl --add /usr/local/sbin/ComboJackMini

# install com.ComboJackMini.plist
sudo cp com.ComboJackMini.plist /Library/LaunchDaemons/
sudo chmod 644 /Library/LaunchDaemons/com.ComboJackMini.plist
sudo chown root:wheel /Library/LaunchDaemons/com.ComboJackMini.plist
sudo launchctl load /Library/LaunchDaemons/com.ComboJackMini.plist
echo
echo "ComboJackMini is installed and loaded."
echo
exit 0
