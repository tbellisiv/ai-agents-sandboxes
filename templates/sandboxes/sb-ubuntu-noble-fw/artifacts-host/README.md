# sb-ubuntu-noble-fw Template

This template extends `sb-ubuntu-noble` with firewall capabilities for creating network-isolated development sandboxes.

## Overview

The `sb-ubuntu-noble-fw` template inherits all functionality from `sb-ubuntu-noble` and adds firewall support for controlling network access within the sandbox container.

## Base Template

- **Parent**: `sb-ubuntu-noble`
- **Base Image**: Ubuntu 24.04 (Noble)

## Features

All features from `sb-ubuntu-noble` plus:

- Firewall capabilities (to be implemented)

## Usage

Create a sandbox using this template:

```bash
sb new -t sb-ubuntu-noble-fw
```
