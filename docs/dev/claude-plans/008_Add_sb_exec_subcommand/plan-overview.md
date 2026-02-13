# Purpose

The objective is to add an 'exec' sub-command that executes a command in a running sandbox

# References

**Docker Compose 'exec' Command** 
- https://docs.docker.com/reference/cli/docker/compose/exec

## Command-line Syntax

The command-line syntax for the subcommand is similar to the syntax for the docker compose `exec` command :

`sb exec [<sandbox-id>] [-q][OPTIONS] COMMAND [ARGS...]`

Where

- `<sandbox-id>` is the optional ID of the sandbox. If not specified, the default sandbox is assumed.

- `[OPTIONS]` are the same options supported in `docker compose exec`

- `COMMAND` is the command to execute

- `[ARGS...]` are optional arguments to pass to the command

## Execution 

The subcommand will construct and execute a 'docker compose exec' command from the command line arguments.
