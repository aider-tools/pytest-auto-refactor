#!/bin/bash
set -eu

# Change ownership of the /workspace directory to the current user and group IDs
# chown -R $(id -u):$(id -g) /workspace

# Run the main command
exec "$@"