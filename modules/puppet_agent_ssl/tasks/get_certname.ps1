[CmdletBinding()]
param(
  [String] $agent_binary = 'puppet'
)

$ErrorActionPreference = 'Stop'

$certname = & $agent_binary config print certname 2>$null

if (-not $certname) {
  Write-Error 'Could not determine certname'
  exit 1
}

[PSCustomObject]@{ certname = $certname.Trim() } | ConvertTo-Json -Compress
