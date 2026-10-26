; RipX DAW Portable custom code for PortableApps Compiler.
; For support, visit the GitHub project:
; https://github.com/daemondevin/pac-man
;
; What lives here and why:
;   Windows    RipX DAW is 64-bit only; the launcher says so on 32-bit Windows
;              instead of failing to start it.
;   Launch     The launcher needs administrator rights (see Machine below),
;              but RipX itself is started with the rights of the signed in
;              user, the way Explorer would start it. Windows doesn't let
;              Explorer drag files into a program that runs elevated, so
;              this is what makes dragging audio into RipX work. A second
;              launch while RipX runs isn't elevated at all: it only hands its
;              files to the running RipX.
;   Machine    RipX reads where its resources are from
;              HKLM\SOFTWARE\HitnMix\HitnMix\Kit\DataPath, and the user details
;              its installer leaves in ...\Kit\User info; without them it
;              counts as a broken installation. For the session the key gets
;              what RipX's installer would write, pointing at the package
;              (the 64-bit registry view, the one RipX reads), and is put
;              back the way it was afterward. User details an installed RipX
;              left there are kept.
;   Settings   RipX's preferences (HKCU\Software\HitnMix\HitnMix\Kit) travel
;              with the package in Data\settings\RipX.reg: imported for the
;              session and saved back when RipX closes. Whatever an installed
;              RipX had there is put back afterward.
;
; RipX's activation is not touched: RipX keeps it for each Windows user in a
; key of its own, which stays on the computer as Hit'n'Mix intends.
;
; Every change is journaled before it is made, so it is undone when RipX
; closes, or on the next launch after a crash.

; Variables
Var RXSettingsLoaded

; Defines
!define RXEXE       `RipX.exe`
!define HMKEY       `SOFTWARE\HitnMix`
!define KITKEY      `SOFTWARE\HitnMix\HitnMix\Kit`
!define USERKEY     `Software\HitnMix`
!define USERKIT     `Software\HitnMix\HitnMix\Kit`
!define RXREG       `RipX.reg`
!define /ifndef TOKEN_QUERY 0x0008
!define /ifndef PROCESS_QUERY_LIMITED_INFORMATION 0x1000

; Functions

; Instances

; Sets $0 to true when a launcher of this package is already running (the
; primary instance holds the mutex the InstanceManagement segment creates).
; A mutex made by an elevated launcher can't be opened from a launcher that
; isn't elevated, but the refusal still says it exists.
Function RX_PrimaryRunning
	Push $1
	System::Call `kernel32::OpenMutex(i 0x00100000, i 0, t "${APPNAME}-${APPNAME}") p .r0 ?e`
	Pop $1
	${If} $0 P<> 0
		System::Call `kernel32::CloseHandle(p r0)`
		StrCpy $0 true
	${ElseIf} $1 = 5
		StrCpy $0 true
	${Else}
		StrCpy $0 false
	${EndIf}
	Pop $1
FunctionEnd

; Launching

