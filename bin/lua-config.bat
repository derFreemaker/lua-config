@echo off

set "SCRIPT_DIR=%~dp0"
set "PARENT_DIR=%SCRIPT_DIR:~0,-1%"
for %%a in ("%PARENT_DIR%") do set "PARENT_DIR=%%~dpa"

lua %PARENT_DIR%/src/main.lua %PARENT_DIR% %*
