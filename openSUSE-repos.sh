#!/bin/bash

###############################################################################################################
# CDN openSUSE Repositories Management Script
#
# Script Name:      openSUSE-repos.sh
# Date:             Aug 15, 2023
# Author:           UltherEgo
# Description:      This script allows users to manage openSUSE repositories by adding CDN repositories,
#                   restoring original distribution repositories, showing repository list,
#                   cleaning up backup repositories, and exiting the script.
# More info:        https://github.com/openSUSE/openSUSE-repos#restoring-original-distribution-repositories
# VERSION:          0.1
###############################################################################################################

# Global Variables
BACKUP_DIR="/etc/zypp"
TIMESTAMP=$(date +%Y%m%d%H%M%S)

# Color
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
RESET=$(tput sgr0)

# Distro
LEAP="openSUSE-repos-Leap"
TUMBLE="openSUSE-repos-Tumbleweed"
MICRO="openSUSE-repos-MicroOS"
LEAPMICRO="openSUSE-repos-LeapMicro"

# Function for adding CDN repositories
add_cdn_repos() {
    case $1 in
        "Leap")
             zypper in $LEAP
            ;;
        "Tumbleweed")
             zypper in $TUMBLE
            ;;
        "MicroOS")
             zypper in $MICRO
            ;;
        "LeapMicro")
             zypper in $LEAPMICRO
            ;;
    esac

    # Removing older repositories
    zypper rr --all || { echo "${RED}Error removing older repositories.${RESET}"; exit 1; }
    # Refreshing repositories
    zypper ref -s || { echo "${RED}Error refreshing repositories.${RESET}"; exit 1; }

    # Displaying the list of repositories
    zypper lr -d
}

# Function for restoring original distribution repositories
restore_original_repos() {
    case $1 in
        "Leap")
             zypper rm $LEAP
            ;;
        "Tumbleweed")
             zypper rm $TUMBLE
            ;;
        "MicroOS")
             zypper rm $MICRO
            ;;
        "LeapMicro")
             zypper rm $LEAPMICRO
            ;;
    esac

    # Restoring original repositories from backup
    for file in /etc/zypp/repos.d/*.rpmsave; do
         mv "$file" "$(echo $file | sed -e 's/\.rpmsave$//')" || { echo "${RED}Error restoring $file.${RESET}"; exit 1; }
    done

    # Refreshing repositories
    zypper ref -s || { echo "${RED}Error refreshing repositories.${RESET}"; exit 1; }

    # Displaying the list of repositories
    zypper lr -d
}

# Function for performing cleanup actions
cleanup() {
    local VERSION="$1"
    
    echo "${GREEN}Performing cleanup actions...${RESET}"
    
    if [ "$choice" == "4" ]; then
        if [ "$confirm" == "y" ]; then
            for backup_file in "$BACKUP_DIR"/repos_backup_"$VERSION"*.tar.gz; do
                if [ -f "$backup_file" ]; then
                    rm "$backup_file"
                    echo "${GREEN}Backup removed: $backup_file${RESET}"
                fi
            done
        fi
    fi
    
    echo "${GREEN}Cleanup completed.${RESET}"
}

# Checking for root privileges
if [[ $EUID -ne 0 ]]; then
    echo "${RED}This script must be run with sudo privileges.${RESET}"
    exit 1
fi

# VERSION detection
if grep -q "Leap" /etc/os-release; then
    VERSION="Leap"
    # Additional check for Leap version 15.5 or newer
    if grep -q "VERSION=\"15\.5" /etc/os-release; then
        SUPPORTS_CDN=true
    else
        SUPPORTS_CDN=false
    fi
elif grep -q "Tumbleweed" /etc/os-release; then
    VERSION="Tumbleweed"
    SUPPORTS_CDN=true
elif grep -q "MicroOS" /etc/os-release; then
    VERSION="MicroOS"
    SUPPORTS_CDN=true
elif grep -q "LeapMicro" /etc/os-release; then
    VERSION="LeapMicro"
    SUPPORTS_CDN=true
else
    echo "${RED}Unsupported openSUSE VERSION.${RESET}"
    exit 1
fi

# Defining multi-line prompt as a variable
multi_line_prompt="CDN openSUSE-repos
More info: 
https://github.com/openSUSE/openSUSE-repos#restoring-original-distribution-repositories
---------------------------------------------------------------------------------------
Choose an option:
1. Add CDN Repositories
2. Restore original distribution repositories
3. Test and check repository
4. Cleanup backup repository
5. Exit
---------------------------------------------------------------------------------------
Enter your choice: "

# Displaying the prompt and reading the choice
read -p "$multi_line_prompt" choice

# Validate user choice
if ! [[ "$choice" =~ ^[1-5]$ ]]; then
    echo "${RED}Invalid choice.${RESET}"
    exit 1
fi

# Perform backup before making any changes
backup_filename="repos_backup_${VERSION}_${TIMESTAMP}.tar.gz"
if [ "$SUPPORTS_CDN" == true ]; then
    if [ "$choice" == "1" ] || [ "$choice" == "2" ]; then
        echo "${GREEN}Creating a backup of repository configuration...${RESET}"
        tar -czf "$BACKUP_DIR/$backup_filename" -C /etc/zypp/repos.d .
        echo "${GREEN}Backup saved to $BACKUP_DIR/$backup_filename${RESET}"
    fi
fi

# Performing the chosen action
case $choice in
    1)
        if [ "$SUPPORTS_CDN" == true ]; then
            # Confirmation
            read -p "This will add CDN repositories. Do you want to proceed? (y/n): " confirm
            if [ "$confirm" != "y" ]; then
                echo "${RED}Aborted.${RESET}"
                exit 0
            fi

            # Adding CDN repositories
            add_cdn_repos "$VERSION"
        else
            echo "${RED}Version $VERSION does not support CDN repositories. Update to Leap 15.5 or newer.${RESET}"
        fi
        ;;
    2)
        if [ "$SUPPORTS_CDN" == true ]; then
            # Confirmation
            read -p "This will restore original distribution repositories. Do you want to proceed? (y/n): " confirm
            if [ "$confirm" != "y" ]; then
                echo "${RED}Aborted.${RESET}"
                exit 0
            fi

            # Restoring original repositories
            restore_original_repos "$VERSION"
        else
            echo "${RED}Version $VERSION does not support CDN repositories. Update to Leap 15.5 or newer.${RESET}"
        fi
        ;;
    3)
        # Show repository list
        zypper ref -s && zypper lr -d 
        ;;
    4) 
        # Cleanup backup
        read -p "Do you want to remove the backup of the repository configuration? (y/n): " confirm
        if [ "$confirm" != "y" ]; then
            echo "${RED}Aborted.${RESET}"
            exit 0
        fi

        # Removing Backup repository
        cleanup "$VERSION"
        ;;
    5)
        # Exit
        echo "${GREEN}Exiting the script.${RESET}"
        exit 0
        ;;

    *)
        echo "${RED}Invalid choice.${RESET}"
        exit 1
        ;;
esac