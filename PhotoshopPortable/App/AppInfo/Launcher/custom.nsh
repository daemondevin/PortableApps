; Adobe Photoshop CS3 Portable custom code for PortableApps Compiler.
; For support, visit the GitHub project:
; https://github.com/daemondevin/pac-man
;
; What lives here and why:
;   Launch     The launcher needs administrator rights (Photoshop's shared
;              files live in Common Files, and the product language in HKLM),
;              but Photoshop itself is started with the rights of the signed
;              in user, the way Explorer would start it. Windows doesn't let
;              Explorer drag files into a program that runs elevated, so
;              this is what makes drag and drop work. A second launch while
;              Photoshop runs isn't elevated at all: it only hands its files
;              to the running Photoshop.
;   Registry   Photoshop's own settings (HKCU\Software\Adobe\Photoshop and
;              HKCU\Software\Adobe\IAC) travel with the package in
;              Data\settings. They are imported for the session and saved
;              back when Photoshop closes; whatever an installed Photoshop
;              had there is put back. The machine-wide keys Photoshop CS3
;              registers (file types, scripting classes, type libraries) are
;              listed in [PhotoshopRegistry] in PhotoshopPortable.ini and
;              journaled the same way, as is the product language
;              (ProductLanguage= in PhotoshopPortable.ini).
;   Data       Folders that are linked into Data but missing there are
;              filled from App\DefaultData first, so a link never starts out
;              empty.
;
; The folder links themselves are not done here: they are declared in
; PhotoshopPortable.ini and handled by the journaled Symlinks segment.

; Variables
Var PSKeysLoaded

; Defines
!define LANGKEY     `SOFTWARE\Adobe\DefaultLanguage`
!define PSEXE       `Photoshop.exe`
!define /ifndef TOKEN_QUERY 0x0008
!define /ifndef TOKEN_DUPLICATE 0x0002
!define /ifndef PROCESS_QUERY_LIMITED_INFORMATION 0x1000

; Functions

; Instances

