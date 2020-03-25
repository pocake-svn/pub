#!/bin/bash
#
#  Script to install TigerVNC and make all necessary changes to prepare to use it
#  Version 20200325-2 Removed start service. Needs reboot.
#  by Andrey Ivanov
#  TODO: 2.Do I need any logging and notification?
#        3.Add error handling


#Variables
CURRENT_USER=$(whoami)
HOME_DIRECTORY=$HOME
SSHD_ENABLED="no"
SSND_ACTIVE="no"

#Functions

#Main body

#Script needs to be executed by regular user with sudo privileges
if [ "$EUID" -eq 0 ]
  then 
    echo "Please run the script as regular user."
    exit 1
fi

#start SSHD and change it to autostart
SSHD_ENABLED="$(systemctl is-enabled sshd)"
SSHD_ACTIVE="$(systemctl is-active sshd)"
echo "Enabling SSHD and starting .."
if [ "${SSHD_ENABLED}" = "enabled" ] 
    then
        echo "SSHD already enabled."
    else
        echo "/usr/bin/sudo systemctl enable sshd"
fi
if [ "${SSHD_ACTIVE}" = "active" ] 
    then
        echo "SSHD already started."
    else
        echo "/usr/bin/sudo systemctl start sshd"
fi

echo "Installing TigerVNC .."
/usr/bin/sudo pacman -Sy --noconfirm tigervnc

echo "Creating TigerVNC config file for user $CURRENT_USER and in the directory $HOME_DERECTORY.."
mkdir -p $HOME_DIRECTORY/.vnc
/usr/bin/sudo chown -R $CURRENT_USER $HOME_DIRECTORY/.vnc

# Creating config xkstartup config file and make it executable
cat > $HOME_DIRECTORY/.vnc/xstartup << __END__
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
dbus-launch startkde
__END__

/usr/bin/sudo chmod 755 $HOME_DIRECTORY/.vnc/xstartup

#Creating config file with required resolution
cat > $HOME_DIRECTORY/.vnc/config << __END__
geometry=1920x1080
__END__

#Set VNC pssword file
echo 'Please set your VNC server password'
/usr/bin/vncpasswd

#Creating service config file
(echo '[Unit]'
echo 'Description=Remote desktop service (VNC)'
echo 'After=syslog.target network.target'
echo ' '
echo '[Service]'
echo 'Type=simple'
echo "User=${CURRENT_USER}"
echo 'PAMName=login'
echo 'PIDFile=/home/%u/.vnc/%H%i.pid'
echo "ExecStartPre=/bin/sh -c '/usr/bin/vncserver -kill %i > /dev/null 2>&1 || :'"
echo 'ExecStart=/usr/bin/vncserver %i -geometry 1920x1080 -alwaysshared -fg'
echo 'ExecStop=/usr/bin/sudo systemctl restart vncsever@:1.service'
echo 'TimeoutSec=60'
echo 'Restart=always'

echo ' '
echo '[Install]'
echo 'WantedBy=multi-user.target'
echo ' ') | sudo tee -a /etc/systemd/system/vncserver@:1.service >/dev/null

#Set vncserver to autostart and start service. At that time the server can not be enabled and started.
#/usr/bin/sudo systemctl daemon-reload
#/usr/bin/sudo systemctl start vnserver@:1
#/usr/bin/sudo systemctl enable vnserver@:1