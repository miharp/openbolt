[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$serviceName = @('puppet', 'openvox') | Where-Object { Get-Service -Name $_ -ErrorAction SilentlyContinue }

if (-not $serviceName) {
  Write-Output 'No running puppet/openvox agent service found; continuing'
  exit 0
}

Stop-Service -Name $serviceName[0] -Force
Write-Output "Stopped $($serviceName[0]) service"
