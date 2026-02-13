# Purpose

The objective is to add OpenSnitch firewall to the docker image at `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/image` for the `sb-ubuntu-noble-fw-opensnitch` sandbox. The changes should 

## References

### opensnitch

**GitHub**: https://github.com/evilsocket/opensnitch

**Local**: /home/tellis/dev/ai-tools/agent-sandboxes/devcontainers/git/opensnitch

### agentic-devcontainer

**GitHub**: https://github.com/replete/agentic-devcontainer 

**Local**: /home/tellis/dev/ai-tools/agent-sandboxes/devcontainers/git/agentic-devcontainer

## Approach

- The implementation should closely mirror the the model in agentic-devcontainer

## Tasks

## Task 1 - Dockerfile and docker-compose Updates

### Steps 

1. Update the Dockerfile at `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/image/docker/Dockerfile` to add support for OpenSnitch. The changes should- when possible- closely mirror `/home/tellis/dev/ai-tools/agent-sandboxes/devcontainers/git/agentic-devcontainer/.devcontainer/devcontainer.Dockerfile`.

2. Update the Dockerfile at `templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/image/docker/docker-compose.yml` to add support for OpenSnitch. The changes should- when possible- closely mirror `/home/tellis/dev/ai-tools/agent-sandboxes/devcontainers/git/agentic-devcontainer/.devcontainer/devcontainer.Dockerfile`.

3. Validate the firewall is functional in the image:

  - Use the bash script at templates/sandboxes/sb-ubuntu-noble-fw-opensnitch/image/run.sh to start an ephemeral container. 
  
  - Run netcat, ping and curl commands inside the container to verify outbound traffic is allowed through the firewall for destinations with allow rules. Rules are at .devcontainer/firewall/rules.

  - Run  netcat, ping and curl commands inside the container  to verify oubound traffic is blocked for destinations that do not have allow rules. Rules are at .devcontainer/firewall/rules.



  








