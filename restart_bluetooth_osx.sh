#!/bin/bash

# To run this script you need to give execute permission.
# $chmod +x restart_bluetooth.sh;
# If you want only to restart:
# $ ./restart_bluetooth.sh;
# If you want to turn bluetooth on;
# $ ./restart_bluetooth.sh 1;
# If you want to turn bluetooth off;
# $ ./restart_bluetooth.sh 0;

#Default
output="Bluetooth restarted";

if [ $# -eq 1 ]; then
 if [ $1 -eq "1" ]; then
        sudo defaults write /Library/Preferences/com.apple.Bluetooth.plist ControllerPowerState 1
        output="Bluetooth is on";
 elif [ $1 -eq "0" ]; then
        sudo defaults write /Library/Preferences/com.apple.Bluetooth.plist ControllerPowerState 0
        output="Bluetooth is off";
 fi;
fi;


sudo kextunload -b com.apple.iokit.BroadcomBluetoothHostControllerUSBTransport
sudo kextload -b com.apple.iokit.BroadcomBluetoothHostControllerUSBTransport

echo $output;