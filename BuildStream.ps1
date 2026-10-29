param([ValidateSet('Check','Tests','EspTests','OriginalTests','Map','Physical')][string]$Phase='Check', [string]$Python='C:\Espressif\tools\python\v5.5.6\venv\Scripts\python.exe')
$ErrorActionPreference='Stop'
Push-Location $PSScriptRoot
try {
  & $Python tools/check_round23t_project.py
  if ($LASTEXITCODE -ne 0) { throw 'Signed source gate failed' }
  if ($Phase -eq 'Tests') {
    New-Item -ItemType Directory -Force stream/logs/protocol | Out-Null
    & $Python stream/tests/protocol_test.py
    if ($LASTEXITCODE -ne 0) { throw 'Protocol fixtures failed' }
    foreach ($script in @('run_stream_rtl.py','run_shared_tests.py','run_reset_equivalence.py','run_tap_rtl.py')) {
      & $Python (Join-Path 'stream/scripts' $script)
      if ($LASTEXITCODE -ne 0) { throw "Offline test failed: $script" }
    }
  } elseif ($Phase -eq 'EspTests') {
    & $Python tools/test_stream_esp.py
    if ($LASTEXITCODE -ne 0) { throw 'ESP offline tests failed' }
  } elseif ($Phase -eq 'OriginalTests') {
    & $Python stream/scripts/run_original_regressions.py
    if ($LASTEXITCODE -ne 0) { throw 'Original regressions failed' }
  } elseif ($Phase -eq 'Map') {
    & $Python -B tools/build_styles8.py --phase map
    if ($LASTEXITCODE -ne 0) { throw 'Map failed; inspect prerequisites/evidence' }
  } elseif ($Phase -eq 'Physical') {
    & $Python stream/scripts/fpga_physical.py
    if ($LASTEXITCODE -ne 0) { throw 'Physical flow failed' }
  }
} finally { Pop-Location }
