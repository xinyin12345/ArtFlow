@echo off
setlocal
cd /d "%~dp0"
set "PYTHONPATH="
call "C:\Efinity\2026.1\bin\setup.bat"
call "C:\Efinity\2026.1\bin\efx_run.bat" student_u8.xml --flow pnr --pnr_opts print_critical_path=10 max_threads=4 seed=1
exit /b %errorlevel%
