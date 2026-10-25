param([ValidateSet('map','compile','full','sta_tclsh')][string]$Flow='compile', [string]$EfinityRoot='D:\soft\Efinity\2026.1')
$ErrorActionPreference='Stop'
$env:EFINITY_ROOT=$EfinityRoot
$taskPhase=if($Flow -eq 'map'){'map'}elseif($Flow -eq 'sta_tclsh'){'physical'}else{'all'}
& python -B (Join-Path $PSScriptRoot 'build_styles15.py') --phase $taskPhase
exit $LASTEXITCODE
