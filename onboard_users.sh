#!/bin/bash
LOG_FILE="/var/log/user_onboarding_audit.log"
INPUT_FILE="users.csv"

# ---
# Functions
# ---

log_action() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE"
}

validate_input() {
    local input_value="$1"
    local pattern="$2"
    if [[ ! "$input_value" =~ $pattern ]]; then
        return 1 # Invalid
    fi
    return 0 # Valid
}

listUsers() {
    if [ ! -f "$INPUT_FILE" ]; then
        log_action "Error: $INPUT_FILE not found." >&2
        return 1
    fi

    if [ $(wc -l < "$INPUT_FILE") -lt 2 ]; then
        log_action "Warning: $INPUT_FILE is empty or only contains a header."
        return 0
    fi

    log_action "Listing users from $INPUT_FILE:"
    while IFS=',' read -r username groupname shell; do
        if [[ "$username" == "username" ]]; then
            continue
        fi
        log_action "  - Username: $username, Group: $groupname, Shell: $shell"
    done < <(tail -n +2 "$INPUT_FILE")
}

listGroups() {
    if [ ! -f "$INPUT_FILE" ]; then
        log_action "Error: $INPUT_FILE not found." >&2
        return 1
    fi

    log_action "Listing groups and their members from $INPUT_FILE:"
    local groups
    groups=$(tail -n +2 "$INPUT_FILE" | cut -d',' -f2 | sort | uniq)

    if [ -z "$groups" ]; then
        log_action "No groups found in $INPUT_FILE."
        return 0
    fi

    for group in $groups; do
        if [ -n "$group" ]; then
            log_action "Group: $group"
            while IFS=',' read -r username groupname_in_file shell; do
                if [[ "$groupname_in_file" == "$group" ]]; then
                    log_action "  - $username"
                fi
            done < <(tail -n +2 "$INPUT_FILE")
        fi
    done
}

# ---
# Main Script Logic
# ---

# Pre-checks before starting
if [ ! -f "$INPUT_FILE" ]; then
    log_action "Critical Error: $INPUT_FILE not found. Cannot proceed." >&2
    exit 1
fi

log_action "Starting user onboarding and management process."

# ---
# Interactive CSV File Management
# This section allows you to modify the users.csv file. No system changes are made here.
# ---

# Interactive User Management Section
listUsers

username_check=""
while true; do
    read -p "Enter username to check (or press Enter to skip CSV management): " username_check
    
    # If user presses Enter to skip, break the loop
    if [ -z "$username_check" ]; then
        log_action "Skipping interactive user management."
        break
    fi

    # Validate the input
    if ! validate_input "$username_check" '^[a-z_][a-z0-9_-]{0,31}$'; then
        log_action "Error: Invalid username format '$username_check'. Usernames must start with a lowercase letter or underscore, and contain only lowercase letters, numbers, hyphens, or underscores, with a maximum length of 32 characters." >&2
        # Loop continues, prompting the user again
    else
        # Valid username provided, proceed with the logic
        if grep -q "^$username_check," "$INPUT_FILE"; then
            log_action "User '$username_check' exists in $INPUT_FILE!"
            current_line=$(grep "^$username_check," "$INPUT_FILE")
            IFS=',' read -r -a user_data <<< "$current_line"
            current_group="${user_data[1]}"
            current_shell="${user_data[2]}"

            log_action "Current group in CSV: $current_group"
            log_action "Current shell in CSV: $current_shell"

            read -p "Update user '$username_check' [y/N]? " update_user
            if [[ "$update_user" =~ ^[Yy]$ ]]; then
                read -p "Enter new group [$current_group]: " new_group
                new_group=${new_group:-$current_group}
                if ! validate_input "$new_group" '^[a-z_][a-z0-9_-]{0,31}$'; then
                    log_action "Error: Invalid group name '$new_group'. Groups must follow the same rules as usernames." >&2
                else
                    read -p "Enter new shell [$current_shell]: " new_shell
                    new_shell=${new_shell:-$current_shell}
                    if [ ! -x "$new_shell" ] && [ "$new_shell" != "default" ]; then
                        log_action "Warning: Shell '$new_shell' does not appear to be a valid executable. Proceeding anyway."
                    fi

                    awk -i inplace -F',' -v user="$username_check" -v group="$new_group" -v shell="$new_shell" '
                    BEGIN {OFS=","}
                    $1 == user {$2 = group; $3 = shell}
                    {print}' "$INPUT_FILE"
                    log_action "Updated CSV: $username_check now has group $new_group and shell $new_shell."
                fi
            fi
        else
            log_action "User '$username_check' not found in $INPUT_FILE."
            read -p "Create new user '$username_check'? [y/N] " create
            if [[ "$create" =~ ^[Yy]$ ]]; then
                read -p "Enter group for new user: " new_group
                if ! validate_input "$new_group" '^[a-z_][a-z0-9_-]{0,31}$'; then
                    log_action "Error: Invalid group name format '$new_group'. Creation aborted." >&2
                else
                    read -p "Enter shell for new user [/bin/bash]: " new_shell
                    new_shell=${new_shell:-/bin/bash}
                    if [ ! -x "$new_shell" ]; then
                        log_action "Warning: Shell '$new_shell' does not appear to be a valid executable. Proceeding anyway."
                    fi
                    echo "$username_check,$new_group,$new_shell" >> "$INPUT_FILE"
                    log_action "Added new user '$username_check' to $INPUT_FILE."
                fi
            fi
        fi
        # Break the loop after a valid username is processed
        break
    fi

