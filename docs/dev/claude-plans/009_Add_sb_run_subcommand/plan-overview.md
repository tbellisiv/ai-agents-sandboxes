# Purpose

The objective is to add an 'run' sub-command that runs a one-off command in the Docker compose service that corresponds to the sandbox.

# References

**Docker Compose 'run' Command** 
- https://docs.docker.com/reference/cli/docker/compose/run

## Command-line Syntax

The command-line syntax for the subcommand is similar to the syntax for the docker compose `exec` command :

`sb run [<sandbox-id>] [-q] [OPTIONS] COMMAND [ARGS...]`

Where

- `<sandbox-id>` is the optional ID of the sandbox. If not specified, the default sandbox is assumed.

- `[-q]` is flag that supresses all echo statements. The only output should be the output from 'docker compose run'.

- `[OPTIONS]` are the same options supported in `docker compose exec`

- `COMMAND` is the command to execute

- `[ARGS...]` are optional arguments to pass to the command

## Execution 

The subcommand will construct and execute a 'docker compose run' command from the command line arguments.
