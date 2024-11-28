#!/bin/bash

set -e

# Set the username and password as variables
USERNAME="btadmin"
PASSWORD="k\\4l6*X1UvkC"

# Function to detect the Linux distribution and version
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        echo "Unsupported OS. Exiting."
        exit 1
    fi
}

# Function to update and upgrade system packages with a progress bar
update_system() {
    echo "Updating system packages..."
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        apt update > /dev/null 2>&1 &
        show_progress
        apt upgrade -y > /dev/null 2>&1 &
        show_progress
    elif [[ "$OS" == "centos" || "$OS" == "rhel" ]]; then
        yum update -y > /dev/null 2>&1 &
        show_progress
    else
        echo "Unsupported OS for updates. Exiting."
        exit 1
    fi
}

# Function to show a progress bar for long-running tasks
show_progress() {
    echo -n "Please wait"
    while ps | grep -q 'apt\|yum'; do
        echo -n "."
        sleep 2
    done
    echo " Done."
}

# Function to configure the firewall
configure_firewall() {
    echo "Configuring firewall..."
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        apt install ufw -y
        ufw allow ssh
        ufw default deny incoming
        ufw default allow outgoing
        ufw enable
    elif [[ "$OS" == "centos" || "$OS" == "rhel" ]]; then
        yum install firewalld -y
        systemctl start firewalld
        systemctl enable firewalld
        firewall-cmd --permanent --add-service=ssh
        firewall-cmd --permanent --set-default-zone=block
        firewall-cmd --reload
    fi
}

# Function to create a new user and set their password
create_user() {
    echo "Creating user '$USERNAME'..."
    useradd -m -s /bin/bash $USERNAME

    # Set the user's password
    echo "$USERNAME:$PASSWORD" | chpasswd

    # Add user to the sudo group
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        usermod -aG sudo $USERNAME
    elif [[ "$OS" == "centos" || "$OS" == "rhel" ]]; then
        usermod -aG wheel $USERNAME
    fi
}

# Function to harden SSH configuration but allow password for the specified user
harden_ssh_config() {
    echo "Hardening SSH configuration..."
    SSH_CONFIG="/etc/ssh/sshd_config"

    # Backup the original SSH config file
    cp $SSH_CONFIG ${SSH_CONFIG}.bak

    # Enable password authentication explicitly
    sed -i "s/#*PasswordAuthentication.*/PasswordAuthentication yes/" $SSH_CONFIG
    sed -i "s/#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/" $SSH_CONFIG
    sed -i "s/#*PermitRootLogin.*/PermitRootLogin no/" $SSH_CONFIG
    sed -i "s/#*MaxAuthTries.*/MaxAuthTries 3/" $SSH_CONFIG
    sed -i "s/#*PermitEmptyPasswords.*/PermitEmptyPasswords no/" $SSH_CONFIG

    # Restrict SSH access to only the specified user
    if ! grep -q "AllowUsers $USERNAME" $SSH_CONFIG; then
        echo "AllowUsers $USERNAME" >> $SSH_CONFIG
    fi

    # Make the SSH configuration file immutable
    chattr +i $SSH_CONFIG

    # Restart SSH service
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        systemctl restart ssh
    elif [[ "$OS" == "centos" || "$OS" == "rhel" ]]; then
        systemctl restart sshd
    fi
}

# Main script execution
detect_os
update_system
configure_firewall
create_user
harden_ssh_config
