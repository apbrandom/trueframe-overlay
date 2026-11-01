@echo off
rem Double-click to install TrueFrame Overlay into RivaTuner Statistics Server
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
pause
