; Bearsampp Portable custom code for PortableApps Compiler.
; For support, visit the GitHub project:
; https://github.com/daemondevin/pac-man
;
; Bearsampp is already built to run from any folder: it keeps its sites,
; databases, settings and logs in its own folder, and updates the paths in its
; configuration when that folder moves. What it does to Windows is what this
; file takes care of. Each of these is recorded before Bearsampp starts, so
; it is undone when Bearsampp quits, or on the next launch after a crash:
;
;   Services     Bearsampp installs Apache, MySQL, MariaDB, PostgreSQL,
;                Mailpit, Memcached and Xlight as Windows services
;                (bearsampp<name>). It removes them itself when it quits;
;                services that weren't there before are also stopped and
;                deleted by the journal, in case it didn't get that far.
;   Environment  Bearsampp sets BEARSAMPP_PATH and BEARSAMPP_BINS in the
;                machine environment and puts %BEARSAMPP_BINS% at the front of
;                the machine PATH. Both variables get their previous values
;                back (or are removed), and the PATH entry is taken out again
;                when PATH didn't have it before. Nothing else in PATH is
;                touched, even when another program changes PATH meanwhile.
;   Startup      The "launch on startup" option puts Bearsampp.lnk in the
;                user's Startup folder. A portable copy can't start from a
;                drive that isn't there, so the shortcut is removed again.
;   Root CA      Bearsampp makes its own development root certificate
;                (ssl\rootCA.pem) with mkcert, and offers to trust it so that
;                https://localhost works in the browser. When it wasn't
;                trusted before, it is removed from the user's trusted roots
;                again (Windows asks to confirm). KeepRootCA=true in
;                BearsamppPortable.ini leaves it trusted on this computer.
;
; Updates      With UpdateCheck=true, the launcher compares Bearsampp's
;              version with the latest release on GitHub before Bearsampp
;              starts. An update replaces Bearsampp itself (bearsampp.exe, its
;              tray menu files and the core folder) and nothing else: the
;              Apache, PHP, database and tool versions you have stay, along
;              with your sites, databases, settings and certificates. Bearsampp
;              adds newer module versions itself (QuickPick in its menu). The
;              release is downloaded and checked against its SHA-256
;              checksum, unpacked next to the current version, and swapped in;
;              a failed or interrupted update keeps the version you had.

; Variables
Var BspKB
Var BspLocal
Var BspTag
Var BspFailed
Var BspSwapped
Var BspPS
Var BspStore
Var DlWindow
Var DlLabel
Var DlBar
Var DlMsg
Var DlShown
Var DlText

; Defines
!define BSP         `$EXEDIR\App\Bearsampp`
!define BSPUPD      `$EXEDIR\App\Bearsampp-update`
!define CURL        `$SYSDIR\curl.exe`
!define ENVKEY      `SYSTEM\CurrentControlSet\Control\Session Manager\Environment`
!define SVCKEY      `SYSTEM\CurrentControlSet\Services`
!define RELEASES    `https://github.com/Bearsampp/Bearsampp/releases`
!define ROOTCA      `${BSP}\ssl\rootCA.pem`
!define STARTUPLNK  `$SMSTARTUP\Bearsampp.lnk`
!define SERVICES    `bearsamppapache bearsamppmysql bearsamppmariadb bearsampppostgresql bearsamppmailpit bearsamppmemcached bearsamppxlight`
!define /ifndef HWND_BROADCAST 0xFFFF
!define /ifndef WM_SETTINGCHANGE 0x001A

; Functions

; Windows

Function BSP_Refuse32
	!ifndef BSP_TEST
		${If} $Arch == x86
			MessageBox MB_ICONSTOP|MB_TOPMOST "Bearsampp needs 64-bit Windows.$\r$\n$\r$\n${PORTABLEAPPNAME} can't run on this computer."
			Quit
		${EndIf}
	!endif
FunctionEnd

; Tells running programs that the environment changed, so new command
; prompts see Bearsampp's variables (or no longer see them).
Function BSP_Broadcast
	SendMessage ${HWND_BROADCAST} ${WM_SETTINGCHANGE} 0 "STR:Environment" /TIMEOUT=2000
FunctionEnd

; Small text helpers

; Sets $0 to "true" when string $1 contains $2 (not case-sensitive).
Function BSP_Contains
	Push $3
	Push $4
	Push $5
	Push $R9
	StrCpy $0 false
	StrLen $3 $2
	StrLen $4 $1
	${If} $3 > 0
		IntOp $4 $4 - $3
		${ForEach} $5 0 $4 + 1
			StrCpy $R9 $1 $3 $5
			${If} $R9 == $2
				StrCpy $0 true
				${ExitFor}
			${EndIf}
		${Next}
	${EndIf}
	Pop $R9
	Pop $5
	Pop $4
	Pop $3
FunctionEnd

