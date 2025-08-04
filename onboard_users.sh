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

addingUsersGroups() {
    local groupname="$1"
    read -p "Would you like to add a user to this group? [y/N] " add_user
    if [[ $add_user =~ ^[Yy] ]]; then
        listUsers
       read -p "Enter username to add to new group '$groupname': " username_to_add
        
        # Now, add the new user and their group to the CSV file
        echo "$username_to_add,$groupname,$shell" >> users.csv
        
        log_action "Added new user '$username_to_add' to new group '$groupname' with shell '$shell'."
        listUsers
        else
            log_action " Error: User '$username_to_add' not found!" >&2
        
    fi
}


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
    addingUsersGroups "$groupname"
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
# Directory and Permission Setup
# ---
# ---
# Directory and Permission Setup - ALL BASED ON USERS.CSV
# ---

read -p "Enter username to setup home directory: " username

# 1. Use the CSV as the source of truth to confirm the user exists.
if ! grep -q "^$username," users.csv; then
    log_action "Error: User '$username' not found in users.csv. Aborting directory setup."
    exit 1
fi

# 2. Use the CSV to get the user's group and shell.
# This ensures all actions are driven by your CSV data.
groupname=$(awk -F',' -v user="$username" '$1 == user {print $2}' users.csv 2>/dev/null)
usershell=$(awk -F',' -v user="$username" '$1 == user {print $3}' users.csv 2>/dev/null)

# 3. Create the system user and group, ONLY if they are not already there.
# This makes the system reflect what's in your CSV.
if ! id -u "$username" >/dev/null 2>&1; then
    if useradd -m -s "$usershell" "$username"; then
        log_action "System user '$username' created as specified in users.csv."
    else
        log_action "Error creating system user '$username'."
        exit 1
    fi
else
    log_action "System user '$username' already exists."
fi

# 4. Check if the group from the CSV exists on the system, and create it if it doesn't.
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

# 5. Add the user to the group from the CSV.
if usermod -a -G "$groupname" "$username"; then
    log_action "Added user '$username' to group '$groupname' as per users.csv."
else
    log_action "Error adding user '$username' to group '$groupname'."
fi

# ---
# Now that the system reflects the CSV, the chown commands will work.
# This section directly addresses points 4 and 5 of your assignment.
# ---

home_dir="/home/$username"
project_dir="/opt/projects/$username"

# 4. Setup home directory [5 marks]
if [ ! -d "$home_dir" ]; then
    mkdir -p "$home_dir"
    log_action "Created home directory '$home_dir' as per users.csv."
else
    log_action "Home directory '$home_dir' already exists."
fi
chmod 700 "$home_dir"
chown "$username:$username" "$home_dir"
log_action "Permissions and ownership corrected for '$home_dir' based on users.csv."

# 5. Create a project directory for the user [5 marks]
if [ ! -d "$project_dir" ]; then
    mkdir -p "$project_dir"
    log_action "Created project directory '$project_dir' as per users.csv."
else
    log_action "Project directory '$project_dir' already exists."
fi
chown "$username:$groupname" "$project_dir"
chmod 750 "$project_dir"
log_action "Ownership and permissions corrected for '$project_dir' based on users.csv."