; Sets $0 to true when a launcher of this package is already running (the
; primary instance holds the mutex the InstanceManagement segment creates).
; A mutex made by an elevated launcher can't be opened from a launcher that
; isn't elevated, but the refusal still says it exists.
Function PS_PrimaryRunning
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
Function PS_ShellToken
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
; Photoshop. When the shell's token can't be had, it is started as the
; launcher runs (and drag and drop from Explorer won't work in that session).
Function PS_Start
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
		Call PS_ShellToken
		StrCpy $7 $0
		Pop $0
		${If} $7 P<> 0
			; CREATE_UNICODE_ENVIRONMENT
			System::Call `advapi32::CreateProcessWithTokenW(p r7, i 0, p 0, w r1, i 0x400, p r6, w r2, p r3, p r4) i .r5`
			${If} $5 = 0
				${DebugMsg} "CreateProcessWithTokenW failed; starting Photoshop as the launcher runs."
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

; Journals every key listed in [PhotoshopRegistry]. Each entry is a full key
; path starting with HKLM\ or HKCU\. The launcher is 32-bit, like
; Photoshop CS3, so both see the same (32-bit) registry view.
Function PS_JournalKeys
	Push $0
	Push $1
	Push $2
	Push $3
	Push $R0
	StrCpy $R0 1
	${Do}
		ClearErrors
		${ReadLauncherConfig} $1 PhotoshopRegistry $R0
		${IfThen} ${Errors} ${|} ${ExitDo} ${|}
		StrCpy $2 $1 5
		StrCpy $3 $1 "" 5
		${If} $2 == "HKLM\"
			${Journal::RegKey} Photoshop HKLM $3 $0
		${ElseIf} $2 == "HKCU\"
			${Journal::RegKey} Photoshop HKCU $3 $0
		${Else}
			${InvalidValueError} [PhotoshopRegistry]:$R0 $1
		${EndIf}
		IntOp $R0 $R0 + 1
	${Loop}
	Pop $R0
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Journals HKCU\$1 and loads the portable copy of it from Data\settings\$2,
; when there is one.
Function PS_LoadKey
	Push $0
	Push $R1
	Push $R2
	; Kept in $R1 and $R2: older pac-man builds hand back $0 and $1 swapped
	; from Journal::RegKey.
	StrCpy $R1 $1
	StrCpy $R2 $2
	${Journal::RegKey} Photoshop HKCU $R1 $0
	${If} $0 != ""
	${AndIf} $R1 != ""
		StrCpy $PSKeysLoaded true
		DeleteRegKey HKCU $R1
		${If} ${FileExists} `${DATA}\settings\$R2`
			nsExec::ExecToStack `"$SYSDIR\reg.exe" import "${DATA}\settings\$R2"`
			Pop $0
			Pop $0
		${EndIf}
	${EndIf}
	Pop $R2
	Pop $R1
	Pop $0
FunctionEnd

; Saves HKCU\$1 to Data\settings\$2. The journal then puts back what was
; there before. Only after a session that loaded the keys: when the launcher
; only cleans up after a crash, crash recovery has already put back what was
; there before (an installed Photoshop's settings, or nothing), and that
; must not be saved over Data.
Function PS_SaveKey
	Push $0
	${Journal::RegKeyExists} HKCU $1 $0
	${If} $0 == 1
	${AndIf} $PSKeysLoaded == true
		CreateDirectory `${DATA}\settings`
		nsExec::ExecToStack `"$SYSDIR\reg.exe" export "HKCU\$1" "${DATA}\settings\$2.new" /y`
		Pop $0
		Pop $0
		${If} ${FileExists} `${DATA}\settings\$2.new`
			Delete `${DATA}\settings\$2`
			Rename `${DATA}\settings\$2.new` `${DATA}\settings\$2`
		${EndIf}
	${EndIf}
	Pop $0
FunctionEnd

; Sets the product language for the session, journaled.
Function PS_Language
	Push $0
	Push $R1
	${ReadUserConfig} $R1 ProductLanguage
	${If} $R1 == ""
		StrCpy $R1 en_us
	${EndIf}
	${Journal::RegKey} Photoshop HKLM `${LANGKEY}` $0
	${If} $0 != ""
		WriteRegStr HKLM `${LANGKEY}` AdobeProductLanguage $R1
	${EndIf}
	Pop $R1
	Pop $0
FunctionEnd

; Data

; Copies App\DefaultData\$0 to Data\$0 when Data doesn't have it yet.
Function PS_SeedData
	${IfNot} ${FileExists} `${DATA}\$0\*.*`
	${AndIf} ${FileExists} `$EXEDIR\App\DefaultData\$0\*.*`
		CreateDirectory `${DATA}\$0`
		CopyFiles /SILENT `$EXEDIR\App\DefaultData\$0\*.*` `${DATA}\$0`
	${EndIf}
FunctionEnd

; Fills every [SymlinkN] Source that's missing from Data.
Function PS_SeedLinks
	Push $0
	Push $R0
	StrCpy $R0 1
	${Do}
		ClearErrors
		${ReadLauncherConfig} $0 Symlink$R0 Source
		${IfThen} ${Errors} ${|} ${ExitDo} ${|}
		Call PS_SeedData
		IntOp $R0 $R0 + 1
	${Loop}
	Pop $R0
	Pop $0
FunctionEnd

; Hooks

; RunAsAdmin segment, .onInit, before it elevates. A second launch while
; Photoshop runs only hands its files over, so it isn't elevated: no UAC
; prompt, and it can start Photoshop with the user's normal rights.
!macro CustomOverride
	Call PS_PrimaryRunning
	${If} $0 == true
		Goto RunAsAdminEnd
	${EndIf}
!macroend

; Execute: starts Photoshop and, for the first launch, waits for it and any
; other copy of it to close, as the launcher normally does.
!macro OverrideExecuteFunction
	${GetParent} `$EXEDIR\App\$ProgramExecutable` $2
	StrCpy $1 `$ExecString`
	${If} $Parameters != ""
		StrCpy $1 `$1 $Parameters`
	${EndIf}
	Call PS_Start
	${If} $0 P= 0
		StrCpy $MissingFileOrPath `App\$ProgramExecutable`
		MessageBox MB_ICONSTOP|MB_TOPMOST `$(LauncherFileNotFound)`
	${ElseIf} $WaitForProgram != false
		System::Call `kernel32::WaitForSingleObject(p r0, i -1)`
		System::Call `kernel32::CloseHandle(p r0)`
		${Do}
			Sleep 1000
			${ProcessWaitClose} ${PSEXE} -1 $R9
		${LoopWhile} $R9 > 0
	${Else}
		System::Call `kernel32::CloseHandle(p r0)`
	${EndIf}
!macroend

${SegmentFile}

${SegmentPrePrimary}
	Call PS_SeedLinks
	Call PS_JournalKeys
	Call PS_Language
	StrCpy $1 `Software\Adobe\Photoshop`
	StrCpy $2 HKCU.reg
	Call PS_LoadKey
	StrCpy $1 `Software\Adobe\IAC`
	StrCpy $2 IAC.reg
	Call PS_LoadKey
!macroend

${SegmentPostPrimary}
	StrCpy $1 `Software\Adobe\Photoshop`
	StrCpy $2 HKCU.reg
	Call PS_SaveKey
	StrCpy $1 `Software\Adobe\IAC`
	StrCpy $2 IAC.reg
	Call PS_SaveKey
	${Journal::HasEntries} Photoshop $R0
	${If} $R0 > 0
		${Journal::Rollback} Photoshop
	${EndIf}
!macroend
