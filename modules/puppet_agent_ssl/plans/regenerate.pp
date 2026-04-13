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
  TargetSpec         $targets,
  TargetSpec         $ca_server     = 'localhost',
  String[1]          $agent_binary  = '/opt/puppetlabs/bin/puppet',
  Boolean            $noop           = false,
  Boolean            $restart_agent  = false,
) {
  $agents = get_targets($targets)
  $ca     = get_targets($ca_server)[0]

  out::message("Regenerating certificates for: ${agents.map |$t| { $t.name }.join(', ')}")

  # ------------------------------------------------------------------
  # Step 1: Collect certnames before touching any SSL state.
  # ------------------------------------------------------------------
  $certname_results = run_task('puppet_agent_ssl::get_certname', $agents,
    agent_binary => $agent_binary,
  )

  # ------------------------------------------------------------------
  # Step 2: Stop the agent service so it does not interfere.
  # ------------------------------------------------------------------
  run_task('puppet_agent_ssl::stop_agent', $agents)

  # ------------------------------------------------------------------
  # Steps 3–4: Per-agent: clean local SSL then revoke on CA.
  # CA clean is best-effort — the cert may not exist if this is a
  # re-bootstrap of a brand-new node.
  # ------------------------------------------------------------------
  $certname_results.each |$result| {
    $certname = $result['certname']
    $agent    = $result.target()

    out::message("Cleaning SSL for ${certname}")

    run_command("${agent_binary} ssl clean", $agent)

    run_command("puppetserver ca clean --certname ${certname}", $ca,
      { '_catch_errors' => true }
    )
  }

  # ------------------------------------------------------------------
  # Step 5: Generate a new keypair and submit the CSR on each agent.
  # The agent exits non-zero because the cert is not yet signed — that
  # is expected and suppressed via _catch_errors.
  # ------------------------------------------------------------------
  run_task('puppet_agent_ssl::submit_csr', $agents,
    agent_binary  => $agent_binary,
    _catch_errors => true,
  )

  # ------------------------------------------------------------------
  # Step 6: Sign the new certificates on the CA.
  # ------------------------------------------------------------------
  $certname_results.each |$result| {
    $certname = $result['certname']
    out::message("Signing certificate for ${certname}")
    # _catch_errors: autosign environments will have already signed the cert
    # by the time submit_csr returns; the final agent run confirms success.
    run_command("puppetserver ca sign --certname ${certname}", $ca,
      { '_catch_errors' => true }
    )
  }

  # ------------------------------------------------------------------
  # Step 7: Final agent run to confirm the new certificate works.
  # ------------------------------------------------------------------
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

  # ------------------------------------------------------------------
  # Step 8: Optionally re-enable and start the agent service.
  # ------------------------------------------------------------------
  if $restart_agent {
    run_task('puppet_agent_ssl::start_agent', $agents)
  }

  out::message('Certificate regeneration complete.')
  return $final_results
}
