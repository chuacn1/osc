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
    echo "User '$username' exists in users.csv!"
    
    # Extract current details
    current_line=$(grep "^$username," users.csv)
    current_shell=$(echo "$current_line" | cut -d',' -f3)
    
    # Show current shell
    echo "Current shell in CSV: $current_shell"
    
    # Optionally update the shell
    read -p "Update shell? [y/N] " update
    if [[ $update =~ ^[Yy] ]]; then
        read -p "Enter new shell [$current_shell]: " new_shell
        new_shell=${new_shell:-$current_shell}  # Keep current if empty
    
        # Update CSV (using sed to replace the line)
        sed -i "/^$username,/s/[^,]*$/$new_shell/" users.csv
        echo "Updated CSV: $username now has shell $new_shell"
    fi
else
    echo "User '$username' not found in users.csv."

     read -p "Create new user '$username'? [y/N] " create
    if [[ $create =~ ^[Yy] ]]; then
        read -p "Enter shell for new user [/bin/bash]: " new_shell
        new_shell=${new_shell:-/bin/bash}  # Default to /bin/bash if empty
        
        # Add new user to CSV
        echo "$username,,$new_shell" >> users.csv
        echo "Added new user '$username' with shell '$new_shell' to users.csv"
        
fi
fi

    read -p "Enter group name to manage/create: " groupname

    # Check if group exists in CSV
    if grep -q ",$groupname," users.csv; then
        echo "Group '$groupname' exists in users.csv."
        echo "Members:"
        grep ",$groupname," users.csv | cut -d',' -f1

        # New option to add existing user to this group
        read -p "Would you like to add an existing user to this group? [y/N] " add_user
        if [[ $add_user =~ ^[Yy] ]]; then
            show_users
            read -p "Enter username to add to group '$groupname': " username
            
            if grep -q "^$username," users.csv; then
                current_group=$(grep "^$username," users.csv | cut -d',' -f2)
                if [ "$current_group" == "$groupname" ]; then
                    echo "User '$username' is already in group '$groupname'"
                else
                    sed -i "/^$username,/s/,[^,]*/,${groupname}/2" users.csv
                    echo "Moved '$username' from '$current_group' to '$groupname'"
                    show_group_members "$groupname"
                fi
            else
                echo "Error: User '$username' not found"
            fi
        fi
    else
        echo "Group '$groupname' does not exist in users.csv."
        read -p "Create new group '$groupname'? [y/N] " create
        if [[ $create =~ ^[Yy] ]]; then
            read -p "Enter username for this new group (existing or new): " username
            
            # Check if username exists
            if grep -q "^$username," users.csv; then
                # Update existing user's group
                current_group=$(grep "^$username," users.csv | cut -d',' -f2)
                sed -i "/^$username,/s/,[^,]*/,${groupname}/2" users.csv
                echo "Changed '$username' from '$current_group' to '$groupname'"
                
            else
                # Add new user with this group
                read -p "Enter shell for new user [/bin/bash]: " shell
                shell=${shell:-/bin/bash}
                echo "$username,$groupname,$shell" >> users.csv
                echo "Added new user '$username' with group '$groupname'"
            fi
        else
            echo "No changes made."
        fi
    fi

