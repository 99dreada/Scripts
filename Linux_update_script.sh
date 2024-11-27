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

# Function to create a user with sudo privileges and SSH setup
create_user() {
    USERNAME="btadmin"
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
        sudo mkdir -p "$SSH_DIR"
        sudo chmod 700 "$SSH_DIR"
        sudo chown "$USERNAME:$USERNAME" "$SSH_DIR"

        # Create an authorized_keys file
        AUTH_KEYS="$SSH_DIR/authorized_keys"
        sudo touch "$AUTH_KEYS"
        sudo chmod 600 "$AUTH_KEYS"
        sudo chown "$USERNAME:$USERNAME" "$AUTH_KEYS"
        
        # Instructions for generating SSH key
        echo -e "\nTo configure SSH access, follow these steps:\n"
        echo "1. Generate an SSH key pair on Windows using PuTTYgen:"
        echo "   a. Download PuTTYgen: https://www.putty.org/"
        echo "   b. Open PuTTYgen and click 'Generate'."
        echo "   c. Move your mouse randomly in the key area to generate the key."
        echo "   d. Copy the public key from the 'Public key for pasting into OpenSSH authorized_keys file' field."
        echo "2. Save the private key using PuTTYgen for use with PuTTY (as a .ppk file)."
        echo "3. Press Enter to continue when you have the public key ready."

        # Wait for the user to generate the SSH key
        read -p "Press Enter to continue..."

        # Prompt the user for the public key
        echo -e "\nPaste the public key below and press Enter (Ctrl+D to finish):"
        sudo tee -a "$AUTH_KEYS" > /dev/null

        # Set the correct ownership and permissions again for security
        sudo chmod 600 "$AUTH_KEYS"
        sudo chown "$USERNAME:$USERNAME" "$AUTH_KEYS"
        
        echo -e "\nThe public key has been added. You can now use the private key to connect via SSH."
        echo "If using PuTTY, load the private key (.ppk file) in the SSH configuration and connect with username '$USERNAME'."
    fi
}

# Main script execution
check_os
update_system
create_user
