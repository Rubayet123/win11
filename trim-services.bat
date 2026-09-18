@echo off
setlocal EnableDelayedExpansion
title Win11 Service Trim

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo   [!] This script must be run as Administrator.
    echo       Right-click trim-services.bat -^> Run as administrator
    echo.
    pause
    exit /b 1
)

set "BACKUP=%USERPROFILE%\services-baseline.csv"

:menu
cls
echo.
echo   ==========================================
echo      Win11 Service Trim
echo   ==========================================
echo.
echo     Backup file: %BACKUP%
if exist "%BACKUP%" (echo     Status:      found) else (echo     Status:      NOT CREATED YET)
echo.
echo     [1]  Create backup of current service config
echo     [2]  Disable safe set  ^(telemetry + dead services^)
echo     [3]  Disable optional set  ^(asks about each^)
echo     [4]  Disable telemetry scheduled tasks + policy
echo     [5]  Show status of affected services
echo     [6]  Restore everything from backup
echo     [0]  Exit
echo.
set /p "choice=   Select: "

if "%choice%"=="1" goto backup
if "%choice%"=="2" goto safeset
if "%choice%"=="3" goto optional
if "%choice%"=="4" goto telemetry
if "%choice%"=="5" goto status
if "%choice%"=="6" goto restore
if "%choice%"=="0" exit /b 0
goto menu

:: ---------------------------------------------------------------- backup
:backup
echo.
echo   Exporting current service configuration...
powershell -NoProfile -Command ^
  "Get-Service | Select-Object Name,DisplayName,StartType,Status | Export-Csv -LiteralPath '%BACKUP%' -NoTypeInformation"
if exist "%BACKUP%" (echo   [ok] Saved to %BACKUP%) else (echo   [!] Export failed.)
echo.
pause
goto menu

:: ---------------------------------------------------------------- safe set
:safeset
if not exist "%BACKUP%" (
    echo.
    echo   [!] Create a backup first ^(option 1^).
    echo.
    pause
    goto menu
)
echo.
call :disable DiagTrack                                    "Connected User Experiences and Telemetry"
call :disable dmwappushservice                             "WAP Push Message Routing"
call :disable diagnosticshub.standardcollector.service     "Diagnostics Hub Collector"
call :disable MapsBroker                                   "Downloaded Maps Manager"
call :disable TrkWks                                       "Distributed Link Tracking Client"
call :disable RetailDemo                                   "Retail Demo Service"
call :disable AJRouter                                     "AllJoyn Router"
call :disable WpcMonSvc                                    "Parental Controls"
call :disable WerSvc                                       "Windows Error Reporting"
call :disable PhoneSvc                                     "Phone Service"
call :disable SEMgrSvc                                     "Payments and NFC/SE"
echo.
echo   Done. Reboot when convenient.
echo.
pause
goto menu

:: ---------------------------------------------------------------- optional
:optional
if not exist "%BACKUP%" (
    echo.
    echo   [!] Create a backup first ^(option 1^).
    echo.
    pause
    goto menu
)
echo.
call :ask Spooler     "Print Spooler"            "Do you ever use a printer"
call :ask WbioSrvc    "Windows Biometric"        "Do you use Windows Hello fingerprint/face"
call :ask icssvc      "Windows Mobile Hotspot"   "Do you share your connection as a hotspot"
call :ask lfsvc       "Geolocation"              "Do you need auto timezone or Find My Device"
call :ask CDPSvc      "Connected Devices"        "Do you use Nearby Sharing or Phone Link"
echo.
echo   Xbox services - Steam does NOT need these.
call :ask XblAuthManager  "Xbox Live Auth"       "Do you use Game Pass or Microsoft Store games"
call :ask XblGameSave     "Xbox Live Game Save"  "Do you use Game Pass or Microsoft Store games"
call :ask XboxNetApiSvc   "Xbox Live Networking" "Do you use Game Pass or Microsoft Store games"
echo.
echo   Note: XboxGipSvc is left alone on purpose - disabling it can
echo         break wired Xbox controllers in some games.
echo.
pause
goto menu

:: ---------------------------------------------------------------- telemetry
:telemetry
echo.
echo   Setting AllowTelemetry policy to 0...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f >nul 2>&1
if %errorlevel% equ 0 (echo   [ok] Policy set.) else (echo   [!] Policy failed.)

echo   Disabling telemetry scheduled tasks...
call :task "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser"
call :task "\Microsoft\Windows\Application Experience\ProgramDataUpdater"
call :task "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator"
call :task "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip"
echo.
echo   Windows feature updates may re-enable these. Re-run after a big update.
echo.
pause
goto menu

:: ---------------------------------------------------------------- status
:status
echo.
powershell -NoProfile -Command ^
  "$n='DiagTrack','dmwappushservice','diagnosticshub.standardcollector.service','MapsBroker','TrkWks','RetailDemo','AJRouter','WpcMonSvc','WerSvc','PhoneSvc','SEMgrSvc','Spooler','WbioSrvc','icssvc','lfsvc','CDPSvc','XblAuthManager','XblGameSave','XboxNetApiSvc','XboxGipSvc','WSearch','SysMain'; Get-Service -Name $n -ErrorAction SilentlyContinue | Select-Object Name,StartType,Status | Format-Table -AutoSize"
echo.
pause
goto menu

:: ---------------------------------------------------------------- restore
:restore
if not exist "%BACKUP%" (
    echo.
    echo   [!] No backup found at %BACKUP%
    echo.
    pause
    goto menu
)
echo.
echo   Restoring every service to its backed-up startup type...
powershell -NoProfile -Command ^
  "$r=Import-Csv -LiteralPath '%BACKUP%'; foreach($s in $r){ try { Set-Service -Name $s.Name -StartupType $s.StartType -ErrorAction Stop } catch {} }; Write-Host '   [ok] Restore pass complete.'"
echo.
echo   Reboot to bring services back up.
echo.
pause
goto menu

:: ---------------------------------------------------------------- helpers
:disable
sc.exe query "%~1" >nul 2>&1
if %errorlevel% neq 0 (
    echo   [--] %~2 - not present on this system
    exit /b 0
)
sc.exe stop "%~1" >nul 2>&1
sc.exe config "%~1" start= disabled >nul 2>&1
if %errorlevel% equ 0 (
    echo   [ok] %~2
) else (
    echo   [!]  %~2 - could not disable
)
exit /b 0

:ask
echo.
set "reply="
set /p "reply=   %~3? (y/n): "
if /i "!reply!"=="n" (
    call :disable %~1 %2
) else (
    echo   [--] %~2 - kept
)
exit /b 0

:task
schtasks /Change /TN %1 /Disable >nul 2>&1
if %errorlevel% equ 0 (echo   [ok] %~1) else (echo   [--] %~1 - not found)
exit /b 0
