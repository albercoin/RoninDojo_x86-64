#!/bin/bash

###
### Setup RoninDojo (x86_64 devices) - Updated
### Run with "sudo"
###

echo "********************************"
echo "*** RoninDojo x86_64 install ***"
echo "********************************"

sleep 1
sudo -v

echo "add user ronindojo"
useradd -s /bin/bash -m -c "RoninDojo" ronindojo -p rock
useradd -c "tor" tor && echo "ronindojo    ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
echo "Defaults    timestamp_timeout=60" >> /etc/sudoers

# removes the first user login requirement with monitor and keyboard
rm /root/.not_logged_in_yet &>/dev/null

echo "set hostname"
# initial hostname before automation
hostnamectl set-hostname ronindebian

# RoninDojo part
TMPDIR=/var/tmp
USER="ronindojo"
PASSWORD="$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 21)"
ROOTPASSWORD="$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 21)"
FULLNAME="RoninDojo"
TIMEZONE="UTC"
LOCALE="en_US.UTF-8"
HOSTNAME="RoninDojo"
KEYMAP="us"

_create_oem_install() {
    pam-auth-update --package

    chpasswd <<<"root:$ROOTPASSWORD"
    useradd -m -G wheel,sys,audio,input,video,storage,lp,network,users,power -s /bin/bash "$USER" &>/dev/null

    # Ensure service unit uses correct User and WorkingDirectory
    if [ -f /usr/lib/systemd/system/ronin-setup.service ]; then
        sed -i -e "s/^User=.*$/User=${USER}/" \
               -e "s|^WorkingDirectory=.*$|WorkingDirectory=/home/${USER}|" /usr/lib/systemd/system/ronin-setup.service
    fi

    # Ensure /home/${USER} exists and correct ownership
    if [ ! -d /home/"$USER" ]; then
        mkdir -p /home/"$USER"
    fi
    chown -R "$USER":"$USER" /home/"$USER"

    chfn -f "$FULLNAME" "$USER" &>/dev/null
    chpasswd <<<"$USER:$PASSWORD"

    mkdir -p /home/"${USER}"/.config/RoninDojo
    cat <<EOF >/home/"${USER}"/.config/RoninDojo/info.json
{"user":[{"name":"${USER}","password":"${PASSWORD}"},{"name":"root","password":"${ROOTPASSWORD}"}]}
EOF
    chown -R "${USER}":"${USER}" /home/"${USER}"/.config

    timedatectl set-timezone $TIMEZONE &>/dev/null
    timedatectl set-ntp true &>/dev/null

    sed -i "s/#$LOCALE/$LOCALE/" /etc/locale.gen &>/dev/null
    locale-gen &>/dev/null
    localectl set-locale $LOCALE &>/dev/null

    if [ -f /etc/sway/inputs/default-keyboard ]; then
        sed -i "s/us/$KEYMAP/" /etc/sway/inputs/default-keyboard
        if [ "$KEYMAP" = "uk" ]; then
            sed -i "s/uk/gb/" /etc/sway/inputs/default-keyboard
        fi
    fi

    hostnamectl set-hostname $HOSTNAME &>/dev/null

    resize-fs &>/dev/null
    loadkeys "$KEYMAP"

    sed -i 's/hosts: .*$/hosts: files mdns_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] dns mdns/' /etc/nsswitch.conf
    sed -i 's/.*host-name=.*$/host-name=ronindojo/' /etc/avahi/avahi-daemon.conf
    if ! systemctl is-enabled --quiet avahi-daemon; then
        systemctl enable --quiet avahi-daemon
    fi

    sed -i -e "s/PermitRootLogin yes/#PermitRootLogin prohibit-password/" \
           -e "s/PermitEmptyPasswords yes/#PermitEmptyPasswords no/" /etc/ssh/sshd_config

    # Sudo timeout already set earlier
    # Passwordless sudo already in sudoers

    echo -e "domain .local\nnameserver 1.1.1.1\nnameserver 1.0.0.1" >> /etc/resolv.conf

    mkdir -p /home/"$USER"/.logs
    touch /home/"$USER"/.logs/setup.logs
    touch /home/"$USER"/.logs/post.logs
    chown -R "$USER":"$USER" /home/"$USER"/.logs
}

