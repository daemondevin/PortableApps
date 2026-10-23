; O&O Defrag Portable custom code for PortableApps Compiler.
; For support, visit the GitHub project:
; https://github.com/daemondevin/pac-man
;
; What lives here and why:
;   Windows    O&O Defrag Professional is 64-bit only; the launcher says so on
;              32-bit Windows instead of failing to start it.
;   Settings   O&O Defrag keeps its settings, jobs and your licence in
;              HKLM\SOFTWARE\O&O\O&O Defrag (the 64-bit registry view). The key
;              travels with the package in Data\settings\O&ODefrag.reg: it is
;              imported for the session and saved back when O&O Defrag
;              closes, and whatever an installed O&O Defrag had there is put
;              back. A settings file holding anything but that key is not
;              imported.
;
; The service, the drive map control and the data folder are declared in
; O&ODefragPortable.ini and handled by the journaled Services, RegDLL and
; Symlinks segments.

; Variables
Var OODLoaded

; Defines
!define OODKEY      `SOFTWARE\O&O\O&O Defrag`
!define OODREG      `O&ODefrag.reg`

; Functions

; Sets $0 to true when the .reg file $0 holds keys under
; HKLM\SOFTWARE\O&O\O&O Defrag only.
Function OOD_IsOwnReg
	Push $1
	Push $2
	Push $3
	Push $4
	StrCpy $2 false
	StrCpy $3 `[HKEY_LOCAL_MACHINE\${OODKEY}`
	StrLen $4 $3
	ClearErrors
	FileOpen $1 $0 r
	${IfNot} ${Errors}
		${Do}
			ClearErrors
			FileReadUTF16LE $1 $0
			${IfThen} ${Errors} ${|} ${ExitDo} ${|}
			StrCpy $0 $0 $4
			${If} $0 == $3
				StrCpy $2 true
			${Else}
				StrCpy $0 $0 1
				${If} $0 == "["
					StrCpy $2 false
					${ExitDo}
				${EndIf}
			${EndIf}
		${Loop}
		FileClose $1
	${EndIf}
	StrCpy $0 $2
	Pop $4
	Pop $3
	Pop $2
	Pop $1
FunctionEnd

; Journals HKLM\SOFTWARE\O&O\O&O Defrag (64-bit view) and replaces it with
; the package's copy.
Function OOD_Load
	Push $0
	Push $1
	Push $2
	SetRegView 64
	ClearErrors
	EnumRegKey $0 HKLM `${OODKEY}` 0
	${If} ${Errors}
		; Not there: deleted again afterwards, with HKLM\SOFTWARE\O&O when
		; that isn't there either.
		ClearErrors
		EnumRegKey $0 HKLM `SOFTWARE\O&O` 0
		${If} ${Errors}
			${Journal::Record} OODefrag REGKEY HKLM `SOFTWARE\O&O` "" 64
		${Else}
			${Journal::Record} OODefrag REGKEY HKLM `${OODKEY}` "" 64
		${EndIf}
	${Else}
		CreateDirectory `${JOURNAL_STORE}\OODefrag`
		System::Call `kernel32::GetTickCount() i .r1`
		StrCpy $2 `${JOURNAL_STORE}\OODefrag\OODefrag-$1.reg`
		nsExec::ExecToStack `"$SYSDIR\reg.exe" export "HKLM\${OODKEY}" "$2" /y /reg:64`
		Pop $0
		Pop $1
		${If} ${FileExists} $2
			${Journal::Record} OODefrag REGKEY HKLM `${OODKEY}` $2 64
		${Else}
			${DebugMsg} "Could not back up HKLM\${OODKEY}; it is left alone."
			Goto OOD_Load_End
		${EndIf}
	${EndIf}
	StrCpy $OODLoaded true
	DeleteRegKey HKLM `${OODKEY}`
	StrCpy $0 `$DataDirectory\settings\${OODREG}`
	${If} ${FileExists} $0
		Call OOD_IsOwnReg
		${If} $0 == true
			nsExec::ExecToStack `"$SYSDIR\reg.exe" import "$DataDirectory\settings\${OODREG}" /reg:64`
			Pop $0
			Pop $0
		${Else}
			${DebugMsg} "Data\settings\${OODREG} holds other keys; not imported."
		${EndIf}
	${EndIf}
	OOD_Load_End:
	SetRegView lastused
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Saves HKLM\SOFTWARE\O&O\O&O Defrag to Data\settings\O&ODefrag.reg, only
; after a session that loaded it (when the launcher only cleans up after a
; crash, recovery has already put back what was there before).
Function OOD_Save
	Push $0
	${If} $OODLoaded == true
		SetRegView 64
		ClearErrors
		EnumRegKey $0 HKLM `${OODKEY}` 0
		${IfNot} ${Errors}
			CreateDirectory `$DataDirectory\settings`
			Delete `$DataDirectory\settings\${OODREG}.new`
			nsExec::ExecToStack `"$SYSDIR\reg.exe" export "HKLM\${OODKEY}" "$DataDirectory\settings\${OODREG}.new" /y /reg:64`
			Pop $0
			Pop $0
			${If} ${FileExists} `$DataDirectory\settings\${OODREG}.new`
				Delete `$DataDirectory\settings\${OODREG}`
				Rename `$DataDirectory\settings\${OODREG}.new` `$DataDirectory\settings\${OODREG}`
			${EndIf}
		${EndIf}
		SetRegView lastused
	${EndIf}
	Pop $0
FunctionEnd

; Hooks

${SegmentFile}

${Segment.OnInit}
	!ifndef OOD_TEST
		${If} $Arch == x86
			MessageBox MB_ICONSTOP|MB_TOPMOST "O&O Defrag needs 64-bit Windows.$\r$\n$\r$\n${PORTABLEAPPNAME} can't run on this computer."
			Quit
		${EndIf}
	!endif
!macroend

${SegmentPrePrimary}
	Call OOD_Load
!macroend

${SegmentPostPrimary}
	Call OOD_Save
	${Journal::HasEntries} OODefrag $R0
	${If} $R0 > 0
		${Journal::Rollback} OODefrag
	${EndIf}
!macroend