# Group management section (modifies the CSV file)
# Group Management Section
listGroups

groupname_check=""
while true; do
    read -p "Enter group name to manage (or press Enter to skip): " groupname_check

    # If user presses Enter to skip, break the loop
    if [ -z "$groupname_check" ]; then
        log_action "Skipping interactive group management."
        break
    fi

    # Validate the input
    if ! validate_input "$groupname_check" '^[a-z_][a-z0-9_-]{0,31}$'; then
        log_action "Error: Invalid group name format '$groupname_check'. Management aborted." >&2
    else
        # Check if the group exists in the CSV
        if awk -F',' -v grp="$groupname_check" 'NR>1 && $2 == grp {found=1} END{exit !found}' "$INPUT_FILE"; then
            log_action "Group '$groupname_check' exists."
            log_action "Current members:"
            awk -F',' -v grp="$groupname_check" 'NR>1 && $2 == grp {print " - " $1}' "$INPUT_FILE"

            read -p "Would you like to add an existing user to this group? [y/N] " add_user
            if [[ "$add_user" =~ ^[Yy]$ ]]; then
                listUsers
                read -p "Enter username to add to group '$groupname_check': " user_to_add
                if grep -q "^$user_to_add," "$INPUT_FILE"; then
                    user_group=$(grep "^$user_to_add," "$INPUT_FILE" | cut -d',' -f2)
                    if [ -n "$user_group" ] && [ "$user_group" != "$groupname_check" ]; then
                        log_action "Warning: User '$user_to_add' is already in group '$user_group'. This will change their primary group."
                        read -p "Continue and reassign user to group '$groupname_check'? [y/N] " confirm_reassign
                        if [[ ! "$confirm_reassign" =~ ^[Yy]$ ]]; then
                            log_action "Reassignment cancelled."
                            continue
                        fi
                    fi
                    awk -i inplace -F',' -v user="$user_to_add" -v group="$groupname_check" '
                    BEGIN {OFS=","}
                    NR == 1 {print; next}
                    $1 == user {$2 = group}
                    {print}' "$INPUT_FILE"
                    log_action "Assigned user '$user_to_add' to group '$groupname_check' in $INPUT_FILE."
                    listGroups
                else
                    log_action "Error: User '$user_to_add' not found in $INPUT_FILE!" >&2
                fi
            fi
        else
            log_action "Group '$groupname_check' not found."
            read -p "Create new group '$groupname_check'? [y/N] " create_group
            if [[ "$create_group" =~ ^[Yy]$ ]]; then
                read -p "Enter username to add to new group '$groupname_check': " user_to_add
                if grep -q "^$user_to_add," "$INPUT_FILE"; then
                    log_action "User '$user_to_add' exists. Assigning to new group."
                    awk -i inplace -F',' -v user="$user_to_add" -v group="$groupname_check" '
                    BEGIN {OFS=","}
                    NR == 1 {print; next}
                    $1 == user {$2 = group}
                    {print}' "$INPUT_FILE"
                    log_action "Assigned user '$user_to_add' to the new group '$groupname_check'."
                    listGroups
                else
                    read -p "Enter shell for new user '$user_to_add' [/bin/bash]: " new_shell
                    new_shell=${new_shell:-/bin/bash}
                    if [ ! -x "$new_shell" ]; then
                        log_action "Warning: Shell '$new_shell' does not appear to be a valid executable. Proceeding anyway."
                    fi
                    echo "$user_to_add,$groupname_check,$new_shell" >> "$INPUT_FILE"
                    log_action "Added new user '$user_to_add' with shell '$new_shell' to new group '$groupname_check'."
                    listGroups
                fi
            fi
        fi
        # Break the loop after a valid group is processed
        break
    fi

