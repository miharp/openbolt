#!/bin/bash
# Run the Puppet/openvox agent once.
# Exit codes 0 (no changes) and 2 (changes applied) are both success.
# Exit code 4 or 6 indicates resource failures.

BINARY="${PT_agent_binary:-/opt/puppetlabs/bin/puppet}"
NOOP="${PT_noop:-false}"

args=(agent --onetime --no-daemonize --no-usecacheonfailure --no-splay)
[[ "$NOOP" == "true" ]] && args+=(--noop)

"$BINARY" "${args[@]}"
rc=$?

# Puppet exit code 2 means changes were applied — that is a success.
if [[ $rc -eq 0 || $rc -eq 2 ]]; then
  exit 0
fi

exit $rc
