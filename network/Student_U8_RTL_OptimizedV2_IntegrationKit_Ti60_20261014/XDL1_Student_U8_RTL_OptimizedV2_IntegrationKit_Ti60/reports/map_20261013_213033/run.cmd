@echo off
setlocal
cd /d "%~dp0"
set "PYTHONPATH="
call "C:\Efinity\2026.1\bin\setup.bat"
call "C:\Efinity\2026.1\bin\efx_run.bat" student_u8.xml --flow map --map_opts max_mult=140 max-bit-blast-mem-size=16384
exit /b %errorlevel%