_prep_npm() {
    # install Nodejs 20.x
    curl -sL https://deb.nodesource.com/setup_20.x | bash -
    apt-get update
    apt-get install -y nodejs
    npm install pm2 -g
}

_prep_docker() {
    # Remove Debian Docker packages
    for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
        apt-get remove -y $pkg
    done

    apt-get update
    apt-get install -y ca-certificates curl

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
        | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    usermod -aG docker "$USER"
}

_ronin_ui_avahi_service() {
    if [ ! -f /etc/avahi/services/http.service ]; then
        tee /etc/avahi/services/http.service <<EOF >/dev/null
<?xml version="1.0" standalone='no'?><!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
 <name replace-wildcards="yes">%h Web Application</name>
 <service>
  <type>_http._tcp</type>
  <port>80</port>
 </service>
</service-group>
EOF
    fi
    sed -i 's/hosts: .*$/hosts: files mdns_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] dns mdns/' /etc/nsswitch.conf
    grep -q "host-name=ronindojo" /etc/avahi/avahi-daemon.conf \
        || sed -i 's/.*host-name=.*$/host-name=ronindojo/' /etc/avahi/avahi-daemon.conf
    systemctl enable --quiet avahi-daemon
}

_install_ronin_ui() {
    roninui_version_file="https://ronindojo.io/downloads/RoninUI/version.json"
    gui_api=$(_rand_passwd 69)
    gui_jwt=$(_rand_passwd 69)

    cd /home/ronindojo || exit
    npm i -g pnpm &>/dev/null

    mkdir -p Ronin-UI && cd Ronin-UI
    wget -q "$roninui_version_file" -O /tmp/version.json
    _file=$(jq -r .file /tmp/version.json)
    _shasum=$(jq -r .sha256 /tmp/version.json)

    wget -q https://ronindojo.io/downloads/RoninUI/"$_file"
    echo "${_shasum}  $_file" | sha256sum -c --status \
        || echo "Warning: Ronin UI SHA256 mismatch"

    tar xzf "$_file"
    rm "$_file" /tmp/version.json

    echo "JWT_SECRET=$gui_jwt" > .env
    echo "NEXT_TELEMETRY_DISABLED=1" >> .env

    _ronin_ui_avahi_service
    chown -R "$USER":"$USER" /home/"$USER"/Ronin-UI
}

_service_checks() {
    systemctl disable systemd-resolved.service &>/dev/null
    for svc in tor.service avahi-daemon.service motd.service ronin-setup.service ronin-post.service; do
        systemctl enable --quiet "$svc"
    done
}

main() {
    env -i bash -c '. /etc/os-release'
    case "$VERSION_CODENAME" in
        "bookworm"|"bullseye")
            echo "deb http://deb.debian.org/debian ${VERSION_CODENAME}-backports main contrib non-free" \
                | tee -a /etc/apt/sources.list
            ;;\
        *)
            echo "Unsupported Debian: $VERSION_CODENAME"
            exit 1
            ;;\
    esac

    apt-get update
    apt-get install -y build-essential openssh-server man-db git avahi-daemon nginx fail2ban net-tools htop unzip wget ufw rsync jq python3 python3-pip pipenv gdisk gcc curl apparmor ca-certificates gnupg lsb-release sysstat bc netcat-openbsd nvme-cli
    apt-get install -y tor/bookworm-backports

    # Copy overlays
    cp -Rv /tmp/overlay/RoninOS/overlays/RoninOS/usr/* /usr/
    cp -Rv /tmp/overlay/RoninOS/overlays/RoninOS/etc/* /etc/
    cp -Rv /tmp/overlay/RoninDojo /home/ronindojo/RoninDojo
    chown -R "$USER":"$USER" /home/"$USER"/RoninDojo

    echo "Setup service is PRESENT! Keep going!"
    _create_oem_install
    _prep_npm
    _prep_docker
    _install_ronin_ui
    _service_checks

    echo "Setup is complete"
}

main
