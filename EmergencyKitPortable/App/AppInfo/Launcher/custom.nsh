; Emsisoft Emergency Kit Portable custom code for PortableApps Compiler.
; For support, visit the GitHub project:
; https://github.com/daemondevin/pac-man
;
; Emergency Kit is made to run from a USB stick: it keeps its program files,
; signatures, settings, logs and quarantine in its own folder, and updates
; its program files and signatures there itself. The launcher.ini moves the
; settings, logs, reports and quarantine into Data while it runs. What it
; does to Windows is what this file takes care of. Each of these is recorded
; before Emergency Kit starts, so it is undone when Emergency Kit closes, or
; on the next launch after a crash:
;
;   Driver       Emergency Kit loads the Emsisoft Protection Platform driver
;                (service epp, a file system minifilter) to scan memory and
;                rootkits, and removes it when it closes. When the service
;                wasn't there before, it is stopped and deleted, and its
;                driver file is removed from System32\drivers if it was put
;                there.
;   Service      The command line scanner's /s switch installs a2service to
;                keep the scan engine loaded. It is removed the same way.
;   Registry     Emergency Kit creates HKLM\SOFTWARE\Emsisoft. It is deleted
;                when it wasn't there before.
;   ProgramData  %ProgramData%\Emsisoft is deleted when it wasn't there before.
;
; Anything that already existed before launch (an installed Emsisoft
; Anti-Malware, for example) is left alone. Emergency Kit refuses to start
; while Emsisoft Anti-Malware is running anyway.
;
; Second launcher  CLScannerPortable.exe starts this launcher with /CLScanner,
;                  which runs App\CLScanner.cmd (a menu for the command line
;                  scanner, a2cmd.exe) instead of the graphical scanner.
;
; Version          Emergency Kit updates itself, so after each session the
;                  version of a2emergencykit.exe is written to appinfo.ini,
;                  and the PortableApps.com Platform shows the right one.

; Variables
Var EekCLScanner

; Defines
!define EEK         `$EXEDIR\App\EEK`
!define EEKBIN      `${EEK}\bin64`
!define EEKEXE      `${EEKBIN}\a2emergencykit.exe`
!define EEKCMD      `CLScanner.cmd`
!define SVCKEY      `SYSTEM\CurrentControlSet\Services`
!define EMSIKEY     `SOFTWARE\Emsisoft`
!define EEKINFO     `$EXEDIR\App\AppInfo\appinfo.ini`

; Functions

Function EEK_Refuse32
	!ifndef EEK_TEST
		${If} $Arch == x86
			MessageBox MB_ICONSTOP|MB_TOPMOST "Emsisoft Emergency Kit needs 64-bit Windows.$\r$\n$\r$\n${PORTABLEAPPNAME} can't run on this computer."
			Quit
		${EndIf}
	!endif
FunctionEnd

; Sets $EekCLScanner to true when the command line has /CLScanner.
Function EEK_ReadSwitch
	Push $0
	Push $1
	StrCpy $EekCLScanner false
	${GetParameters} $0
	ClearErrors
	${GetOptions} $0 /CLScanner $1
	${IfNot} ${Errors}
		StrCpy $EekCLScanner true
	${EndIf}
	Pop $1
	Pop $0
FunctionEnd

; Removes /CLScanner from $0, so it isn't passed on to the scanner.
Function EEK_StripSwitch
	Push $1
	Push $2
	Push $3
	Push $R9
	StrCpy $1 ""
	StrLen $3 $0
	StrCpy $2 0
	${DoWhile} $2 < $3
		StrCpy $R9 $0 10 $2
		${If} $R9 == /CLScanner
			IntOp $2 $2 + 10
		${Else}
			StrCpy $R9 $0 1 $2
			StrCpy $1 `$1$R9`
			IntOp $2 $2 + 1
		${EndIf}
	${Loop}
	; Drop the spaces the switch leaves at either end.
	${Do}
		StrCpy $R9 $1 1
		${IfThen} $R9 != " " ${|} ${ExitDo} ${|}
		StrCpy $1 $1 "" 1
	${Loop}
	${Do}
		StrCpy $R9 $1 1 -1
		${IfThen} $R9 != " " ${|} ${ExitDo} ${|}
		StrCpy $1 $1 -1
	${Loop}
	StrCpy $0 $1
	Pop $R9
	Pop $3
	Pop $2
	Pop $1
FunctionEnd

; Older packages kept the signatures and language files in App\DefaultData
; or Data and moved them into bin64 for each session. Emergency Kit updates
; both in bin64 itself, so they now stay there. A copy left in the old place
; is moved in once, when bin64 doesn't have one.
Function EEK_MigrateFolder
	; $1 = folder name
	${IfNot} ${FileExists} `${EEKBIN}\$1\*.*`
		${If} ${FileExists} `$EXEDIR\Data\$1\*.*`
			Rename `$EXEDIR\Data\$1` `${EEKBIN}\$1`
		${ElseIf} ${FileExists} `$EXEDIR\App\DefaultData\$1\*.*`
			Rename `$EXEDIR\App\DefaultData\$1` `${EEKBIN}\$1`
		${EndIf}
	${EndIf}
	; Whatever is left in the old places is out of date now.
	${If} ${FileExists} `${EEKBIN}\$1\*.*`
		RMDir /r `$EXEDIR\App\DefaultData\$1`
		RMDir /r `$EXEDIR\Data\$1`
	${EndIf}
FunctionEnd

