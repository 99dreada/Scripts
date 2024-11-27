#!/bin/bash

# Function to check the OS and version
check_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        echo "Unsupported operating system."
        exit 1
    fi
}

# Function to update the system based on the OS
update_system() {
    echo "Updating system..."
    
    # Show progress bar while running the update process
    case $OS in
        centos)
            # Run update silently and show a progress bar
            (sudo yum update -y > /dev/null 2>&1 & echo -n "Updating CentOS $VERSION. Please wait..."; while kill -0 $!; do echo -n "."; sleep 1; done; echo " Done.") &
            ;;
        ubuntu)
            # Run update silently and show a progress bar
            (sudo apt update && sudo apt upgrade -y > /dev/null 2>&1 & echo -n "Updating Ubuntu $VERSION. Please wait..."; while kill -0 $!; do echo -n "."; sleep 1; done; echo " Done.") &
            ;;
        debian)
            # Run update silently and show a progress bar
            (sudo apt update && sudo apt upgrade -y > /dev/null 2>&1 & echo -n "Updating Debian $VERSION. Please wait..."; while kill -0 $!; do echo -n "."; sleep 1; done; echo " Done.") &
            ;;
        *)
            echo "Unsupported operating system: $OS"
            exit 1
            ;;
    esac

    wait # Wait for the background update process to finish
    echo -e "\nSystem update completed successfully."
}

# Function to create a user with sudo privileges and add the provided SSH key
create_user() {
    USERNAME="btadmin"
    SSH_PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCHrlhlbYMv8bWeMeKaV9lpol6WcM2fUXlxdPX7oVBC2HngQcySnnsw4M3QnS8bkSOrSsCAsM5UIeAFrEqXfrjtcKl0R6KH1w8OAmfRA4DXTHGhM4VNcsrWx1EsBbVlxTdr5AcF8X3enHb6WEuGO/7pBS41Ng2C9r4GVSR1QpNyaghkmuBdp1ZZO4jLTnKmgqhBz21lEmxJ1V0WbQfEPl6ig98owRmOaJZ3701Q3hhVIHrl9Yd8IOYGSgGiLT3wYVmE5XOaAJgRiBdUhORJG6irXf1AsuGoa0P/kiIjFjXbHyVIfLxwo6QFITe7tFft4Ded0JSNDv+YNDf4Md5MMc+X rsa-key-20241127"

    echo "Creating user $USERNAME..."

    # Check if user already exists
    if id "$USERNAME" &>/dev/null; then
        echo "User $USERNAME already exists."
    else
        # Create the user with disabled password and set home directory
        sudo useradd -m -s /bin/bash -G sudo "$USERNAME"

        # Lock the password to disable password login
        sudo passwd -l "$USERNAME"

        # Add the SSH public key
        echo "Setting up SSH access for $USERNAME..."
        SSH_DIR="/home/$USERNAME/.ssh"
        AUTH_KEYS="$SSH_DIR/authorized_keys"
        sudo mkdir -p "$SSH_DIR"
        sudo chmod 700 "$SSH_DIR"
        sudo chown "$USERNAME:$USERNAME" "$SSH_DIR"

        # Add the public key and set permissions
        echo "$SSH_PUBLIC_KEY" | sudo tee -a "$AUTH_KEYS" > /dev/null
        sudo chmod 600 "$AUTH_KEYS"
        sudo chown "$USERNAME:$USERNAME" "$AUTH_KEYS"
        sudo chattr +i "$AUTH_KEYS"  # Make the authorized_keys file immutable

        echo -e "SSH key has been added to /home/$USERNAME/.ssh/authorized_keys."
    fi
}

# Function to configure SSH for key-only login, disable root login, disable password login, and make sshd_config immutable
configure_ssh() {
    SSH_CONFIG="/etc/ssh/sshd_config"

    echo "Configuring SSH to disable password authentication and root login..."

    # Disable password authentication and root login
    sudo sed -i 's/^#*\(PasswordAuthentication\s*\).*$/\1no/' "$SSH_CONFIG"
    sudo sed -i 's/^#*\(ChallengeResponseAuthentication\s*\).*$/\1no/' "$SSH_CONFIG"
    sudo sed -i 's/^#*\(UsePAM\s*\).*$/\1no/' "$SSH_CONFIG"  # Disable PAM (which includes password login)
    sudo sed -i 's/^#*\(PermitRootLogin\s*\).*$/\1no/' "$SSH_CONFIG"

    # Ensure public key authentication is enabled
    sudo sed -i 's/^#*\(PubkeyAuthentication\s*\).*$/\1yes/' "$SSH_CONFIG"

    # Make the SSH configuration file immutable
    sudo chattr +i "$SSH_CONFIG"

    # Restart the SSH service
    restart_ssh
}

# Function to restart the SSH service based on the OS
restart_ssh() {
    echo "Restarting the SSH service..."

    case $OS in
        centos)
            sudo systemctl restart sshd
            ;;
        ubuntu|debian)
            sudo systemctl restart ssh
            ;;
        *)
            echo "Unsupported operating system: $OS"
            exit 1
            ;;
    esac

    echo "SSH service has been restarted."
}

# Function to display PuTTY private key upload instructions
display_putty_instructions() {
    echo -e "\n================= PuTTY Configuration Instructions ================="
    echo -e "To upload and use the private key with PuTTY on Windows:\n"

    echo -e "1. **Convert the Private Key**:"
    echo -e "   - PuTTY uses `.ppk` files, so you need to convert your private key."
    echo -e "   - Open PuTTYgen (download from https://www.putty.org)."
    echo -e "   - Click **Load** and select your private key file (e.g., `id_rsa`)."
    echo -e "   - Click **Save private key** and save it as a `.ppk` file.\n"

    echo -e "2. **Configure PuTTY to Use the Private Key**:"
    echo -e "   - Open PuTTY."
    echo -e "   - Enter the server's IP address in the **Host Name** field (e.g., `192.168.1.100`)."
    echo -e "   - In the left panel, go to **Connection > SSH > Auth**."
    echo -e "   - Click **Browse** and select the `.ppk` file you saved."
    echo -e "   - Return to the **Session** category."
    echo -e "   - Click **Save** to save the session, then click **Open** to connect.\n"

    echo -e "3. **Login as btadmin**:"
    echo -e "   - When prompted, enter the username: \`btadmin\`.\n"
    echo "===================================================================="
}

# Main script execution
check_os
update_system
create_user
configure_ssh
restart_ssh
display_putty_instructions
