@echo off
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul || exit /b 1
cd /d "%~dp0"
set PRESET=%1
if "%PRESET%"=="" set PRESET=windows
.venv\Scripts\cmake.exe --preset %PRESET% && .venv\Scripts\cmake.exe --build --preset %PRESET%