; Sets $0 to a primary token of the signed in user, taken from the shell
; (Explorer), or 0 when there is none or it belongs to someone else (the
; launcher was elevated with another account's password). The caller closes
; it.
Function RX_ShellToken
	Push $1
	Push $2
	Push $3
	Push $4
	Push $5
	Push $6
	StrCpy $0 0
	System::Call `user32::GetShellWindow() p .r1`
	${If} $1 P<> 0
		System::Call `user32::GetWindowThreadProcessId(p r1, *i .r2)`
		System::Call `kernel32::OpenProcess(i ${PROCESS_QUERY_LIMITED_INFORMATION}, i 0, i r2) p .r3`
		${If} $3 P<> 0
			System::Call `advapi32::OpenProcessToken(p r3, i 0x000A, *p .r4) i .r5`
			${If} $5 <> 0
				; Same account as the launcher? Compare the users of both
				; tokens (TokenUser, 1).
				System::Call `kernel32::GetCurrentProcess() p .r1`
				System::Call `advapi32::OpenProcessToken(p r1, i ${TOKEN_QUERY}, *p .r1) i .r5`
				${If} $5 <> 0
					System::Call `*(&i256) p .r2`
					System::Call `*(&i256) p .r6`
					System::Call `advapi32::GetTokenInformation(p r4, i 1, p r2, i 256, *i .r5) i .r5`
					${If} $5 <> 0
						System::Call `advapi32::GetTokenInformation(p r1, i 1, p r6, i 256, *i .r5) i .r5`
					${EndIf}
					${If} $5 <> 0
						; TOKEN_USER starts with a pointer to the SID.
						Push $2
						Push $6
						System::Call `*$2(p .r2)`
						System::Call `*$6(p .r6)`
						System::Call `advapi32::EqualSid(p r2, p r6) i .r5`
						Pop $6
						Pop $2
					${EndIf}
					System::Free $2
					System::Free $6
					System::Call `kernel32::CloseHandle(p r1)`
					${If} $5 <> 0
						; MAXIMUM_ALLOWED, SecurityImpersonation, TokenPrimary
						System::Call `advapi32::DuplicateTokenEx(p r4, i 0x02000000, p 0, i 2, i 1, *p .r0) i .r5`
						${If} $5 = 0
							StrCpy $0 0
						${EndIf}
					${EndIf}
				${EndIf}
				System::Call `kernel32::CloseHandle(p r4)`
			${EndIf}
			System::Call `kernel32::CloseHandle(p r3)`
		${EndIf}
	${EndIf}
	Pop $6
	Pop $5
	Pop $4
	Pop $3
	Pop $2
	Pop $1
FunctionEnd

; Starts command line $1 in folder $2 and sets $0 to its process handle (0
; when it could not be started). An elevated launcher starts it with the
; shell's token, so it runs with the user's normal rights; the launcher's
; environment is passed on either way, so the PAL variables still reach
; RipX. When the shell's token can't be had, it is started as the
; launcher runs (and drag and drop from Explorer won't work in that session).
Function RX_Start
	Push $3
	Push $4
	Push $5
	Push $6
	Push $7
	System::Call `*(i 68, &i64) p .r3`
	System::Call `*(&i16) p .r4`
	System::Call `kernel32::GetEnvironmentStringsW() p .r6`
	StrCpy $5 0
	StrCpy $7 0
	${If} $Admin == true
		Push $0
		Call RX_ShellToken
		StrCpy $7 $0
		Pop $0
		${If} $7 P<> 0
			; CREATE_UNICODE_ENVIRONMENT
			System::Call `advapi32::CreateProcessWithTokenW(p r7, i 0, p 0, w r1, i 0x400, p r6, w r2, p r3, p r4) i .r5`
			${If} $5 = 0
				${DebugMsg} "CreateProcessWithTokenW failed; starting RipX as the launcher runs."
			${EndIf}
			System::Call `kernel32::CloseHandle(p r7)`
		${EndIf}
	${EndIf}
	${If} $5 = 0
		System::Call `kernel32::CreateProcessW(p 0, w r1, p 0, p 0, i 0, i 0x400, p r6, w r2, p r3, p r4) i .r5`
	${EndIf}
	StrCpy $0 0
	${If} $5 <> 0
		System::Call `*$4(p .r0, p .r5)`
		System::Call `kernel32::CloseHandle(p r5)`
	${EndIf}
	System::Call `kernel32::FreeEnvironmentStringsW(p r6)`
	System::Free $3
	System::Free $4
	Pop $7
	Pop $6
	Pop $5
	Pop $4
	Pop $3
FunctionEnd

; Machine-wide registry

; Writes value $1 = $2 under HKLM\$0 (64-bit view) unless it is set already.
Function RX_DefaultValue
	Push $3
	ClearErrors
	ReadRegStr $3 HKLM $0 $1
	${If} ${Errors}
		WriteRegStr HKLM $0 $1 $2
	${EndIf}
	Pop $3
FunctionEnd

; Journals HKLM\SOFTWARE\HitnMix in the 64-bit view and gives RipX the
; values its installer writes, pointing at the package.
Function RX_Machine
	Push $0
	Push $1
	Push $2
	Push $3
	SetRegView 64
	ClearErrors
	EnumRegKey $0 HKLM `${HMKEY}` 0
	${If} ${Errors}
		; Not there: deleted again afterward.
		${Journal::Record} RipX REGKEY HKLM `${HMKEY}` "" 64
	${Else}
		; There (an installed RipX): exported first, put back afterward.
		CreateDirectory `${JOURNAL_STORE}\RipX`
		System::Call `kernel32::GetTickCount() i .r1`
		StrCpy $2 `${JOURNAL_STORE}\RipX\HitnMix-$1.reg`
		nsExec::ExecToStack `"$SYSDIR\reg.exe" export "HKLM\${HMKEY}" "$2" /y /reg:64`
		Pop $0
		Pop $1
		${If} ${FileExists} $2
			${Journal::Record} RipX REGKEY HKLM `${HMKEY}` $2 64
		${Else}
			${DebugMsg} "Could not back up HKLM\${HMKEY}; it is left alone."
			Goto RX_Machine_End
		${EndIf}
	${EndIf}
	StrCpy $3 `$EXEDIR\App\RipXDAW`
	WriteRegStr HKLM `SOFTWARE\HitnMix\HitnMix\ApplicationPath` "" `$3\${RXEXE}`
	WriteRegStr HKLM `${KITKEY}\DataPath` ResourcePath `$3\`
	WriteRegStr HKLM `${KITKEY}\DataPath` HitnMixSharedPath `$3\`
	; The installer's defaults; RipX replaces them when it is activated.
	StrCpy $0 `${KITKEY}\User info`
	StrCpy $1 Name
	StrCpy $2 Name
	Call RX_DefaultValue
	StrCpy $1 Company
	StrCpy $2 Company
	Call RX_DefaultValue
	StrCpy $1 ActivationCode
	StrCpy $2 00000-00000-00000-00000-00000
	Call RX_DefaultValue
	RX_Machine_End:
	SetRegView lastused
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; User settings

; Sets $0 to true when the .reg file $0 holds HKCU\Software\HitnMix keys
; only. Older packages shipped an export of the installer's HKLM key under
; this name, and importing that would write to HKLM unjournaled.
Function RX_IsUserReg
	Push $1
	Push $2
	StrCpy $2 false
	ClearErrors
	FileOpen $1 $0 r
	${IfNot} ${Errors}
		${Do}
			ClearErrors
			FileReadUTF16LE $1 $0
			${IfThen} ${Errors} ${|} ${ExitDo} ${|}
			StrCpy $0 $0 35
			${If} $0 == "[HKEY_CURRENT_USER\Software\HitnMix"
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
	Pop $2
	Pop $1
FunctionEnd

; Journals HKCU\Software\HitnMix and replaces RipX's preferences with the
; package's copy.
Function RX_LoadSettings
	Push $0
	${Journal::RegKey} RipX HKCU `${USERKEY}` $0
	${If} $0 != ""
		StrCpy $RXSettingsLoaded true
		DeleteRegKey HKCU `${USERKIT}`
		StrCpy $0 `$DataDirectory\settings\${RXREG}`
		${If} ${FileExists} $0
			Call RX_IsUserReg
			${If} $0 == true
				nsExec::ExecToStack `"$SYSDIR\reg.exe" import "$DataDirectory\settings\${RXREG}"`
				Pop $0
				Pop $0
			${Else}
				${DebugMsg} "Data\settings\${RXREG} isn't an export of RipX's preferences; not imported."
			${EndIf}
		${EndIf}
	${EndIf}
	Pop $0
FunctionEnd

; Saves RipX's preferences to Data\settings\RipX.reg. The new export replaces
; the old one only once it is complete. Only after a session that loaded
; them: when the launcher only cleans up after a crash, crash recovery has
; already put back what was there before, and that must not be saved over
; Data.
Function RX_SaveSettings
	Push $0
	${Journal::RegKeyExists} HKCU `${USERKIT}` $0
	${If} $0 == 1
	${AndIf} $RXSettingsLoaded == true
		CreateDirectory `$DataDirectory\settings`
		Delete `$DataDirectory\settings\${RXREG}.new`
		nsExec::ExecToStack `"$SYSDIR\reg.exe" export "HKCU\${USERKIT}" "$DataDirectory\settings\${RXREG}.new" /y`
		Pop $0
		Pop $0
		${If} ${FileExists} `$DataDirectory\settings\${RXREG}.new`
			Delete `$DataDirectory\settings\${RXREG}`
			Rename `$DataDirectory\settings\${RXREG}.new` `$DataDirectory\settings\${RXREG}`
		${EndIf}
	${EndIf}
	Pop $0
FunctionEnd

; Hooks

; RunAsAdmin segment, .onInit, before it elevates. A second launch while
; RipX runs only hands its files over, so it isn't elevated: no UAC
; prompt, and it can start RipX with the user's normal rights.
!macro CustomOverride
	Call RX_PrimaryRunning
	${If} $0 == true
		Goto RunAsAdminEnd
	${EndIf}
!macroend

; Execute: starts RipX and, for the first launch, waits for it and any
; other copy of it to close, as the launcher normally does.
!macro OverrideExecuteFunction
	${GetParent} `$EXEDIR\App\$ProgramExecutable` $2
	StrCpy $1 `$ExecString`
	${If} $Parameters != ""
		StrCpy $1 `$1 $Parameters`
	${EndIf}
	Call RX_Start
	${If} $0 P= 0
		StrCpy $MissingFileOrPath `App\$ProgramExecutable`
		MessageBox MB_ICONSTOP|MB_TOPMOST `$(LauncherFileNotFound)`
	${ElseIf} $WaitForProgram != false
		System::Call `kernel32::WaitForSingleObject(p r0, i -1)`
		System::Call `kernel32::CloseHandle(p r0)`
		${Do}
			Sleep 1000
			${ProcessWaitClose} ${RXEXE} -1 $R9
		${LoopWhile} $R9 > 0
	${Else}
		System::Call `kernel32::CloseHandle(p r0)`
	${EndIf}
!macroend


${SegmentFile}

${Segment.OnInit}
	!ifndef RX_TEST
		${If} $Arch == x86
			MessageBox MB_ICONSTOP|MB_TOPMOST "RipX DAW needs 64-bit Windows.$\r$\n$\r$\n${PORTABLEAPPNAME} can't run on this computer."
			Quit
		${EndIf}
	!endif
!macroend

${SegmentPrePrimary}
	Call RX_Machine
	Call RX_LoadSettings
!macroend

${SegmentPostPrimary}
	Call RX_SaveSettings
	${Journal::HasEntries} RipX $R0
	${If} $R0 > 0
		${Journal::Rollback} RipX
	${EndIf}
!macroend
