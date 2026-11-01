@echo off
rem Double-click to remove TrueFrame Overlay and restore your previous RTSS settings
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Uninstall %*
pause
