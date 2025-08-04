#!/bin/bash
LOG_FILE="/var/log/user_onboarding_audit.log"

# ---
# Functions
# ---

log_action() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE"
}

listUsers(){
if [ -f "users.csv" ]; then
# skip the header
   while IFS=',' read -r username groupname shell
do
    echo "Username: $username"
    echo "Group: $groupname"
    echo "Shell: $shell"
    echo ""
done < <(tail -n +2 "users.csv")
else
    log_action "Error: users.csv not found"
fi
}

log_action "Starting user onboarding process."

listGroups() {
    if [ -f "users.csv" ]; then
        echo "List of Groups and Users:"
  
        # Get a list of unique group names (skip header)
        groups=$(tail -n +2 users.csv | cut -d',' -f2 | sort | uniq)

        # Loop through each group and find matching users
        for group in $groups; do
            echo "Group: $group"
            # Print users belonging to that group
            tail -n +2 users.csv | while IFS=',' read -r username groupname shell; do
                if [ "$groupname" = "$group" ]; then
                    echo "  - $username" 
                fi
            done
            log_action ""
        done
    else
        log_action "Error: users.csv not found"
    fi
}

# The addingUsersGroups function was removed because it was a source of errors.
# The correct logic is now in the main script body.


# ---
# Main Script Logic
# ---

listUsers

read -p "Enter username to check: " username
if grep -q "^$username," users.csv; then
    log_action "User '$username' exists in users.csv!"

    current_line=$(grep "^$username," users.csv)
    current_shell=$(echo "$current_line" | cut -d',' -f3)

    log_action "Current shell in CSV: $current_shell"

    read -p "Update shell? [y/N] " update
    if [[ $update =~ ^[Yy] ]]; then
        read -p "Enter new shell [$current_shell]: " new_shell
        new_shell=${new_shell:-$current_shell}
        awk -i inplace -F',' -v user="$username" -v shell="$new_shell" '
        BEGIN {OFS=","}
        NR == 1 {print; next}
        $1 == user {$3 = shell}
        {print}' users.csv
        log_action "Updated CSV: $username now has shell $new_shell"
        listUsers
    fi
else
    log_action "User '$username' not found in users.csv."

    read -p "Create new user '$username'? [y/N] " create
    if [[ $create =~ ^[Yy] ]]; then
        read -p "Enter shell for new user [/bin/bash]: " new_shell
        new_shell=${new_shell:-/bin/bash}
        
        echo "$username,,$new_shell" >> users.csv
        log_action "Added new user '$username' with shell '$new_shell' to users.csv"
        listUsers
    fi
fi
    
listGroups

read -p "Enter group name: " groupname
# Check if the group already exists in users.csv
if awk -F',' -v grp="$groupname" 'NR>1 && $2 == grp {found=1} END{exit !found}' users.csv; then
    log_action "Group '$groupname' exists."
    echo "Current members:"
    awk -F',' -v grp="$groupname" '$2 == grp {print $1}' users.csv
    # This block was corrected to handle adding users to an existing group.
    read -p "Would you like to add an existing user to this group? [y/N] " add_user
    if [[ $add_user =~ ^[Yy] ]]; then
        listUsers
        read -p "Enter username to add to group '$groupname': " username_to_add

        if grep -q "^$username_to_add," users.csv; then
            awk -i inplace -F',' -v user="$username_to_add" -v group="$groupname" '
            BEGIN {OFS=","}
            NR == 1 {print; next}
            $1 == user {$2 = group}
            {print}' users.csv

            log_action "Assigned user '$username_to_add' to group '$groupname' in users.csv"
            log_action "Updated '$username_to_add' to group '$groupname'."
            listUsers
        else
            log_action " Error: User '$username_to_add' not found!" >&2
        fi
    fi
