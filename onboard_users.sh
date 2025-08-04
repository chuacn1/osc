#!/bin/bash
LOG_FILE="/var/log/user_onboarding_audit.log"
USERS_FILE="users.csv"

# ---
# Functions
# ---

log_action() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE"
}

# New function for input validation
validate_name() {
    local name="$1"
    # Usernames and group names typically must start with a letter, and
    # can contain lowercase letters, numbers, hyphens, and underscores.
    if [[ ! "$name" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        return 1 # Invalid
    fi
    return 0 # Valid
}

listUsers(){
if [ -f "$USERS_FILE" ]; then
    echo "--- Current Users in CSV ---"
    while IFS=',' read -r username groupname shell
    do
        echo "Username: $username"
        echo "Group: $groupname"
        echo "Shell: $shell"
        echo ""
    done < <(tail -n +2 "$USERS_FILE")
else
    log_action "Error: $USERS_FILE not found"
fi
}

listGroups() {
    if [ -f "$USERS_FILE" ]; then
        echo "--- List of Groups and Users from CSV ---"
        groups=$(tail -n +2 "$USERS_FILE" | cut -d',' -f2 | sort | uniq)

        for group in $groups; do
            echo "Group: $group"
            tail -n +2 "$USERS_FILE" | while IFS=',' read -r username groupname shell; do
                if [ "$groupname" = "$group" ]; then
                    echo "  - $username" 
                fi
            done
            log_action ""
        done
    else
        log_action "Error: $USERS_FILE not found"
    fi
}

# The user/group management logic has been moved into the main loop below.

# ---
# Main Script Logic
# ---

log_action "Starting user onboarding process."
listUsers
listGroups

# This is the new part that processes every user from the CSV.
# This structure ensures the script continues even if one user fails.
log_action "Processing users from $USERS_FILE..."

# Skip the header and loop through each user entry in the CSV file
tail -n +2 "$USERS_FILE" | while IFS=',' read -r username groupname usershell; do
    log_action "--- Processing user: $username ---"

    # --- Input Validation and Missing Fields Checks ---
    if [ -z "$username" ]; then
        log_action "Error: Skipping empty username entry."
        continue # Skip to the next user
    fi

    if ! validate_name "$username"; then
        log_action "Error: Skipping invalid username '$username'."
        continue
    fi

    if [ -z "$groupname" ]; then
        log_action "Warning: No group specified for user '$username'. Setting to primary group."
        groupname=$username # Default to a group with the same name as the user
    fi
    
    if ! validate_name "$groupname"; then
        log_action "Error: Skipping invalid group name '$groupname' for user '$username'."
        continue
    fi
    
    if [ -z "$usershell" ]; then
        log_action "Warning: No shell specified for user '$username'. Defaulting to /bin/bash."
        usershell="/bin/bash"
    fi

    # --- Directory and Permission Setup - ALL BASED ON USERS.CSV ---

    # Check and create system user/group based on what exists
    if id -u "$username" >/dev/null 2>&1; then
        log_action "System user '$username' already exists."
    else
        if getent group "$groupname" >/dev/null; then
            if useradd -m -s "$usershell" -g "$groupname" "$username"; then
                log_action "System user '$username' created with existing primary group '$groupname'."
            else
                log_action "Error creating user '$username' with existing group. Continuing to next user."
                continue
            fi
        else
            if useradd -m -s "$usershell" "$username"; then
                log_action "System user '$username' created with new primary group '$username'."
            else
                log_action "Error creating user '$username'. Continuing to next user."
                continue
            fi
        fi
    fi

    if ! getent group "$groupname" >/dev/null; then
        if groupadd "$groupname"; then
            log_action "System group '$groupname' created as specified in users.csv."
        else
            log_action "Error creating system group '$groupname'. Continuing to next user."
            continue
        fi
    else
        log_action "System group '$groupname' already exists."
    fi

    if usermod -a -G "$groupname" "$username"; then
        log_action "Ensured user '$username' is in group '$groupname' as per users.csv."
    else
        log_action "Error adding user '$username' to group '$groupname'. Continuing to next user."
        continue
    fi

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

done