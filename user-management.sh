#!/bin/bash

log_activity() {

    local action="$1"
    local username="$2"
    local timestamp

    timestamp=$(date "+%Y-%m-%d %H:%M:%S")

    echo "$timestamp | $action | $username" >> logs/activity.log
}

create_user() {

    echo ""
    echo "===== Create New User ====="

    read -p "Enter username: " username

    if [ -z "$username" ]; then
        echo "Error: Username cannot be empty."
        return
    fi

    if id "$username" &>/dev/null; then
        echo "Error: User '$username' already exists."
        return
    fi

    sudo useradd -m "$username"

    if [ $? -eq 0 ]; then

    echo "User '$username' created successfully."

    log_activity "USER_CREATED" "$username"

    echo ""
    echo "Now set a password for $username:"
    sudo passwd "$username"
    else
        echo "Error: Failed to create user."
    fi

}

delete_user() {
    echo ""
    echo "===== Delete User ====="

    read -p "Enter username: " username

    if [ -z "$username" ]; then
        echo "Error: Username cannot be empty."
        return
    fi

    if ! id "$username" &>/dev/null; then
        echo "Error: User '$username' does not exist."
        return
    fi

    if [ "$username" = "root" ]; then
        echo "Error: Cannot delete the root user."
        return
    fi

    echo ""
    echo "WARNING: This will delete user '$username' and their home directory."
    read -p "Are you sure? (y/n): " confirm

    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "Delete operation cancelled."
        return
    fi

    sudo userdel -r "$username"

    if [ $? -eq 0 ]; then
        echo "User '$username' deleted successfully."
        log_activity "USER_DELETED" "$username"
    else
        echo "Error: Failed to delete user '$username'."
    fi
}

create_group() {

    echo ""
    echo "===== Create New Group ====="

    read -p "Enter group name: " groupname

    if [ -z "$groupname" ]; then
        echo "Error: Group name cannot be empty."
        return
    fi

    if getent group "$groupname" > /dev/null; then
        echo "Error: Group '$groupname' already exists."
        return
    fi

    sudo groupadd "$groupname"

    if [ $? -eq 0 ]; then
        echo "Group '$groupname' created successfully."

        log_activity "GROUP_CREATED" "$groupname"
    else
        echo "Error: Failed to create group."
    fi
}

add_user_to_group() {

    echo ""
    echo "===== Add User to Group ====="

    read -p "Enter username: " username
    read -p "Enter group name: " groupname

    if [ -z "$username" ] || [ -z "$groupname" ]; then
        echo "Error: Username and group name cannot be empty."
        return
    fi

    if ! id "$username" &>/dev/null; then
        echo "Error: User '$username' does not exist."
        return
    fi

    if ! getent group "$groupname" > /dev/null; then
        echo "Error: Group '$groupname' does not exist."
        return
    fi

    sudo usermod -aG "$groupname" "$username"

    if [ $? -eq 0 ]; then
        echo "User '$username' added to group '$groupname' successfully."

        log_activity "USER_ADDED_TO_GROUP" "$username -> $groupname"
    else
        echo "Error: Failed to add user to group."
    fi
}


remove_user_from_group() {
    echo ""
    echo "===== Remove User from Group ====="

    read -p "Enter username: " username
    read -p "Enter group name: " groupname

    if [ -z "$username" ] || [ -z "$groupname" ]; then
        echo "Error: Username and group name cannot be empty."
        return
    fi

    if ! id "$username" &>/dev/null; then
        echo "Error: User '$username' does not exist."
        return
    fi

    if ! getent group "$groupname" > /dev/null; then
        echo "Error: Group '$groupname' does not exist."
        return
    fi

    if ! id -nG "$username" | grep -qw "$groupname"; then
        echo "Error: User '$username' is not a member of '$groupname'."
        return
    fi

    sudo gpasswd -d "$username" "$groupname"

    if [ $? -eq 0 ]; then
        echo "User '$username' removed from group '$groupname' successfully."
        log_activity "USER_REMOVED_FROM_GROUP" "$username -> $groupname"
    else
        echo "Error: Failed to remove user from group."
    fi
}

