#!/bin/bash

SCRIPT_DIR=$(dirname $0)
SCRIPT_NAME=$(basename $0)

modules_root=/sandbox/modules

if [ -d $modules_root ]; then

  modules=($(find $modules_root -maxdepth 1 -mindepth 1 -type d -printf '%f '))
  
  if [ ${#modules[@]} -gt 0 ]; then

    for mod in "${modules[@]}"; do

      mod_init_script="${modules_root}/$mod/hooks/init.sh"

      if [ -f "$mod_init_script" ]; then

        echo "$SCRIPT_NAME: Module [$mod] Executing $mod_init_script"

        $mod_init_script

        if [ $? -ne 0 ]; then
          echo "$SCRIPT_NAME: Module [$mod] WARNING- $mod_init_script execution failed"
        else
          echo "$SCRIPT_NAME: Module [$mod] $mod_init_script execution successful"
        fi

        echo ""

      fi

    done
  
  else

    echo "$SCRIPT_NAME: No modules installed at $modules_root"

  fi

else
   echo "$SCRIPT_NAME: WARNING- Module root directoy $modules_root does not exist!"
fi


echo "$SCRIPT_NAME: Execution complete"


