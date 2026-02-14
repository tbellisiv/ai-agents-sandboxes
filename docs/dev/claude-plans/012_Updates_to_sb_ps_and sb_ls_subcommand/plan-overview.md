# Purpose

The objective is to update output of 'sb ps' subcommand and 'sb ls' add a 'PROJECT ID' column that displays the value of SB_PROJECT_ID.

## Updates

- The output of the 'sb ps' should look as follows (example):

PROJECT ID          SANDBOX ID          STATUS                      CREATED           CONTAINER_NAME                   SERVICE      IMAGE
----------          ------              -------                     -------           --------------                   -----        -----
test4               default             Up 19 hours (healthy)       19 hours ago      sandbox-test4-default            sandbox      sb-ubuntu-noble:latest
test4               test                Paused                      26 hours ago      sandbox-test4-test               sandbox      sb-ubuntu-noble-fw:latest
test4               dev-worktree-1      Up 2 minutes (not health)   2 minutes ago     sandbox-test4-dev-worktree-1     sandbox      sb-ubuntu-noble-fw-opensnitch:latest
test4               dev-main            Paused                      90 seconds ago    sandbox-test4-dev-main           sandbox      sb-ubuntu-noble:latest


- The output of the 'sb ps' should look as follows (example):

PROJECT ID    SANDBOX ID    TEMPLATE ID                      IMAGE
----------    ----------    -----------                      -----
test4         default       sb-ubuntu-noble-fw-opensnitch    sb-ubuntu-noble-fw-opensnitch:latest