#1	Read and parse users.csv [5 marks]	Correctly open and loop through each line of users.csv.	Use IFS, read, or cut to extract fields (username, groupname, shell).

#2.	Check and manage user accounts [5 marks] Check if the user already exists. If user exists, update their login shell to the specified shell in the CSV. 	If the user does not exist, create the user with the specified shell.
#3.	Verify and manage group membership [5 marks]	Check if the specified group exists; if not, create it. Ensure the user is added to the group.
#4.	Setup home directory [5 marks] Ensure that the user’s home directory is created with 700 permissions.	If it already exists, correct its permissions and ownership if needed.
#5.	Create a project directory for the user [5 marks] • Create a directory at /opt/projects/<username>. 	Set ownership to <username>:<groupname>. Set permissions to 750.
#6.	Log actions to /var/log/user_onboarding_audit.log [5 marks] 	Log every significant action (user creation, group addition, directory setup). Include timestamps and clear messages.
#7.	Implement error handling and input validation [5 marks] 	Ensure the script continues processing other users if one entry fails.	Include checks for missing fields or invalid characters in usernames/groups.
