#!/bin/bash

# Jonatas' Auto Rice Bootstrapping Script (JARBS)
# by Jonatas Medeiros <jonatascmedeiros@gmail.com>
# License: GNU GPLv3

[ -z ${user_name+x} ] && user_name="jonatas"
[ -z ${host_name+x} ] && host_name="/tmp/host_name"
[ -z ${root_pass+x} ] && root_pass="/tmp/.rpass"
[ -z ${user_pass+x} ] && user_pass="/tmp/.upass"

fatal_error()
{
    dialog --msgbox "$1\n\nThe installation process cannot continue." --ok-label "Exit" 0 0
    clear
    exit 1
}

check_requirements()
{
    if [[ `whoami` != "root" ]]; then
        fatal_error "You need to run this script as root."
    fi
    if [[ ! $(ping -c 1 google.com) ]]; then
        fatal_error "You need an internet connection."
    fi
}

greetings()
{
    dialog --msgbox "JARBS - Jonatas' Auto-Rice Bootstrapping Script.\n\nThis script will automatically install a full arch linux system with i3-gaps as a window manager.\n\nThe system comes pre-configured with a focus on a terminal based workflow." 0 0
}

ask_user()
{
    dialog --no-cancel --inputbox "Enter the name for the computer:" 0 0 2>${host_name}

    root_pass1=$(dialog --no-cancel --passwordbox "Enter the password for root:" 0 0 3>&1 1>&2 2>&3 3>&1)
    root_pass2=$(dialog --no-cancel --passwordbox "Retype the password for root:" 0 0 3>&1 1>&2 2>&3 3>&1)
    while ! [[ -n ${root_pass1} && ${root_pass1} == ${root_pass2} ]]; do
        root_pass1=$(dialog --no-cancel --passwordbox "Passwords do not match or are empty.\nEnter the password for root:" 0 0 3>&1 1>&2 2>&3 3>&1)
        root_pass2=$(dialog --no-cancel --passwordbox "Retype the password for root:" 0 0 3>&1 1>&2 2>&3 3>&1)
    done
    echo "${root_pass1}" > ${root_pass}
    unset root_pass1
    unset root_pass2

    user_pass1=$(dialog --no-cancel --passwordbox "Enter a password for ${user_name}:" 0 0 3>&1 1>&2 2>&3 3>&1)
    user_pass2=$(dialog --no-cancel --passwordbox "Retype the password for ${user_name}:" 0 0 3>&1 1>&2 2>&3 3>&1)
    while ! [[ ${user_pass1} == ${user_pass2} ]]; do
        unset user_pass2
        user_pass1=$(dialog --no-cancel --passwordbox "Passwords do not match.\nEnter a password for ${user_name}:" 0 0 3>&1 1>&2 2>&3 3>&1)
        user_pass2=$(dialog --no-cancel --passwordbox "Retype the password for ${user_name}:" 0 0 3>&1 1>&2 2>&3 3>&1)
    done
    echo "${user_pass1}" > ${user_pass}
    unset user_pass1
    unset user_pass2
}

confirm_install()
{
    dialog --yesno "The installation is ready to start.\n\nFrom this point onwards the script will install everything automatically, without asking you anything or giving any warnings.\n\nBe aware that the script will DELETE your entire disk. The disk that will be erased is the one in /dev/sda. If you have multiple drives and that one is not the right one, DO NOT continue the installation.\n\nDo you want to start the installation process?" 0 0 || fatal_error "Process aborted."
}

pre_install()
{
    timedatectl set-ntp true

    dialog --infobox "Partitioning the disk..." 0 0
    parted /dev/sda mklabel gpt &>/dev/null
    parted /dev/sda mkpart esp fat32 0% 129MiB set 1 boot on name 1 ESP &>/dev/null
    parted /dev/sda mkpart arch ext4 129MiB 32897MiB name 2 arch &>/dev/null
    parted /dev/sda mkpart home ext4 32897MiB 100% name 3 home &>/dev/null

    mkfs.vfat -F32 -n ESP /dev/disk/by-partlabel/ESP &>/dev/null
    mkfs.ext4 -q -m 0 -T big -L arch /dev/disk/by-partlabel/arch
    mkfs.ext4 -q -m 0 -T big -L home /dev/disk/by-partlabel/home

    mount PARTLABEL=arch /mnt
    mkdir -p /mnt/{boot,home}
    mount PARTLABEL=ESP /mnt/boot
    mount PARTLABEL=home /mnt/home

    dialog --infobox "Updating the mirrorlist..." 0 0
    cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
    curl -s "https://www.archlinux.org/mirrorlist/?country=BR&use_mirror_status=on" | sed -e 's/^#Server/Server/' -e '/^#/d' > /etc/pacman.d/mirrorlist
}

base_install()
{
    dialog --infobox "Installing base system..." 0 0
    pacstrap /mnt base base-devel intel-ucode dialog &>/dev/null
    genfstab -t PARTUUID -p /mnt > /mnt/etc/fstab
}

go_chroot()
{
    mv ${host_name} /mnt/etc/hostname
    mv ${root_pass} /mnt/${root_pass}
    mv ${user_pass} /mnt/${user_pass}
    echo "${user_name}" > /mnt/uname

    curl -s https://raw.githubusercontent.com/jonatascmedeiros/JARBS/master/jarbs.sh > /mnt/jarbs.sh && arch-chroot /mnt bash jarbs.sh && rm /mnt/jarbs.sh
}

check_requirements
greetings
ask_user
confirm_install

# start automatic installation
pre_install
base_install
go_chroot

dialog --infobox "Rebooting..." 0 0
umount -R /mnt
reboot
