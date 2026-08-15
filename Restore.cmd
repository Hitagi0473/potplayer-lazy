@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ============================================================
rem PotPlayer Personal Lazy Pack - Restore Utility
rem Fixed package root: D:\Potplayer
rem ============================================================

set "REQUIRED_ROOT=D:\Potplayer\"
set "ROOT=%~dp0"
set "LOG=%ROOT%Restore.log"
set "REGEXE=%SystemRoot%\System32\reg.exe"
set "REGSVR=%SystemRoot%\System32\regsvr32.exe"
set "TASKLIST=%SystemRoot%\System32\tasklist.exe"
set "TASKKILL=%SystemRoot%\System32\taskkill.exe"
set "POTPLAYER=%ROOT%Potplayer\PotPlayerMini64.exe"

rem Elevate before performing any package or system operation.
fltmc >nul 2>&1
if errorlevel 1 (
    echo Administrator privileges are required. Requesting elevation...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -WorkingDirectory '%~dp0' -Verb RunAs" >nul 2>&1
    if errorlevel 1 (
        echo [FAIL] Elevation was cancelled or could not be started.
        pause
        exit /b 1
    )
    exit /b 0
)

rem The package intentionally supports only its fixed absolute path.
if /I not "%ROOT%"=="%REQUIRED_ROOT%" (
    echo.
    echo [FAIL] Package root path is incorrect.
    echo        Current : %ROOT%
    echo        Required: %REQUIRED_ROOT%
    echo.
    echo Move the complete package to D:\Potplayer before restoring.
    pause
    exit /b 1
)

call :WriteRunHeader
call :Banner
call :Status PASS "Administrator privileges confirmed."
call :Status PASS "Package root: %ROOT%"

echo.
echo [1/7] Checking package...
>>"%LOG%" echo [1/7] Checking package...
set /a MISSING=0
call :RequireFile "Potplayer\PotPlayerMini64.exe"
call :RequireFile "Potplayer\PotPlayerMini64.ini"
call :RequireFile "LAVFilters\LAVSplitter.ax"
call :RequireFile "LAVFilters\LAVVideo.ax"
call :RequireFile "LAVFilters\LAVAudio.ax"
call :RequireFile "madVR\install.bat"
call :RequireFile "madVR\madVR.ax"
call :RequireFile "madVR\madVR64.ax"
call :RequireFile "madVR\settings.bin"
call :RequireFile "xyVSFilterSubFilter\x64\XySubFilter.dll"
call :RequireFile "Config\LAV.reg"
call :RequireFile "Config\madVR.reg"
call :RequireFile "Config\XySubFilter.reg"

if not "!MISSING!"=="0" (
    call :Status FAIL "Package validation failed: !MISSING! required file(s) missing."
    goto :FAILED
)
call :Status PASS "Package validation complete: 13 required files found."

call :StopProcess "PotPlayerMini64.exe"
if errorlevel 1 goto :FAILED
call :StopProcess "madHcCtrl.exe"
if errorlevel 1 goto :FAILED

call :CreateBackupDirectory
if errorlevel 1 goto :FAILED
call :BackupKey "HKCU\Software\LAV" "LAV-before.reg" "LAV settings"
if errorlevel 1 goto :FAILED
call :BackupKey "HKCU\Software\madshi\madVR" "madVR-before.reg" "madVR settings"
if errorlevel 1 goto :FAILED
call :BackupKey "HKCU\Software\Gabest\XySubFilter" "XySubFilter-before.reg" "XySubFilter settings"
if errorlevel 1 goto :FAILED

echo.
echo [2/7] Registering LAV Filters...
>>"%LOG%" echo [2/7] Registering LAV Filters...
call :RegisterComponent "LAV Splitter" "%ROOT%LAVFilters\LAVSplitter.ax"
if errorlevel 1 goto :FAILED
call :RegisterComponent "LAV Video" "%ROOT%LAVFilters\LAVVideo.ax"
if errorlevel 1 goto :FAILED
call :RegisterComponent "LAV Audio" "%ROOT%LAVFilters\LAVAudio.ax"
if errorlevel 1 goto :FAILED

