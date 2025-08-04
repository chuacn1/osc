#!/bin/bash
# Check if file exists
if [ -f "users.csv" ]; then
   while IFS=',' read -r username groupname shell
do
    echo "Username: $username"
    echo "Group: $groupname"
    echo "Shell: $shell"
    echo ""
done < <(tail -n +2 "users.csv")
else
    echo "Error: users.csv not found"
fi

#!/bin/bash

#!/bin/bash

# Check if user exists in system and update/create accordingly
read -p "Enter username to check/add: " username

if id "$username" ; then
    # User exists in system - update shell from CSV
    echo "User '$username' exists in system!"
    
    if grep -q "^$username," users.csv; then
        # Get shell from CSV
        shell=$(grep "^$username," users.csv | cut -d',' -f3)
        
        # Update user's shell
        if sudo usermod -s "$shell" "$username"; then
            echo "Updated $username's shell to $shell"
        else
            echo "Failed to update shell for $username"
        fi
    else
        echo "Warning: User exists but not in users.csv"
        read -p "Would you like to add this user to CSV? (y/n) " choice
        if [[ $choice == [Yy] ]]; then
            read -p "Please enter group for $username: " groupname
            read -p "Please enter shell (/bin/bash): " shell
            shell=${shell:-/bin/bash}
            echo "$username,$groupname,$shell" >> users.csv
            echo "Added $username to users.csv"
        fi
    fi
else
    # User doesn't exist - create from CSV
    echo "User does not exist in system!"
    
    if grep -q "^$username," users.csv; then
        # Get details from CSV
        groupname=$(grep "^$username," users.csv | cut -d',' -f2)
        shell=$(grep "^$username," users.csv | cut -d',' -f3)
        
        # Create user
        if sudo useradd -m -g "$groupname" -G "$groupname" -s "$shell" "$username"; then
            echo "Created user $username with shell $shell"
        else
            echo "Failed to create user $username"
        fi
    else
        # Not in CSV - collect details
        read -p "Please enter primary group for $username: " groupname
        read -p "Please enter shell (/bin/bash): " shell
        shell=${shell:-/bin/bash}

        # Create user and add to CSV
        if sudo useradd -m -g "$groupname" -G "$shell" "$username"; then
            echo "$username,$groupname,$shell" >> users.csv
            echo "Created user $username and added to users.csv"
        else
            echo "Failed to create user $username"
        fi
    fi
fi

# Group management
read -p "Enter group name to verify: " groupname

# Check if group exists
if grep -qw "$groupname" /etc/group; then
    echo "Group '$groupname' exists in system"
    echo "Members:"
    grep "^$groupname:" /etc/group | cut -d: -f4
    
    # Check if user is in this group
    if ! grep -q "^$groupname:.*\<$username\>" /etc/group; then
        read -p "User $username is not in group $groupname. Add them? (y/n) " choice
        if [[ $choice == [Yy] ]]; then
            if sudo usermod -aG "$groupname" "$username"; then
                echo "Added $username to $groupname"
            else
                echo "Failed to add $username to $groupname"
            fi
        fi
    else
        echo "$username is already a member of $groupname"
    fi
else
    echo "Group '$groupname' does not exist"
    if sudo groupadd "$groupname"; then
        echo "Created group '$groupname'"
        
        # Offer to add user to the newly created group
        read -p "Add user $username to new group $groupname? (y/n) " choice
        if [[ $choice == [Yy] ]]; then
            if sudo usermod -aG "$groupname" "$username"; then
                echo "Added $username to $groupname"
            else
                echo "Failed to add $username to $groupname"
            fi
        fi
    else
        echo "Failed to create group '$groupname'"
    fi
fi

# Home directory setup
user_home="/home/$username"

