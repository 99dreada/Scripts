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
    case $OS in
        centos)
            echo "Detected CentOS $VERSION. Updating system..."
            sudo yum update -y
            ;;
        ubuntu)
            echo "Detected Ubuntu $VERSION. Updating system..."
            sudo apt update && sudo apt upgrade -y
            ;;
        debian)
            echo "Detected Debian $VERSION. Updating system..."
            sudo apt update && sudo apt upgrade -y
            ;;
        *)
            echo "Unsupported operating system: $OS"
            exit 1
            ;;
    esac
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
        # Create the user
        sudo useradd -m -s /bin/bash "$USERNAME"
        
        # Set the password
        echo "Please set a password for $USERNAME:"
        sudo passwd "$USERNAME"
        
        # Add user to sudoers group
        case $OS in
            centos)
                sudo usermod -aG wheel "$USERNAME"
                ;;
            ubuntu|debian)
                sudo usermod -aG sudo "$USERNAME"
                ;;
        esac

        echo "User $USERNAME created and added to the sudoers group."

        # Set up SSH directory and permissions
        echo "Setting up SSH access for $USERNAME..."
        SSH_DIR="/home/$USERNAME/.ssh"
        AUTH_KEYS="$SSH_DIR/authorized_keys"
        sudo mkdir -p "$SSH_DIR"
        sudo chmod 700 "$SSH_DIR"
        sudo chown "$USERNAME:$USERNAME" "$SSH_DIR"

        # Add the provided SSH public key to the authorized_keys file
        echo "$SSH_PUBLIC_KEY" | sudo tee -a "$AUTH_KEYS" > /dev/null
        sudo chmod 600 "$AUTH_KEYS"
        sudo chown "$USERNAME:$USERNAME" "$AUTH_KEYS"
        
        # Enhance security: Make authorized_keys file immutable and restrict permissions
        sudo chattr +i "$AUTH_KEYS"
        sudo chmod 600 "$AUTH_KEYS"

        echo -e "SSH key has been added to /home/$USERNAME/.ssh/authorized_keys.\n"
        echo "You can now use the private key corresponding to the provided public key to log in as $USERNAME."
    fi
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
restart_ssh
display_putty_instructions