echo.
echo [3/7] Restoring LAV settings...
>>"%LOG%" echo [3/7] Restoring LAV settings...
call :ImportSettings "LAV" "%ROOT%Config\LAV.reg" "HKCU\Software\LAV"
if errorlevel 1 goto :FAILED

echo.
echo [4/7] Installing madVR...
>>"%LOG%" echo [4/7] Installing madVR...
pushd "%ROOT%madVR" >nul 2>&1
if errorlevel 1 (
    call :Status FAIL "Could not enter the madVR directory."
    goto :FAILED
)
call install.bat <nul >>"%LOG%" 2>&1
set "MADVR_BAT_RC=!errorlevel!"
popd
call :Info "madVR install.bat returned rc=!MADVR_BAT_RC!; COM verification is authoritative."
call :VerifyCom "madVR renderer" "HKCR\CLSID\{E1A8B82A-32CE-4B0D-BE0D-AA68C772E423}\InprocServer32" "%ROOT%madVR\madVR64.ax"
if errorlevel 1 goto :FAILED
call :VerifyCom "madVR allocator presenter" "HKCR\CLSID\{F352C9C1-D39D-4622-A279-978A60927CDE}\InprocServer32" "%ROOT%madVR\madVR64.ax"
if errorlevel 1 goto :FAILED
call :Status PASS "madVR x64 COM registration verified."

echo.
echo [5/7] Restoring madVR settings...
>>"%LOG%" echo [5/7] Restoring madVR settings...
call :ImportSettings "madVR" "%ROOT%Config\madVR.reg" "HKCU\Software\madshi\madVR"
if errorlevel 1 goto :FAILED

echo.
echo [6/7] Installing XySubFilter x64...
>>"%LOG%" echo [6/7] Installing XySubFilter x64...
call :RegisterComponent "XySubFilter x64" "%ROOT%xyVSFilterSubFilter\x64\XySubFilter.dll"
if errorlevel 1 goto :FAILED
call :VerifyCom "XySubFilter x64" "HKCR\CLSID\{2DFCB782-EC20-4A7C-B530-4577ADB33F21}\InprocServer32" "%ROOT%xyVSFilterSubFilter\x64\XySubFilter.dll"
if errorlevel 1 goto :FAILED

echo.
echo [7/7] Restoring XySubFilter settings and verifying...
>>"%LOG%" echo [7/7] Restoring XySubFilter settings and verifying...
call :ImportSettings "XySubFilter" "%ROOT%Config\XySubFilter.reg" "HKCU\Software\Gabest\XySubFilter"
if errorlevel 1 goto :FAILED

call :FinalVerification
if errorlevel 1 goto :FAILED

call :Divider
call :Status PASS "RESTORE COMPLETE"
call :Info "PotPlayer: %POTPLAYER%"
call :Info "Backup: %BACKUP_DIR%"
call :Info "Log: %LOG%"
call :Divider
>>"%LOG%" echo Completed: %DATE% %TIME%

echo.
set "LAUNCH_CHOICE="
set /p "LAUNCH_CHOICE=Press Y to launch PotPlayer, or press N/Enter to exit: "
if /I "!LAUNCH_CHOICE!"=="Y" (
    start "" "%POTPLAYER%"
    set "START_RC=!errorlevel!"
    if not "!START_RC!"=="0" (
        call :Status WARN "PotPlayer launch returned rc=!START_RC!."
    ) else (
        call :Status PASS "PotPlayer launch requested."
    )
) else (
    call :Info "PotPlayer launch skipped by user."
)

endlocal & exit /b 0

:FAILED
call :Divider
call :Status FAIL "RESTORE FAILED. Review %LOG% for the failed stage."
>>"%LOG%" echo Failed: %DATE% %TIME%
call :Divider
echo.
pause
endlocal & exit /b 1

:Banner
echo ============================================================
echo  PotPlayer Personal Lazy Pack
echo  Restore Utility
echo ============================================================
echo.
echo Root:
echo %ROOT%
exit /b 0

