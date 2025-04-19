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

echo "add user roinindojo"
useradd -s /bin/bash -m -c "ronindojo" ronindojo -p rock
useradd -c "tor" tor && echo "ronindojo    ALL=(ALL) ALL" >> /etc/sudoers

#removes the first user login requirement with monitor and keyboard
rm /root/.not_logged_in_yet 

echo "set hostname"
hostname -b "ronindebian"

# RoninDojo part
TMPDIR=/var/tmp
USER="ronindojo"
#PASSWORD="password" # test purposes only
PASSWORD="$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c'21')"
#ROOTPASSWORD="password" ## for testing purposes only
ROOTPASSWORD="$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c'21')"
FULLNAME="RoninDojo"
TIMEZONE="UTC"
LOCALE="en_US.UTF-8"
HOSTNAME="RoninDojo"
KEYMAP="us"

_create_oem_install() {
    pam-auth-update --package
    # Setting root password
    chpasswd <<<"root:$ROOTPASSWORD"

    # Adding user $USER
    useradd -m -G wheel,sys,audio,input,video,storage,lp,network,users,power -s /bin/bash ronindojo &>/dev/null
    
    # Check if /home/ronindojo exists and is owned by ronindojo
    if [ ! -d /home/ronindojo ]; then
        echo "Directory /home/ronindojo does not exist. Creating it..."
        mkdir -p /home/ronindojo
        echo "Directory /home/ronindojo created. Setting permissions for ronindojo user..."
        chown -R ronindojo:ronindojo /home/ronindojo
    else
        # Check ownership
        owner=$(stat -c '%U' /home/ronindojo)
        if [ "$owner" != "ronindojo" ]; then
            echo "Directory /home/ronindojo exists but is not owned by ronindojo. Fixing ownership..."
            sudo chown -R ronindojo:ronindojo /home/ronindojo
        else
            echo "Directory /home/ronindojo exists and is owned by ronindojo."
        fi
    fi

    # Setting full name to $FULLNAME
    chfn -f "$FULLNAME" "$USER" &>/dev/null

    # Setting password for $USER
    chpasswd <<<"$USER:$PASSWORD"

    # Save Linux user credentials for UI access
    mkdir -p /home/ronindojo/.config/RoninDojo
    if [ ! -d /home/ronindojo/.config/ ]; then
        echo "ERROR: /home/ronindojo/.config failed to be created"
        exit 1
    else
        echo "/home/ronindojo/.config/ present"
    fi
    cat <<EOF >/home/ronindojo/.config/RoninDojo/info.json
{"user":[{"name":"${USER}","password":"${PASSWORD}"},{"name":"root","password":"${ROOTPASSWORD}"}]}
EOF
    chown -R "${USER}":"${USER}" /home/"${USER}"
    chown -R "${USER}":"${USER}" /home/"${USER}"/.config

    # Setting timezone to $TIMEZONE
    timedatectl set-timezone $TIMEZONE &>/dev/null
    timedatectl set-ntp true &>/dev/null

    # Generating $LOCALE locale
    sed -i "s/#$LOCALE/$LOCALE/" /etc/locale.gen &>/dev/null
    locale-gen &>/dev/null
    localectl set-locale $LOCALE &>/dev/null

    if [ -f /etc/sway/inputs/default-keyboard ]; then
        sed -i "s/us/$KEYMAP/" /etc/sway/inputs/default-keyboard

        if [ "$KEYMAP" = "uk" ]; then
            sed -i "s/uk/gb/" /etc/sway/inputs/default-keyboard
        fi
    fi

    # Setting hostname to $HOSTNAME
    hostnamectl set-hostname $HOSTNAME &>/dev/null

    # Resizing partition
    resize-fs &>/dev/null

    loadkeys "$KEYMAP"

    # Configuration complete. Cleaning up
    #rm /root/.bash_profile

    # Avahi setup
    sed -i 's/hosts: .*$/hosts: files mdns_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] dns mdns/' /etc/nsswitch.conf
    sed -i 's/.*host-name=.*$/host-name=ronindojo/' /etc/avahi/avahi-daemon.conf
    if ! systemctl is-enabled --quiet avahi-daemon; then
        systemctl enable --quiet avahi-daemon
    fi

    # sshd setup
    sed -i -e "s/PermitRootLogin yes/#PermitRootLogin prohibit-password/" \
        -e "s/PermitEmptyPasswords yes/#PermitEmptyPasswords no/" /etc/ssh/sshd_config

    # Set sudo timeout to 1 hour
    sed -i '/env_reset/a Defaults\ttimestamp_timeout=60' /etc/sudoers

    # Enable passwordless sudo
    sed -i '/ronindojo/s/ALL) ALL/ALL) NOPASSWD:ALL/' /etc/sudoers # change to no password

    echo -e "domain .local\nnameserver 1.1.1.1\nnameserver 1.0.0.1" >> /etc/resolv.conf
    
    # Setup logs for outputs
    mkdir -p /home/ronindojo/.logs
    touch /home/ronindojo/.logs/setup.logs
    touch /home/ronindojo/.logs/post.logs
    chown -R ronindojo:ronindojo /home/ronindojo/.logs
}

