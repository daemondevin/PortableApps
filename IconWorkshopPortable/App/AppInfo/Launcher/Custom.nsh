; Axialis IconWorkshop Portable custom code for PortableApps Compiler.
; For support, visit the GitHub project:
; https://github.com/daemondevin/pac-man
;
; IconWorkshop runs from App\IconWorkshop: your own licensed copy, which
; you add. It keeps its settings, and the registration you make with your
; own product key, under HKCU\Software\Axialis; its templates and color
; swatches in %APPDATA%\Axialis\IconWorkshop and its work files in
; %LOCALAPPDATA%\Axialis (both moved in from Data by the launcher's INI).
; What this file adds:
;
;   Settings      HKCU\Software\Axialis\IconWorkshop, Customer Info, folders
;                 and Internet Access are filled from .reg files in
;                 Data\settings for the session and saved back afterward.
;                 The keys are journaled first, so an installed IconWorkshop's
;                 settings come back as they were.
;   Librarian     The Librarian's location is set to Data\Axialis Librarian
;                 for every launch, so it follows the package.
;   Language      Follows the PortableApps.com Platform's language when that
;                 changes. A language picked in IconWorkshop stays until then.
;   Older layout  Settings from earlier packages are taken over once, without
;                 their registration: you register again with your own key.
;   Moving        Paths in the settings are updated when the package moves.
;   Version       The version of IconWorkshop.exe is written to appinfo.ini.

; Defines
!define AX_SEG      IconWorkshopPortable
!define IW_APP      `$EXEDIR\App\IconWorkshop`
!define IW_LIB      `${DATA}\Axialis Librarian`

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

; Removes HKCU\Software\Axialis when the session leaves it empty (it wasn't
; there before, or only held what was journaled away).
Function AX_CleanParent
	DeleteRegKey /ifempty HKCU `Software\Axialis`
	ClearErrors
FunctionEnd

; IconWorkshop

; The keys IconWorkshop keeps, each with its .reg file in Data\settings.
; _CALL is AX_Import or AX_Export.
!macro IW_Keys _CALL
	StrCpy $R0 `Software\Axialis\IconWorkshop`
	StrCpy $R1 `${SET}\IconWorkshop.reg`
	Call ${_CALL}
	StrCpy $R0 `Software\Axialis\Customer Info`
	StrCpy $R1 `${SET}\AxialisCustomerInfo.reg`
	Call ${_CALL}
	StrCpy $R0 `Software\Axialis\folders`
	StrCpy $R1 `${SET}\AxialisFolders.reg`
	Call ${_CALL}
	StrCpy $R0 `Software\Axialis\Internet Access`
	StrCpy $R1 `${SET}\AxialisInternetAccess.reg`
	Call ${_CALL}
!macroend

; IconWorkshop's interface language (prefs, AppLanguage) for the
; PortableApps.com Platform's language, when that's not the one it was last
; time and IconWorkshop has it.
Function IW_Language
	Push $0
	Push $1
	Push $2
	ReadEnvStr $1 PAL:_IgnoreLanguage
	ReadEnvStr $0 PAL:LanguageName
	${ReadSettings} $2 LanguageFrom
	${If} $1 != true
	${AndIf} $0 != ""
	${AndIf} $0 != $2
		${WriteSettings} $0 LanguageFrom
		StrCpy $1 ""
		${If} $0 == English
		${OrIf} $0 == EnglishGB
			StrCpy $1 1
		${ElseIf} $0 == French
			StrCpy $1 2
		${ElseIf} $0 == Italian
			StrCpy $1 3
		${ElseIf} $0 == Spanish
		${OrIf} $0 == SpanishInternational
			StrCpy $1 4
		${ElseIf} $0 == German
			StrCpy $1 5
		${ElseIf} $0 == Dutch
			StrCpy $1 7
		${ElseIf} $0 == Portuguese
		${OrIf} $0 == PortugueseBR
			StrCpy $1 11
		${ElseIf} $0 == SimpChinese
			StrCpy $1 14
		${ElseIf} $0 == Greek
			StrCpy $1 17
		${ElseIf} $0 == Japanese
			StrCpy $1 20
		${ElseIf} $0 == Korean
			StrCpy $1 21
		${EndIf}
		${If} $1 != ""
			WriteRegDWORD HKCU `Software\Axialis\IconWorkshop\prefs` AppLanguage $1
		${EndIf}
	${EndIf}
	ClearErrors
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Paths in the saved settings. $R8 and $R9 are set by AX_UpdatePaths.
Function AX_PathFiles
	Push $R7
	StrCpy $R7 `${SET}\IconWorkshop.reg`
	Call AX_ReplaceInReg
	StrCpy $R7 `${SET}\AxialisFolders.reg`
	Call AX_ReplaceInReg
	Pop $R7
FunctionEnd

; Hooks

${SegmentFile}

${SegmentPrePrimary}
	Push $R0
	Push $R1
	CreateDirectory `${SET}`
	CreateDirectory `${IW_LIB}`
	Call AX_UpdatePaths
	!insertmacro IW_Keys AX_Import
	WriteRegStr HKCU `Software\Axialis\folders` LibrarianLocation `${IW_LIB}`
	Call IW_Language
	Pop $R1
	Pop $R0
!macroend

${SegmentPostPrimary}
	Push $R0
	Push $R1
	!insertmacro IW_Keys AX_Export
	${Journal::HasEntries} ${AX_SEG} $R0
	${If} $R0 > 0
		${Journal::Rollback} ${AX_SEG}
	${EndIf}
	Call AX_CleanParent
	StrCpy $R0 `${IW_APP}\IconWorkshop.exe`
	Call AX_WriteVersion
	Pop $R1
	Pop $R0
!macroend
