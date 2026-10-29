[CmdletBinding()]
param(
  [String] $agent_binary = 'puppet'
)

# 'puppet ssl submit_request' exits non-zero when the cert is not yet signed.
# That is expected — suppress the automatic error and let the plan decide.
& $agent_binary ssl submit_request
exit $LASTEXITCODE
