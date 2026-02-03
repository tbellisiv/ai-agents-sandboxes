# Purpose

Implement each task specified below

## Task 1: Create bin/sb-templates bash script

- Create a bash script with name 'sb-templates' in the bin/ folder.The script should adhere to the same code conventions/style as the bin/sb script.

- The script should implement the following sub-commands:

   - 'init'. See the 'init sub-command' section below for details.

###  init sub-command

#### Purpose 

The purpose of 'sb-templates init' sub-command is to generate the file env/sb-templates.env.

The sub-command should do the following:

- If the env/sb-templates.env exists, indicate that the file exists and prompt the user for confirmation to either overwrite or quit.

- Prompt the user to enter a root password for template images:

  - Prompt the user to re-enter the password for confirmation of the password. Loop until the initial password and re-entered password match.

  - Run the following command to generate the password hash:

    ```bash
    openssl passwd -6 "$pass" | sed 's/\$/\$\$/g'
    ```

    where `$pass` is the password.

  - Save the generated hash in env/sb-templates.env:

    ```
    IMAGE_SUHASH=$pass
    ```

  - Write the absolute path to env/sb-templates to stdout. Following the same conventions for script output as bin/sb

