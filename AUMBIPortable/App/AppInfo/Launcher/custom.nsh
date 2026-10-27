; AUMBI Portable custom code for PortableApps Compiler.
; For support, visit the GitHub project:
; https://github.com/daemondevin/pac-man
;
; AUMBI is a single program file that unpacks its tools into a temporary
; folder each time it runs and keeps no settings, so there's no data to move.
; What this file adds:
;
;   Adding AUMBI   AUMBI comes as AUMBI-<version>.exe. One put in App\AUMBI,
;                  or left in the package folder (where it may have been kept
;                  before), becomes App\AUMBI\AUMBI.exe when it's newer than
;                  the one there (an older one is left where it is). Its
;                  version goes to appinfo.ini.

!define AU_APP      `$EXEDIR\App\AUMBI`
!define AU_INFO     `$EXEDIR\App\AppInfo\appinfo.ini`

; $R0 = the folder to look in. $R1 and $R2 hold the best AUMBI-<version>.exe
; found so far (path and version) and are updated.
Function AU_Find
	Push $0
	Push $1
	Push $2
	Push $R0
	Push $R3
	FindFirst $0 $1 `$R0\AUMBI-*.exe`
	${DoWhile} $1 != ""
		; AUMBI-2020.2.exe: the version is between "AUMBI-" and ".exe".
		StrCpy $2 $1 -4 6
		${If} $R2 == ""
			StrCpy $R3 1
		${Else}
			${VersionCompare} $2 $R2 $R3
		${EndIf}
		${If} $R3 == 1
			StrCpy $R1 `$R0\$1`
			StrCpy $R2 $2
		${EndIf}
		FindNext $0 $1
	${Loop}
	FindClose $0
	ClearErrors
	Pop $R3
	Pop $R0
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

Function AU_Adopt
	Push $R0
	Push $R1
	Push $R2
	Push $0
	Push $1
	StrCpy $R1 ""
	StrCpy $R2 ""
	StrCpy $R0 `${AU_APP}`
	Call AU_Find
	StrCpy $R0 $EXEDIR
	Call AU_Find
	${If} $R1 != ""
		; Only when it's newer than the one in place, or there's none.
		ReadINIStr $0 `${AU_INFO}` Version DisplayVersion
		StrCpy $1 1
		${If} ${FileExists} `${AU_APP}\AUMBI.exe`
		${AndIf} $0 != ""
			${VersionCompare} $R2 $0 $1
		${EndIf}
		CreateDirectory `${AU_APP}`
		${If} $1 == 1
			Delete `${AU_APP}\AUMBI.exe`
			Rename $R1 `${AU_APP}\AUMBI.exe`
			${IfNot} ${Errors}
				WriteINIStr `${AU_INFO}` Version DisplayVersion $R2
				GetDllVersion `${AU_APP}\AUMBI.exe` $0 $1
				${IfNot} ${Errors}
					IntOp $R0 $0 >> 16
					IntOp $R0 $R0 & 0xFFFF
					IntOp $R1 $0 & 0xFFFF
					IntOp $0 $1 >> 16
					IntOp $0 $0 & 0xFFFF
					IntOp $1 $1 & 0xFFFF
					WriteINIStr `${AU_INFO}` Version PackageVersion `$R0.$R1.$0.$1`
				${EndIf}
			${EndIf}
		${EndIf}
	${EndIf}
	ClearErrors
	Pop $1
	Pop $0
	Pop $R2
	Pop $R1
	Pop $R0
FunctionEnd

${SegmentFile}

; Before the check for a missing AUMBI.exe.
${Segment.onInit}
	Call AU_Adopt
!macroend
