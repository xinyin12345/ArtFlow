# Dot-source this script in a dedicated PowerShell session.
# All environment changes are process-local; no registry or global PATH edits.
$ErrorActionPreference = 'Stop'
$officialProfile = 'D:\Espressif\Microsoft.v5.5.6.PowerShell_profile.ps1'
if (-not (Test-Path -LiteralPath $officialProfile)) { throw "Missing official EIM profile: $officialProfile" }
. $officialProfile
if ($env:IDF_VERSION -ne '5.5.6') { throw "Expected ESP-IDF 5.5.6; got $env:IDF_VERSION" }
$env:IDF_COMPONENT_MANAGER = '0'
