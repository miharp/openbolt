#!/bin/bash
# Stop the puppet/openvox agent service.
# Tries systemd first, falls back to SysV init, then no-op if neither is found.

set -e

stop_service() {
  local name="$1"
  if command -v systemctl >/dev/null 2>&1 && systemctl list-units --type=service | grep -q "${name}.service"; then
    systemctl stop "$name"
    return 0
  elif command -v service >/dev/null 2>&1; then
    service "$name" stop 2>/dev/null && return 0
  fi
  return 1
}

# openvox-agent may install the service as 'puppet' or 'openvox'
if stop_service puppet; then
  echo "Stopped puppet service"
elif stop_service openvox; then
  echo "Stopped openvox service"
else
  echo "No running puppet/openvox agent service found; continuing"
fi
