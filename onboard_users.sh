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

add_to_group() {
    local username="$1"
    local groupname="$2"
    
    # Check if user exists
    if ! grep -q "^$username," users.csv; then
        log_action "Error: User $username not found"
        return 1
    fi
    
    # Add group to user's record (appends if groups exist)
    awk -i inplace -F',' -v user="$username" -v group="$groupname" '
    BEGIN {OFS=","}
    $1 == user {
        if (NF == 2) $3 = $2; $2 = group  # Handle missing shell case
        else if ($2 !~ group) $2 = $2 "/" group
    }
    {print}' users.csv
    
    log_action "Added $username to group $groupname"
}

addingUsersGroups() {
    local groupname="$1"
    read -p "Add user to group '$groupname'? [y/N] " add_user
    [[ $add_user =~ ^[Yy] ]] || return
    
    listUsers
    read -p "Enter username to add: " username
    add_to_group "$username" "$groupname"
    listGroups
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
if grep -q ",$groupname\(/\|$\)" users.csv; then
    log_action "Group '$groupname' exists."
    echo "Members:"
    awk -F',' -v group="$groupname" '$2 ~ group {print $1}' users.csv
    addingUsersGroups "$groupname"
else
    log_action "Group '$groupname' not found."
    read -p "Create it? [y/N] " create
    [[ $create =~ ^[Yy] ]] && {
        echo "$username,$groupname,/bin/bash" >> users.csv  # Example new user
        log_action "Created group '$groupname'"
    }
fi

# ---
# Directory and Permission Setup
# ---

read -p "Enter username to setup home directory: " username
home_dir="/home/$username"

if [ -d "$home_dir" ]; then
    log_action "Home directory '$home_dir' already exists."
    chmod 700 "$home_dir" 
    chown "$username:$username" "$home_dir"
    log_action "Permissions and ownership corrected for '$home_dir'."
else
    mkdir -p "$home_dir"    
    chmod 700 "$home_dir" 
    chown "$username:$username" "$home_dir"
    log_action "Created home directory '$home_dir' with 700 permissions."
fi

project_dir="/opt/projects/$username"
groupname=$(awk -F',' -v user="$username" '$1 == user {print $2}' users.csv 2>/dev/null)

if [ -d "$project_dir" ]; then
    log_action "Project directory '$project_dir' already exists."
    chown "$username:$groupname" "$project_dir"
    chmod 750 "$project_dir"
    log_action "Ownership and permissions corrected for '$project_dir'."
else
    mkdir -p "$project_dir"
    chown "$username:$groupname" "$project_dir"
    chmod 750 "$project_dir"
    log_action "Created project directory '$project_dir' with 750 permissions."
fi