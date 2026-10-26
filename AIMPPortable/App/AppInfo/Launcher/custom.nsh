; AIMP Portable custom code for PortableApps Compiler.
; For support, visit the GitHub project:
; https://github.com/daemondevin/pac-man
;
; AIMP is portable by design: with AIMP.ini next to AIMP.exe saying
; UserMode=0, it keeps its whole profile in the Profile folder beside it.
; The launcher.ini keeps both in Data. What this file adds:
;
;   Portable mode  A copy of AIMP added from an installed one may bring its
;                  own AIMP.ini. It's adopted into Data once, and UserMode=0
;                  is set before every launch, so AIMP never falls back to a
;                  profile in %APPDATA%.
;   Integration    AIMP can register itself with Windows from its settings:
;                  file types, the Explorer context menu, AutoPlay handlers
;                  and a "Default Programs" entry. It does that through
;                  Elevator.exe, which asks for administrator rights and
;                  writes machine-wide keys that the launcher, running
;                  without those rights, can't undo. So by default
;                  Elevator.exe is set aside while AIMP runs, and those
;                  options do nothing. SystemIntegration=true in
;                  AIMPPortable.ini allows them; AIMP then changes Windows
;                  for every user until the options are turned off in AIMP.
;   Startup        "Run AIMP at Windows startup" adds a Run entry for the
;                  current user. It's put back the way it was when AIMP
;                  closes: a portable copy can't start from a drive that
;                  isn't there.
;   Version        AIMP can update itself. After each session the version
;                  of AIMP.exe is written to appinfo.ini, so the
;                  PortableApps.com Platform shows the right one.

; Defines
!define AIMP        `$EXEDIR\App\AIMP`
!define ELEVATOR    `${AIMP}\Elevator.exe`
!define RUNKEY      `Software\Microsoft\Windows\CurrentVersion\Run`
!define RUNVALUE    `AIMP`
!define AIMPINFO    `$EXEDIR\App\AppInfo\appinfo.ini`

; Functions

; A copy of AIMP added from an installed one can bring its own AIMP.ini.
; Data\AIMP.ini is the one that counts (the launcher.ini moves it into place
; for each session, and would otherwise keep the one it finds there), so a
; copy in the program folder is adopted into Data when Data has none, and
; removed otherwise. Then UserMode=0 makes sure AIMP keeps its profile in
; the package.
Function AIMP_PortableMode
	CreateDirectory `${DATA}`
	${If} ${FileExists} `${AIMP}\AIMP.ini`
		${If} ${FileExists} `${DATA}\AIMP.ini`
			Delete `${AIMP}\AIMP.ini`
		${Else}
			Rename `${AIMP}\AIMP.ini` `${DATA}\AIMP.ini`
		${EndIf}
	${EndIf}
	WriteINIStr `${DATA}\AIMP.ini` System UserMode 0
FunctionEnd

; Journals the current user's Run entry for AIMP: its previous value with
; its registry type, or "" when there was none, so it's removed again.
Function AIMP_JournalStartup
	Push $0
	Push $1
	Push $2
	; RRF_RT_ANY | RRF_NOEXPAND: only ask for the type.
	System::Call `advapi32::RegGetValueW(p 0x80000001, w "${RUNKEY}", w "${RUNVALUE}", i 0x1000FFFF, *i .r1, p 0, p 0) i .r0`
	${If} $0 <> 0
		StrCpy $2 ""
	${Else}
		ReadRegStr $2 HKCU `${RUNKEY}` `${RUNVALUE}`
		${If} $1 = 1
			StrCpy $2 `STR:$2`
		${ElseIf} $1 = 2
			StrCpy $2 `EXP:$2`
		${Else}
			; A type the journal can't restore isn't AIMP's; leave it.
			Goto AIMP_JournalStartup_End
		${EndIf}
	${EndIf}
	${Journal::Record} AIMP REGVALUE HKCU `${RUNKEY}` `${RUNVALUE}` $2
	AIMP_JournalStartup_End:
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Sets Elevator.exe aside for the session unless SystemIntegration=true.
; The undo puts it back, unless an AIMP update installed a new Elevator.exe
; meanwhile; then the old copy is just deleted.
Function AIMP_Integration
	Push $0
	ClearErrors
	${ReadUserConfig} $0 SystemIntegration
	${If} $0 != true
		; A copy left set aside by a session that crashed is put back first;
		; recovery normally does this, and this covers a journal that was
		; cleared by hand.
		${If} ${FileExists} `${ELEVATOR}.disabled`
		${AndIfNot} ${FileExists} `${ELEVATOR}`
			Rename `${ELEVATOR}.disabled` `${ELEVATOR}`
		${EndIf}
		${If} ${FileExists} `${ELEVATOR}`
			Delete `${ELEVATOR}.disabled`
			${Journal::Record} AIMPElevator CMD `"$SYSDIR\cmd.exe" /c if exist "${ELEVATOR}.disabled" (if exist "${ELEVATOR}" (del /f /q "${ELEVATOR}.disabled") else (move /y "${ELEVATOR}.disabled" "${ELEVATOR}"))` "0" "" ""
			ClearErrors
			Rename `${ELEVATOR}` `${ELEVATOR}.disabled`
			${If} ${Errors}
				${Journal::Discard} AIMPElevator
			${EndIf}
		${EndIf}
	${EndIf}
	ClearErrors
	Pop $0
FunctionEnd

; Writes the version of AIMP.exe to appinfo.ini. AIMP numbers its releases
; 5.40.2722 for file version 5.4.0.2722.
Function AIMP_WriteVersion
	Push $0
	Push $1
	Push $2
	Push $3
	Push $4
	Push $5
	ClearErrors
	GetDllVersion `${AIMP}\AIMP.exe` $0 $1
	${IfNot} ${Errors}
		IntOp $2 $0 >> 16
		IntOp $2 $2 & 0xFFFF
		IntOp $3 $0 & 0xFFFF
		IntOp $4 $1 >> 16
		IntOp $4 $4 & 0xFFFF
		IntOp $5 $1 & 0xFFFF
		StrCpy $0 `$2.$3$4.$5`
		ReadINIStr $1 `${AIMPINFO}` Version DisplayVersion
		${If} $0 != $1
		${AndIf} $2 > 0
			WriteINIStr `${AIMPINFO}` Version PackageVersion `$0.0`
			WriteINIStr `${AIMPINFO}` Version DisplayVersion $0
		${EndIf}
	${EndIf}
	ClearErrors
	Pop $5
	Pop $4
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Hooks

${SegmentFile}

; Language segment, Init: the Variables segment sets PAL:AppDir and
; PAL:DataDir later, in PrePrimary, but [Language] CheckIfExists and
; [LanguageFile] use them now, so they're set here first (to the same
; values).
!macro LangInit
	${SetEnvironmentVariable} PAL:AppDir `$EXEDIR\App`
	${SetEnvironmentVariable} PAL:DataDir `$EXEDIR\Data`
!macroend

; Runs before FileWrite and FilesMove, so AIMP.ini is in Data with
; UserMode=0 when it's written to and moved into place.
${SegmentPrePrimary}
	Call AIMP_PortableMode
	Call AIMP_JournalStartup
	Call AIMP_Integration
!macroend

${SegmentPostPrimary}
	${Journal::HasEntries} AIMPElevator $R0
	${If} $R0 > 0
		${Journal::Rollback} AIMPElevator
	${EndIf}
	${Journal::HasEntries} AIMP $R0
	${If} $R0 > 0
		${Journal::Rollback} AIMP
	${EndIf}
	Call AIMP_WriteVersion
!macroend
