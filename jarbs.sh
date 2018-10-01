#!/bin/bash

# Jonatas' Auto Rice Bootstrapping Script (JARBS)
# by Jonatas Medeiros <jonatascmedeiros@gmail.com>
# as a heavily modified version of Luke Smith's LARBS
# License: GNU GPLv3

[ -z ${aurhelper+x} ] && aurhelper="yay"
[ -z ${time_zone+x} ] && time_zone="America/Fortaleza"
[ -z ${progs_file+x} ] && progs_file="https://raw.githubusercontent.com/jonatascmedeiros/JARBS/master/progs.csv"
[ -z ${dotfiles_repo+x} ] && dotfiles_repo="https://github.com/jonatascmedeiros/dotfiles.git"

title_message()
{
    echo "*********************************************************"
    echo -e "$1"
    echo "*********************************************************"
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

new_perms()
{
    sed -i "/#JARBS/d" /etc/sudoers
    echo -e "$@ #JARBS" >> /etc/sudoers ;
}

root_config()
{
    title_message "Starting JARBS"

    echo "root password setting."
    root_pass=$(cat /tmp/.rpass)
    echo "root:${root_pass}" | chpasswd
    rm /tmp/.rpass

    echo "Time zone setting."
    ln -sf /usr/share/zoneinfo/${time_zone} /etc/localtime
    hwclock -wu

    echo "Locale setting."
    sed -i 's/^#en_US/en_US/' /etc/locale.gen
    locale-gen
    echo "LANG=en_US.UTF-8" > /etc/locale.conf

    echo "Network Manager installation."
    pacman --noconfirm --needed -S networkmanager
    systemctl enable NetworkManager

    echo "Bootloader installation"
    bootctl install
    echo -e 'default\tarch\ntimeout\t3\neditor\t0' > /boot/loader/loader.conf
    echo -e 'title\tArch Linux\nlinux\t/vmlinuz-linux\ninitrd\t/intel-ucode.img\ninitrd\t/initramfs-linux.img\noptions\troot=PARTLABEL=arch rw' > /boot/loader/entries/arch.conf

    echo "SSD settings."
    systemctl enable fstrim.timer
    echo -e "ACTION==\"add|change\", KERNEL==\"sd[a-z]\", ATTR{queue/rotational}==\"0\", ATTR{queue/scheduler}=\"deadline\"" > /etc/udev/rules.d/60-schedulers.rules
}

swap_file()
{
    title_message "Swap File Creation"
    fallocate -l 512M /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo -e "# Swap File\n/swapfile\tnone\tswap\tdefaults\t0 0\n" >> /etc/fstab
}

user_config()
{
    title_message "New User Configuration"
    user_name=$(cat /tmp/uname)
    useradd -m -g wheel -s /bin/bash "${user_name}"
    user_pass=$(cat /tmp/.upass)
    echo "${user_name}:${user_pass}" | chpasswd
    rm /tmp/.upass /tmp/uname
    new_perms "%wheel ALL=(ALL) NOPASSWD: ALL"
}

refresh_keys()
{
    title_message "Refreshing Pacman Keys"
    pacman-key --init
    pacman-key --populate archlinux
    pacman-key --refresh-keys
}

install_aur_helper()
{
    [[ -f /usr/bin/${aurhelper} ]] || (
    title_message "${aurhelper} Installation"

    cd /tmp
    rm -rf /tmp/"${aurhelper}"*

    curl -O https://aur.archlinux.org/cgit/aur.git/snapshot/"${aurhelper}".tar.gz && sudo -u "${user_name}" tar -xvf "${aurhelper}".tar.gz && cd "${aurhelper}" && sudo -u "${user_name}" makepkg --noconfirm -si

    cd /tmp) ;
}

git_make_install()
{
    echo "Installing \`$(basename $1)\` ($n_prog of $total_progs) via \`git\` and \`make\`. $(basename $1) $2."
    dir=$(mktemp -d)
    git clone --depth 1 "$1" "$dir"
    cd "$dir" || fatal_error "git failed." 
    make
    make install
    cd /tmp ;
}

pac_install()
{
    echo "Installing \`$1\` ($n_prog of $total_progs). $1 $2."
    pacman --noconfirm --needed -S "$1"
}

aur_install()
{
    echo "Installing \`$1\` ($n_prog of $total_progs) from the AUR. $1 $2."
    grep "^$1$" <<< "$aur_installed" && return
    sudo -u ${user_name} ${aurhelper} -S --noconfirm "$1"
}

install_progs()
{
    title_message "Programs Installation"
    echo "Program list download."
    ([ -f "$progs_file" ] && cp "$progs_file" /tmp/progs.csv) || curl -L "$progs_file" > /tmp/progs.csv
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
    title_message "Download and Installation of $(basename $1)."
    dir=$(mktemp -d)
    chown -R "${user_name}":wheel "$dir"
    sudo -u "${user_name}" git clone --depth 1 "$1" "$dir"/git_repo && sudo -u "${user_name}" mkdir -p "$2" && sudo -u "${user_name}" cp -rT "$dir"/git_repo "$2"
}

service_init()
{
    title_message "Enabling Services"
    for service in "$@"; do
        echo "Enabling \"${service}\"."
        systemctl enable "${service}"
    done ;
}

system_beep_off()
{
    echo "Getting rid of error beep sound."
	rmmod pcspkr
	echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf ;
}

final_configs()
{
    title_message "Finishing Things Off"

    new_perms "%wheel ALL=(ALL) ALL\\n%wheel ALL=(ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/packer -Syu,/usr/bin/packer -Syyu,/usr/bin/systemctl restart NetworkManager,/usr/bin/rc-service NetworkManager restart,/usr/bin/pacman -Syyu --noconfirm,/usr/bin/loadkeys,/usr/bin/yay"

    sed -i "s/^#Color/Color/g" /etc/pacman.conf
    system_beep_off
}

final_message()
{
    title_message "The installation process is finished."
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
