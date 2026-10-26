; O&O RegEditor Portable custom code for PortableApps Compiler.
; For support, visit the GitHub project:
; https://github.com/daemondevin/pac-man
;
; O&O RegEditor is portable by design: it keeps its settings in OORegEdt.ini
; next to the program, which the launcher.ini keeps in Data. What this file
; adds:
;
;   Settings       An OORegEdt.ini found in the program folder (O&O RegEditor
;                  was started without the launcher) is taken into Data if
;                  Data has none, and otherwise kept beside it, never lost.
;   .reg files     "Always open .REG files with O&O RegEditor" points the .reg
;                  file type at the copy in the package, machine-wide, and
;                  registers OOREGEDIT.Document. Both are journaled and put
;                  back when O&O RegEditor closes: Explorer can't open a .reg
;                  file with a program on a drive that isn't there.
;   Language       O&O RegEditor picks English or German by the system locale,
;                  or uses the only language folder there is. Language=en or
;                  de in O&ORegEditorPortable.ini sets the other folder aside
;                  for the session; Language=auto follows the PortableApps.com
;                  Platform's language when started from the Platform.
;   Version        The product version of the program is written to
;                  appinfo.ini after each session, so the PortableApps.com
;                  Platform shows the version that was added.

; Defines
!define ORE         `$EXEDIR\App\OORegEditor`
!define OREINI      `OORegEdt.ini`
!define OREINFO     `$EXEDIR\App\AppInfo\appinfo.ini`
!define DOCTYPE     `OOREGEDIT.Document`

; Macros

; Journals the default value of a registry key, or the key itself when it
; doesn't exist yet (it's then removed again).
!macro ORE_JournalDefault _ROOT _HKEY _KEY
	StrCpy $R0 `${_ROOT}`
	StrCpy $R1 `${_HKEY}`
	StrCpy $R2 `${_KEY}`
	Call ORE_JournalDefault
!macroend

; Journals a key that's created or replaced as a whole.
!macro ORE_JournalKey _ROOT _KEY
	${Journal::RegKey} OORegEditor ${_ROOT} `${_KEY}` $R3
!macroend

; Functions

; OORegEdt.ini in Data is the one that counts: the launcher.ini moves it into
; place for each session, and would keep a copy it finds in the program
; folder instead. So a copy there is taken into Data when Data has none,
; and otherwise kept as OORegEdt.found.ini in Data.
Function ORE_Settings
	${If} ${FileExists} `${ORE}\${OREINI}`
		CreateDirectory `${DATA}`
		${If} ${FileExists} `${DATA}\${OREINI}`
			Delete `${DATA}\OORegEdt.found.ini`
			Rename `${ORE}\${OREINI}` `${DATA}\OORegEdt.found.ini`
		${Else}
			Rename `${ORE}\${OREINI}` `${DATA}\${OREINI}`
		${EndIf}
	${EndIf}
	ClearErrors
FunctionEnd

; $R0 root name (HKLM or HKCU), $R1 its handle, $R2 the key.
Function ORE_JournalDefault
	Push $0
	Push $1
	Push $2
	${Journal::RegKeyExists} $R0 $R2 $0
	${If} $0 = 0
		${Journal::RegKey} OORegEditor $R0 $R2 $0
	${Else}
		; RRF_RT_ANY | RRF_NOEXPAND: only ask for the type. An empty value
		; name is the key's default value.
		System::Call `advapi32::RegGetValueW(p R1, w R2, w "", i 0x1000FFFF, *i .r1, p 0, p 0) i .r0`
		${If} $0 <> 0
			StrCpy $2 ""
		${Else}
			${If} $R0 == HKLM
				ReadRegStr $2 HKLM $R2 ""
			${Else}
				ReadRegStr $2 HKCU $R2 ""
			${EndIf}
			${If} $1 = 1
				StrCpy $2 `STR:$2`
			${ElseIf} $1 = 2
				StrCpy $2 `EXP:$2`
			${Else}
				; Not a string: not something O&O RegEditor wrote.
				Goto ORE_JournalDefault_End
			${EndIf}
		${EndIf}
		${Journal::Record} OORegEditor REGVALUE $R0 $R2 "" $2
	${EndIf}
	ORE_JournalDefault_End:
	ClearErrors
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; The .reg association. O&O RegEditor runs elevated, so it writes to
; HKEY_CLASSES_ROOT as an administrator: into HKLM\SOFTWARE\Classes, or into
; HKCU\Software\Classes where the user's own .reg key already exists. Both
; are journaled.
Function ORE_JournalAssociation
	Push $R0
	Push $R1
	Push $R2
	Push $R3
	${If} $Admin == true
		!insertmacro ORE_JournalDefault HKLM 0x80000002 `SOFTWARE\Classes\.reg`
		!insertmacro ORE_JournalKey HKLM `SOFTWARE\Classes\${DOCTYPE}`
	${EndIf}
	!insertmacro ORE_JournalDefault HKCU 0x80000001 `Software\Classes\.reg`
	!insertmacro ORE_JournalKey HKCU `Software\Classes\${DOCTYPE}`
	Pop $R3
	Pop $R2
	Pop $R1
	Pop $R0
FunctionEnd

