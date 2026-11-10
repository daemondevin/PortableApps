; BitLord Portable custom code for PortableApps Compiler.
; For support, visit the GitHub project:
; https://github.com/daemondevin/pac-man
;
; BitLord keeps its settings in HKCU\Software\bitlord.com\BitLord and its
; data in %APPDATA%\BitLord and %LOCALAPPDATA%\BitLord; the launcher INI
; moves all of that in and out of Data. What this file adds:
;
;   Downloads  The first time, BitLord's download folders are set to
;              Downloads in the PortableApps.com Documents folder, next to
;              the package. A folder you choose in BitLord afterward is kept.
;   Version    The version that ran is written to appinfo.ini.

; Defines
!define BL_EXE `$EXEDIR\App\BitLord\BitLord.exe`
!define BL_REG `$DataDirectory\settings\BitLord.reg`
!define BL_CORE `HKEY_CURRENT_USER\Software\bitlord.com\BitLord\coreconfig`

; Sets the value $R0 in coreconfig to the folder $R1 when it has none.
; Values in a .reg file are quoted, with backslashes doubled.
Function BL_DefaultFolder
	Push $0
	ClearErrors
	ReadINIStr $0 `${BL_REG}` `${BL_CORE}` `"$R0"`
	${If} $0 == ""
	${OrIf} $0 == `""`
		${WordReplace} $R1 "\" "\\" "+" $0
		WriteINIStr `${BL_REG}` `${BL_CORE}` `"$R0"` `"$0"`
	${EndIf}
	ClearErrors
	Pop $0
FunctionEnd

; The download folders, the first time.
Function BL_DefaultFolders
	Push $R0
	Push $R1
	${If} ${FileExists} `${BL_REG}`
		ReadEnvStr $R1 PortableApps.comDocuments
		StrCpy $R1 `$R1\Downloads`
		CreateDirectory $R1
		StrCpy $R0 download_location
		Call BL_DefaultFolder
		StrCpy $R0 torrentfiles_location
		Call BL_DefaultFolder
		StrCpy $R0 autoadd_location
		Call BL_DefaultFolder
		StrCpy $R0 move_completed_path
		Call BL_DefaultFolder
	${EndIf}
	Pop $R1
	Pop $R0
FunctionEnd

; Writes the version of BitLord.exe to appinfo.ini: 2.4.6.366 as
; PackageVersion and 2.4.6 as DisplayVersion, as BitLord numbers its
; releases (2.4.6-366).
Function BL_WriteVersion
	Push $0
	Push $1
	Push $2
	Push $3
	ClearErrors
	GetDllVersion `${BL_EXE}` $0 $1
	${IfNot} ${Errors}
		IntOp $2 $0 >> 16
		IntOp $2 $2 & 0xFFFF
		IntOp $3 $0 & 0xFFFF
		StrCpy $3 `$2.$3`
		IntOp $2 $1 >> 16
		IntOp $2 $2 & 0xFFFF
		StrCpy $3 `$3.$2`
		IntOp $2 $1 & 0xFFFF
		StrCpy $0 `$3.$2`
		ReadINIStr $1 `$EXEDIR\App\AppInfo\appinfo.ini` Version PackageVersion
		${If} $0 != $1
		${AndIf} $0 != "0.0.0.0"
			WriteINIStr `$EXEDIR\App\AppInfo\appinfo.ini` Version PackageVersion $0
			WriteINIStr `$EXEDIR\App\AppInfo\appinfo.ini` Version DisplayVersion $3
		${EndIf}
	${EndIf}
	ClearErrors
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

${SegmentFile}

; Runs before FileWrite and RegistryKeys, so the folders are in the file
; that's imported.
${SegmentPrePrimary}
	Call BL_DefaultFolders
!macroend

${SegmentPostPrimary}
	Call BL_WriteVersion
!macroend