; Sets $0 to $0 without the spaces, tabs and line breaks around it.
Function BSP_Trim
	Push $1
	${Do}
		StrCpy $1 $0 1
		${If} $1 == " "
		${OrIf} $1 == "$\t"
		${OrIf} $1 == "$\r"
		${OrIf} $1 == "$\n"
			StrCpy $0 $0 "" 1
		${Else}
			${ExitDo}
		${EndIf}
	${Loop}
	${Do}
		StrCpy $1 $0 1 -1
		${If} $1 == " "
		${OrIf} $1 == "$\t"
		${OrIf} $1 == "$\r"
		${OrIf} $1 == "$\n"
			StrCpy $0 $0 -1
		${Else}
			${ExitDo}
		${EndIf}
	${Loop}
	Pop $1
FunctionEnd

; Machine environment

; Records how to put machine environment variable $1 back the way it is
; now: its value with its real registry type, or "" when there is none. A
; type the journal can't write back is left alone.
Function BSP_JournalEnv
	Push $0
	Push $2
	Push $3
	; RRF_RT_ANY | RRF_NOEXPAND: only ask for the type.
	System::Call `advapi32::RegGetValueW(p 0x80000002, w "${ENVKEY}", w r1, i 0x1000FFFF, *i .r2, p 0, p 0) i .r0`
	${If} $0 <> 0
		StrCpy $3 ""
	${Else}
		ReadRegStr $3 HKLM `${ENVKEY}` $1
		${If} $2 = 1
			StrCpy $3 `STR:$3`
		${ElseIf} $2 = 2
			StrCpy $3 `EXP:$3`
		${Else}
			${DebugMsg} "$1 has a registry type that can't be restored; left alone."
			Goto BSP_JournalEnv_End
		${EndIf}
	${EndIf}
	${Journal::Record} Bearsampp REGVALUE HKLM `${ENVKEY}` $1 $3
	BSP_JournalEnv_End:
	Pop $3
	Pop $2
	Pop $0
FunctionEnd

; Journals the machine PATH entry Bearsampp adds, when PATH doesn't have it
; yet. The undo is a script in the journal store, so it still works when
; the portable drive is gone.
Function BSP_JournalPath
	Push $0
	Push $1
	Push $2
	ReadRegStr $1 HKLM `${ENVKEY}` Path
	StrCpy $2 `%BEARSAMPP_BINS%`
	Call BSP_Contains
	${If} $0 != true
	${AndIf} ${FileExists} $BspPS
		File `/oname=$BspStore\BearsamppPathClean.ps1` `${PACKAGE}\App\AppInfo\Launcher\BearsamppPathClean.ps1`
		${Journal::Record} Bearsampp CMD `"$BspPS" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$BspStore\BearsamppPathClean.ps1"` 0 admin ""
	${EndIf}
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Services

; Journals service $1 for removal when it doesn't exist yet: stopped first,
; then deleted (the undo runs newest first). A service that already exists
; belongs to someone else and is left to Bearsampp, which repoints it.
Function BSP_JournalService
	Push $0
	ClearErrors
	ReadRegStr $0 HKLM `${SVCKEY}\$1` ImagePath
	${If} ${Errors}
		; 1060: the service doesn't exist (Bearsampp removed it already).
		${Journal::Record} Bearsampp CMD `"$SYSDIR\sc.exe" delete $1` "0,1060,1072" admin ""
		${Journal::Record} Bearsampp SVCSTOP $1 30 "" ""
	${EndIf}
	Pop $0
FunctionEnd

Function BSP_JournalServices
	Push $1
	Push $2
	Push $3
	StrCpy $2 `${SERVICES} `
	${Do}
		; Pop the first space-separated name off the list.
		StrCpy $3 0
		${Do}
			StrCpy $1 $2 1 $3
			${IfThen} $1 == " " ${|} ${ExitDo} ${|}
			${IfThen} $1 == "" ${|} ${ExitDo} ${|}
			IntOp $3 $3 + 1
		${Loop}
		StrCpy $1 $2 $3
		IntOp $3 $3 + 1
		StrCpy $2 $2 "" $3
		${If} $1 != ""
			Call BSP_JournalService
		${EndIf}
	${LoopUntil} $2 == ""
	Pop $3
	Pop $2
	Pop $1
FunctionEnd

; Startup shortcut

Function BSP_JournalStartup
	${IfNot} ${FileExists} `${STARTUPLNK}`
		${Journal::Record} Bearsampp FILE `${STARTUPLNK}` "" "" ""
	${EndIf}
FunctionEnd

; Root certificate