# Check if home directory exists
if [ -d "$user_home" ]; then
    echo "Home directory $user_home exists"
    
    # Get current permissions and ownership using ls/awk
    perms=$(ls -ld "$user_home" | awk '{print $1}')
    owner=$(ls -ld "$user_home" | awk '{print $3}')
    group=$(ls -ld "$user_home" | awk '{print $4}')
    
    # Fix permissions if needed (700 = drwx------)
    if [ "$perms" != "drwx------" ]; then
        echo "Correcting permissions (from $perms to drwx------)"
        sudo chmod 700 "$user_home"
    fi
    
    # Fix ownership if needed
    if [ "$owner" != "$username" ] || [ "$group" != "$username" ]; then
        echo "Correcting ownership (from $owner:$group to $username:$username)"
        sudo chown -R "$username:$username" "$user_home"
    fi
else
    # Create home directory if missing
    echo "Creating home directory: $user_home"
    sudo mkdir -p "$user_home"
    sudo chmod 700 "$user_home"
    sudo chown "$username:$username" "$user_home"
fi

# Final verification
echo "Home directory verification:"
ls -ld "$user_home"


# Project directory setup
project_dir="/opt/projects/$username"

# Create parent directory if it doesn't exist
sudo mkdir -p /opt/projects

# Check if project directory exists
if [ -d "$project_dir" ]; then
    echo "Project directory $project_dir already exists"
    
    # Get current permissions and ownership
    perms=$(ls -ld "$project_dir" | awk '{print $1}')
    owner=$(ls -ld "$project_dir" | awk '{print $3}')
    group=$(ls -ld "$project_dir" | awk '{print $4}')
    
    # Fix permissions if needed (750 = drwxr-x---)
    if [ "$perms" != "drwxr-x---" ]; then
        echo "Correcting permissions (from $perms to drwxr-x---)"
        sudo chmod 750 "$project_dir"
    fi
    
    # Fix ownership if needed
    if [ "$owner" != "$username" ] || [ "$group" != "$groupname" ]; then
        echo "Correcting ownership (from $owner:$group to $username:$groupname)"
        sudo chown -R "$username:$groupname" "$project_dir"
    fi
else
    # Create project directory
    echo "Creating project directory: $project_dir"
    sudo mkdir -p "$project_dir"
    sudo chmod 750 "$project_dir"
    sudo chown "$username:$groupname" "$project_dir"
    echo "Created project directory with:"
    echo "  - Ownership: $username:$groupname"
    echo "  - Permissions: 750 (drwxr-x---)"
fi

# Final verification
echo "Project directory verification:"
ls -ld "$project_dir"

# Audit Log Configuration
AUDIT_LOG="/var/log/user_onboarding_audit.log"
sudo touch "$AUDIT_LOG"
sudo chmod 600 "$AUDIT_LOG"  # Restrict to root access only

# Logging function
log_action() {
    local timestamp=$(date +"%Y-%m-%d %T")
    echo "[$timestamp] $1" | sudo tee -a "$AUDIT_LOG" >/dev/null
}

# Example usage throughout your script:

# User creation
log_action "Starting user onboarding process for $username"

if id "$username" &>/dev/null; then
    log_action "User $username already exists in system"
    # ... rest of user existence handling
else
    sudo useradd -m -G "$groupname" -s "$shell" "$username"
    log_action "Created user $username with shell $shell and group $groupname"
fi

# Group management
log_action "Verifying group $groupname"
if grep -qw "$groupname" /etc/group; then
    log_action "Group $groupname exists with members: $(grep "^$groupname:" /etc/group | cut -d: -f4)"
else
    sudo groupadd "$groupname"
    log_action "Created new group $groupname"
fi

# Home directory setup
log_action "Configuring home directory for $username"
if [ -d "/home/$username" ]; then
    sudo chmod 700 "/home/$username"
    sudo chown -R "$username:$username" "/home/$username"
    log_action "Verified home directory permissions (700) and ownership ($username:$username)"
else
    sudo mkdir -p "/home/$username"
    sudo chmod 700 "/home/$username"
    sudo chown "$username:$username" "/home/$username"
    log_action "Created home directory with 700 permissions and $username ownership"
fi

# Project directory setup
log_action "Configuring project directory for $username"
if [ -d "/opt/projects/$username" ]; then
    sudo chmod 750 "/opt/projects/$username"
    sudo chown "$username:$groupname" "/opt/projects/$username"
    log_action "Verified project directory permissions (750) and ownership ($username:$groupname)"
