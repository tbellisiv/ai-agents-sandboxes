#!/bin/bash

script_name=$(basename $0)

id=$1
name=$2

#see a group with the specified group ID exists; if so return the group ID/name
existing_group_name=$(awk -F: "\$3 == $id {print \$1}" /etc/group)
if [[ $? -eq 0 && -n "$existing_group_name" ]]; then
    echo -e "SB_GROUP_ID=$id\nSB_GROUP_NAME=$existing_group_name"
    exit 0
fi

set -e

#create the group and return ID/name
groupadd -g ${id} ${name}
echo -e "SB_GROUP_ID=$id\nSB_GROUP_NAME=$name"

exit 0