:WriteRunHeader
>>"%LOG%" echo.
>>"%LOG%" echo ============================================================
>>"%LOG%" echo PotPlayer Personal Lazy Pack - Restore Utility
>>"%LOG%" echo Started: %DATE% %TIME%
>>"%LOG%" echo Root: %ROOT%
>>"%LOG%" echo ============================================================
exit /b 0

:Divider
echo ============================================================
>>"%LOG%" echo ============================================================
exit /b 0

:Status
echo [%~1] %~2
>>"%LOG%" echo [%~1] %~2
exit /b 0

:Info
echo [INFO] %~1
>>"%LOG%" echo [INFO] %~1
exit /b 0

:RequireFile
if exist "%ROOT%%~1" exit /b 0
set /a MISSING+=1
call :Status FAIL "Missing: %~1"
exit /b 0

:StopProcess
"%TASKLIST%" /FI "IMAGENAME eq %~1" /NH 2>nul | "%SystemRoot%\System32\find.exe" /I "%~1" >nul
if errorlevel 1 (
    call :Status SKIP "%~1 is not running."
    exit /b 0
)

"%TASKKILL%" /IM "%~1" /F >nul 2>&1
set "KILL_RC=!errorlevel!"
"%TASKLIST%" /FI "IMAGENAME eq %~1" /NH 2>nul | "%SystemRoot%\System32\find.exe" /I "%~1" >nul
if not errorlevel 1 (
    call :Status FAIL "Could not stop %~1; taskkill rc=!KILL_RC!."
    exit /b 1
)
call :Status PASS "Stopped %~1; taskkill rc=!KILL_RC!."
exit /b 0

:CreateBackupDirectory
set "STAMP="
for /f %%I in ('powershell.exe -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss"') do set "STAMP=%%I"
if not defined STAMP (
    call :Status FAIL "Could not generate a backup timestamp."
    exit /b 1
)

set "BACKUP_BASE=%ROOT%Backup-Before-Restore\!STAMP!"
set "BACKUP_DIR=!BACKUP_BASE!"
set /a BACKUP_SUFFIX=0
:BACKUP_NAME_LOOP
if not exist "!BACKUP_DIR!\" goto :BACKUP_NAME_READY
set /a BACKUP_SUFFIX+=1
set "PADDED_SUFFIX=0!BACKUP_SUFFIX!"
set "BACKUP_DIR=!BACKUP_BASE!-!PADDED_SUFFIX:~-2!"
goto :BACKUP_NAME_LOOP

:BACKUP_NAME_READY
mkdir "!BACKUP_DIR!" >nul 2>&1
set "MKDIR_RC=!errorlevel!"
if not "!MKDIR_RC!"=="0" (
    call :Status FAIL "Could not create backup directory: !BACKUP_DIR!; rc=!MKDIR_RC!."
    exit /b 1
)
call :Status PASS "Backup directory created: !BACKUP_DIR!"
exit /b 0

:BackupKey
"%REGEXE%" query "%~1" >nul 2>&1
if errorlevel 1 (
    call :Status SKIP "%~3 not present; no backup required."
    exit /b 0
)

"%REGEXE%" export "%~1" "%BACKUP_DIR%\%~2" /y >nul 2>&1
set "EXPORT_RC=!errorlevel!"
if not "!EXPORT_RC!"=="0" (
    call :Status FAIL "%~3 backup failed; rc=!EXPORT_RC!."
    exit /b 1
)
call :Status PASS "%~3 backed up to %~2; rc=!EXPORT_RC!."
exit /b 0

:RegisterComponent
"%REGSVR%" /s "%~2"
set "REGISTER_RC=!errorlevel!"
if not "!REGISTER_RC!"=="0" (
    call :Status FAIL "%~1 registration failed; rc=!REGISTER_RC!."
    exit /b 1
)
call :Status PASS "%~1 registered; rc=!REGISTER_RC!."
exit /b 0

