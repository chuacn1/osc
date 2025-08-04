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

read -p "Enter username to check: " username

# Check if username exists in CSV
if grep -q "^$username," users.csv; then
    echo "User '$username' exists in records!"
    
    # Extract shell from CSV (3rd column)
    shell=$(grep "^$username," users.csv | cut -d',' -f3)
    echo "Configured shell in CSV: $shell"
    
    # Update system login shell if different
    current_shell=$(getent passwd "$username" | cut -d':' -f7)
    if [ "$current_shell" != "$shell" ]; then
        echo "Updating $username's shell from $current_shell to $shell..."
        if sudo usermod -s "$shell" "$username"; then
            echo "Successfully updated shell!"
        else
            echo "Failed to update shell. Try running as root."
        fi
    else
        echo "Shell is already correct. No changes needed."
    fi
else
    echo "User '$username' not found in records. No action taken."
fi