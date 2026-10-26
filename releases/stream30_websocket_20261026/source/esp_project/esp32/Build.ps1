$ErrorActionPreference='Stop'
Set-Location -LiteralPath $PSScriptRoot
. "$PSScriptRoot\Activate.ps1"
& "$env:IDF_PYTHON_ENV_PATH\Scripts\python.exe" "$env:IDF_PATH\tools\idf.py" -B build-xmc build
if ($LASTEXITCODE -ne 0) { throw "ESP build failed: $LASTEXITCODE" }


& "$env:IDF_PYTHON_ENV_PATH\Scripts\python.exe" "$PSScriptRoot\..\scripts\package_esp.py"
if($LASTEXITCODE -ne 0){throw "Artifact verification failed"}