; Journals the removal of Bearsampp's root certificate from the user's
; trusted roots, unless it is trusted already or KeepRootCA=true. A copy of
; rootCA.pem goes to the journal store, so the undo works without the
; portable drive; the copy in the package is removed too, which also covers
; a new root certificate Bearsampp makes during the session.
Function BSP_JournalRootCA
	Push $0
	Push $1
	${ReadUserConfig} $0 KeepRootCA
	${If} $0 == true
	${OrIfNot} ${FileExists} $BspPS
		Goto BSP_JournalRootCA_End
	${EndIf}
	File `/oname=$BspStore\BearsamppRootCA.ps1` `${PACKAGE}\App\AppInfo\Launcher\BearsamppRootCA.ps1`
	StrCpy $1 ""
	${If} ${FileExists} `${ROOTCA}`
		nsExec::ExecToStack `"$BspPS" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$BspStore\BearsamppRootCA.ps1" check "${ROOTCA}"`
		Pop $0
		Pop $1
		${If} $0 == 1
			${DebugMsg} "Bearsampp's root certificate is trusted already; left alone."
			Goto BSP_JournalRootCA_End
		${EndIf}
		CopyFiles /SILENT `${ROOTCA}` `$BspStore\rootCA.pem`
		; Trusted at the end of the last session: trust it again for this one.
		; Bearsampp itself only asks when it makes a new root certificate.
		${ReadSettings} $0 RootCATrusted
		${If} $0 == true
		${AndIf} ${FileExists} `${BSP}\core\libs\mkcert\mkcert.exe`
			${Journal::Record} Bearsampp CMD `"$BspPS" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$BspStore\BearsamppRootCA.ps1" remove "$BspStore\rootCA.pem" "${ROOTCA}"` 0 "" ""
			System::Call `kernel32::SetEnvironmentVariable(t "CAROOT", t "${BSP}\ssl")`
			nsExec::ExecToStack `"${BSP}\core\libs\mkcert\mkcert.exe" -install`
			Pop $0
			Pop $1
			System::Call `kernel32::SetEnvironmentVariable(t "CAROOT", p 0)`
			Goto BSP_JournalRootCA_End
		${EndIf}
	${EndIf}
	${Journal::Record} Bearsampp CMD `"$BspPS" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$BspStore\BearsamppRootCA.ps1" remove "$BspStore\rootCA.pem" "${ROOTCA}"` 0 "" ""
	BSP_JournalRootCA_End:
	Pop $1
	Pop $0
FunctionEnd

; Notes whether Bearsampp's root certificate is trusted now, at the end of
; the session, before the journal removes it again: the next session then
; trusts it again on its own. Only after a session that ran (crash cleanup
; has nothing to go on).
Function BSP_RememberRootCA
	Push $0
	Push $1
	${If} $BspPS != ""
	${AndIf} ${FileExists} $BspPS
	${AndIf} ${FileExists} `$BspStore\BearsamppRootCA.ps1`
	${AndIf} ${FileExists} `${ROOTCA}`
		nsExec::ExecToStack `"$BspPS" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$BspStore\BearsamppRootCA.ps1" check "${ROOTCA}"`
		Pop $0
		Pop $1
		${If} $0 == 1
			${WriteSettings} true RootCATrusted
		${ElseIf} $0 == 0
			${WriteSettings} false RootCATrusted
		${EndIf}
	${EndIf}
	Pop $1
	Pop $0
FunctionEnd

; Updates: progress window and download

; Opens the download window: the banner, made wider, with a progress bar
; under its text. The bar belongs to this thread, so BSP_Pump has to run
; while the download is waiting, or it would never be drawn.
Function BSP_ProgressOpen
	Push $0
	Push $1
	Push $2
	Push $3
	Push $4
	Push $5
	Push $6
	Push $7
	Push $8
	Push $9
	Push $R8
	Push $R9
	Banner::show "$DlText"
	Banner::getWindow
	Pop $DlWindow
	GetDlgItem $DlLabel $DlWindow 1030
	StrCpy $DlShown ""
	System::Call 'comctl32::InitCommonControls()'
	System::Call '*(i,i,i,i) p .r0'
	System::Call 'user32::GetWindowRect(p $DlWindow, p r0)'
	System::Call '*$0(i .r1, i .r2, i .r3, i .r4)'
	System::Call 'user32::GetWindowRect(p $DlLabel, p r0)'
	System::Call 'user32::MapWindowPoints(p 0, p $DlWindow, p r0, i 2)'
	System::Call '*$0(i .r5, i .r6, i .r7, i .r8)'
	System::Free $0
	; Sizes come from the label, so they follow the DPI the banner uses:
	; the bar is as tall as the label, with half that as the gap above it,
	; and both are made half as wide again.
	IntOp $9 $7 - $5
	IntOp $0 $8 - $6
	IntOp $R9 $0 / 2
	IntOp $R8 $9 / 2
	IntOp $9 $9 + $R8
	; The window grows by the same amounts and stays centred where it was.
	IntOp $3 $3 - $1
	IntOp $3 $3 + $R8
	IntOp $4 $4 - $2
	IntOp $4 $4 + $0
	IntOp $4 $4 + $R9
	IntOp $7 $R8 / 2
	IntOp $1 $1 - $7
	IntOp $7 $0 + $R9
	IntOp $7 $7 / 2
	IntOp $2 $2 - $7
	; SWP_NOZORDER|SWP_NOACTIVATE
	System::Call 'user32::SetWindowPos(p $DlWindow, p 0, i r1, i r2, i r3, i r4, i 0x14)'
	; SWP_NOMOVE|SWP_NOZORDER|SWP_NOACTIVATE
	System::Call 'user32::SetWindowPos(p $DlLabel, p 0, i 0, i 0, i r9, i r0, i 0x16)'
	IntOp $8 $8 + $R9
	; WS_CHILD|WS_VISIBLE, PBS_SMOOTH
	System::Call 'user32::CreateWindowExW(i 0, w "msctls_progress32", w "", i 0x50000001, i r5, i r8, i r9, i r0, p $DlWindow, p 0, p 0, p 0) p .s'
	Pop $DlBar
	${If} $BspKB > 0
		; PBM_SETRANGE32 0 to 100
		SendMessage $DlBar 0x406 0 100
	${Else}
		; Size unknown: a marquee (PBS_MARQUEE, PBM_SETMARQUEE).
		System::Call 'user32::GetWindowLongW(p $DlBar, i -16) i .r1'
		IntOp $1 $1 | 0x08
		System::Call 'user32::SetWindowLongW(p $DlBar, i -16, i r1)'
		SendMessage $DlBar 0x40A 1 30
	${EndIf}
	System::Call '*(&i32) p .s'
	Pop $DlMsg
	Call BSP_Pump
	Pop $R9
	Pop $R8
	Pop $9
	Pop $8
	Pop $7
	Pop $6
	Pop $5
	Pop $4
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