; Sets the language folder that isn't wanted aside for the session. The undo
; puts it back, unless an update added a new one meanwhile; then the old one
; is deleted.
Function ORE_Language
	Push $0
	Push $1
	Push $2
	ClearErrors
	${ReadUserConfig} $0 Language
	${If} $0 == ""
		StrCpy $0 auto
	${EndIf}
	; A folder left set aside by a session that crashed is put back first;
	; recovery normally does this, and this covers a journal that was
	; cleared by hand.
	${If} ${FileExists} `${ORE}\en.off\*.*`
	${AndIfNot} ${FileExists} `${ORE}\en\*.*`
		Rename `${ORE}\en.off` `${ORE}\en`
	${EndIf}
	${If} ${FileExists} `${ORE}\de.off\*.*`
	${AndIfNot} ${FileExists} `${ORE}\de\*.*`
		Rename `${ORE}\de.off` `${ORE}\de`
	${EndIf}
	${If} $0 == auto
		; Outside the Platform the Language segment sets PAL:_IgnoreLanguage,
		; and O&O RegEditor's own choice stands.
		ReadEnvStr $1 PAL:_IgnoreLanguage
		${If} $1 == true
			StrCpy $0 ""
		${Else}
			ReadEnvStr $1 PAL:LanguageCode
			StrCpy $1 $1 2
			${If} $1 == de
				StrCpy $0 de
			${Else}
				StrCpy $0 en
			${EndIf}
		${EndIf}
	${EndIf}
	${If} $0 == en
		StrCpy $2 de
	${ElseIf} $0 == de
		StrCpy $2 en
	${Else}
		StrCpy $2 ""
	${EndIf}
	${If} $2 != ""
	${AndIf} ${FileExists} `${ORE}\$0\OORegEdt.dll`
	${AndIf} ${FileExists} `${ORE}\$2\*.*`
		RMDir /r `${ORE}\$2.off`
		${Journal::Record} OORegEditorLang CMD `"$SYSDIR\cmd.exe" /c if exist "${ORE}\$2.off" (if exist "${ORE}\$2" (rd /s /q "${ORE}\$2.off") else (move /y "${ORE}\$2.off" "${ORE}\$2"))` "0" "" ""
		ClearErrors
		Rename `${ORE}\$2` `${ORE}\$2.off`
		${If} ${Errors}
			${Journal::Discard} OORegEditorLang
		${EndIf}
	${EndIf}
	ClearErrors
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Reads the product version of the file in $R0 into $R1 ("" when it has
; none). The file version of O&O RegEditor is its own build number; the
; product version is the one O&O publishes (12.0.2172).
Function ORE_ProductVersion
	Push $0
	Push $1
	Push $2
	Push $3
	Push $4
	Push $5
	Push $6
	StrCpy $R1 ""
	System::Call `version::GetFileVersionInfoSizeW(w R0, *i .r1) i .r0`
	${If} $0 > 0
		System::Alloc $0
		Pop $2
		System::Call `version::GetFileVersionInfoW(w R0, i 0, i r0, p r2) i .r1`
		${If} $1 <> 0
			System::Call `version::VerQueryValueW(p r2, w "\VarFileInfo\Translation", *p .r3, *i .r4) i .r1`
			${If} $1 <> 0
			${AndIf} $4 >= 4
				System::Call `*$3(&i2 .r5, &i2 .r6)`
				IntFmt $5 "%04x" $5
				IntFmt $6 "%04x" $6
				System::Call `version::VerQueryValueW(p r2, w "\StringFileInfo\$5$6\ProductVersion", *p .r3, *i .r4) i .r1`
				${If} $1 <> 0
				${AndIf} $4 > 0
					System::Call `*$3(&w${NSIS_MAX_STRLEN} .R1)`
				${EndIf}
			${EndIf}
		${EndIf}
		System::Free $2
	${EndIf}
	Pop $6
	Pop $5
	Pop $4
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Writes the product version of the program that ran to appinfo.ini:
; 12.0.2172 as DisplayVersion, 12.0.2172.0 as PackageVersion.
Function ORE_WriteVersion
	Push $0
	Push $1
	Push $2
	Push $R0
	Push $R1
	StrCpy $R0 `${ORE}\OORegEdt.exe`
	${IfNot} ${FileExists} $R0
		StrCpy $R0 `${ORE}\OORegEdt32.exe`
	${EndIf}
	Call ORE_ProductVersion
	${If} $R1 != ""
		; Four parts for PackageVersion.
		StrCpy $0 0
		StrCpy $1 0
		${Do}
			StrCpy $2 $R1 1 $1
			${IfThen} $2 == "." ${|} IntOp $0 $0 + 1 ${|}
			IntOp $1 $1 + 1
		${LoopUntil} $2 == ""
		StrCpy $1 $R1
		${DoWhile} $0 < 3
			StrCpy $1 `$1.0`
			IntOp $0 $0 + 1
		${Loop}
		ReadINIStr $2 `${OREINFO}` Version DisplayVersion
		${If} $2 != $R1
			WriteINIStr `${OREINFO}` Version PackageVersion $1
			WriteINIStr `${OREINFO}` Version DisplayVersion $R1
		${EndIf}
	${EndIf}
	ClearErrors
	Pop $R1
	Pop $R0
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Hooks

${SegmentFile}

; Custom runs first in PrePrimary, before the launcher.ini moves
; OORegEdt.ini into place.
${SegmentPrePrimary}
	Call ORE_Settings
	Call ORE_JournalAssociation
	Call ORE_Language
!macroend

${SegmentPostPrimary}
	${Journal::HasEntries} OORegEditorLang $R0
	${If} $R0 > 0
		${Journal::Rollback} OORegEditorLang
	${EndIf}
	${Journal::HasEntries} OORegEditor $R0
	${If} $R0 > 0
		${Journal::Rollback} OORegEditor
	${EndIf}
	Call ORE_WriteVersion
!macroend
