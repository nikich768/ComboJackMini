#!/bin/bash
cd `dirname $0`

rm -f ../Installer/ComboJackNano
xcodebuild -configuration Release || exit 1
cp -f build/Release/ComboJackNano ../Installer/
rm -rf ./build
rm -rf ./ComboJackNano--RELEASE.zip