view_users() {
    echo ""
    echo "===== System Users ====="
    echo ""

    awk -F: '$3 >= 1000 && $3 < 60000 {print $1}' /etc/passwd
}

view_groups() {
    echo ""
    echo "===== System Groups ====="
    echo ""

    awk -F: '$3 >= 1000 && $3 < 60000 {print $1}' /etc/group
}

view_group_members() {
    echo ""
    echo "===== Group Members ====="

    read -p "Enter group name: " groupname

    if [ -z "$groupname" ]; then
        echo "Error: Group name cannot be empty."
        return
    fi

    if ! getent group "$groupname" > /dev/null; then
        echo "Error: Group '$groupname' does not exist."
        return
    fi

    echo ""
    echo "Group: $groupname"
    echo "Members:"

    members=$(getent group "$groupname" | cut -d: -f4)

    if [ -z "$members" ]; then
        echo "No members found."
    else
        echo "$members" | tr ',' '\n'
    fi
}

backup_configuration() {
    echo ""
    echo "===== Backup Configuration ====="

    local timestamp
    local backup_dir

    timestamp=$(date "+%Y-%m-%d_%H-%M-%S")
    backup_dir="backups/backup_$timestamp"

    mkdir -p "$backup_dir"

    echo "Creating backup..."

    sudo cp /etc/passwd "$backup_dir/passwd"
    sudo cp /etc/group "$backup_dir/group"
    sudo cp /etc/shadow "$backup_dir/shadow"
    sudo cp /etc/gshadow "$backup_dir/gshadow"

    if [ $? -eq 0 ]; then
        sudo chmod 700 "$backup_dir"
        sudo chmod 600 "$backup_dir/shadow"
        sudo chmod 600 "$backup_dir/gshadow"

        echo "Backup created successfully."
        echo "Location: $backup_dir"

        log_activity "CONFIGURATION_BACKUP_CREATED" "$backup_dir"
    else
        echo "Error: Backup failed."
    fi
}

create_shared_directory() {
    echo ""
    echo "===== Create Shared Directory ====="

    read -p "Enter group name: " groupname

    if [ -z "$groupname" ]; then
        echo "Error: Group name cannot be empty."
        return
    fi

    if ! getent group "$groupname" > /dev/null; then
        echo "Error: Group '$groupname' does not exist."
        return
    fi

    read -p "Enter directory name: " dirname

    if [ -z "$dirname" ]; then
        echo "Error: Directory name cannot be empty."
        return
    fi

    local dirpath="/shared/$dirname"

    if [ -d "$dirpath" ]; then
        echo "Error: Directory '$dirpath' already exists."
        return
    fi

    sudo mkdir -p "$dirpath"
    sudo chown root:"$groupname" "$dirpath"
    sudo chmod 2770 "$dirpath"

    if [ $? -eq 0 ]; then
        echo "Shared directory '$dirpath' created successfully."
        echo "Group '$groupname' has access."

        log_activity "SHARED_DIRECTORY_CREATED" "$dirpath -> $groupname"
    else
        echo "Error: Failed to create shared directory."
    fi
}

while true
do
    echo ""
    echo "===================================="
    echo "   Linux User Management System"
    echo "===================================="
    echo "1. Create User"
    echo "2. Delete User"
    echo "3. Create Group"
    echo "4. Add User to Group"
    echo "5. Remove User from Group"
    echo "6. Create Shared Directory"
    echo "7. View Users"
    echo "8. View Groups"
    echo "9. View Group Members"
    echo "10.Backup Configuration"
    echo "11. Exit"


    echo ""

    read -p "Enter your choice: " choice

    case $choice in
        1) create_user ;;
        2) delete_user ;;
        3) create_group ;;
        4) add_user_to_group ;;
        5) remove_user_from_group ;;
        6) create_shared_directory ;;
        7) view_users ;;
        8) view_groups ;;
	9) view_group_members ;;
	10) backup_configuration ;;
	11)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid choice!"
            ;;
    esac
done
