param(
    [string]$EfinityRoot = 'D:\soft\Efinity\2026.1',
    [ValidateSet('map','compile','full','sta_tclsh')][string]$Flow = 'compile'
)
$ErrorActionPreference = 'Stop'
$projectDir = Split-Path -Parent $PSScriptRoot
$scratchDir = Join-Path $projectDir 'work'
New-Item -ItemType Directory -Path $scratchDir -Force | Out-Null
Set-Content -LiteralPath (Join-Path $scratchDir 'implementation_summary.json') -Value '{"status":"RUNNING"}' -Encoding ascii
# Build the BRAM program before mapping. This tool never downloads hardware.
if ($Flow -ne 'sta_tclsh') {
    Copy-Item -LiteralPath (Join-Path $projectDir 'ArtFlow.xml') -Destination (Join-Path $scratchDir 'ArtFlow.before_compile.xml') -Force
    & python -B (Join-Path $PSScriptRoot 'build_firmware.py')
    if ($LASTEXITCODE -ne 0) { throw 'Firmware build failed' }
    & python -B (Join-Path $PSScriptRoot 'check_project_v06.py') --snapshot
    if ($LASTEXITCODE -ne 0) { throw 'Project input gate failed' }
}
New-Item -ItemType Directory -Path (Join-Path $scratchDir 'efinity_user') -Force | Out-Null
$env:EFINITY_HOME = $EfinityRoot.Replace('\','/')
$env:EFXPT_HOME = "$env:EFINITY_HOME/pt"
$env:EFXPGM_HOME = "$env:EFINITY_HOME/pgm"
$env:EFXDBG_HOME = "$env:EFINITY_HOME/debugger"
$env:EFXIPM_HOME = "$env:EFINITY_HOME/ipm"
$env:EFINITY_USER_DIR_INI = Join-Path $scratchDir 'efinity_user.ini'
$userDir = (Join-Path $scratchDir 'efinity_user').Replace('\','/')
Set-Content -LiteralPath $env:EFINITY_USER_DIR_INI -Value "[General]`nEFINITY_USER_DIR=$userDir" -Encoding ascii
$env:PYTHONHOME = "$env:EFINITY_HOME/python311"
$env:QT_PLUGIN_PATH = "$env:EFINITY_HOME/python311"
$env:PATH = "$EfinityRoot\python311\bin;$EfinityRoot\bin;$EfinityRoot\pgm\bin;" + $env:PATH
Push-Location $projectDir
try {
    $efinityPython = "$EfinityRoot\python311\bin\python.exe"
    $resultCode = 0
    if ($Flow -ne 'sta_tclsh') {
      & $efinityPython "$EfinityRoot\scripts\efx_run.py" ArtFlow.xml `
        --flow $Flow --timeout 900 --output_dir work/efinity_out --work_dir work/efinity_build `
        *> "work/efinity_$Flow.log"
      $resultCode = $LASTEXITCODE
      Get-Content -LiteralPath "work/efinity_$Flow.log" -Tail 35
      if ($resultCode -eq 0) {
        & $efinityPython -B tools/restore_project_xml.py
        if ($LASTEXITCODE -ne 0) { throw 'Project XML preservation failed' }
      }
    }
    if ($resultCode -eq 0 -and $Flow -ne 'map') {
      & $efinityPython -B tools/check_video_cdc.py prepare
      if ($LASTEXITCODE -ne 0) { throw 'CDC audit preparation failed' }
      & $efinityPython "$EfinityRoot\scripts\efx_run.py" ArtFlow.xml `
        --flow sta_tclsh --timeout 120 --output_dir work/efinity_out --work_dir work/efinity_build `
        -t tools/check_video_cdc.tcl --pnr_opts sdc_file=work/video_cdc_audit.sdc `
        *> work/efinity_sta_tclsh.log
      $resultCode = $LASTEXITCODE
      Get-Content -LiteralPath work/efinity_sta_tclsh.log -Tail 20
      if ($resultCode -eq 0) {
        & $efinityPython -B tools/check_video_cdc.py check
        $resultCode = $LASTEXITCODE
        if ($resultCode -eq 0) {
          & $efinityPython -B tools/check_implementation.py
          $resultCode = $LASTEXITCODE
          if ($resultCode -eq 0) {
            & $efinityPython -B tools/check_project_v06.py --check-snapshot
            $resultCode = $LASTEXITCODE
          }
        }
      }
    }
    if ($resultCode -eq 0 -and $Flow -ne 'map') {
      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'run_ui_cdc.ps1') -EfinityRoot $EfinityRoot
      $resultCode = $LASTEXITCODE
    }
    exit $resultCode
} finally { Pop-Location }
