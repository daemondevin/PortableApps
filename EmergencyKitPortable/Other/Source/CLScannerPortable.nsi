;=#
;
; PORTABLEAPPS COMPILER
; Developed by daemon.devin (daemon.devin@gmail.com)
;
; For support, visit the GitHub project:
; https://github.com/daemondevin/pac-man
;
; CLScannerPortable.nsi
; The second launcher of Emsisoft Emergency Kit Portable. It starts the main
; launcher, EmergencyKitPortable.exe, with /CLScanner, which runs the menu
; for the Emsisoft Commandline Scanner (App\CLScanner.cmd) instead of the
; graphical scanner. Elevation, the data moves and the journal are all left
; to the main launcher, so this one runs with normal rights. Anything else on
; its command line is passed on.
;
; Compile it from this folder; it writes CLScannerPortable.exe to the
; package's root.
;

; Defines
!define NAME                     "CLScannerPortable"
!define FULLNAME                 "Emsisoft Commandline Scanner Portable"
!define VERSION                  "2.0.0.0"
!define LAUNCHER                 "EmergencyKitPortable.exe"
!define LAUNCHSWITCH             "/CLScanner"

; Specifications
Unicode true
Name                             "${FULLNAME}"
OutFile                          "..\..\${NAME}.exe"
Caption                          "${FULLNAME}"
VIProductVersion                 "${VERSION}"
VIAddVersionKey ProductName      "${FULLNAME}"
VIAddVersionKey Comments         "Starts Emsisoft Emergency Kit Portable's command line scanner. https://github.com/daemondevin/pac-man"
VIAddVersionKey CompanyName      "daemon.devin"
VIAddVersionKey LegalCopyright   "Emsisoft Emergency Kit is copyright Emsisoft Ltd."
VIAddVersionKey FileDescription  "${FULLNAME}"
VIAddVersionKey FileVersion      "${VERSION}"
VIAddVersionKey ProductVersion   Portable
VIAddVersionKey InternalName     "${FULLNAME}"
VIAddVersionKey OriginalFilename "${NAME}.exe"

; Runtime
CRCCheck On
WindowIcon Off
SilentInstall Silent
AutoCloseWindow True
RequestExecutionLevel user

; Compression
SetCompress Auto
SetCompressor /SOLID lzma
SetCompressorDictSize 32
SetDatablockOptimize On

; Includes
!include FileFunc.nsh
!include LogicLib.nsh

; Icon
Icon "..\..\App\AppInfo\appicon2.ico"

Section Main
	${GetParameters} $0
	${IfNot} ${FileExists} "$EXEDIR\${LAUNCHER}"
		MessageBox MB_OK|MB_ICONSTOP "$EXEDIR\${LAUNCHER} was not found."
		Abort
	${EndIf}
	SetOutPath "$EXEDIR"
	${If} $0 == ""
		Exec `"$EXEDIR\${LAUNCHER}" ${LAUNCHSWITCH}`
	${Else}
		Exec `"$EXEDIR\${LAUNCHER}" ${LAUNCHSWITCH} $0`
	${EndIf}
SectionEnd