# ---
# System Provisioning Based on users.csv
# This section reads the entire CSV and makes system-level changes.
# ---

echo "------------------------------------------------------"
read -p "Do you want to proceed with system provisioning based on '$INPUT_FILE'? This will create/update users, groups, and directories. [y/N] " confirm_provisioning

if [[ ! "$confirm_provisioning" =~ ^[Yy]$ ]]; then
    log_action "System provisioning cancelled by user. Exiting."
    exit 0
fi

log_action "Starting system-level user and directory setup from $INPUT_FILE."
tail -n +2 "$INPUT_FILE" | while IFS=',' read -r username groupname usershell; do
    # Skip lines with missing or invalid data
    if [ -z "$username" ] || [ -z "$usershell" ]; then
        log_action "Error: Skipping line due to missing username or shell: '$username,$groupname,$usershell'." >&2
        continue
    fi
    if ! validate_input "$username" '^[a-z_][a-z0-9_-]{0,31}$'; then
        log_action "Error: Skipping user '$username' due to invalid username format." >&2
        continue
    fi
    if [ -n "$groupname" ] && ! validate_input "$groupname" '^[a-z_][a-z0-9_-]{0,31}$'; then
        log_action "Error: Skipping user '$username' due to invalid group name '$groupname'." >&2
        continue
    fi
    if [ -n "$usershell" ] && [ ! -x "$usershell" ]; then
        log_action "Warning: User '$username' has an invalid shell '$usershell'. Setting to default '/bin/bash'."
        usershell="/bin/bash"
    fi

    log_action "Processing user '$username'..."

    # Ensure the group exists on the system
    if [ -n "$groupname" ]; then
        if getent group "$groupname" >/dev/null; then
            log_action "System group '$groupname' already exists."
        else
            if groupadd "$groupname"; then
                log_action "System group '$groupname' created as specified."
            else
                log_action "Error: Failed to create system group '$groupname'. Cannot proceed for this user." >&2
                continue
            fi
        fi
    fi

    # Create the user if they don't exist
    if id -u "$username" >/dev/null 2>&1; then
        log_action "System user '$username' already exists."
    else
        if [ -n "$groupname" ]; then
            if useradd -m -s "$usershell" -g "$groupname" "$username"; then
                log_action "System user '$username' created with primary group '$groupname'."
            else
                log_action "Error: Failed to create system user '$username' with group '$groupname'." >&2
                continue
            fi
        else
            if useradd -m -s "$usershell" "$username"; then
                log_action "System user '$username' created with default primary group '$username'."
                groupname="$username"
            else
                log_action "Error: Failed to create system user '$username'." >&2
                continue
            fi
        fi
    fi

    # Ensure user is a member of the specified group
    if [ -n "$groupname" ]; then
        if ! id -nG "$username" | grep -qw "$groupname"; then
            if usermod -a -G "$groupname" "$username"; then
                log_action "Ensured user '$username' is a member of group '$groupname'."
            else
                log_action "Error: Failed to add user '$username' to group '$groupname'." >&2
            fi
        fi
    fi

    # Home Directory Setup
# Home Directory Setup
home_dir="/home/$username"
if [ ! -d "$home_dir" ]; then
    mkdir -p "$home_dir"
    log_action "Created home directory '$home_dir'."
else
    log_action "Home directory '$home_dir' already exists."
fi
# Correct syntax: these are two separate commands on two separate lines.
chown "$username:$groupname" "$home_dir"  
chmod 700 "$home_dir"
log_action "Permissions and ownership corrected for '$home_dir'."

    # Project Directory Setup
    project_dir="/opt/projects/$username"
    if [ ! -d "$project_dir" ]; then
        mkdir -p "$project_dir"
        log_action "Created project directory '$project_dir'."
    else
        log_action "Project directory '$project_dir' already exists."
    fi
    chown "$username:$groupname" "$project_dir"
    chmod 750 "$project_dir"
    log_action "Ownership and permissions corrected for '$project_dir'."

done

log_action "Script finished."