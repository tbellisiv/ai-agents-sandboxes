# Purpose

The objective is to update the 'sb ls' subcommand to display additional information.

Updates:

- By default, display the output as table in the following format for the first two rows in the table:

  |Sandbox ID|Template ID|Image|
  |----------|-----------|-----|

Where:

- 'Sandbox ID' displays the sandbox as specified in SB_SANDBOX_ID

- 'Template ID' displays the sandbox template as specified in SB_SANDBOX_TEMPLATE_ID

- 'Image' displays the sandbox container image as specified in SB_SANDBOX_IMAGE

- Add '--output' ('-o') option to specify the following formats:

  - `json` - Output JSON

  - `yaml`  - Output YAML

  - `table` - Output the tabular format described above. This is the default format.
  
  - `plain` - Output without a table. The output for each sandbox should have the form:

    <sandbox-id> [template=<template-id>] [image=<image>]

    