_service_checks(){  
    set +x
    if ! systemctl is-enabled tor.service; then
        systemctl enable tor.service
    fi

    if ! systemctl is-enabled --quiet avahi-daemon.service; then
        systemctl disable systemd-resolved.service &>/dev/null
        systemctl enable avahi-daemon.service
    fi

    if ! systemctl is-enabled motd.service; then
        systemctl enable motd.service
    fi
    
    if ! systemctl is-enabled ronin-setup.service; then
        systemctl enable ronin-setup.service
    fi

    if ! systemctl is-enabled ronin-post.service; then
        systemctl enable ronin-post.service
    fi
    set -x
}

# Installs Nodejs and pm2. Clones the RoninDojo repo.
_prep_npm(){
    # install Nodejs
    curl -sL https://deb.nodesource.com/setup_20.x | bash -
    apt-get update
    apt-get install -y nodejs

    # install pm2 
    npm install pm2 -g
}

_ronin_ui_avahi_service() {
    if [ ! -f /etc/avahi/services/http.service ]; then
        tee "/etc/avahi/services/http.service" <<EOF >/dev/null
<?xml version="1.0" standalone='no'?><!--*-nxml-*-->
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<!-- This advertises the RoninDojo vhost -->
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

    if ! grep -q "host-name=ronindojo" /etc/avahi/avahi-daemon.conf; then
        sed -i 's/.*host-name=.*$/host-name=ronindojo/' /etc/avahi/avahi-daemon.conf
    fi

    if ! systemctl is-enabled --quiet avahi-daemon; then
        systemctl enable --quiet avahi-daemon
    fi

    return 0
}

_rand_passwd() {
    local _length
    _length="${1:-16}"

    tr -dc 'a-zA-Z0-9' </dev/urandom | head -c"${_length}"
}


