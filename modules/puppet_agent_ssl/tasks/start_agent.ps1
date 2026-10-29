[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$serviceName = @('puppet', 'openvox') | Where-Object { Get-Service -Name $_ -ErrorAction SilentlyContinue }

if (-not $serviceName) {
  Write-Output 'No puppet/openvox agent service found; continuing'
  exit 0
}

Set-Service -Name $serviceName[0] -StartupType Automatic
Start-Service -Name $serviceName[0]
Write-Output "Started $($serviceName[0]) service"
