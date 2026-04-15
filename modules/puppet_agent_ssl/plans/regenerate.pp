# @summary
#   Regenerate SSL certificates for one or more openvox/Puppet agents.
#
# Stops the agent service on each target, cleans the agent's local SSL
# directory, revokes the old certificate on the CA, submits a new CSR,
# signs it on the CA, then performs a final agent run to confirm the new
# certificate is working.
#
# This plan is designed to run from the Puppet/OpenVox CA server itself so
# that CA operations execute locally via `puppetserver ca`.
#
# @param targets
#   The agent targets to regenerate certificates for.
# @param ca_server
#   Target representing the CA server. Defaults to 'localhost' because
#   OpenBolt is assumed to be running on the CA server.
# @param agent_binary
#   Path or name of the agent binary on the target nodes. Defaults to the
#   canonical install path '/opt/puppetlabs/bin/puppet', which is correct
#   for both puppet-agent and openvox-agent packages.
# @param noop
#   When true, runs the final agent run in noop mode.
# @param restart_agent
#   When true, starts and enables the agent service after cert regeneration.
#   Defaults to false to preserve the service state that existed before the
#   plan ran (e.g. intentionally disabled agents in dev environments).
#
# @example Regenerate certs for a single agent
#   run_plan(puppet_agent_ssl::regenerate, targets => 'agent.example.com')
#
# @example Regenerate certs for an inventory group
#   run_plan(puppet_agent_ssl::regenerate, targets => 'agents', ca_server => 'puppet.example.com')
#
plan puppet_agent_ssl::regenerate(
  TargetSpec  $targets,
  TargetSpec  $ca_server    = 'localhost',
  String[1]   $agent_binary = '/opt/puppetlabs/bin/puppet',
  Boolean     $noop         = false,
  Boolean     $restart_agent = false,
) {
  $agents = get_targets($targets)
  $ca     = get_targets($ca_server)[0]

  out::message("Regenerating certificates for: ${agents.map |$t| { $t.name }.join(', ')}")

  # Collect certnames from agents and CA in parallel before touching any SSL
  # state. Fail early if any agent IS the CA — regenerating the CA's own cert
  # would break puppetserver while it is running.
  $all_certname_results = run_task('puppet_agent_ssl::get_certname', $agents + [$ca],
    agent_binary => $agent_binary,
  )

  $certname_results = $all_certname_results.filter |$r| { $r.target().name != $ca.name }
  $ca_certname      = ($all_certname_results.filter |$r| { $r.target().name == $ca.name })[0]['certname']

  $ca_targets = $certname_results.filter |$r| { $r['certname'] == $ca_certname }
  if $ca_targets.length > 0 {
    $names = $ca_targets.map |$r| { $r.target().name }.join(', ')
    fail_plan(
      "Refusing to regenerate the CA server's own certificate (${ca_certname}). \
Use a dedicated CA cert regeneration procedure instead. Affected targets: ${names}",
      'puppet_agent_ssl/ca-target-not-supported',
      { targets => $names }
    )
  }

  run_task('puppet_agent_ssl::stop_agent', $agents)

  # Clean local SSL on all agents in parallel, then revoke each cert on the CA.
  # CA clean is best-effort — the cert may not exist on a re-bootstrapped node.
  $certnames = $certname_results.map |$r| { $r['certname'] }.join(',')

  run_command("${agent_binary} ssl clean", $agents)

  # Revoke all old certificates in a single CA round-trip.
  # Best-effort — certs may not exist on re-bootstrapped nodes.
  out::message("Revoking old certificates on CA: ${certnames}")
  run_command("puppetserver ca clean --certname ${certnames}", $ca,
    { '_catch_errors' => true }
  )

  # submit_request exits non-zero when the cert is not yet signed — expected.
  run_task('puppet_agent_ssl::submit_csr', $agents,
    agent_binary  => $agent_binary,
    _catch_errors => true,
  )

  # Sign all new certificates in a single CA round-trip.
  # Autosign environments will have already signed the certs by the time
  # submit_csr returns; the final agent run confirms success either way.
  out::message("Signing certificates on CA: ${certnames}")
  run_command("puppetserver ca sign --certname ${certnames}", $ca,
    { '_catch_errors' => true }
  )

  $final_results = run_task('puppet_agent_ssl::run_agent', $agents,
    agent_binary  => $agent_binary,
    noop          => $noop,
    _catch_errors => true,
  )

  $failed = $final_results.error_set()
  if $failed.count() > 0 {
    $names = $failed.targets().map |$t| { $t.name }.join(', ')
    fail_plan(
      "Certificate regeneration succeeded but the final agent run failed on: ${names}",
      'puppet_agent_ssl/agent-run-failed',
      { targets => $names }
    )
  }

  if $restart_agent {
    run_task('puppet_agent_ssl::start_agent', $agents)
  }

  out::message('Certificate regeneration complete.')
  return $final_results
}
