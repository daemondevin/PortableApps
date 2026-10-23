; WeBuilder Portable custom code for PortableApps Compiler.
; For support, visit the GitHub project:
; https://github.com/daemondevin/pac-man
;
; What lives here and why:
;   Tools      Firefox=, Chrome=, Opera= and DiffTool= in WeBuilderPortable.ini
;              point WeBuilder's preview browsers and diff tool at portable
;              copies. Each one that is set is written to WeBuilder's
;              settings (Data\config\settings.dat, in the section named in
;              [WeBuilderTools] in the launcher ini) before WeBuilder starts.
;              Empty ones are left alone, so whatever was set in WeBuilder
;              itself stays. %PAL:...% variables are expanded, so a path can
;              follow the drive the package is on.
;   Migration  Earlier packages moved App\WeBuilder\settings in and out of
;              Data\config. A settings folder left behind by a crash of such a
;              launcher holds the newest settings, so it is moved into
;              Data\config before the link is made.

; Functions

; Writes user setting $0 to settings.dat key $1 when it is set.
Function WB_Tool
	Push $2
	Push $3
	${ReadUserConfig} $2 $0
	${If} $2 != ""
		ExpandEnvStrings $2 $2
		${ReadLauncherConfig} $3 WeBuilderTools Section
		${If} $3 != ""
			CreateDirectory `$DataDirectory\config`
			WriteINIStr `$DataDirectory\config\settings.dat` $3 $1 $2
		${EndIf}
	${EndIf}
	Pop $3
	Pop $2
FunctionEnd

; Takes over a real App\WeBuilder\settings folder an earlier launcher left
; behind: its files replace Data\config, which is kept as config.old.
Function WB_Migrate
	Push $0
	Push $1
	StrCpy $0 `$EXEDIR\App\WeBuilder\settings`
	System::Call `kernel32::GetFileAttributes(t "$0") i .r1`
	${If} $1 <> -1
		IntOp $1 $1 & 0x400
		${If} $1 = 0
		${AndIfNot} ${FileExists} `$DataDirectory\config.old\*.*`
			${If} ${FileExists} `$DataDirectory\config\*.*`
				Rename `$DataDirectory\config` `$DataDirectory\config.old`
			${EndIf}
			CreateDirectory $DataDirectory
			ClearErrors
			Rename $0 `$DataDirectory\config`
			${If} ${Errors}
				${DebugMsg} "Could not take over $0."
				${If} ${FileExists} `$DataDirectory\config.old\*.*`
				${AndIfNot} ${FileExists} `$DataDirectory\config\*.*`
					Rename `$DataDirectory\config.old` `$DataDirectory\config`
				${EndIf}
			${EndIf}
		${EndIf}
	${EndIf}
	Pop $1
	Pop $0
FunctionEnd

; Hooks

${SegmentFile}

${SegmentPrePrimary}
	Call WB_Migrate
	StrCpy $0 Firefox
	StrCpy $1 FireFox
	Call WB_Tool
	StrCpy $0 Chrome
	StrCpy $1 Chrome
	Call WB_Tool
	StrCpy $0 Opera
	StrCpy $1 Opera
	Call WB_Tool
	StrCpy $0 DiffTool
	StrCpy $1 DiffPath
	Call WB_Tool
!macroend