else
    log_action "Group '$groupname' not found."
    read -p "Create new group '$groupname'? [y/N] " create_group
    if [[ $create_group =~ ^[Yy] ]]; then
        # This section creates the first user in the new group.
        read -p "Enter username to add to new group '$groupname': " username_to_add
        
        # Check if the user to be added already exists
        if grep -q "^$username_to_add," users.csv; then
            log_action "User '$username_to_add' already exists. Assigning to new group."
            
            # Use awk to find the existing user and update their group to the new one
            awk -i inplace -F',' -v user="$username_to_add" -v group="$groupname" '
            BEGIN {OFS=","}
            NR == 1 {print; next}
            $1 == user {$2 = group}
            {print}' users.csv
            
            log_action "Assigned user '$username_to_add' to the new group '$groupname'."
            listUsers
            listGroups
        else
            # User does not exist, so we create a new entry with the new group
            read -p "Enter shell for new user '$username_to_add' [/bin/bash]: " new_shell
            new_shell=${new_shell:-/bin/bash}
            
            echo "$username_to_add,$groupname,$new_shell" >> users.csv
            log_action "Added new user '$username_to_add' with shell '$new_shell' to new group '$groupname'."
            listUsers
            listGroups
        fi
    fi
fi

# ---
# Directory and Permission Setup - ALL BASED ON USERS.CSV
# ---

log_action "Setting up home and project directories based on users.csv."
read -p "Enter username to setup home directory: " username

if ! grep -q "^$username," users.csv; then
    log_action "Error: User '$username' not found in users.csv. Aborting directory setup."
    exit 1
fi

groupname=$(awk -F',' -v user="$username" '$1 == user {print $2}' users.csv 2>/dev/null)
usershell=$(awk -F',' -v user="$username" '$1 == user {print $3}' users.csv 2>/dev/null)

# --- Check and create system user/group based on what exists ---

# Check if the user already exists on the system
if id -u "$username" >/dev/null 2>&1; then
    log_action "System user '$username' already exists."
else
    # The user doesn't exist, so we create them.
    # We explicitly check if the primary group from the CSV already exists.
    if getent group "$groupname" >/dev/null; then
        # Group exists, so we create the user and set their primary group to the existing one.
        if useradd -m -s "$usershell" -g "$groupname" "$username"; then
            log_action "System user '$username' created with existing primary group '$groupname'."
        else
            log_action "Error creating user '$username' with existing group."
            exit 1
        fi
    else
        # Neither the user nor the group exists, so we use the standard useradd.
        if useradd -m -s "$usershell" "$username"; then
            log_action "System user '$username' created with new primary group '$username'."
        else
            log_action "Error creating user '$username'."
            exit 1
        fi
    fi
fi

# Check if the group exists on the system, and create it if it doesn't.
if ! getent group "$groupname" >/dev/null; then
    if groupadd "$groupname"; then
        log_action "System group '$groupname' created as specified in users.csv."
    else
        log_action "Error creating system group '$groupname'."
        exit 1
    fi
else
    log_action "System group '$groupname' already exists."
fi

# Make sure the user is in the correct group as per the CSV.
# This is a safe operation even if they are already in the group.
if usermod -a -G "$groupname" "$username"; then
    log_action "Ensured user '$username' is in group '$groupname' as per users.csv."
else
    log_action "Error adding user '$username' to group '$groupname'."
fi

# --- Now the chown commands will work because the user and group exist ---

home_dir="/home/$username"
project_dir="/opt/projects/$username"

# Home Directory Setup
if [ ! -d "$home_dir" ]; then
    mkdir -p "$home_dir"
    log_action "Created home directory '$home_dir' as per users.csv."
else
    log_action "Home directory '$home_dir' already exists."
fi
chmod 700 "$home_dir"
chown "$username:$username" "$home_dir"
log_action "Permissions and ownership corrected for '$home_dir' based on users.csv."

# Project Directory Setup
if [ ! -d "$project_dir" ]; then
    mkdir -p "$project_dir"
    log_action "Created project directory '$project_dir' as per users.csv."
else
    log_action "Project directory '$project_dir' already exists."
fi
chown "$username:$groupname" "$project_dir"
chmod 750 "$project_dir"
log_action "Ownership and permissions corrected for '$project_dir' based on users.csv."