Function BSP_ProgressClose
	${If} $DlBar != ""
		System::Call 'user32::DestroyWindow(p $DlBar)'
		StrCpy $DlBar ""
	${EndIf}
	${If} $DlMsg != ""
		System::Free $DlMsg
		StrCpy $DlMsg ""
	${EndIf}
	${If} $DlWindow != ""
		Banner::destroy
		StrCpy $DlWindow ""
	${EndIf}
FunctionEnd

; Shows plain text $0 in the banner, opening it when it isn't up yet.
Function BSP_Banner
	${If} $DlWindow == ""
		Banner::show ""
		Banner::getWindow
		Pop $DlWindow
		GetDlgItem $DlLabel $DlWindow 1030
	${EndIf}
	SendMessage $DlLabel ${WM_SETTEXT} 0 "STR:$0"
FunctionEnd

; Handles the messages waiting for this thread (the progress bar's).
Function BSP_Pump
	Push $0
	${Do}
		; PM_REMOVE
		System::Call 'user32::PeekMessageW(p $DlMsg, p 0, i 0, i 0, i 1) i .r0'
		${IfThen} $0 = 0 ${|} ${ExitDo} ${|}
		System::Call 'user32::TranslateMessage(p $DlMsg)'
		System::Call 'user32::DispatchMessageW(p $DlMsg)'
	${Loop}
	Pop $0
FunctionEnd

; Sets $0 to the size of file $1 in KB, or 0 when it isn't there. Works for
; files over 2 GB (the full edition is close to that).
Function BSP_SizeKB
	Push $2
	Push $3
	Push $4
	StrCpy $0 0
	System::Call '*(&i36) p .r2'
	System::Call 'kernel32::GetFileAttributesExW(w r1, i 0, p r2) i .r3'
	${If} $3 <> 0
		; nFileSizeHigh at 28, nFileSizeLow at 32.
		System::Call '*$2(&i28, i .r3, i .r4)'
		System::Int64Op $3 << 32
		Pop $3
		; The low part is unsigned.
		System::Int64Op $4 & 0xFFFFFFFF
		Pop $4
		System::Int64Op $3 + $4
		Pop $3
		System::Int64Op $3 / 1024
		Pop $0
	${EndIf}
	System::Free $2
	Pop $4
	Pop $3
	Pop $2
FunctionEnd

; Shows $0 KB downloaded: "45%  (390.2 / 868.7 MB)", or "390.2 MB" when the
; size is unknown. The text only changes when the numbers do.
Function BSP_ProgressSet
	Push $1
	Push $2
	Push $3
	Push $4
	; Tenths of a MB.
	IntOp $2 $0 * 10
	IntOp $2 $2 / 1024
	IntOp $3 $2 % 10
	IntOp $2 $2 / 10
	StrCpy $2 `$2.$3`
	${If} $BspKB > 0
		System::Int64Op $0 * 100
		Pop $4
		System::Int64Op $4 / $BspKB
		Pop $4
		${IfThen} $4 > 100 ${|} StrCpy $4 100 ${|}
		IntOp $3 $BspKB * 10
		IntOp $3 $3 / 1024
		IntOp $1 $3 % 10
		IntOp $3 $3 / 10
		StrCpy $3 `$4%  ($2 / $3.$1 MB)`
		SendMessage $DlBar 0x402 $4 0
	${Else}
		StrCpy $3 `$2 MB`
	${EndIf}
	${If} $3 != $DlShown
		StrCpy $DlShown $3
		SendMessage $DlLabel ${WM_SETTEXT} 0 `STR:$DlText  $3`
	${EndIf}
	Pop $4
	Pop $3
	Pop $2
	Pop $1
FunctionEnd

; Downloads URL $2 to file $1 with curl, showing $DlText and the progress
; ($BspKB is the expected size in KB, 0 when unknown). Sets $0 to curl's
; exit code, or -1 when curl could not be started or nothing arrived.
Function BSP_Fetch
	Push $3
	Push $4
	Push $5
	Push $6
	Push $7
	Call BSP_ProgressClose
	Delete $1
	Call BSP_ProgressOpen
	StrCpy $0 -1
	StrCpy $7 `"${CURL}" -fsSL --retry 3 -o "$1" "$2"`
	System::Call '*(i 68, &i64) p .r3'
	System::Call '*(&i16) p .r4'
	; CREATE_NO_WINDOW
	System::Call 'kernel32::CreateProcessW(p 0, w r7, p 0, p 0, i 0, i 0x08000000, p 0, p 0, p r3, p r4) i .r5'
	${If} $5 <> 0
		System::Call '*$4(p .r5, p .r6)'
		System::Call 'kernel32::CloseHandle(p r6)'
		${Do}
			System::Call 'kernel32::WaitForSingleObject(p r5, i 200) i .r6'
			Call BSP_Pump
			Call BSP_SizeKB
			Call BSP_ProgressSet
		${LoopWhile} $6 <> 0
		System::Call 'kernel32::GetExitCodeProcess(p r5, *i .r0)'
		System::Call 'kernel32::CloseHandle(p r5)'
	${EndIf}
	System::Free $3
	System::Free $4
	Call BSP_ProgressClose
	${If} $0 = 0
	${AndIfNot} ${FileExists} $1
		StrCpy $0 -1
	${EndIf}
	Pop $7
	Pop $6
	Pop $5
	Pop $4
	Pop $3
FunctionEnd

; Updates: release

; Sets $BspTag to the tag of the latest Bearsampp release ("2026.10.13"), or
; "" when GitHub can't be reached. GitHub redirects .../releases/latest to
; .../releases/tag/<tag>, so no JSON has to be read.
Function BSP_LatestTag
	Push $0
	Push $1
	Push $2
	Push $3
	StrCpy $BspTag ""
	nsExec::ExecToStack `"${CURL}" -fsS -o NUL -w "%{redirect_url}" "${RELEASES}/latest"`
	Pop $0
	Pop $1
	${If} $0 == 0
		; Everything after the last "/tag/".
		StrLen $2 $1
		${Do}
			IntOp $2 $2 - 1
			${IfThen} $2 < 0 ${|} ${ExitDo} ${|}
			StrCpy $3 $1 5 $2
			${If} $3 == "/tag/"
				IntOp $2 $2 + 5
				StrCpy $BspTag $1 "" $2
				${ExitDo}
			${EndIf}
		${Loop}
		; Only digits and dots: anything else isn't a release tag.
		StrLen $2 $BspTag
		IntOp $2 $2 - 1
		${ForEach} $3 0 $2 + 1
			StrCpy $0 $BspTag 1 $3
			${If} $0 != "."
			${AndIf} $0 != "0"
			${AndIf} $0 != "1"
			${AndIf} $0 != "2"
			${AndIf} $0 != "3"
			${AndIf} $0 != "4"
			${AndIf} $0 != "5"
			${AndIf} $0 != "6"
			${AndIf} $0 != "7"
			${AndIf} $0 != "8"
			${AndIf} $0 != "9"
				StrCpy $BspTag ""
				${ExitFor}
			${EndIf}
		${Next}
	${EndIf}
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Sets $0 to Bearsampp's own version (core\resources\version.dat), or "".
Function BSP_LocalVersion
	Push $1
	StrCpy $0 ""
	ClearErrors
	FileOpen $1 `${BSP}\core\resources\version.dat` r
	${IfNot} ${Errors}
		FileRead $1 $0
		FileClose $1
		Call BSP_Trim
	${EndIf}
	Pop $1
FunctionEnd

; Sets $1 to the archive name of the edition in UpdateEdition= (lite,
; basic or full; lite when it is anything else) for release $BspTag.
Function BSP_Archive
	Push $0
	${ReadUserConfig} $0 UpdateEdition
	${If} $0 == full
		StrCpy $1 `Bearsampp-$BspTag.7z`
	${ElseIf} $0 == basic
		StrCpy $1 `Bearsampp-basic-$BspTag.7z`
	${Else}
		StrCpy $1 `Bearsampp-lite-$BspTag.7z`
	${EndIf}
	Pop $0
FunctionEnd

; Sets $BspKB to the size of URL $2 in KB from its Content-Length, or 0
; when it can't be had (the bar then shows activity instead of a percentage).
Function BSP_RemoteKB
	Push $0
	Push $1
	StrCpy $BspKB 0
	nsExec::ExecToStack `"${CURL}" -fsSIL -o NUL -w "%header{content-length}" "$2"`
	Pop $1
	Pop $0
	${If} $1 == 0
		Call BSP_Trim
		System::Int64Op $0 / 1024
		Pop $BspKB
		${IfThen} $BspKB < 0 ${|} StrCpy $BspKB 0 ${|}
	${EndIf}
	Pop $1
	Pop $0
FunctionEnd

; Checks archive $1 against the SHA-256 in file $2 (the release's own
; .sha256 file). Sets $0 to true when they match. certutil's other output
; is localized, but the hash itself is plain hex in every language.
Function BSP_Verify
	Push $3
	Push $4
	StrCpy $0 false
	ClearErrors
	FileOpen $3 $2 r
	${IfNot} ${Errors}
		FileRead $3 $4
		FileClose $3
		StrCpy $4 $4 64
		StrLen $3 $4
		${If} $3 = 64
			Push $1
			Push $2
			nsExec::ExecToStack `"$SYSDIR\certutil.exe" -hashfile "$1" SHA256`
			Pop $3
			Pop $1
			${If} $3 == 0
				StrCpy $2 $4
				Call BSP_Contains
			${EndIf}
			Pop $2
			Pop $1
		${EndIf}
	${EndIf}
	Pop $4
	Pop $3
FunctionEnd

; Updates: swap

; The files of Bearsampp itself that an update replaces, next to the core
; folder. Everything else in App\Bearsampp is left alone.
!define BSPFILES    `bearsampp.exe bearsampp.ini bar.dat sprites.dat favicon.ico LICENSE `

; Calls function _FUNC once for every name in ${BSPFILES}, with the name in
; $1.
!define BSP::EachFile "!insertmacro _BSP::EachFile"
!macro _BSP::EachFile _FUNC
	Push $2
	Push $3
	StrCpy $2 `${BSPFILES}`
	${Do}
		StrCpy $3 0
		${Do}
			StrCpy $1 $2 1 $3
			${IfThen} $1 == " " ${|} ${ExitDo} ${|}
			${IfThen} $1 == "" ${|} ${ExitDo} ${|}
			IntOp $3 $3 + 1
		${Loop}
		StrCpy $1 $2 $3
		IntOp $3 $3 + 1
		StrCpy $2 $2 "" $3
		${If} $1 != ""
			Call ${_FUNC}
		${EndIf}
	${LoopUntil} $2 == ""
	Pop $3
	Pop $2
!macroend

; Swaps the new copy of file $1 in. Moving the current one aside is the
; backup, and it is journaled straight away, so from then on a failure or a
; crash puts it back.
Function BSP_SwapFile
	${IfThen} $BspFailed != "" ${|} Return ${|}
	${IfNot} ${FileExists} `${BSPUPD}\new\$1`
		Return
	${EndIf}
	${If} ${FileExists} `${BSP}\$1`
		ClearErrors
		Rename `${BSP}\$1` `${BSP}\$1.backup`
		${If} ${Errors}
			StrCpy $BspFailed "$1 is in use and can't be replaced. Quit Bearsampp (from its tray icon), then try again."
			Return
		${EndIf}
		${Journal::Record} BearsamppUpdate FILE `${BSP}\$1` `${BSP}\$1.backup` "" ""
	${Else}
		${Journal::Record} BearsamppUpdate FILE `${BSP}\$1` "" "" ""
	${EndIf}
	IntOp $BspSwapped $BspSwapped + 1
	ClearErrors
	Rename `${BSPUPD}\new\$1` `${BSP}\$1`
	${If} ${Errors}
		StrCpy $BspFailed "The new $1 couldn't be moved into place."
	${EndIf}
FunctionEnd

Function BSP_SwapCore
	${IfThen} $BspFailed != "" ${|} Return ${|}
	ClearErrors
	Rename `${BSP}\core` `${BSP}\core-backup`
	${If} ${Errors}
		StrCpy $BspFailed "The core folder is in use and can't be replaced. Quit Bearsampp (from its tray icon), then try again."
		Return
	${EndIf}
	${Journal::Record} BearsamppUpdate DIR `${BSP}\core` `${BSP}\core-backup` recursive ""
	IntOp $BspSwapped $BspSwapped + 1
	ClearErrors
	Rename `${BSPUPD}\new\core` `${BSP}\core`
	${If} ${Errors}
		StrCpy $BspFailed "The new core folder couldn't be moved into place."
	${EndIf}
FunctionEnd

Function BSP_DropBackupFile
	Delete `${BSP}\$1.backup`
FunctionEnd

; Puts Bearsampp back after an update that was interrupted between moving a
; file aside and journaling it. When the new copy made it into place, the
; leftover backup is deleted; when it didn't, the backup goes back.
Function BSP_RepairFile
	${If} ${FileExists} `${BSP}\$1.backup`
		${If} ${FileExists} `${BSP}\$1`
			Delete `${BSP}\$1.backup`
		${Else}
			Rename `${BSP}\$1.backup` `${BSP}\$1`
		${EndIf}
	${EndIf}
FunctionEnd

Function BSP_Repair
	Push $0
	Push $1
	${Journal::HasEntries} BearsamppUpdate $0
	${If} $0 > 0
		${Journal::Rollback} BearsamppUpdate
	${EndIf}
	${If} ${FileExists} `${BSP}\core-backup\*.*`
		${If} ${FileExists} `${BSP}\core\root.php`
			RMDir /r `${BSP}\core-backup`
		${Else}
			RMDir /r `${BSP}\core`
			Rename `${BSP}\core-backup` `${BSP}\core`
		${EndIf}
	${EndIf}
	${BSP::EachFile} BSP_RepairFile
	RMDir /r `${BSPUPD}`
	Pop $1
	Pop $0
FunctionEnd

; Updates: the whole update

; Writes Bearsampp's version into appinfo.ini, so the PortableApps.com
; Platform shows the version that runs.
Function BSP_WriteVersion
	Push $0
	Push $1
	Push $2
	Push $3
	Push $R9
	Call BSP_LocalVersion
	${If} $0 != ""
		WriteINIStr `$EXEDIR\App\AppInfo\appinfo.ini` Version DisplayVersion $0
		; PackageVersion needs four numbers.
		StrCpy $1 0
		StrLen $2 $0
		${ForEach} $3 0 $2 + 1
			StrCpy $R9 $0 1 $3
			${IfThen} $R9 == "." ${|} IntOp $1 $1 + 1 ${|}
		${Next}
		${If} $1 = 2
			StrCpy $0 `$0.0`
		${EndIf}
		WriteINIStr `$EXEDIR\App\AppInfo\appinfo.ini` Version PackageVersion $0
	${EndIf}
	Pop $R9
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Checks for a newer Bearsampp and, if the user agrees, updates it.
Function BSP_Update
	Push $0
	Push $1
	Push $2
	Push $3
	${ReadUserConfig} $0 UpdateCheck
	${If} $0 == false
		Goto update_done
	${EndIf}
	; An earlier update that couldn't be undone yet is retried by the
	; journal; don't start another one.
	${Journal::HasEntries} BearsamppUpdate $0
	${If} $0 > 0
		Goto update_done
	${EndIf}
	${IfNot} ${FileExists} `${CURL}`
		Goto update_done
	${EndIf}

	Call BSP_LatestTag
	${If} $BspTag == ""
		; Offline, or GitHub didn't answer: just start Bearsampp.
		Goto update_done
	${EndIf}
	Call BSP_LocalVersion
	StrCpy $BspLocal $0
	${If} $BspLocal != ""
		${VersionCompare} $BspTag $BspLocal $1
		${If} $1 != 1
			Goto update_done
		${EndIf}
	${Else}
		StrCpy $BspLocal "an unknown version"
	${EndIf}
	Call BSP_Archive
	StrCpy $2 `${RELEASES}/download/$BspTag/$1`
	Call BSP_RemoteKB
	; The archive lands next to Bearsampp, on the same drive, so the new
	; files are moved into place, not copied.
	StrCpy $3 0
	${If} $BspKB > 0
		System::Call 'kernel32::GetDiskFreeSpaceExW(w "$EXEDIR", *l .r0, p 0, p 0) i .r3'
		System::Int64Op $0 / 1048576
		Pop $0
		IntOp $3 $BspKB / 1024
		; Room for the archive plus the unpacked core.
		IntOp $3 $3 + 600
		${If} $0 < $3
			MessageBox MB_ICONEXCLAMATION|MB_TOPMOST "Bearsampp $BspTag is available, but the update needs about $3 MB free on this drive and there are only $0 MB.$\r$\n$\r$\nBearsampp starts without updating."
			Goto update_done
		${EndIf}
	${EndIf}
	MessageBox MB_USERICON|MB_YESNO|MB_TOPMOST "Bearsampp $BspTag is available (you have $BspLocal).$\r$\n$\r$\nThe update replaces Bearsampp itself. Your sites, databases, settings, certificates and the Apache, PHP, database and tool versions you have are kept.$\r$\n$\r$\nDo you want to download it now? ($1)" IDYES +2
	Goto update_done

	StrCpy $BspFailed ""
	RMDir /r `${BSPUPD}`
	CreateDirectory `${BSPUPD}`
	StrCpy $DlText "Downloading Bearsampp $BspTag.."
	StrCpy $3 $1
	StrCpy $1 `${BSPUPD}\$3`
	Call BSP_Fetch
	${If} $0 <> 0
		StrCpy $BspFailed "The download failed (curl exit code $0)."
		Goto update_failed
	${EndIf}
	StrCpy $0 "Checking the download.."
	Call BSP_Banner
	StrCpy $BspKB 0
	StrCpy $1 `${BSPUPD}\$3.sha256`
	StrCpy $2 `${RELEASES}/download/$BspTag/$3.sha256`
	nsExec::ExecToStack `"${CURL}" -fsSL -o "$1" "$2"`
	Pop $0
	Pop $0
	StrCpy $1 `${BSPUPD}\$3`
	StrCpy $2 `${BSPUPD}\$3.sha256`
	Call BSP_Verify
	${If} $0 != true
		StrCpy $BspFailed "The download doesn't match the release's SHA-256 checksum."
		Goto update_failed
	${EndIf}

	; Unpacked with the 7-Zip that comes with Bearsampp, copied out first
	; because its folder is about to be replaced.
	StrCpy $0 "Unpacking Bearsampp $BspTag.."
	Call BSP_Banner
	InitPluginsDir
	CopyFiles /SILENT `${BSP}\core\libs\7zip\*.*` `$PLUGINSDIR\7zip`
	${IfNot} ${FileExists} `$PLUGINSDIR\7zip\7za.exe`
		StrCpy $BspFailed "7-Zip wasn't found in Bearsampp's core\libs\7zip."
		Goto update_failed
	${EndIf}
	nsExec::ExecToStack `"$PLUGINSDIR\7zip\7za.exe" x "${BSPUPD}\$3" -o"${BSPUPD}\new" -y -bso0 -bsp0 core ${BSPFILES}`
	Pop $0
	Pop $1
	Delete `${BSPUPD}\$3`
	; The new copy has to be complete, and the version GitHub announced.
	ClearErrors
	FileOpen $1 `${BSPUPD}\new\core\resources\version.dat` r
	${IfNot} ${Errors}
		Push $0
		FileRead $1 $0
		FileClose $1
		Call BSP_Trim
		StrCpy $3 $0
		Pop $0
	${Else}
		StrCpy $3 ""
	${EndIf}
	${If} $0 <> 0
	${OrIfNot} ${FileExists} `${BSPUPD}\new\bearsampp.exe`
	${OrIfNot} ${FileExists} `${BSPUPD}\new\core\root.php`
	${OrIf} $3 != $BspTag
		StrCpy $BspFailed "The download couldn't be unpacked completely (7-Zip exit code $0)."
		Goto update_failed
	${EndIf}
	; Bearsampp's record of where it was last run from, so it knows whether
	; to update the paths in its configuration.
	CopyFiles /SILENT `${BSP}\core\resources\lastPath.dat` `${BSPUPD}\new\core\resources`

	StrCpy $0 "Installing Bearsampp $BspTag.."
	Call BSP_Banner
	StrCpy $BspSwapped 0
	Call BSP_SwapCore
	${BSP::EachFile} BSP_SwapFile
	${If} $BspFailed != ""
		${Journal::Rollback} BearsamppUpdate
		Goto update_failed
	${EndIf}

	; Commit. The entries go first: if the launcher stops before the backups
	; are deleted, BSP_Repair deletes them on the next launch.
	${DoWhile} $BspSwapped > 0
		${Journal::Discard} BearsamppUpdate
		IntOp $BspSwapped $BspSwapped - 1
	${Loop}
	${Journal::HasEntries} BearsamppUpdate $0
	${If} $0 == 0
		DeleteRegKey HKCU `${JOURNAL_KEY}\BearsamppUpdate`
	${EndIf}
	RMDir /r `${BSP}\core-backup`
	${BSP::EachFile} BSP_DropBackupFile
	RMDir /r `${BSPUPD}`
	Call BSP_WriteVersion
	Call BSP_ProgressClose
	MessageBox MB_ICONINFORMATION|MB_TOPMOST "Bearsampp has been updated to $BspTag.$\r$\n$\r$\nNow launching ${PORTABLEAPPNAME}."
	Goto update_done

	update_failed:
	Call BSP_ProgressClose
	RMDir /r `${BSPUPD}`
	MessageBox MB_ICONSTOP|MB_TOPMOST "The Bearsampp update failed. $BspFailed$\r$\n$\r$\nThe current version of Bearsampp was kept."

	update_done:
	Call BSP_ProgressClose
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Hooks

${SegmentFile}

${Segment.OnInit}
	Call BSP_Refuse32
!macroend

; InstanceManagement segment, Init, right before the executable is looked
; for: an update that was interrupted is put right first.
!macro EXE
	${If} $SecondaryLaunch != true
		Call BSP_Repair
	${EndIf}
!macroend

${SegmentPre}
	; Runs after crash recovery and after the journal session is open, and
	; before Bearsampp starts.
	${If} ${PrimaryInstance}
		Call BSP_Update
	${EndIf}
!macroend

${SegmentPrePrimary}
	StrCpy $BspPS `$SYSDIR\WindowsPowerShell\v1.0\powershell.exe`
	StrCpy $BspStore `${JOURNAL_STORE}\Bearsampp`
	CreateDirectory $BspStore
	StrCpy $1 BEARSAMPP_PATH
	Call BSP_JournalEnv
	StrCpy $1 BEARSAMPP_BINS
	Call BSP_JournalEnv
	Call BSP_JournalPath
	Call BSP_JournalStartup
	Call BSP_JournalServices
	Call BSP_JournalRootCA
!macroend

${SegmentPostPrimary}
	Call BSP_RememberRootCA
	${Journal::HasEntries} Bearsampp $R0
	${If} $R0 > 0
		${Journal::Rollback} Bearsampp
		Call BSP_Broadcast
	${EndIf}
!macroend
