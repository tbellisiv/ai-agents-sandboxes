# Purpose

The objective is to add support for using the rsync command to copy files from the host filesystem into sandbox containers filesystem.

# Approach

## Specify the file source files and destination in YAML

- The YAML has the following format:

- A top-level `sync` object that consists of:

  - A `spec` array that consists of the following:

    - A `host` object that consists of 

      - A required `path` property (string). `path` represents a file or directory path on the host filesystem that supports string Bash string interpolation. String interpolation will be use primarily for referencing environment variables.

    - A `sandbox` object that consists of:

      - A required `path` property. `path` represents a file path (only if the host path references a file) or a directory path in the sandbox filesystem. `path` supports string interpolation for references to variables defined in the sandbox's .env Docker compose file with the syntax `__ENV_<variable-name>`. For example the token `__ENV__SB_LOGIN_USER_HOME` will be replace with the value of `SB_LOGIN_USER_HOME` defined in the .env file.

      - An optional `includes` array that is a list of rsync patterns of type string for filtering files or directories to include from host path.

      - An optional `excludes` property that is an array of rsync patterns of type string for filtering files or directories to exclude from host path.

- Below is example YAML. The array entry under `sync.spec` is an example. Refer the comments above for example for details.

  ```yaml
  sync:

    spec: 

      # Example 1: Sync a single file in host user's home to the sandbox user's .ssh/ sub-directory under the sandbox user's home directory.
      - host: 
          path: 
            - $HOME/.ssh/tbellisiv_mediware_github
        sandbox:
          path: __ENV__SB_LOGIN_USER_HOME/.ssh

      # Example 2: Sync a single file to the sandbox user's home directory and rename the file. __ENV__SB_LOGIN_USER_HOME is a token that is replace by looking up the 
      - host: 
          path: 
            - $HOME/my-file.txt
        sandbox:
          path: __ENV__SB_LOGIN_USER_HOME/my-file-renamed.txt

      # Example 3: Sync a directory on the host to a directory in the sandbox- filtering the files based on rysnc include pattern
      - host: 
          path: 
            - $HOME/.config
        sandbox:
          path: __ENV__SB_LOGIN_USER_HOME
          include: 
            - '*.env'
            - 'tmux/***'
            - nvim/
            - mimeapps.txt

      # Example 4: Sync a directory on the host to a directory in the sandbox- filtering the files based on a rysnc exclude patterns
      - host: 
          path: 
            - $HOME/.config
        sandbox:
          path: __ENV__SB_LOGIN_USER_HOME
          exclude:
            - '**/*secrets*'
            - 'tmux/tmux.conf'

      # Example 5: Sync a directory on the host to a directory in the sandbox- filtering the files based on rysnc include and exclude patterns
      - host: 
          path: 
            - $HOME/.config
        sandbox:
          path: __ENV__SB_LOGIN_USER_HOME
          include: 
            - '*.env'
            - 'tmux/***''
            - nvim/
            - mimeapps.txt
          exclude:
            - '**/*secrets*'
  ```

## Use `rsync` and `docker compose cp` to sync files

- For each entry under `sync.spec` in the YAML, do the following:

  - Create a unique temporary directory.
  
  - Execute the `rsync` command (with verbose output) and pass it the following arguments:
  
    - The host path as the source

    - The temporary directory as the destination
    
    - The include patterns (if specified)

    - The exclude patterns (if specified)

  - Save the output of the rsync command to a file in the sandbox's `logs` directory
    
  - If the temporary directory contains files, execute a `docker compose cp` command (with verbose output) to copy the files to the sandbox path specified in the YAML. Save command output to the sandbox's `logs` directory.

  - If the `rsync` and `docker compose cp` commands succeed, delete the temporary directory. Otherwise print an error message with the following information:
  
     - The path to the temp directory
     - The path to the generated logfile for the `rsync` output
     - The path to the generated logfile for the `docker compose cp` output

## Updates to bin/sb script

### Add new sync_files() function 

- The function takes an input:
  - A string consisting of YAML formatted as described above in 'Specify the file source files and destination in YAML' 

- The executes the logic specified above in 'Use `rsync` and `docker compose cp` to sync the files

### Updates to sandbox_sync() function

- Add logic to check the user 'env' directory (the same logic used for checking for user.env and user-secrets.env) for the presence of a `user-sync.yml` file. If present:

  - Execute sync_files(), passing it the contents of `user-sync.yml`

- Add logic to check the sandbox project 'env' directory (the same logic used for checking for sb-project.env) for the presence of a `sb-project-sync.yml` file. If present:

  - Execute sync_files(), passing it the contents of `sb-project-sync.yml`

- Add logic to check the sandbox 'env' directory (the same logic used for checking for sb-sandbox.env) for the presence of a `sb-sandbox-sync.yml` file. If present:

  - Execute sync_files(), passing it the contents of `sb-sandbox-sync.yml`  

  







