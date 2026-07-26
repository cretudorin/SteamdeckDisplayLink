# SteamdeckDisplayLink
Steamdeck OS DisplayLink install script


## Installation 
`curl -fsSL https://raw.githubusercontent.com/cretudorin/SteamdeckDisplayLink/refs/heads/main/DisplayLink.sh | bash`

###  ⚠️ ⚠️ This script needs to be executed after every SteamOs update  ⚠️ ⚠️


## What does it do?
* checks if it is running on SteamOS
* disables SteamOS read-only mode
* initializes and populates the pacman keyring
* updates the package database
* installs required system packages, including Plymouth, kernel packages and headers, development tools, and DKMS dependencies
* builds and installs the EVDI kernel module from the Arch User Repository (AUR)
* builds and installs the DisplayLink driver from the AUR
* enables and starts the displaylink.service systemd service


## Source

Based on this reddit comment with some help from chatgpt


https://www.reddit.com/r/steamdeck_linux/comments/u2jb9m/comment/mopur3p
