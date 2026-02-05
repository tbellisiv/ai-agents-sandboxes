# Purpose

Implement each task specified below

## Task 1: Create a new sandbox template

NOTE: For this task, read the content of every file in

- Create a new template at templates/sandboxes/ named 'sb-ubuntu-noble-fw'.

- The template Docker image should use the 'sb-ubuntu-noble' at templates/sandboxes/sb-ubuntu-noble/image as the base image. 

- The contents of the templates/sandboxes/sb-ubuntu-noble-fw/artifacts directory should only include the following:
s
  - docker-compose.yml

  - README.md

  - .gitignore

- The contents of the templates/sandboxes/sb-ubuntu-noble-fw/image folder should only include the following:

  - docker/Dockerfile
  - build.sh
  - run.sh
  - run_user.sh

  The templates/sandboxes/sb-ubuntu-noble-fw/image/build.sh script should first execute templates/sandboxes/sb-ubuntu-noble/image/build.sh and check for error before building the sb-ubuntu-noble-fw/image. 

  - Each script in the templates/sandboxes/sb-ubuntu-noble-fw/hooks directory should  execute the corresponding script in templates/sandboxes/sb-ubuntu-noble/hooks and check for error.


  ## Task 2: Configure the docker-compose.yaml for the sb-ubuntu-noble-fw template use the sb-ubuntu-noble-fw image

  - Add a sb-sandbox.env file to templates/sandboxes/sb-ubuntu-noble-fw/artifacts. The contents should mirror templates/sandboxes/sb-ubuntu-noble/artifacts/sb-sandbox.env with the exception that SB_IMAGE=sb-ubuntu-noble-fw:latest.

  - Update line 47 of templates/sandboxes/sb-ubuntu-noble-fw/hooks/create/copy.sh to unconditionally set SB_IMAGE=sb-ubuntu-noble-fw:latest instead of attempting to match based on a regex.


  ## Task 3:  Add a sub-template list sub-command

  The subcommand should list each template available. The output should list each template name and it's associatd docker image (specified in sb-sandbox.env)

  ## Task 4: Add a '-f' option to the 'sb logs' sub-command to tail the sandbox container logs

  - If the '-f' option is specified appennd the '-f' option to the 'docker compose logs' command.

