#!/bin/bash

script_name=$(basename $0)

user_id=$1
user_name=$2
group_name=$3
user_hash="$4"

#see if a user with the specified user ID exists; if so, return the user ID/name  and home directory
existing_user_name=$(awk -F: "\$3 == $user_id {print \$1}" /etc/passwd)
if [[ $? -eq 0 && -n "$existing_user_name" ]]; then

    user_home=$(getent passwd ${existing_user_name} | cut -d: -f6)

    # Set user password if hash is provided
    if [ -n "$user_hash" ]; then
        usermod -p "$user_hash" "$existing_user_name"
    fi

    echo -e "SB_LOGIN_USER_ID=$user_id\nSB_LOGIN_USER_NAME=$existing_user_name\nSB_LOGIN_USER_HOME=$user_home\n"
    
else

    #create the user, add it to the group and return the user ID/name and home directory
    useradd -m -u ${user_id} -g ${group_name} ${user_name}

    # Set user password if hash is provided
    if [ -n "$user_hash" ]; then
        usermod -p "$user_hash" "$user_name"
    fi

    user_home=$(getent passwd ${user_name} | cut -d: -f6)

    echo -e "SB_LOGIN_USER_ID=$user_id\nSB_LOGIN_USER_NAME=$user_name\nSB_LOGIN_USER_HOME=$user_home\n"

fi


