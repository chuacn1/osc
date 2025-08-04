#!/bin/bash
LOG_FILE="/var/log/user_onboarding_audit.log"

# ---
# Functions
# ---

log_action() {
    local message="$1"
    log_action "$(date '+%Y-%m-%d %H:%M:%S') - $message"  
}
# Lists all users, their groups, and shells from the CSV file
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

#Lists all users, their groups, and shells in a CSV format
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
            log_action "" >> 
        done
    else
        log_action "Error: users.csv not found" continue
    fi
}

# Function to add an existing user to a group
    addingUsersGroups(){
    read -p "Would you like to add an existing user to this group? [y/N] " add_user
        if [[ $add_user =~ ^[Yy] ]]; then
            listUsers
            read -p "Enter username to add to group '$groupname': " username_to_add
         
            # Check if user exists
            if grep -q "^$username_to_add," users.csv; then
                # Add user to group in CSV
                sed -i "/^$username_to_add,/s/,$/,$groupname/" users.csv
                log_action " - Added user '$username_to_add' to group '$groupname'." continue

                listGroups
                fi
                fi
    }

# ---
# Main Script Logic
# ---

listUsers

# Check if a specific user exists in the CSV file
read -p "Enter username to check: " username
if grep -q "^$username," users.csv; then
    log_action "User '$username' exists in users.csv!"   continue

    # Extract current details
    current_line=$(grep "^$username," users.csv)
    current_shell=$(echo "$current_line" | cut -d',' -f3)

    # Show current shell
    log_action "Current shell in CSV: $current_shell"   continue

        read -p "Update shell? [y/N] " update
    if [[ $update =~ ^[Yy] ]]; then
        read -p "Enter new shell [$current_shell]: " new_shell
        new_shell=${new_shell:-$current_shell}  # Keep current if empty
    
        # Update CSV (using sed to replace the line)
        sed -i "/^$username,/s/[^,]*$/$new_shell/" users.csv
        log_action " Updated CSV: $username now has shell $new_shell"   continue
         listUsers
    fi
    else
    
    log_action "User '$username' not found in users.csv."   continue

     read -p "Create new user '$username'? [y/N] " create
    if [[ $create =~ ^[Yy] ]]; then
        read -p "Enter shell for new user [/bin/bash]: " new_shell
        new_shell=${new_shell:-/bin/bash}  # Default to /bin/bash if empty
        
        # Add new user to CSV
        echo "$username,,$new_shell" >> users.csv
        log_action "Added new user '$username' with shell '$new_shell' to users.csv"   continue
         listUsers
    fi
    fi
    
    listGroups

    read -p "Enter group name: " groupname

    # Check if group exists in CSV
    if grep -q ",$groupname," users.csv; then
        log_action "Group '$groupname' exists in users.csv."   continue
        echo "Members:" 
        grep ",$groupname," users.csv | cut -d',' -f1
    addingUsersGroups

    else
        log_action "Group '$groupname' not found in users.csv."   continue
        read -p "Create new group '$groupname'? [y/N] " create_group
        if [[ $create_group =~ ^[Yy] ]]; then
            echo ",$groupname," >> users.csv
            log_action " Added new group '$groupname' to users.csv"   continue
    fi

# ---
# Directory and Permission Setup
# ---

# Create or correct home directory permissions
    read -p "Enter username to setup home directory: " username
    home_dir="/home/$username"

    if [ -d "$home_dir" ]; then
        log_action "Home directory '$home_dir' already exists."   
            # Correct the permissions and ownership
        chmod 700 "$home_dir" 
        chown "$username:$username" "$home_dir"
        log_action "Permissions and ownership corrected for '$home_dir'."   
    else
        mkdir -p "$home_dir"    
        chmod 700 "$home_dir" 
        chown "$username:$username" "$home_dir"
        log_action "Created home directory '$home_dir' with 700 permissions."  
    fi

# Set up project directory
    project_dir="/opt/projects/$username"
    # Get the user's group from the CSV file
# awk finds the line with the matching username and prints the second field.
groupname=$(awk -F',' -v user="$username" '$1 == user {print $2}' users.csv)

    if [ -d "$project_dir" ]; then
        log_action "Project directory '$project_dir' already exists."
            # Correct ownership and permissions
        chown "$username:$groupname" "$project_dir"
        chmod 750 "$project_dir"
        log_action "- Ownership and permissions corrected for '$project_dir'."
    else
        # Create the project directory and set ownership/permissions
        mkdir -p "$project_dir"
        chown "$username:$groupname" "$project_dir"
        chmod 750 "$project_dir"
        log_action " Created project directory '$project_dir' with 750 permissions." 
    fi








