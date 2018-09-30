#!/bin/bash

# Jonatas' Auto Rice Bootstrapping Script (JARBS)
# by Jonatas Medeiros <jonatascmedeiros@gmail.com>
# as a heavily modified version of Luke Smith's LARBS
# License: GNU GPLv3

[ -z ${aurhelper+x} ] && aurhelper="yay"
[ -z ${time_zone+x} ] && time_zone="America/Fortaleza"
[ -z ${progs_file+x} ] && progs_file="https://raw.githubusercontent.com/jonatascmedeiros/JARBS/master/progs.csv"
[ -z ${dotfiles_repo+x} ] && dotfiles_repo="https://github.com/jonatascmedeiros/dotfiles.git"

fatal_error()
{
    dialog --msgbox "$1\n\nThe installation process cannot continue." --ok-label "Exit" 0 0
    clear
    exit 1
}

new_perms()
{
    sed -i "/#JARBS/d" /etc/sudoers
    echo -e "$@ #JARBS" >> /etc/sudoers ;
}

root_config()
{
    dialog --infobox "Configuring system..." 0 0

    # root password
    root_pass=$(cat /tmp/.rpass)
    echo "root:${root_pass}" | chpasswd
    rm .rpass

    # time
    ln -sf /usr/share/zoneinfo/${time_zone} /etc/localtime &>/dev/null
    hwclock -wu

    # locale
    sed -i 's/^#en_US/en_US/' /etc/locale.gen
    locale-gen &>/dev/null
    echo "LANG=en_US.UTF-8" > /etc/locale.conf

    # network
    dialog --infobox "Installing NetworkManager..." 0 0
    pacman --noconfirm --needed -S networkmanager &>/dev/null
    systemctl enable NetworkManager &>/dev/null

    # bootloader
    bootctl install &>/dev/null
    echo -e 'default\tarch\ntimeout\t3\neditor\t0' > /boot/loader/loader.conf
    echo -e 'title\tArch Linux\nlinux\t/vmlinuz-linux\ninitrd\t/intel-ucode.img\ninitrd\t/initramfs-linux.img\noptions\troot=PARTLABEL=arch rw' > /boot/loader/entries/arch.conf

    # ssd settings
    systemctl enable fstrim.timer &>/dev/null
    echo -e "ACTION==\"add|change\", KERNEL==\"sd[a-z]\", ATTR{queue/rotational}==\"0\", ATTR{queue/scheduler}=\"deadline\"" > /etc/udev/rules.d/60-schedulers.rules
}

swap_file()
{
    dialog --infobox "Creating swap file..." 0 0
    fallocate -l 512M /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo -e "# Swap File\n/swapfile\tnone\tswap\tdefaults\t0 0\n" >> /etc/fstab
}

user_config()
{
    dialog --infobox "Configuring new user..." 0 0
    user_name=$(cat /tmp/uname)
    useradd -m -g wheel -s /bin/bash \"${user_name}\" &>/dev/null
    user_pass=$(cat /tmp/.upass)
    echo "${user_name}:${user_pass}" | chpasswd
    rm .upass uname
    new_perms "%wheel ALL=(ALL) NOPASSWD: ALL"
}

refresh_keys()
{
    dialog --infobox "Refreshing pacman keys..." 0 0
    pacman-key --init &>/dev/null
    pacman-key --populate archlinux &>/dev/null
    pacman-key --refresh-keys &>/dev/null
}

install_aur_helper()
{
    [[ -f /usr/bin/${aurhelper} ]] || (
    dialog --infobox "Installing \"${aurhelper}\", an AUR helper..." 0 0

    cd /tmp
    rm -rf /tmp/"${aurhelper}"*

    curl -sO https://aur.archlinux.org/cgit/aur.git/snapshot/"${aurhelper}".tar.gz && sudo -u "${user_name}" tar -xvf "${aurhelper}".tar.gz &>/dev/null && cd "${aurhelper}" && sudo -u "${user_name}" makepkg --noconfirm -si &>/dev/null

    cd /tmp) ;
}

git_make_install()
{
    dir=$(mktemp -d)
    dialog --infobox "Installing \`$(basename $1)\` ($n_prog of $total_progs) via \`git\` and \`make\`. $(basename $1) $2." 5 70
    git clone --depth 1 "$1" "$dir" &>/dev/null
    cd "$dir" || fatal_error "git failed." 
    make &>/dev/null
    make install &>/dev/null
    cd /tmp ;
}

pac_install()
{
    dialog --infobox "Installing \`$1\` ($n_prog of $total_progs). $1 $2." 5 70
    pacman --noconfirm --needed -S "$1" &>/dev/null
}

aur_install()
{
    dialog --infobox "Installing \`$1\` ($n_prog of $total_progs) from the AUR. $1 $2." 5 70
    grep "^$1$" <<< "$aur_installed" && return
    sudo -u $user_name $aurhelper -S --noconfirm "$1" &>/dev/null
}

install_progs()
{
    dialog --infobox "Preparing to install programs..." 4 60
    ([ -f "$progs_file" ] && cp "$progs_file" /tmp/progs.csv) || curl -Ls "$progs_file" > /tmp/progs.csv
    total_progs=$(wc -l < /tmp/progs.csv)
    aur_installed=$(pacman -Qm | awk '{print $1}')
    while IFS=, read -r tag program comment; do
        n_prog=$((n_prog+1))
        case "$tag" in
            "") pac_install "$program" "$comment" ;;
            "A") aur_install "$program" "$comment" ;;
            "G") git_make_install "$program" "$comment" ;;
        esac
    done < /tmp/progs.csv ;
}

get_git_repo()
{
    dialog --infobox "Downloading and installing config files..." 4 60
    dir=$(mktemp -d)
    chown -R "${user_name}":wheel "$dir"
    sudo -u "${user_name}" git clone --depth 1 "$1" "$dir"/git_repo &>/dev/null && sudo -u "${user_name}" mkdir -p "$2" && sudo -u "${user_name}" cp -rT "$dir"/git_repo "$2"
}

service_init()
{
    for service in "$@"; do
        dialog --infobox "Enabling \"${service}\"..." 4 40
        systemctl enable "${service}"
    done ;
}

systembeep_off()
{
    dialog --infobox "Getting rid of error beep sound..." 10 50
	rmmod pcspkr
	echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf ;
}

final_configs()
{
    new_perms "%wheel ALL=(ALL) ALL\\n%wheel ALL=(ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/packer -Syu,/usr/bin/packer -Syyu,/usr/bin/systemctl restart NetworkManager,/usr/bin/rc-service NetworkManager restart,/usr/bin/pacman -Syyu --noconfirm,/usr/bin/loadkeys,/usr/bin/yay"

    sed -i "s/^#Color/Color/g" /etc/pacman.conf
    systembeep_off
}

final_message()
{
    dialog --msgbox "The installation process is finished.\n\nReboot the computer." --ok-label "Reboot" 0 0
}

root_config
swap_file
user_config
refresh_keys
install_aur_helper
install_progs
get_git_repo "${dotfiles_repo}" "/home/${user_name}"
get_git_repo "https://github.com/LukeSmithxyz/mozillarbs.git" "/home/${user_name}/.mozilla/firefox"
service_init NetworkManager cronie
final_configs
final_message
