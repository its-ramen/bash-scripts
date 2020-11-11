#!/bin/bash

# Simple BASH  script to rename and reIP the CentOS guest
# tested on CentOS 8 / other versions or distributions may not apply
#
# THIS INTELLECTUAL PROPERTY IS FOR VIEWING ONLY BY AUTHORIZED PARTIES
# CREATOR RETAINS ALL RIGHTS FOR THIS INTELLECTUAL PROPERTY
# ANY REPRODUCTION OR USE OF THIS SCRIPT IS PROHIBITED EXCEPT BY CREATOR
# THIS SCRIPT HAS BEEN SANITIZED AND MODIFIED FROM ITS ORIGINAL VERSION AND MAY NOT BE OPERABLE
#
# ------------- START FUNCTIONS -------------

# this utility needs to be run as root to make the changes
# this function will check to see if its run as root (sudo) and exit if not
function ami_root () {
    if [ "$EUID" -ne 0 ]
    then 
        echo "Please run as root or sudoer account"
        exit
    fi
}

# prompt for confirmation
function yes_or_no () {
    while true; do
        read -p "$* [y/n]: " yn
        case $yn in
            [Yy][eE][sS]|[Yy]*) answer=0 ; return $answer ;;  
            [Nn][oO]|[Nn]*) answer=1 ; return $answer ;;
        esac
    done
}

# get the guest name
function get_name () {
    local continue=1
    while [ $continue == 1 ]; 
    do
        echo "Please enter the host name (NOT FQDN):"
        read hostname
        fqdn=$hostname.YOUR.DOMAIN
        echo "This computer will be renamed $fqdn"
        yes_or_no "Is this correct?"
        continue=$answer
    done
}

# get new IP information and validate that the IP is valid
function get_ipaddress () {
    local continue=1
    while [ $continue == 1 ];
    do
        echo "Please enter the IP address and mask (e.g. 10.100.1.1/16):"
        read ipaddress
        ipcalc -sc $ipaddress
        if [[ $? == 0 ]];
        then
            echo "This computer will be $ipaddress"
            yes_or_no "Is this correct? Don't forget to check your mask!"
            continue=$answer
        else
        echo "ERROR: this is not a valid IP address"
        fi
    done
}

# get new default gateway and validate that the IP is valid
function get_gateway () {
    local continue=1
    while [ $continue == 1 ];
    do
        echo "Please enter the Default Gateway:"
        read gateway
        ipcalc -sc $gateway
        if [[ $? == 0 ]];
        then
            echo "This computer will use $gateway as its gateway."
            yes_or_no "Is this correct?"
            continue=$answer
        else
        echo "ERROR: this is not a valid IP address"
        fi
    done
}

# get new DNS server address and validate that the IP is something between 0.0.0.0 and 255.255.255.255
function get_dns () {
    local continue=1
    while [ $continue == 1 ];
    do
        echo "Please enter the DNS server IP address:"
        read dns
        ipcalc -sc $ipaddress
        if [[ $? == 0 ]];
        then
            echo "This computer will get DNS from $dns"
            yes_or_no "Is this correct?"
            continue=$answer
        else
        echo "ERROR: This is not a valid DNS address"
        fi
    done
}

# use systemctl to set the hostname
function set_hostname () {
    echo "Setting hostname..."
    hostnamectl set-hostname $fqdn
    echo "Hostname is now $hostname"
    echo "... done."
}

# use NetworkManager CLI to set the IP configs
# this will be used to set ip on ens192; this may need to be changed depending on the server
function set_ipinfo () {
    # add the necessary ip configs
    echo "Setting IP Address on ens192"
    nmcli con mod ens192 ipv4.address $ipaddress
    echo "Disabling DHCP"
    nmcli con mod ens192 ipv4.method manual
    echo "Adding Default Gateway"
    nmcli con mod ens192 ipv4.gateway $gateway
    echo "Setting DNS servers"
    nmcli con mod ens192 ipv4.dns $dns
    echo "... done."
}

# This will bind the server to the YOUR.DOMAIN domain using realmd in CentOS 8 and later.
function bind_domain () { 
    # CentOS 7 and earlier will need to have realmd installed
    # Install or update realmd
    echo "This will now /silently/ install or update realmd to enable binding to Windows Domain (Active Directory). Press any key to continue."
    read
    dnf install -y realmd > /dev/null
    # get the name for the admin account used for binding
    echo "Now joining YOUR.DOMAIN."
    echo "Please enter your administrator name (NO @YOUR.DOMAIN):"
    read user
    echo "Joining YOUR.DOMAIN..."
    echo "Please enter your password at the prompt"
    # does the actual joining and puts the AD Computer account in the "servers" OU.
    realm join YOUR.DOMAIN --user=$user --computer-ou=OU=servers
    echo "Joined domain. Remeber to move the computer to the correct AD OU."
    # realm deny is used to prevent AD user account from logging in
    # this is the equivalent of an ACL to "deny all users"
    echo "Restricting YOUR.DOMAIN user log ins"
    realm deny --all
    # then we specifically include a certain user group to enable the log in
    # this will allow AD user accounts in the Domain Admins AD SG to log in
    echo "Enabling Domain Admin login"
    realm permit --groups 'Domain Admins'
    # this allows those domain admins to perform "sudo"
    echo "Adding Domain Admins to sudoers"
    sh -c echo '"#Allow YOUR.DOMAIN Domain Admin AD group members sudo access to this system" >> /etc/sudoers'
    sh -c echo '"%Domain\ Admins@YOUR.DOMAIN ALL=(ALL)   ALL" >> /etc/sudoers'
    echo "Done."
}

# ------------- END FUNCTIONS -------------
#
#
#
#
#
# ------------- START WORKFLOW -------------

echo "Use this utility to rename, re-IP, and bind Linux/CentOS guests"

# is this utility running in with root privileges?
# if no, then bail
# if yes, carry on then
ami_root

# use these functions to collect and validate the information
get_name
get_ipaddress
get_gateway
get_dns

# then set the things
set_hostname
set_ipinfo

# bind to domain
bind_domain

# then reboot
echo \n "This system will now reboot. Press any key to continue."
read
reboot now

# ------------- END WORKFLOW -------------