else
    sudo mkdir -p "/opt/projects/$username"
    sudo chmod 750 "/opt/projects/$username"
    sudo chown "$username:$groupname" "/opt/projects/$username"
    log_action "Created project directory with 750 permissions and $username:$groupname ownership"
fi

log_action "Completed onboarding process for $username"


#!/bin/bash

# Configuration
AUDIT_LOG="/var/log/user_onboarding_audit.log"
USERS_CSV="users.csv"

# Initialize audit log
sudo touch "$AUDIT_LOG"
sudo chmod 600 "$AUDIT_LOG"

# Logging function
log_action() {
    echo "[$(date +"%Y-%m-%d %T")] $1" | sudo tee -a "$AUDIT_LOG" >/dev/null
}

# Error handling function
handle_error() {
    log_action "ERROR: $1 - $2"
    echo "ERROR: $1" >&2
    return 1
}

# Validate username (alphanumeric + underscores)
validate_username() {
    [[ "$1" =~ ^[a-z_][a-z0-9_-]*$ ]] || return 1
    (( ${#1} <= 32 )) || return 1
    return 0
}

# Validate group name (similar to username)
validate_groupname() {
    validate_username "$1"
}

# Validate shell path
validate_shell() {
    [[ -x "$1" ]] && grep -q "$1" /etc/shells
}

# Process CSV file
while IFS=',' read -r username groupname shell; do
    # Skip empty or comment lines
    [[ -z "$username" || "$username" == \#* ]] && continue
    
    log_action "Processing user: $username"
    
    # Input validation
    if ! validate_username "$username"; then
        handle_error "Invalid username format" "$username" && continue
    fi
    
    if ! validate_groupname "$groupname"; then
        handle_error "Invalid groupname format" "$groupname" && continue
    fi
    
    if ! validate_shell "$shell"; then
        handle_error "Invalid shell path" "$shell" && continue
        shell="/bin/bash" # Default fallback
    fi

    # User creation/modification
    if id "$username" &>/dev/null; then
        if sudo usermod -s "$shell" "$username"; then
            log_action "Updated shell for existing user $username to $shell"
        else
            handle_error "Failed to update user $username" && continue
        fi
    else
        if sudo useradd -m -G "$groupname" -s "$shell" "$username"; then
            log_action "Created user $username with shell $shell"
        else
            handle_error "Failed to create user $username" && continue
        fi
    fi

    # Group management
    if ! grep -q "^$groupname:" /etc/group; then
        if ! sudo groupadd "$groupname"; then
            handle_error "Failed to create group $groupname" && continue
        fi
        log_action "Created group $groupname"
    fi

    # Add user to group if not already member
    if ! id -nG "$username" | grep -qw "$groupname"; then
        if sudo usermod -aG "$groupname" "$username"; then
            log_action "Added $username to group $groupname"
        else
            handle_error "Failed to add $username to $groupname" && continue
        fi
    fi

    # Home directory setup
    home_dir="/home/$username"
    if [ ! -d "$home_dir" ]; then
        if ! sudo mkdir -p "$home_dir"; then
            handle_error "Failed to create home directory for $username" && continue
        fi
    fi
    
    if ! sudo chmod 700 "$home_dir" || ! sudo chown "$username:$username" "$home_dir"; then
        handle_error "Failed to set permissions on $home_dir" && continue
    fi
    log_action "Verified home directory for $username"

    # Project directory setup
    project_dir="/opt/projects/$username"
    if [ ! -d "$project_dir" ]; then
        if ! sudo mkdir -p "$project_dir"; then
            handle_error "Failed to create project directory for $username" && continue
        fi
    fi
    
    if ! sudo chmod 750 "$project_dir" || ! sudo chown "$username:$groupname" "$project_dir"; then
        handle_error "Failed to set permissions on $project_dir" && continue
    fi
    log_action "Verified project directory for $username"

done < "$USERS_CSV"

log_action "User onboarding process completed"