#!/bin/bash

# Function to display section headers
print_section_header() {
    echo "======================================================================"
    echo "$1"
    echo "======================================================================"
}

# Function to display error messages
print_error() {
    echo "ERROR: $1" >&2
}

# Function to verify if a package is installed
is_package_installed() {
    dpkg -s "$1" &> /dev/null
}

# Function to add user accounts with specified configurations
add_user_accounts() {
    local users=("dennis" "aubrey" "captain" "snibbles" "brownie" "scooter" "sandy" "perrier" "cindy" "tiger" "yoda")

    print_section_header "Adding user accounts"

    for user in "${users[@]}"; do
        if ! id "$user" &> /dev/null; then
            echo "Creating user: $user"
            sudo useradd -m -s /bin/bash "$user" || {
                print_error "Failed to create user: $user"
                continue
            }
        else
            echo "User '$user' already exists."
        fi

        echo "Setting up SSH keys for user: $user"
        sudo mkdir -p "/home/$user/.ssh"
        sudo cp "/home/student/.ssh/id_rsa.pub" "/home/$user/.ssh/authorized_keys"
        sudo cp "/home/student/.ssh/id_ed25519.pub" "/home/$user/.ssh/authorized_keys"
        sudo chown -R "$user:$user" "/home/$user/.ssh"
        sudo chmod 700 "/home/$user/.ssh"
        sudo chmod 600 "/home/$user/.ssh/authorized_keys"
    done

    # allow sudo access to dennis
    sudo usermod -aG sudo dennis

    echo "User account setup completed."
}

# Function to configure network interface

configure_network_interface() {
    local interface="ens192"  # change the interface name if necessary
    local ip_address="192.168.16.21"
    local netmask="24"
    local netplan_file="/etc/netplan/01-network-manager-all.yaml"  # Corrected file path

    print_section_header "Configuring network interface"

    if [ -f "$netplan_file" ]; then
        if grep -q "ens192" "$netplan_file"; then
            echo "Network interface $interface already configured."
        else
            echo "Adding configuration for $interface to $netplan_file"
           cat >> "$netplan_file" <<-EOF
            network:
              version: 2
              ethernets:
                $interface:
                  addresses: [$ip_address/$netmask]
EOF
            netplan apply || {
                print_error "Failed to apply netplan configuration."
                return 1
            }
            echo "Network interface $interface configured successfully."
        fi
    else
        print_error "Netplan configuration file $netplan_file not found."
        return 1
    fi
}

# Function to configure /etc/hosts file
configure_hosts_file() {
    local hosts_file="/etc/hosts"
    local hostname="server1"
    local ip_address="192.168.16.21"

    print_section_header "Configuring /etc/hosts file"

    if grep -q "$hostname" "$hosts_file"; then
        sudo sed -i "/$hostname/c\\$ip_address\t$hostname" "$hosts_file" || {
            print_error "Failed to update /etc/hosts file."
            return 1
        }
        echo "/etc/hosts file updated successfully."
    else
        echo "$ip_address\t$hostname" | sudo tee -a "$hosts_file" > /dev/null || {
            print_error "Failed to update /etc/hosts file."
            return 1
        }
        echo "/etc/hosts file updated successfully."
    fi
}

# Function for installing required software packages
install_packages() {
    print_section_header "Installing required software packages"

    # Install apache2 if it's not installed
    if ! is_package_installed "apache2"; then
        echo "Installing apache2..."
        sudo apt update && sudo apt install -y apache2 || {
            print_error "Failed to install apache2."
            return 1
        }
        echo "apache2 installed successfully."
    else
        echo "apache2 is already installed."
    fi

    # Install squid if not installed
    if ! is_package_installed "squid"; then
        echo "Installing squid..."
        sudo apt update && sudo apt install -y squid || {
            print_error "Failed to install squid."
            return 1
        }
        echo "squid installed successfully."
    else
        echo "squid is already installed."
    fi
}

# Function to configure firewall using ufw
configure_firewall() {
    print_section_header "Configuring firewall using ufw"

    # Reset ufw to default settings
    echo "Resetting ufw to its default settings..."
    sudo ufw --force reset

    # Set default policies
    sudo ufw default deny incoming
    sudo ufw default allow outgoing

    # Allow SSH on the management network (if it is ens192)
    sudo ufw allow in on ens192 to any port 22

    # Allow HTTP on both interfaces
    sudo ufw allow in on ens192 to any port 80
    sudo ufw allow in on ens192 to any port 80

    # Allow squid proxy on both interfaces
    sudo ufw allow in on ens192 to any port 3128
    sudo ufw allow in on ens192 to any port 3128

    # Enable ufw
    echo "Enabling ufw..."
    sudo ufw --force enable

    echo "Firewall configured successfully."
}

# Main function
main() {
    add_user_accounts && \
    configure_network_interface && \
    configure_hosts_file && \
    install_packages && \
    configure_firewall

    if [ $? -eq 0 ]; then
        echo "All configurations have been carried out successfully."
    else
        print_error "One or more configurations have failed. Please verify the error messages."
        return 1
    fi
}

# Execute main function
main
