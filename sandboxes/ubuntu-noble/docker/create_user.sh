#!/bin/bash

script_name=$(basename $0)

username=$1

getent group $username >/dev/null
if [ $? -ne 0 ]; then
    echo "${script_name}: Creating group '$username' ..."
    echo "groupadd ${username}"
    groupadd ${username}
fi

id -u ${username} &>/dev/null 
if [ $? -ne 0 ]; then
    echo "${script_name}: Creating user '$username' ..."
    echo "useradd -m -g ${username} ${username}"
    useradd -m -g ${username}  ${username}
else
    echo "${script_name}: Skipping- user '$username' exists"
fi

