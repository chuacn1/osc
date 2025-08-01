# Check if file exists
if [ -f "users.csv" ]; then
    cat users.csv
else
    echo "Error: users.csv not found"
fi

# Process each line
while read -r line
do
    echo "$line"
done < users.csv

#IFS, read or cut to extract fields
while IFS=',' read -r username groupname shell
do
    echo "Username: $username"
    echo "Group: $groupname"
    echo "Shell: $shell"
    echo ""  # Empty line between entries
done < users.csv:
