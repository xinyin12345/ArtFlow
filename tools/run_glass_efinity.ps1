param([ValidateSet('map','compile','full','sta_tclsh')][string]$Flow='compile',
[string]$EfinityRoot='D:\soft\Efinity\2026.1')
$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent $PSScriptRoot
$taskWork=Join-Path $taskRoot 'work/glass_int8'
$env:EFINITY_HOME=$EfinityRoot.Replace('\','/')
$env:EFXPT_HOME="$env:EFINITY_HOME/pt"
$env:EFXPGM_HOME="$env:EFINITY_HOME/pgm"
$env:EFXDBG_HOME="$env:EFINITY_HOME/debugger"
$env:EFXIPM_HOME="$env:EFINITY_HOME/ipm"
$env:PYTHONHOME="$env:EFINITY_HOME/python311"
$env:QT_PLUGIN_PATH="$env:EFINITY_HOME/python311"
$env:PATH="$EfinityRoot\python311\bin;$EfinityRoot\bin;$EfinityRoot\pgm\bin;"+$env:PATH
$env:EFINITY_USER_DIR_INI=Join-Path $taskWork 'efinity_user.ini'
New-Item -ItemType Directory -Path (Join-Path $taskWork 'efinity_user') -Force | Out-Null
Set-Content -LiteralPath $env:EFINITY_USER_DIR_INI -Value "[General]`nEFINITY_USER_DIR=$($taskWork.Replace('\','/'))/efinity_user" -Encoding ascii
$taskXml=Join-Path $taskRoot 'ArtFlow_glass.xml'
$taskMain=Join-Path $taskRoot 'ArtFlow.xml'
if((Get-Content -LiteralPath $taskMain -Raw) -match 'rtl/cnn/glass_int8/glass_int8.v') {
 Copy-Item -LiteralPath $taskMain -Destination $taskXml -Force
}
$taskOriginal=[IO.File]::ReadAllBytes($taskXml)
Push-Location $taskRoot
try {
 if($Flow -eq 'sta_tclsh') {
  & powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_glass_cdc.ps1 -EfinityRoot $EfinityRoot
  exit $LASTEXITCODE
 }
 & "$EfinityRoot\python311\bin\python.exe" -B tools/check_glass_project.py --snapshot
 if($LASTEXITCODE -ne 0){throw 'Glass source gate failed'}
 Set-Content -LiteralPath work/glass_int8/implementation_summary.json -Value '{"status":"RUNNING"}' -Encoding ascii
 try {
  & "$EfinityRoot\python311\bin\python.exe" "$EfinityRoot\scripts\efx_run.py" ArtFlow_glass.xml --flow $Flow --timeout 1800 --output_dir work/glass_int8/efinity_out --work_dir work/glass_int8/efinity_build *> "work/glass_int8/efinity_$Flow.log"
  $taskCode=$LASTEXITCODE
 } finally {[IO.File]::WriteAllBytes($taskXml,$taskOriginal)}
 Get-Content -LiteralPath "work/glass_int8/efinity_$Flow.log" -Tail 20
 if($taskCode -ne 0){exit $taskCode}
 & "$EfinityRoot\python311\bin\python.exe" -B tools/check_glass_project.py --check-snapshot
 if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}
 if($Flow -ne 'map') {
  & powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_glass_cdc.ps1 -EfinityRoot $EfinityRoot
  if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}
  & "$EfinityRoot\python311\bin\python.exe" -B tools/check_glass_implementation.py
  exit $LASTEXITCODE
 }
 exit 0
} finally {Pop-Location}

