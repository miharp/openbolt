[CmdletBinding()]
param(
  [String]  $agent_binary = 'puppet',
  [Boolean] $noop         = $false
)

$args = @('agent', '--onetime', '--no-daemonize', '--no-usecacheonfailure', '--no-splay')
if ($noop) { $args += '--noop' }

& $agent_binary @args
$rc = $LASTEXITCODE

# Puppet exit code 2 means changes were applied — that is a success.
if ($rc -eq 0 -or $rc -eq 2) { exit 0 }
exit $rc
