@echo off
setlocal DisableDelayedExpansion
set "DG_SCRIPT=%~dp0DriverGuard.ps1"
if not exist "%DG_SCRIPT%" (
  echo DriverGuard.ps1 is missing from the same folder as this BAT file.
  exit /b 2
)
:menu
cls
echo ====================================================
echo                 DRIVERGUARD v1.1.1
echo          Windows Driver Update Control
echo ====================================================
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%DG_SCRIPT%" -Action Summary
echo.
echo  [1] Enable Driver Update Protection
echo  [2] Restore Original Windows Settings
echo  [3] Check Protection Status
echo  [4] View Activity Logs
echo  [5] About / Help
echo  [6] Inspect GPUs and driver provenance
echo  [7] Guided manufacturer driver installation
echo  [8] Verify installation after restart
echo  [9] Review optional obsolete package cleanup
echo  [0] Exit
echo ----------------------------------------------------
choice /C 0123456789 /N /M "Enter your choice: "
if errorlevel 10 goto cleanup
if errorlevel 9 goto verify
if errorlevel 8 goto install
if errorlevel 7 goto inspect
if errorlevel 6 goto help
if errorlevel 5 goto log
if errorlevel 4 goto status
if errorlevel 3 goto restore
if errorlevel 2 goto enable
if errorlevel 1 exit /b 0
echo Input cancelled.
goto menu
:enable
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%DG_SCRIPT%" -Action Enable
goto done
:restore
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%DG_SCRIPT%" -Action Restore
goto done
:status
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%DG_SCRIPT%" -Action Status
goto done
:log
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%DG_SCRIPT%" -Action Log
goto done
:help
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%DG_SCRIPT%" -Action Help
goto done
:inspect
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%DG_SCRIPT%" -Action Inspect
goto done
:install
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%DG_SCRIPT%" -Action Install
goto done
:verify
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%DG_SCRIPT%" -Action Verify
goto done
:cleanup
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%DG_SCRIPT%" -Action Cleanup
:done
echo.
pause
goto menu
