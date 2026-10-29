#!/bin/bash
# Returns {"certname": "<value>"} by reading the agent config.

set -e

BINARY="${PT_agent_binary:-/opt/puppetlabs/bin/puppet}"

certname=$("$BINARY" config print certname 2>/dev/null)

if [[ -z "$certname" ]]; then
  echo '{"_error":{"msg":"Could not determine certname","kind":"puppet_agent_ssl/certname-lookup-failed"}}'
  exit 1
fi

printf '{"certname":"%s"}\n' "$certname"
