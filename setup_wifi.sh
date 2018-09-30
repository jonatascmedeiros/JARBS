#!/bin/bash

# Jonatas' Auto Rice Bootstrapping Script (JARBS)
# by Jonatas Medeiros <jonatascmedeiros@gmail.com>
# License: GNU GPLv3

# This file is meant to be put inside the arch installation iso using the archiso
# package, so that the initial wifi configuration can be done as part of the
# jarbs setup. 

wifi_connection()
{
    WIFI_DEV=$(ip link | awk '$2 ~ /wl/ {print $2}')
    if [[ -n $WIFI_DEV ]]; then
        rfkill unblock wlan
        ip link set $WIFI_DEV down
        wifi-menu
    else
        dialog --msgbox "No wifi device found!" 0 0
    fi
}

fatal_error()
{
    dialog --msgbox "The installation process cannot continue." --ok-label "Exit" 0 0
    clear
    exit 1
}

# Checks if we have internet connection (if using ethernet, nothing is done).
# If using wifi, a dialog asks if we want to set it up, if so, we call
# wifi_connection(). If not, we call fatal_error() to exit.
until ping -c 1 www.google.com &>/dev/null; do
    dialog --yesno "Not connected to the internet.\nWould you like to setup wifi connection?" 0 0 || fatal_error()
    wifi_connection()
done

curl -sO https://raw.githubusercontent.com/jontascmedeiros/JARBS/master/setup.sh && bash setup.sh
