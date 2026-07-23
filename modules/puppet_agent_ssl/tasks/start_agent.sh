#!/bin/bash
# Start and enable the puppet/openvox agent service.
# Tries systemd first, falls back to SysV init, then no-op if neither is found.

set -e

start_service() {
  local name="$1"
  if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files --type=service | grep -q "^${name}.service"; then
    systemctl enable --now "$name"
    return 0
  elif command -v service >/dev/null 2>&1; then
    service "$name" start 2>/dev/null && return 0
  fi
  return 1
}

# openvox-agent may install the service as 'puppet' or 'openvox'
if start_service puppet; then
  echo "Started puppet service"
elif start_service openvox; then
  echo "Started openvox service"
else
  echo "No puppet/openvox agent service found; continuing"
fi
