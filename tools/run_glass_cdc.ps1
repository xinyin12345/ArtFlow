param([string]$EfinityRoot='D:\soft\Efinity\2026.1')
$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent $PSScriptRoot
$env:EFINITY_HOME=$EfinityRoot.Replace('\','/')
$env:EFXPT_HOME="$env:EFINITY_HOME/pt"
$env:EFINITY_USER_DIR_INI=Join-Path $taskRoot 'work/glass_int8/efinity_user.ini'
$env:PYTHONHOME="$env:EFINITY_HOME/python311"
$env:PATH="$EfinityRoot\python311\bin;$EfinityRoot\bin;"+$env:PATH
Push-Location $taskRoot
try {
 & "$EfinityRoot\python311\bin\python.exe" -B tools/check_glass_video_cdc.py prepare
 if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}
 & "$EfinityRoot\python311\bin\python.exe" -B tools/check_glass_cnn_cdc.py prepare
 if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}
 & "$EfinityRoot\python311\bin\python.exe" -B tools/check_style_io.py prepare
 if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}
 $taskTcl = (Get-Content -LiteralPath tools/check_video_cdc.tcl -Raw) + (Get-Content -LiteralPath tools/check_ui_cdc.tcl -Raw) + (Get-Content -LiteralPath tools/check_cnn_cdc.tcl -Raw) + (Get-Content -LiteralPath tools/check_style_io.tcl -Raw)
 Set-Content -LiteralPath work/glass_int8/audit.tcl -Value $taskTcl -Encoding ascii
 & "$EfinityRoot\python311\bin\python.exe" "$EfinityRoot\scripts\efx_run.py" ArtFlow_glass.xml --flow sta_tclsh --timeout 300 --output_dir work/glass_int8/efinity_out --work_dir work/glass_int8/efinity_build -t work/glass_int8/audit.tcl --pnr_opts sdc_file=work/glass_int8/video_cdc_audit.sdc *> work/glass_int8/cnn_cdc.log
 $taskCode=$LASTEXITCODE
 Get-Content -LiteralPath work/glass_int8/cnn_cdc.log -Tail 25
 if($taskCode -ne 0){exit $taskCode}
 Copy-Item -LiteralPath work/glass_int8/cnn_cdc.log -Destination work/glass_int8/ui_cdc.log -Force
 & "$EfinityRoot\python311\bin\python.exe" -B tools/check_glass_project.py --check-snapshot
 if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}
 & "$EfinityRoot\python311\bin\python.exe" -B tools/check_glass_video_cdc.py check
 if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}
 & "$EfinityRoot\python311\bin\python.exe" -B tools/check_glass_ui_cdc.py
 if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}
 & "$EfinityRoot\python311\bin\python.exe" -B tools/check_style_io.py check
 if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}
 & "$EfinityRoot\python311\bin\python.exe" -B tools/check_glass_cnn_cdc.py check
 exit $LASTEXITCODE
} finally {Pop-Location}

