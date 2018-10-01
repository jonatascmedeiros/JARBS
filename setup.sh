#!/bin/bash

# Jonatas' Auto Rice Bootstrapping Script (JARBS)
# by Jonatas Medeiros <jonatascmedeiros@gmail.com>
# License: GNU GPLv3

title_message()
{
    echo -e "\n*********************************************************"
    echo -e "$1"
    echo "---------------------------------------------------------"
}

fatal_error()
{
    title_message "$1\nThe installation process cannot continue."
    exit 1
}

confirm()
{
    read -r -p "${1:-Are you sure? [y/N]} " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            true
            ;;
        *)
            false
            ;;
    esac
}

check_requirements()
{
    title_message "Requirements Check"
    echo -n "Checking if root..."
    if [[ `whoami` != "root" ]]; then
        fatal_error "You need to run this script as root."
    fi
    echo "OK"
    echo -n "Checking internet connection..."
    if [[ ! $(ping -c 1 google.com) ]]; then
        fatal_error "You need an internet connection."
    fi
    echo "OK"
}

greetings()
{
    title_message "JARBS - Jonatas' Auto-Rice Bootstrapping Script.\n\nThis script will automatically install a full arch linux\nsystem with i3-gaps as a window manager.\n\nThe system comes pre-configured with a focus on a\nterminal based workflow."
}

ask_user()
{
    title_message "Info Gathering"

    read -p "Enter a name for the computer: " host_name

    read -sp "Enter root password: " root_pass1 && echo
    read -sp "Retype root password: " root_pass2 && echo
    while ! [[ -n ${root_pass1} && ${root_pass1} == ${root_pass2} ]]; do
        echo "Passwords do not match. Try again."
        read -sp "Enter root password: " root_pass1 && echo
        read -sp "Retype root password: " root_pass2 && echo
    done
    unset root_pass2

    read -p "Enter name of new user: " user_name
    read -sp "Enter password for ${user_name}: " user_pass1 && echo
    read -sp "Retype password for ${user_name}: " user_pass2 && echo
    while ! [[ -n ${user_pass1} && ${user_pass1} == ${user_pass2} ]]; do
        echo "Passwords do not match. Try again."
        read -sp "Enter password for ${user_name}: " user_pass1 && echo
        read -sp "Retype password for ${user_name}: " user_pass2 && echo
    done
    unset user_pass2
}

confirm_install()
{
    title_message "The installation is ready to start.\n\nFrom this point onwards the script will install\neverything automatically, without asking you\nanything or giving any warnings.\n\nBe aware that the script will DELETE your entire disk.\nThe disk that will be erased is the one\nin /dev/sda. If you have multiple drives and that one\nis not the right one, DO NOT continue\nthe installation." || fatal_error "Process aborted."

    confirm "Do you want to start the installation process? [y/N] " || fatal_error "Process aborted."
}

pre_install()
{
    echo -n "Clock synchronization."
    timedatectl set-ntp true

    title_message "Preparing the Disk"

    echo "Disk partitioning."
    parted -s /dev/sda mklabel gpt
    parted -s /dev/sda mkpart esp fat32 0% 129MiB set 1 boot on name 1 ESP
    parted -s /dev/sda mkpart arch ext4 129MiB 32897MiB name 2 arch
    parted -s /dev/sda mkpart home ext4 32897MiB 100% name 3 home

    echo "Filesystems creation."
    mkfs.vfat -F32 -n ESP /dev/disk/by-partlabel/ESP
    mkfs.ext4 -F -m 0 -T big -L arch /dev/disk/by-partlabel/arch
    mkfs.ext4 -F -m 0 -T big -L home /dev/disk/by-partlabel/home

    echo "Partition mounting."
    mount PARTLABEL=arch /mnt
    mkdir -p /mnt/{boot,home}
    mount PARTLABEL=ESP /mnt/boot
    mount PARTLABEL=home /mnt/home

    title_message "Mirrolist Update"
    cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
    curl "https://www.archlinux.org/mirrorlist/?country=BR&use_mirror_status=on" | sed -e 's/^#Server/Server/' -e '/^#/d' > /etc/pacman.d/mirrorlist
}

base_install()
{
    title_message "Base Installation"
    pacstrap /mnt base base-devel intel-ucode dialog

    echo "fstab generation."
    genfstab -t PARTUUID -p /mnt > /mnt/etc/fstab
}

go_chroot()
{
    echo "Temp files migration."
    echo "${host_name}" > /mnt/etc/hostname
    echo "${user_name}" > /mnt/.uname
    echo "${root_pass1}" > /mnt/.rpass
    echo "${user_pass1}" > /mnt/.upass
    unset root_pass1
    unset user_pass1

    title_message "Downloading JARBS"
    curl https://raw.githubusercontent.com/jonatascmedeiros/JARBS/master/jarbs.sh > /mnt/jarbs.sh && arch-chroot /mnt bash jarbs.sh && rm /mnt/jarbs.sh
}

reboot_computer()
{
    echo "Partitions unmounting."
    umount -R /mnt
    title_message "Rebooting"
    reboot
}

check_requirements
greetings
ask_user
confirm_install

# start automatic installation
pre_install
base_install
go_chroot

confirm "Reboot the computer?" && reboot_computer
