# puppet_agent_ssl

#### Table of Contents

1. [Description](#description)
2. [Requirements](#requirements)
3. [Usage - Configuration options and additional functionality](#usage)
4. [Reference - An under-the-hood peek at what the module is doing and how](#reference)

## Description

This module provides the `puppet_agent_ssl::regenerate` plan. The plan automates the full certificate regeneration lifecycle for one or more Puppet/OpenVox agents: stopping the agent service, cleaning the old SSL state, revoking the old certificate on the CA, submitting a new CSR, signing it, and confirming the new certificate works with a final agent run.

The plan is designed to run from the Puppet/OpenVox CA server so that CA operations (`puppetserver ca`) execute locally.

## Requirements

This module is compatible with the version of OpenBolt it ships with. Targets must have the `openvox-agent` or `puppet-agent` package installed. The CA server must have `puppetserver` available on PATH.

Tasks must run as `root` (or the user that owns the system SSL directory, typically `/etc/puppetlabs/puppet/ssl`). Configure privilege escalation in your inventory:

```yaml
config:
  ssh:
    run-as: root
```

If tasks run as an unprivileged user, `puppet ssl clean` will clean that user's home-directory ssldir instead of the system ssldir. The old (revoked) certificate in `/etc/puppetlabs/puppet/ssl` will then cause `puppet agent` runs by root to fail with an SSL certificate unknown error.

## Usage

Regenerate certificates for a single agent:

```
bolt plan run puppet_agent_ssl::regenerate targets=agent.example.com
```

Regenerate certificates for an inventory group, specifying a remote CA server:

```
bolt plan run puppet_agent_ssl::regenerate targets=agents ca_server=puppet.example.com
```

Run the final agent check in noop mode:

```
bolt plan run puppet_agent_ssl::regenerate targets=agents noop=true
```

Call the plan from another plan:

```puppet
run_plan('puppet_agent_ssl::regenerate', targets => $targets, ca_server => 'puppet.example.com')
```

### Parameters

**targets** - The agent targets to regenerate certificates for. Required.

**ca_server** - Target representing the CA server. Defaults to `localhost` because the plan is assumed to run on the CA.

**agent_binary** - Full path to the Puppet/OpenVox agent binary on the target nodes. Defaults to `/opt/puppetlabs/bin/puppet`, which is the canonical install path for both `puppet-agent` and `openvox-agent` packages.

**noop** - When `true`, runs the final agent check in noop mode. Defaults to `false`.

**restart_agent** - When `true`, starts and enables the agent service after cert regeneration is complete. Defaults to `false` to preserve the service state that existed before the plan ran (e.g. intentionally disabled agents in dev environments).

## Reference

The plan executes the following steps:

1. **get_certname** — Reads the configured certname from each agent before any SSL state is changed.
2. **stop_agent** — Stops the agent service on each target.
3. **ssl clean** — Removes the local SSL directory on each agent (`puppet ssl clean`), then revokes the old certificate on the CA (`puppetserver ca clean`). The CA revocation is best-effort; it is skipped silently if the certificate does not exist.
4. **submit_csr** — Generates a new keypair and submits a CSR to the CA on each agent.
5. **sign** — Signs each new certificate on the CA (`puppetserver ca sign`). This step is skipped silently if the certificate was already signed automatically (e.g. autosign is enabled).
6. **run_agent** — Runs the agent once on each target to confirm the new certificate is accepted by the CA. The plan fails if any agent fails this step.
7. **start_agent** — If `restart_agent` is `true`, starts and enables the agent service on each target.

The plan returns the ResultSet from the final agent run. If the final agent run fails on any target, the plan raises an error with kind `puppet_agent_ssl/agent-run-failed`.
