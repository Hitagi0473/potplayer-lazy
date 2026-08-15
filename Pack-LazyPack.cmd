@echo off
setlocal EnableExtensions

rem PotPlayer Lazy Pack - double-click wrapper
rem The PowerShell script performs validation, packaging, and verification.

set "SCRIPT=%~dp0Pack-LazyPack.ps1"
if not exist "%SCRIPT%" (
    echo [FAIL] Missing: %SCRIPT%
    set "RC=1"
    goto :END
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
set "RC=%ERRORLEVEL%"

if not "%RC%"=="0" (
    echo.
    echo Packaging failed with exit code %RC%.
) else (
    echo.
    echo Packaging finished successfully.
)

:END
echo.
echo Please press any key to exit...
pause >nul
exit /b %RC%