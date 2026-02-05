#!/bin/bash

SCRIPT_DIR=$(dirname $0)
SCRIPT_NAME=$(basename $0)

modules_root=/sandbox/modules

if [ -d $modules_root ]; then

  modules=($(find $modules_root -maxdepth 1 -mindepth 1 -type d -printf '%f '))
  
  if [ ${#modules[@]} -gt 0 ]; then

    for mod in "${modules[@]}"; do

      shell_login_hook_script="${modules_root}/$mod/hooks/shell-login/login.sh"

      if [ -f "$shell_login_hook_script" ]; then

        if grep -q -E -i '^(true)|(1)$' <<< "${SB_HOOK_DEBUG_ENABLED}"; then
          echo "$SCRIPT_NAME: Module [$mod] Executing $shell_login_hook_script"
        fi

        $shell_login_hook_script

        if [ $? -ne 0 ]; then
          echo "$SCRIPT_NAME: Module [$mod] WARNING- $shell_login_hook_script execution failed"
        else
          if grep -q -E -i '^(true)|(1)$' <<< "${SB_HOOK_DEBUG_ENABLED}"; then
            echo "$SCRIPT_NAME: Module [$mod] $shell_login_hook_script execution successful"
          fi
        fi

        echo ""

      fi

    done
  
  else

    if grep -q -E -i '^(true)|(1)$' <<< "${SB_HOOK_DEBUG_ENABLED}"; then
      echo "$SCRIPT_NAME: No modules installed at $modules_root"
    fi

  fi

else
  if grep -q -E -i '^(true)|(1)$' <<< "${SB_HOOK_DEBUG_ENABLED}"; then
    echo "$SCRIPT_NAME: WARNING- Module root directory $modules_root does not exist!"
  fi
fi

if grep -q -E -i '^(true)|(1)$' <<< "${SB_HOOK_DEBUG_ENABLED}"; then
  echo "$SCRIPT_NAME: Execution complete"
fi

