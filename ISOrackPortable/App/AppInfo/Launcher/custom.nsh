; ISOrack Portable custom code for PortableApps Compiler.
; For support, visit the GitHub project:
; https://github.com/daemondevin/pac-man
;
; ISOrack is a Tauri app: one program file that shows its interface in
; WebView2, with GRUB, its boot tools and QEMU in folders next to it. Its
; folders are moved into Data by [DirectoriesMove] in the launcher INI. What
; this file adds:
;
;   WebView2   ISOrack needs the WebView2 Runtime. A copy in
;              App\WebView2 (the Fixed Version runtime) is used when it's
;              there; otherwise the installed one, and when there's none the
;              launcher says where to get it and stops before anything starts.
;   Closing    WebView2's own processes can hold its folder for a moment after
;              ISOrack closes. The launcher waits for them, so the folder can
;              be moved back to Data.
;   Version    The version that ran is written to appinfo.ini.

; Defines
!define IR_EXE       `$EXEDIR\App\ISOrack\isorack-app.exe`
!define IR_WV2       `$EXEDIR\App\WebView2`
!define IR_WV2_ID    `{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}`
!define IR_WV2_URL   `https://developer.microsoft.com/microsoft-edge/webview2/`
!define IR_LOCAL     `$LOCALAPPDATA\dev.isorack.app`

; $R0 = true when the WebView2 Runtime is installed, for the computer or for
; this user. A 32-bit process reads the 32-bit view of HKLM, which is where
; the runtime registers itself on 64-bit Windows too.
Function IR_WebView2Installed
	Push $0
	StrCpy $R0 false
	ClearErrors
	ReadRegStr $0 HKLM `SOFTWARE\Microsoft\EdgeUpdate\Clients\${IR_WV2_ID}` pv
	${If} $0 == ""
	${OrIf} $0 == "0.0.0.0"
		ReadRegStr $0 HKCU `Software\Microsoft\EdgeUpdate\Clients\${IR_WV2_ID}` pv
	${EndIf}
	${If} $0 != ""
	${AndIf} $0 != "0.0.0.0"
		StrCpy $R0 true
	${EndIf}
	ClearErrors
	Pop $0
FunctionEnd

; Uses the Fixed Version runtime in App\WebView2 when there is one, or else
; checks for an installed runtime.
Function IR_WebView2
	${If} ${FileExists} `${IR_WV2}\msedgewebview2.exe`
		System::Call `kernel32::SetEnvironmentVariable(t "WEBVIEW2_BROWSER_EXECUTABLE_FOLDER", t "${IR_WV2}")`
		Return
	${EndIf}
	Call IR_WebView2Installed
	${If} $R0 != true
		MessageBox MB_YESNO|MB_ICONEXCLAMATION|MB_TOPMOST \
			`${PORTABLEAPPNAME} needs the Microsoft Edge WebView2 Runtime, which isn't installed on this computer.$\r$\n$\r$\nInstall the Evergreen runtime from Microsoft, or put the Fixed Version runtime in this package's App\WebView2 folder.$\r$\n$\r$\nOpen the download page now?` \
			IDNO +2
		ExecShell open `${IR_WV2_URL}`
		Quit
	${EndIf}
FunctionEnd

; WebView2's browser process holds EBWebView\lockfile while it runs, and it
; can outlive ISOrack by a moment. The file can't be deleted while it's held,
; so the launcher tries for up to ten seconds; Chromium makes a new one on the
; next start.
Function IR_WaitForWebView2
	Push $0
	StrCpy $0 0
	${DoWhile} ${FileExists} `${IR_LOCAL}\EBWebView\lockfile`
		Delete `${IR_LOCAL}\EBWebView\lockfile`
		${IfThen} ${FileExists} `${IR_LOCAL}\EBWebView\lockfile` ${|} Sleep 250 ${|}
		IntOp $0 $0 + 1
		${IfThen} $0 >= 40 ${|} ${ExitDo} ${|}
	${Loop}
	ClearErrors
	Pop $0
FunctionEnd

; Writes the version of isorack-app.exe to appinfo.ini: 0.1.0.0 as
; PackageVersion, and 0.1.0 as DisplayVersion, the way Tauri numbers it.
Function IR_WriteVersion
	Push $0
	Push $1
	Push $2
	Push $3
	ClearErrors
	GetDllVersion `${IR_EXE}` $0 $1
	${IfNot} ${Errors}
		IntOp $2 $0 >> 16
		IntOp $2 $2 & 0xFFFF
		IntOp $3 $0 & 0xFFFF
		StrCpy $3 `$2.$3`
		IntOp $2 $1 >> 16
		IntOp $2 $2 & 0xFFFF
		StrCpy $3 `$3.$2`
		IntOp $2 $1 & 0xFFFF
		StrCpy $0 `$3.$2`
		ReadINIStr $1 `$EXEDIR\App\AppInfo\appinfo.ini` Version PackageVersion
		${If} $0 != $1
		${AndIf} $0 != "0.0.0.0"
			WriteINIStr `$EXEDIR\App\AppInfo\appinfo.ini` Version PackageVersion $0
			WriteINIStr `$EXEDIR\App\AppInfo\appinfo.ini` Version DisplayVersion $3
		${EndIf}
	${EndIf}
	ClearErrors
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Runs in Execute, once ISOrack has closed, before the folders move back.
!macro PostExecWaitCommand
	${If} $WaitForProgram != false
		Call IR_WaitForWebView2
	${EndIf}
!macroend

${SegmentFile}

; Init: nothing has been changed yet, so stopping here is clean.
${SegmentInit}
	Call IR_WebView2
!macroend

${SegmentPostPrimary}
	Call IR_WriteVersion
!macroend
