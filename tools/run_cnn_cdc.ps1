param([string]$EfinityRoot='D:\soft\Efinity\2026.1')
$ErrorActionPreference='Stop'
$projectDir=Split-Path -Parent $PSScriptRoot
$env:EFINITY_HOME=$EfinityRoot.Replace('\','/')
$env:EFXPT_HOME="$env:EFINITY_HOME/pt"
$env:EFINITY_USER_DIR_INI=Join-Path $projectDir 'work/efinity_user.ini'
$env:PYTHONHOME="$env:EFINITY_HOME/python311"
$env:PATH="$EfinityRoot\python311\bin;$EfinityRoot\bin;"+$env:PATH
Push-Location $projectDir
try {
    & "$EfinityRoot\python311\bin\python.exe" -B tools/check_cnn_cdc.py prepare
    if($LASTEXITCODE -ne 0) {throw 'CNN CDC preparation failed'}
    & "$EfinityRoot\python311\bin\python.exe" "$EfinityRoot\scripts\efx_run.py" ArtFlow.xml --flow sta_tclsh --timeout 240 --output_dir work/efinity_out --work_dir work/efinity_build -t tools/check_cnn_cdc.tcl --pnr_opts sdc_file=work/cnn_cdc_audit.sdc *> work/cnn_cdc.log
    $code=$LASTEXITCODE
    Get-Content work/cnn_cdc.log -Tail 20
    if($code -ne 0) {exit $code}
    & "$EfinityRoot\python311\bin\python.exe" -B tools/check_cnn_cdc.py check
    exit $LASTEXITCODE
} finally {Pop-Location}
