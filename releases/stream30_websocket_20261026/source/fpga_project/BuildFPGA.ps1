param([ValidateSet('Tests','Map','Physical')][string]$Phase='Tests')
$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$python='C:\Python314\python.exe'
Set-Location -LiteralPath "$root\fpga"
if($Phase -eq 'Tests') {
 & $python "$root\tests\protocol_test.py"
 if($LASTEXITCODE -ne 0){throw 'Protocol tests failed'}
 & 'D:\soft\Node_js\node.exe' "$root\tests\browser_test.js"
 if($LASTEXITCODE -ne 0){throw 'Browser tests failed'}
 & $python "$root\scripts\run_stream_rtl.py"
 if($LASTEXITCODE -ne 0){throw 'SPI simulation failed'}
 & $python "$root\scripts\run_shared_tests.py"
 if($LASTEXITCODE -ne 0){throw 'Shared C and RTL wire cross-check failed'}
 & $python "$root\scripts\run_reset_equivalence.py"
 if($LASTEXITCODE -ne 0){throw 'Reset equivalence failed'}
 & $python "$root\scripts\run_tap_rtl.py"
 if($LASTEXITCODE -ne 0){throw 'Tap simulation failed'}
 & $python "$root\scripts\run_original_regressions.py"
} elseif($Phase -eq 'Map') { & $python -B tools\build_styles15.py --phase map }
else { & $python "$root\scripts\fpga_physical.py" }
if($LASTEXITCODE -ne 0){throw "FPGA $Phase failed: $LASTEXITCODE"}
