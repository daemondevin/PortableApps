; Adobe Illustrator CS3 Portable custom code for PortableApps Compiler.
; For support, visit the GitHub project:
; https://github.com/daemondevin/pac-man
;
; What lives here and why:
;   Registry   Illustrator CS3 registers its file types, its scripting (COM)
;              classes and its type library in HKLM when it can (when it runs
;              elevated, which is now only the fallback below), and Adobe's
;              licensing code keeps payload records in HKCU. The
;              keys are listed in [IllustratorRegistry] in
;              IllustratorPortable.ini and journaled before Illustrator
;              starts, so they are deleted, or put back the way an installed
;              Illustrator had them, when it closes or on the next launch
;              after a crash.
;   Launch     The launcher needs administrator rights (Illustrator's shared
;              files live in Common Files and Program Data, and the product
;              language in HKLM), but Illustrator itself is started with the
;              rights of the signed in user, the way Explorer would start it.
;              Windows doesn't let Explorer drag files into a program that
;              runs elevated, so this is what makes drag and drop work. A
;              second launch while Illustrator runs isn't elevated at all: it
;              only hands its files to the running Illustrator.
;   Language   Adobe's shared code reads the product language from
;              HKLM\SOFTWARE\Adobe\DefaultLanguage. It is set for the session
;              (ProductLanguage= in IllustratorPortable.ini, en_us by
;              default) and journaled the same way.
;
; Illustrator's settings, the Adobe PDF settings and the shared files it
; expects in Common Files are not done here: they are declared in
; IllustratorPortable.ini and handled by the journaled Symlinks segment.

; Defines
!define LANGKEY     `SOFTWARE\Adobe\DefaultLanguage`
!define ILLEXE      `Illustrator.exe`
!define /ifndef TOKEN_QUERY 0x0008
!define /ifndef PROCESS_QUERY_LIMITED_INFORMATION 0x1000

; Functions

; Instances

; Sets $0 to true when a launcher of this package is already running (the
; primary instance holds the mutex the InstanceManagement segment creates).
; A mutex made by an elevated launcher can't be opened from a launcher that
; isn't elevated, but the refusal still says it exists.
Function ILL_PrimaryRunning
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
Function ILL_ShellToken
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
; Illustrator. When the shell's token can't be had, it is started as the
; launcher runs (and drag and drop from Explorer won't work in that session).
Function ILL_Start
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
		Call ILL_ShellToken
		StrCpy $7 $0
		Pop $0
		${If} $7 P<> 0
			; CREATE_UNICODE_ENVIRONMENT
			System::Call `advapi32::CreateProcessWithTokenW(p r7, i 0, p 0, w r1, i 0x400, p r6, w r2, p r3, p r4) i .r5`
			${If} $5 = 0
				${DebugMsg} "CreateProcessWithTokenW failed; starting Illustrator as the launcher runs."
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

; Registry

; Journals every key listed in [IllustratorRegistry]. Each entry is a full
; key path starting with HKLM\ or HKCU\. The launcher is 32-bit, like
; Illustrator CS3, so both see the same (32-bit) registry view.
Function ILL_JournalKeys
	Push $0
	Push $1
	Push $2
	Push $3
	Push $R0
	StrCpy $R0 1
	${Do}
		ClearErrors
		${ReadLauncherConfig} $1 IllustratorRegistry $R0
		${IfThen} ${Errors} ${|} ${ExitDo} ${|}
		StrCpy $2 $1 5
		StrCpy $3 $1 "" 5
		${If} $2 == "HKLM\"
			${Journal::RegKey} Illustrator HKLM $3 $0
		${ElseIf} $2 == "HKCU\"
			${Journal::RegKey} Illustrator HKCU $3 $0
		${Else}
			${InvalidValueError} [IllustratorRegistry]:$R0 $1
		${EndIf}
		IntOp $R0 $R0 + 1
	${Loop}
	Pop $R0
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Sets the product language for the session, journaled.
Function ILL_Language
	Push $0
	Push $R1
	; $R1, not $1: older pac-man builds hand back $0 and $1 swapped from
	; Journal::RegKey.
	${ReadUserConfig} $R1 ProductLanguage
	${If} $R1 == ""
		StrCpy $R1 en_us
	${EndIf}
	${Journal::RegKey} Illustrator HKLM `${LANGKEY}` $0
	${If} $0 != ""
		WriteRegStr HKLM `${LANGKEY}` AdobeProductLanguage $R1
	${EndIf}
	Pop $R1
	Pop $0
FunctionEnd

; Hooks

; RunAsAdmin segment, .onInit, before it elevates. A second launch while
; Illustrator runs only hands its files over, so it isn't elevated: no UAC
; prompt, and it can start Illustrator with the user's normal rights.
!macro CustomOverride
	Call ILL_PrimaryRunning
	${If} $0 == true
		Goto RunAsAdminEnd
	${EndIf}
!macroend

; Execute: starts Illustrator and, for the first launch, waits for it and any
; other copy of it to close, as the launcher normally does.
!macro OverrideExecuteFunction
	${GetParent} `$EXEDIR\App\$ProgramExecutable` $2
	StrCpy $1 `$ExecString`
	${If} $Parameters != ""
		StrCpy $1 `$1 $Parameters`
	${EndIf}
	Call ILL_Start
	${If} $0 P= 0
		StrCpy $MissingFileOrPath `App\$ProgramExecutable`
		MessageBox MB_ICONSTOP|MB_TOPMOST `$(LauncherFileNotFound)`
	${ElseIf} $WaitForProgram != false
		System::Call `kernel32::WaitForSingleObject(p r0, i -1)`
		System::Call `kernel32::CloseHandle(p r0)`
		${Do}
			Sleep 1000
			${ProcessWaitClose} ${ILLEXE} -1 $R9
		${LoopWhile} $R9 > 0
	${Else}
		System::Call `kernel32::CloseHandle(p r0)`
	${EndIf}
!macroend

${SegmentFile}

${SegmentPrePrimary}
	Call ILL_JournalKeys
	Call ILL_Language
!macroend

${SegmentPostPrimary}
	${Journal::HasEntries} Illustrator $R0
	${If} $R0 > 0
		${Journal::Rollback} Illustrator
	${EndIf}
!macroend
