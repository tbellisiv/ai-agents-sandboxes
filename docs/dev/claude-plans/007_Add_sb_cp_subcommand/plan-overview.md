# Purpose

The objective is to add a 'cp' sub-command to the bin/sb command for copying files between the host and the sandbox (container)

# References

**Docker Compose 'cp' Command** 
- https://docs.docker.com/reference/cli/docker/compose/cp/

## Command-line Syntax

The command-line syntax for the subcommand is similar to the syntax for the 'docker compose cp' command and can take two forms:

Form 1: `sb cp [<sandbox-id>] cp [-a] [-L] <compose-service>:<src-path> <dest-path>`

Form 2: `sb cp [<sandbox-id>] cp [-a] [-L] <src-path> <compose-service>:<dest-path>`

In Form 1, the command copies from files/directories from the sandbox to the host.

In Form 2, the command copies files/directories from the host to the sandox.

In both forms:

- `<sandbox-id>` is the optional ID of the sandbox. If not specified, the default sandbox is assumed.

- `<compose-service>` is the name of the docker compose service for the sandbox as specified in `SB_COMPOSE_SERVICE` variable in the sandboxes sb-compose.enf

- The `-a` option is identical to the docker compose cp `-a` option

- The `-L` option is identical to the docker compose cp `-L` option

## Execution 

The subcommand will construct and execute a 'docker-compose cp' command from the command line arguments.
