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

greetings()
{
    title_message "JARBS - Jonatas' Auto-Rice Bootstrapping Script.\n\nThis script will automatically install a full arch linux\nsystem with i3-gaps as a window manager.\n\nThe system comes pre-configured with a focus on a\nterminal based workflow."
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

ask_user()
{
    title_message "Info Gathering"

    read -p "Enter a name for the computer: " host_name
    echo

    read -sp "Enter root password: " root_pass1 && echo
    read -sp "Retype root password: " root_pass2 && echo
    while ! [[ -n ${root_pass1} && ${root_pass1} == ${root_pass2} ]]; do
        echo "Passwords do not match. Try again."
        read -sp "Enter root password: " root_pass1 && echo
        read -sp "Retype root password: " root_pass2 && echo
    done
    unset root_pass2
    echo

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
    title_message "The installation is ready to start.\n\nFrom this point onwards the script will install\neverything automatically, without asking you anything\nor giving any warnings.\n\nBe aware that the script will DELETE your entire disk.\nThe disk that will be erased is the one in /dev/sda.\nIf you have multiple drives and that one is\nnot the right one, DO NOT continue the installation." || fatal_error "Process aborted."

    confirm "Do you want to start the installation process? [y/N] " || fatal_error "Process aborted."
}

pre_install()
{
    title_message "Clock synchronization"
    timedatectl set-ntp true

    title_message "Disk partitioning"
    parted -s /dev/sda mklabel gpt
    echo
    parted -s /dev/sda mkpart esp fat32 0% 129MiB set 1 boot on name 1 ESP
    echo
    parted -s /dev/sda mkpart arch ext4 129MiB 32897MiB name 2 arch
    echo
    parted -s /dev/sda mkpart home ext4 32897MiB 100% name 3 home
    sleep 2

    title_message "Filesystems creation"
    mkfs.vfat -F32 -n ESP /dev/disk/by-partlabel/ESP
    echo
    mkfs.ext4 -F -m 0 -T big -L arch /dev/disk/by-partlabel/arch
    echo
    mkfs.ext4 -F -m 0 -T big -L home /dev/disk/by-partlabel/home
    sleep 2

    title_message "Partition mounting"
    mount PARTLABEL=arch /mnt
    mkdir -p /mnt/{boot,home}
    mount PARTLABEL=ESP /mnt/boot
    mount PARTLABEL=home /mnt/home

    title_message "Mirrolist Update"
    cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
    curl "https://www.archlinux.org/mirrorlist/?country=BR&use_mirror_status=on" | sed -e 's/^#Server/Server/' -e '/^#/d' > /etc/pacman.d/mirrorlist
    echo "Mirrorlist:"
    cat /etc/pacman.d/mirrorlist
    sleep 3
}

base_install()
{
    title_message "Base Installation"
    pacstrap /mnt base base-devel intel-ucode
    title_message "End of Base Installation"
    sleep 3

    title_message "fstab Generation"
    genfstab -t PARTUUID -p /mnt > /mnt/etc/fstab
}

go_chroot()
{
    title_message "Temp files migration."
    echo "${host_name}" > /mnt/etc/hostname
    echo "${user_name}" > /mnt/.uname
    echo "${root_pass1}" > /mnt/.rpass
    echo "${user_pass1}" > /mnt/.upass
    unset root_pass1
    unset user_pass1

    title_message "Downloading and Starting JARBS"
    curl https://raw.githubusercontent.com/jonatascmedeiros/JARBS/master/jarbs.sh > /mnt/jarbs.sh && arch-chroot /mnt bash jarbs.sh && rm /mnt/jarbs.sh
}

reboot_computer()
{
    title_message "Partitions Unmounting"
    umount -R /mnt
    title_message "Rebooting"
    sleep 2
    reboot
}

confirm_reboot()
{
    confirm "Reboot the computer?" && reboot_computer
}

greetings
check_requirements
ask_user
confirm_install

# start automatic installation
pre_install
base_install
go_chroot
confirm_reboot
