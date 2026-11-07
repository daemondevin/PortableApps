; Axialis IconVectors Portable custom code for PortableApps Compiler.
; For support, visit the GitHub project:
; https://github.com/daemondevin/pac-man
;
; IconVectors runs from App\IconVectors: your own licensed copy, which you
; add. It keeps its settings, and the registration you make with your own
; product key, in HKCU\Software\Axialis\IconVectors, and its palettes, icon
; packs and autosaved drawings in %APPDATA%\Axialis\IconVectors (moved in
; from Data\IconVectors by the launcher's INI). What this file adds:
;
;   Settings      HKCU\Software\Axialis\IconVectors is filled from
;                 Data\settings\IconVectors.reg for the session and saved
;                 back afterward. The key is journaled first, so an installed
;                 IconVectors' settings come back as they were.
;   Updates       IconVectors' own update check is turned off: it would
;                 install IconVectors into Program Files.
;   Version       The version of IconVectors.exe is written to appinfo.ini.

; Defines
!define AX_SEG      IconVectorsPortable
!define IV_APP      `$EXEDIR\App\IconVectors`
!define IV_KEY      `Software\Axialis\IconVectors`
!define IV_REG      `${SET}\IconVectors.reg`

; Shared Axialis helpers

; Journals a folder that may be created: removed again if it isn't there
; yet. $R0 = the folder, $R1 = recursive to remove it with its contents.
Function AX_JournalDir
	${IfNot} ${FileExists} `$R0\*.*`
		${Journal::Record} ${AX_SEG} DIR $R0 "" $R1 ""
	${EndIf}
FunctionEnd

; The registry key HKCU\$R0 is the package's for the session: journaled
; first (a key an installed copy has comes back afterward), emptied, and
; filled from the .reg file $R1 when there is one.
Function AX_Import
	Push $0
	${Journal::RegKey} ${AX_SEG} HKCU $R0 $0
	DeleteRegKey HKCU $R0
	${If} ${FileExists} $R1
		nsExec::Exec `"$SYSDIR\reg.exe" import "$R1"`
		Pop $0
	${EndIf}
	ClearErrors
	Pop $0
FunctionEnd

; Saves HKCU\$R0 to the .reg file $R1 (UTF-16, as reg.exe writes it). The
; file is only replaced once the export has worked.
Function AX_Export
	Push $0
	ClearErrors
	EnumRegKey $0 HKCU $R0 0
	${IfNot} ${Errors}
		CreateDirectory `${SET}`
		Delete `$R1.new`
		nsExec::Exec `"$SYSDIR\reg.exe" export "HKCU\$R0" "$R1.new" /y`
		Pop $0
		${If} $0 = 0
		${AndIf} ${FileExists} `$R1.new`
			Delete $R1
			Rename `$R1.new` $R1
		${EndIf}
		Delete `$R1.new`
	${EndIf}
	ClearErrors
	Pop $0
FunctionEnd

; Replaces the path $R8 with $R9 (both ending in a backslash) in the .reg
; file $R7, where backslashes are doubled (D:\\Apps\\).
Function AX_ReplaceInReg
	Push $0
	Push $1
	${If} ${FileExists} $R7
		${WordReplace} $R8 "\" "\\" "+" $0
		${WordReplace} $R9 "\" "\\" "+" $1
		${ReplaceInFileU16} $R7 $0 $1
	${EndIf}
	ClearErrors
	Pop $1
	Pop $0
FunctionEnd

; When the package has moved, calls AX_PathFiles (defined by the package)
; with $R8 and $R9 set: first the paths into the package, then, if the
; drive letter changed, the other paths on that drive.
Function AX_UpdatePaths
	Push $0
	Push $1
	Push $2
	Push $3
	Push $R7
	Push $R8
	Push $R9
	ReadEnvStr $0 PAL:LastDrive
	ReadEnvStr $1 PAL:LastPackagePartialDir
	ReadEnvStr $2 PAL:Drive
	ReadEnvStr $3 PAL:PackagePartialDir
	StrCpy $R8 `$0$1`
	StrCpy $R9 `$2$3`
	StrCpy $1 $R8 1 -1
	${IfThen} $1 == "\" ${|} StrCpy $R8 $R8 -1 ${|}
	StrCpy $1 $R9 1 -1
	${IfThen} $1 == "\" ${|} StrCpy $R9 $R9 -1 ${|}
	${If} $R8 != $R9
	${AndIf} $R8 != ""
		StrCpy $R8 `$R8\`
		StrCpy $R9 `$R9\`
		Call AX_PathFiles
	${EndIf}
	StrCpy $3 $0 1 1
	StrCpy $R7 $2 1 1
	${If} $0 != $2
	${AndIf} $3 == ":"
	${AndIf} $R7 == ":"
		StrCpy $R8 `$0\`
		StrCpy $R9 `$2\`
		Call AX_PathFiles
	${EndIf}
	ClearErrors
	Pop $R9
	Pop $R8
	Pop $R7
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Writes the version of the program file $R0 to appinfo.ini the way Axialis
; numbers its releases: 6.9.5.0 as PackageVersion and 6.95 as
; DisplayVersion (1.1.0.0 is 1.10).
Function AX_WriteVersion
	Push $0
	Push $1
	Push $2
	Push $3
	Push $4
	ClearErrors
	GetDllVersion $R0 $0 $1
	${IfNot} ${Errors}
		IntOp $2 $0 >> 16
		IntOp $2 $2 & 0xFFFF
		IntOp $3 $0 & 0xFFFF
		IntOp $4 $1 >> 16
		IntOp $4 $4 & 0xFFFF
		IntOp $1 $1 & 0xFFFF
		StrCpy $0 `$2.$3.$4.$1`
		StrCpy $3 `$2.$3$4`
		ReadINIStr $2 `$EXEDIR\App\AppInfo\appinfo.ini` Version PackageVersion
		${If} $0 != $2
		${AndIf} $0 != "0.0.0.0"
			WriteINIStr `$EXEDIR\App\AppInfo\appinfo.ini` Version PackageVersion $0
			WriteINIStr `$EXEDIR\App\AppInfo\appinfo.ini` Version DisplayVersion $3
		${EndIf}
	${EndIf}
	ClearErrors
	Pop $4
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; IconVectors

; Settings an older package kept as Data\settings\HKCU.reg (the same key)
; become Data\settings\IconVectors.reg.
Function IV_Migrate
	Push $R0
	Push $R1
	${If} ${FileExists} `${SET}\HKCU.reg`
	${AndIfNot} ${FileExists} `${IV_REG}`
        Rename `${SET}\HKCU.reg` `${IV_REG}`
		${If} ${FileExists} `${IV_REG}`
			Delete `${SET}\HKCU.reg`
		${EndIf}
	${EndIf}
	ClearErrors
	Pop $R1
	Pop $R0
FunctionEnd

; Paths in the saved settings. $R8 and $R9 are set by AX_UpdatePaths.
Function AX_PathFiles
	Push $R7
	StrCpy $R7 `${IV_REG}`
	Call AX_ReplaceInReg
	Pop $R7
FunctionEnd

; Hooks

${SegmentFile}

; Settings go in before IconVectors starts; the update check stays off.
${SegmentPrePrimary}
	Push $R0
	Push $R1
	CreateDirectory `${SET}`
	Call IV_Migrate
	Call AX_UpdatePaths
	StrCpy $R0 `${IV_KEY}`
	StrCpy $R1 `${IV_REG}`
	Call AX_Import
	WriteRegDWORD HKCU `${IV_KEY}\Options` UpdateAutoApplication 0
	; Crash reports and such, if anything still uses the defaults.
	StrCpy $R1 recursive
	StrCpy $R0 `$LOCALAPPDATA\Axialis\IconVectors`
	Call AX_JournalDir
	Pop $R1
	Pop $R0
!macroend

${SegmentPostPrimary}
	Push $R0
	Push $R1
	StrCpy $R0 `${IV_KEY}`
	StrCpy $R1 `${IV_REG}`
	Call AX_Export
	${Journal::HasEntries} ${AX_SEG} $R0
	${If} $R0 > 0
		${Journal::Rollback} ${AX_SEG}
	${EndIf}
    DeleteRegKey /ifempty HKCU `Software\Axialis`
	ClearErrors
	StrCpy $R0 `${IV_APP}\IconVectors.exe`
	Call AX_WriteVersion
	Pop $R1
	Pop $R0
!macroend