:ImportSettings
"%REGEXE%" import "%~2" >nul 2>&1
set "IMPORT_RC=!errorlevel!"
if not "!IMPORT_RC!"=="0" (
    call :Status FAIL "%~1 settings import failed; rc=!IMPORT_RC!."
    exit /b 1
)
"%REGEXE%" query "%~3" >nul 2>&1
set "QUERY_RC=!errorlevel!"
if not "!QUERY_RC!"=="0" (
    call :Status FAIL "%~1 settings key missing after import; query rc=!QUERY_RC!."
    exit /b 1
)
call :Status PASS "%~1 settings imported and verified; rc=!IMPORT_RC!."
exit /b 0

:VerifyCom
set "COM_VALUE="
for /f "tokens=2,*" %%A in ('%REGEXE% query "%~2" /ve 2^>nul ^| findstr.exe /I "REG_"') do set "COM_VALUE=%%B"
if not defined COM_VALUE (
    call :Status FAIL "%~1 COM registration was not found."
    exit /b 1
)
if /I not "!COM_VALUE!"=="%~3" (
    call :Status FAIL "%~1 COM path mismatch: !COM_VALUE!"
    call :Info "Expected COM path: %~3"
    exit /b 1
)
exit /b 0

:FinalVerification
set /a VERIFY_FAIL=0

call :VerifyRegistryKey "LAV configuration" "HKCU\Software\LAV"
call :VerifyRegistryKey "madVR configuration" "HKCU\Software\madshi\madVR"
call :VerifyRegistryKey "XySubFilter configuration" "HKCU\Software\Gabest\XySubFilter"

call :VerifyComFinal "LAV Splitter" "HKCR\CLSID\{B98D13E7-55DB-4385-A33D-09FD1BA26338}\InprocServer32" "%ROOT%LAVFilters\LAVSplitter.ax"
call :VerifyComFinal "LAV Video" "HKCR\CLSID\{EE30215D-164F-4A92-A4EB-9D4C13390F9F}\InprocServer32" "%ROOT%LAVFilters\LAVVideo.ax"
call :VerifyComFinal "LAV Audio" "HKCR\CLSID\{E8E73B6B-4CB3-44A4-BE99-4F7BCB96E491}\InprocServer32" "%ROOT%LAVFilters\LAVAudio.ax"
call :VerifyComFinal "madVR renderer" "HKCR\CLSID\{E1A8B82A-32CE-4B0D-BE0D-AA68C772E423}\InprocServer32" "%ROOT%madVR\madVR64.ax"
call :VerifyComFinal "madVR allocator presenter" "HKCR\CLSID\{F352C9C1-D39D-4622-A279-978A60927CDE}\InprocServer32" "%ROOT%madVR\madVR64.ax"
call :VerifyComFinal "XySubFilter x64" "HKCR\CLSID\{2DFCB782-EC20-4A7C-B530-4577ADB33F21}\InprocServer32" "%ROOT%xyVSFilterSubFilter\x64\XySubFilter.dll"

if not exist "%ROOT%Potplayer\PotPlayerMini64.exe" (
    set /a VERIFY_FAIL+=1
    call :Status FAIL "PotPlayerMini64.exe missing during final verification."
) else (
    call :Status PASS "PotPlayer executable present."
)
if not exist "%ROOT%Potplayer\PotPlayerMini64.ini" (
    set /a VERIFY_FAIL+=1
    call :Status FAIL "PotPlayerMini64.ini missing during final verification."
) else (
    call :Status PASS "PotPlayer INI present."
)

if not "!VERIFY_FAIL!"=="0" (
    call :Status FAIL "Final verification failed: !VERIFY_FAIL! check(s)."
    exit /b 1
)
call :Status PASS "Final verification complete."
exit /b 0

:VerifyRegistryKey
"%REGEXE%" query "%~2" >nul 2>&1
if errorlevel 1 (
    set /a VERIFY_FAIL+=1
    call :Status FAIL "%~1 key not found."
) else (
    call :Status PASS "%~1 key found."
)
exit /b 0

:VerifyComFinal
call :VerifyCom "%~1" "%~2" "%~3"
if errorlevel 1 (
    set /a VERIFY_FAIL+=1
) else (
    call :Status PASS "%~1 COM path verified."
)
exit /b 0
