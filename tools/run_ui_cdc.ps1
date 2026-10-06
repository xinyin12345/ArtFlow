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
    Set-Content -LiteralPath work/ui_cdc_summary.json -Value '{"status":"RUNNING"}' -Encoding ascii
    & "$EfinityRoot\python311\bin\python.exe" "$EfinityRoot\scripts\efx_run.py" ArtFlow.xml --flow sta_tclsh --timeout 120 --output_dir work/efinity_out --work_dir work/efinity_build -t tools/check_ui_cdc.tcl --pnr_opts sdc_file=ArtFlow.sdc *> work/ui_cdc.log
    $code=$LASTEXITCODE
    Get-Content work/ui_cdc.log -Tail 25
    if($code -ne 0){exit $code}
    & "$EfinityRoot\python311\bin\python.exe" -B tools/check_ui_cdc.py
    exit $LASTEXITCODE
} finally {Pop-Location}