Function EEK_Migrate
	Push $1
	StrCpy $1 Signatures
	Call EEK_MigrateFolder
	StrCpy $1 Languages
	Call EEK_MigrateFolder
	Pop $1
FunctionEnd

; Language= in the user configuration overrides the Platform's language,
; when Emergency Kit has that language.
Function EEK_UserLanguage
	Push $0
	ClearErrors
	${ReadUserConfig} $0 Language
	${If} $0 != ""
	${AndIf} ${FileExists} `${EEKBIN}\Languages\$0.lng`
		${SetEnvironmentVariable} PAL:LanguageCustom $0
	${EndIf}
	Pop $0
FunctionEnd

; Journals a service ($1) that doesn't exist yet: on rollback it is stopped,
; then deleted. One that exists already isn't ours and is left alone.
Function EEK_JournalService
	Push $0
	ClearErrors
	ReadRegStr $0 HKLM `${SVCKEY}\$1` ImagePath
	${If} ${Errors}
		; 1060: the service doesn't exist (Emergency Kit removed it already).
		; 1072: it is marked for deletion already.
		${Journal::Record} EEK CMD `"$SYSDIR\sc.exe" delete $1` "0,1060,1072" admin ""
		${Journal::Record} EEK SVCSTOP $1 30 "" ""
	${EndIf}
	Pop $0
FunctionEnd

; Journals HKLM\SOFTWARE\Emsisoft in one registry view ($1 = 64 or 32) when
; it doesn't exist yet.
Function EEK_JournalKey
	Push $0
	${If} $1 == 64
		SetRegView 64
	${Else}
		SetRegView 32
	${EndIf}
	${Journal::RegKeyExists} HKLM `${EMSIKEY}` $0
	SetRegView lastused
	${If} $0 != 1
		${Journal::Record} EEK REGKEY HKLM `${EMSIKEY}` "" $1
	${EndIf}
	Pop $0
FunctionEnd

Function EEK_Journal
	Push $0
	Push $1
	; The driver file comes first, so it is removed last, after the service
	; that uses it has been stopped and deleted. The launcher is a 32-bit
	; program, so the real System32 is reached through Sysnative.
	${If} ${FileExists} `$WINDIR\Sysnative\*.*`
		StrCpy $0 `$WINDIR\Sysnative\drivers\epp.sys`
	${Else}
		StrCpy $0 `$WINDIR\System32\drivers\epp.sys`
	${EndIf}
	${IfNot} ${FileExists} $0
		${Journal::Record} EEK FILE $0 "" "" ""
	${EndIf}
	StrCpy $1 epp
	Call EEK_JournalService
	StrCpy $1 a2service
	Call EEK_JournalService
	StrCpy $1 64
	Call EEK_JournalKey
	StrCpy $1 32
	Call EEK_JournalKey
	ReadEnvStr $0 ProgramData
	${If} $0 != ""
	${AndIfNot} ${FileExists} `$0\Emsisoft\*.*`
		${Journal::Record} EEK DIR `$0\Emsisoft` "" recursive ""
	${EndIf}
	Pop $1
	Pop $0
FunctionEnd

; Writes the version of a2emergencykit.exe to appinfo.ini, so the Platform
; shows the version Emergency Kit has updated itself to.
Function EEK_WriteVersion
	Push $0
	Push $1
	Push $2
	Push $3
	Push $4
	Push $5
	ClearErrors
	GetDllVersion `${EEKEXE}` $0 $1
	${IfNot} ${Errors}
		IntOp $2 $0 >> 16
		IntOp $2 $2 & 0xFFFF
		IntOp $3 $0 & 0xFFFF
		IntOp $4 $1 >> 16
		IntOp $4 $4 & 0xFFFF
		IntOp $5 $1 & 0xFFFF
		StrCpy $0 `$2.$3.$4.$5`
		ReadINIStr $1 `${EEKINFO}` Version PackageVersion
		${If} $0 != $1
		${AndIf} $2 > 0
			WriteINIStr `${EEKINFO}` Version PackageVersion $0
			WriteINIStr `${EEKINFO}` Version DisplayVersion $0
		${EndIf}
	${EndIf}
	Pop $5
	Pop $4
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Hooks

${SegmentFile}

${Segment.OnInit}
	Call EEK_Refuse32
	Call EEK_ReadSwitch
!macroend

; Language segment, Init: runs before the Platform's language is looked up.
; The Variables segment sets PAL:AppDir and PAL:DataDir later, in PrePrimary,
; but [Language] CheckIfExists and [LanguageFile] use them now, so they are
; set here first (to the same values).
!macro LangInit
	${SetEnvironmentVariable} PAL:AppDir `$EXEDIR\App`
	${SetEnvironmentVariable} PAL:DataDir `$EXEDIR\Data`
	Call EEK_UserLanguage
!macroend

; Init, primary instance only: runs before the default data is copied and
; before the executable is looked for.
${SegmentInit}
	Call EEK_Migrate
!macroend

; InstanceManagement segment, Init, right before the executable is checked:
; /CLScanner runs the command line scanner's menu instead.
!macro EXE
	${If} $EekCLScanner == true
		StrCpy $ProgramExecutable `${EEKCMD}`
	${EndIf}
!macroend

; ExecString segment: the switch was for the launcher, not the scanner.
!macro ParseParameters
	Call EEK_StripSwitch
!macroend

${SegmentPrePrimary}
	Call EEK_Journal
!macroend

${SegmentPostPrimary}
	${Journal::HasEntries} EEK $R0
	${If} $R0 > 0
		${Journal::Rollback} EEK
	${EndIf}
	Call EEK_WriteVersion
!macroend
