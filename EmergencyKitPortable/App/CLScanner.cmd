@echo off
setlocal EnableExtensions

::
:: CLScanner.cmd
:: A menu for the Emsisoft Commandline Scanner (a2cmd.exe).
:: Developed by daemon.devin, released with Emsisoft Emergency Kit Portable.
::
:: Started by CLScannerPortable.exe through the portable launcher, which runs
:: it as administrator and moves the logs and quarantine into place first.
::

set "ver=2.0"
set "eek=%~dp0EEK"
set "a2cmd=%eek%\bin64\a2cmd.exe"
set "logsdir=%eek%\Logs"
set "quardir=%eek%\Quarantine"

if not exist "%a2cmd%" (
	echo.
	echo The command line scanner was not found:
	echo %a2cmd%
	echo.
	pause
	goto :EOF
)
if not exist "%logsdir%" mkdir "%logsdir%"
if not exist "%quardir%" mkdir "%quardir%"

title Emsisoft Commandline Scanner Portable

:MENU
call :HEADER
echo   1. Quick scan       Active programs and the places malware usually starts from
echo   2. Malware scan     All the places malware usually infects
echo   3. Custom scan      A folder or drive you choose
echo   4. Quarantine       List, restore or delete quarantined objects
echo   5. Update           Update the signatures and the scanner
echo   6. Exit
echo.
set "opt="
set /p "opt=Choose an option: "
if "%opt%"=="1" set "scantype=/quick" & goto :OPTIONS
if "%opt%"=="2" set "scantype=/malware" & goto :OPTIONS
if "%opt%"=="3" goto :CUSTOM
if "%opt%"=="4" goto :QUARANTINE
if "%opt%"=="5" goto :UPDATE
if "%opt%"=="6" goto :EOF
goto :MENU

:CUSTOM
call :HEADER
echo Enter the full path of a folder or drive to scan, for example C:\ or D:\Downloads.
echo Leave it empty to go back.
echo.
set "target="
set /p "target=Path: "
if not defined target goto :MENU
set "target=%target:"=%"
if not exist "%target%" (
	echo.
	echo "%target%" doesn't exist.
	echo.
	pause
	goto :CUSTOM
)
set "scantype=/f="%target%" /m /t"
goto :OPTIONS

:OPTIONS
set "pup="
set "zip="
set "ads="
call :HEADER
call :ASK "Detect potentially unwanted programs (PUP)?"
if not errorlevel 1 set "pup=/pup"
call :ASK "Scan inside compressed archives (zip, rar, cab)?"
if not errorlevel 1 set "zip=/a"
call :ASK "Scan NTFS alternate data streams?"
if not errorlevel 1 set "ads=/n"

:ACTION
call :HEADER
echo What should happen to objects that are detected?
echo.
echo   1. Move them to quarantine (recommended, they can be restored)
echo   2. Delete them, including their references such as registry entries
echo   3. Delete only the detected files (faster)
echo   4. Only report them
echo   5. Go back
echo.
set "opt="
set /p "opt=Choose an option: "
if "%opt%"=="1" set "action=/q="%quardir%"" & goto :SCAN
if "%opt%"=="2" set "action=/d" & goto :SCAN
if "%opt%"=="3" set "action=/dq" & goto :SCAN
if "%opt%"=="4" set "action=" & goto :SCAN
if "%opt%"=="5" goto :MENU
goto :ACTION

:SCAN
call :STAMP
call :HEADER
echo Scanning. The log is saved as Logs\clscan_%stamp%.log
echo.
"%a2cmd%" %scantype% %action% %pup% %zip% %ads% /l="%logsdir%\clscan_%stamp%.log"
echo.
echo Scan finished.
echo.
pause
goto :MENU

:QUARANTINE
call :HEADER
echo Quarantined objects:
echo.
"%a2cmd%" /ql
echo.
echo   1. Restore an object
echo   2. Restore all objects
echo   3. Delete an object permanently
echo   4. Go back
echo.
set "opt="
set /p "opt=Choose an option: "
if "%opt%"=="1" goto :RESTORE
if "%opt%"=="2" goto :RESTOREALL
if "%opt%"=="3" goto :DELETE
if "%opt%"=="4" goto :MENU
goto :QUARANTINE

:RESTORE
set "idx="
set /p "idx=Number of the object to restore: "
if defined idx "%a2cmd%" /qr=%idx%
echo.
pause
goto :QUARANTINE

:RESTOREALL
call :ASK "Restore every quarantined object to where it was found?"
if errorlevel 1 goto :QUARANTINE
"%a2cmd%" /qr
echo.
pause
goto :QUARANTINE

:DELETE
set "idx="
set /p "idx=Number of the object to delete permanently: "
if defined idx "%a2cmd%" /qd=%idx%
echo.
pause
goto :QUARANTINE

:UPDATE
call :HEADER
call :ASK "Update the signatures and the scanner now?"
if errorlevel 1 goto :MENU
echo.
"%a2cmd%" /u
echo.
echo Update finished.
echo.
pause
goto :MENU

:: Subroutines

:HEADER
cls
echo.
echo  EMSISOFT COMMANDLINE SCANNER PORTABLE (menu v%ver%)
echo.
goto :EOF

:: Asks a yes or no question. Errorlevel 0 means yes, 1 means no.
:ASK
set "yn="
set /p "yn=%~1 [Y/N]: "
if /i "%yn%"=="Y" exit /b 0
if /i "%yn%"=="N" exit /b 1
goto :ASK

:: Sets stamp to the date and time as yyyyMMdd-HHmmss, whatever the locale.
:STAMP
set "stamp="
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss" 2^>nul`) do set "stamp=%%i"
if not defined stamp set "stamp=%RANDOM%%RANDOM%"
goto :EOF