_install_ronin_ui(){

    roninui_version_file="https://ronindojo.io/downloads/RoninUI/version.json"

    gui_api=$(_rand_passwd 69)
    gui_jwt=$(_rand_passwd 69)

    cd /home/ronindojo || exit

    npm i -g pnpm &>/dev/null

    test -d /home/ronindojo/Ronin-UI || mkdir /home/ronindojo/Ronin-UI
    cd /home/ronindojo/Ronin-UI || exit

    wget -q "${roninui_version_file}" -O /tmp/version.json 2>/dev/null

    _file=$(jq -r .file /tmp/version.json)
    _shasum=$(jq -r .sha256 /tmp/version.json)

    wget -q https://ronindojo.io/downloads/RoninUI/"$_file" 2>/dev/null

    if ! echo "${_shasum} ${_file}" | sha256sum --check --status; then
        _bad_shasum=$(sha256sum ${_file})
        echo "Ronin UI archive verification failed! Valid sum is ${_shasum}, got ${_bad_shasum} instead..."
    fi
      
    tar xzf "$_file"

    rm "$_file" /tmp/version.json

    # Preinstall dependencies
    pnpm install --prod

    # Mark Ronin UI initialized if necessary
    if [ -e "${ronin_ui_init_file}" ]; then
        echo -e "{\"initialized\": true}\n" > ronin-ui.dat
    fi

    # Generate .env file
    echo "JWT_SECRET=$gui_jwt" > .env
    echo "NEXT_TELEMETRY_DISABLED=1" >> .env

    if [ "${roninui_version_staging}" = true ] ; then
        echo -e "VERSION_CHECK=staging\n" >> .env
    fi

    _ronin_ui_avahi_service

    chown -R ronindojo:ronindojo /home/ronindojo/Ronin-UI

    usermod -aG pm2 ronindojo
}


_prep_docker(){
    # Remove Debian shipped Docker packages
    for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do 
        sudo apt-get remove $pkg; 
    done

    # Add Docker's official GPG key:
    sudo apt-get update
    sudo apt-get install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
    $(lsb_release -cs) stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update

    # install Docker
    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    usermod -aG docker ronindojo
}

# The debian default was incompatible with our setup. This sets tor to match RoninDojo requirements and removes the debian variants.
_prep_tor(){
	mkdir -p /mnt/usb/tor
	chown -R tor:tor /mnt/usb/tor
	sed -i '$a\User tor\nDataDirectory /mnt/usb/tor' /etc/tor/torrc
    sed -i '$ a\
HiddenServiceDir /mnt/usb/tor/hidden_service_ronin_backend/\
HiddenServiceVersion 3\
HiddenServicePort 80 127.0.0.1:8470\
' /etc/tor/torrc

    cp -Rv /tmp/overlay/RoninOS/overlays/RoninOS/example.tor.service /usr/lib/systemd/system/tor.service
    rm -rf /usr/lib/systemd/system/tor@* #remove unnecessary debian installed services
}






# This installs all required packages needed for RoninDojo. Clones the RoninOS repo so it can be copied to appropriate locations. Then runs all the functions defined above.
main(){
    # Check appropriate paths before starting.

    if [ ! -d /tmp/overlay/RoninDojo ]; then
        echo "ERROR: YOU NEED TO PUT RONINDOJO REPO IN ./build/userpatches/overlay/"
        echo "Stopping now..."
        exit 1
    fi
    # install dependencies
    apt-get update
    apt-get install -y build-essential openssh-server man-db git avahi-daemon nginx fail2ban net-tools htop unzip wget ufw rsync jq python3 python3-pip pipenv gdisk gcc curl apparmor ca-certificates gnupg lsb-release sysstat bc netcat-openbsd nvme-cli
    apt-get install -y tor/bookworm-backports #install 0.4.7.x tor

    cp -Rv /tmp/overlay/RoninOS/overlays/RoninOS/usr/* /usr/
    cp -Rv /tmp/overlay/RoninOS/overlays/RoninOS/etc/* /etc/
    chown -R ronindojo:ronindojo /usr/local/sbin/*

    cp -Rv /tmp/overlay/RoninDojo /home/ronindojo/RoninDojo
    chown -R ronindojo:ronindojo /home/ronindojo/RoninDojo

    cp -Rv /tmp/overlay/dojo /home/ronindojo/dojo
    chown -R ronindojo:ronindojo /home/ronindojo/dojo

    ### sanity check ###
    echo "Setup service is PRESENT! Keep going!"
    _create_oem_install

    _prep_npm
    _prep_docker
    _prep_tor

    mkdir -p /usr/share/nginx/logs
    rm -rf /etc/nginx/sites-enabled/default
    _install_ronin_ui
    systemctl enable oem-boot.service
    _service_checks

    echo "Setup is complete"
}

main
