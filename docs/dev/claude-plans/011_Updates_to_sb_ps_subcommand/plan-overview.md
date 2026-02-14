# Purpose

The objective is to update output of 'sb ps' subcommand to match the output style and options of the 'sb ls' subcommand

## Updates

- By default, display the output as a table in the following format (example):

SANDBOX ID          STATUS                      CREATED           CONTAINER_NAME                   SERVICE       IMAGE
----------          ------                      -------           --------------                   -------       -----
default             Up 19 hours (healthy)       19 hours ago      sandbox-test4-default            sandbox      sb-ubuntu-noble:latest
test                Paused                      26 hours ago      sb-ubuntu-noble-fw               sandbox      sb-ubuntu-noble-fw:latest
dev-worktree-1      Up 2 minutes (not health)   2 minutes ago     sb-ubuntu-noble-fw-opensnitch    sandbox      sb-ubuntu-noble-fw-opensnitch:latest
dev-main            Paused                      90 seconds ago    sb-ubuntu-noble                  sandbox      sb-ubuntu-noble:latest

- The output should populate values for the following columns from the output of the 'docker compose ps' commnad:
  - STATUS
  - CREATE
  - CONTAINER NAME (Column is named 'NAME' in `docker compose ps`)
  - SERVICE

- Add '--output' ('-o') option to specify the following formats:

  - `json` - Output JSON

  - `yaml`  - Output YAML

  - `table` - Output the tabular format described above. This is the default format.
  
  - `plain` - Output without a table. The output for each sandbox should have the form:

    <sandbox-id> [template=<template-id>] [image=<image>]

    

