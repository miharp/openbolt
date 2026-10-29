#!/bin/bash
# Generate a new SSL keypair and submit a CSR to the CA.
#
# 'puppet ssl submit_request' generates a private key and CSR then sends
# it to the CA. It exits non-zero when the cert is not yet signed, which
# is expected — the plan handles signing immediately after this task.

BINARY="${PT_agent_binary:-/opt/puppetlabs/bin/puppet}"

"$BINARY" ssl submit_request
