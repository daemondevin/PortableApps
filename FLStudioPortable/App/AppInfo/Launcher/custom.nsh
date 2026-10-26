; FL Studio Portable custom code for PortableApps Compiler.
; For support, visit the GitHub project:
; https://github.com/daemondevin/pac-man
;
; What lives here and why:
;   Windows    FL Studio is 64-bit only; the launcher says so on 32-bit
;              Windows instead of failing to start it.
;   Scaled     Scaled=true in FLStudioPortable.ini starts "FL64 (scaled).exe",
;              the build Windows scales up on high DPI screens.
;   Registry   FL Studio keeps its settings, and its registration, in
;              HKCU\Software\Image-Line (one subkey per FL Studio version, plus
;              keys Image-Line's tools share). The whole key travels with the
;              package in Data\settings\Image-Line.reg: it is imported for the
;              session and saved back when FL Studio closes, and whatever an
;              installed FL Studio had there is put back. The keys in
;              [FLStudioRegistry] in FLStudioPortable.ini are journaled the
;              same way, without being saved.
;   Migration  Earlier packages kept FL Studio's registry in
;              Data\settings\FLStudio.reg and ILReg.reg, and the folders now
;              linked from Data\AppData\Image-Line and
;              Data\ProgramData\FL Cloud Plugins directly in Data\AppData and
;              Data\ProgramData. Both are taken over the first time.
;   Cloud      %ProgramData%\FL Cloud Plugins is linked into Data like the
;              folders in [SymlinkN], but here: an installed FL Studio's copy
;              of it was made with administrator rights, and the launcher
;              doesn't have those. When it can't be moved aside, it is left
;              in use for the session, without a warning on every launch.
;
; Every change is journaled before it is made, so it is undone when FL Studio
; closes, or on the next launch after a crash.

; Variables
Var FLKeyLoaded

; Defines
!define ILKEY       `Software\Image-Line`
!define ILREG       `Image-Line.reg`
!define CLOUDDIR    `FL Cloud Plugins`
!define FLEXE       `FL64.exe`
!define FLSCALED    `FL64 (scaled).exe`

; Functions

; Data migration

; Moves everything in Data\$0 into Data\$0\$1, the layout the junctions use
; now. Earlier packages moved %APPDATA%\Image-Line itself to Data\AppData
; (and %ProgramData%\FL Cloud Plugins to Data\ProgramData). The folder is
; renamed to $0.migrating first and then into place, so an interrupted move
; is finished on the next launch.
Function FL_MigrateFolder
	Push $2
	StrCpy $2 `$DataDirectory\$0.migrating`
	${If} ${FileExists} `$DataDirectory\$0\*.*`
	${AndIfNot} ${FileExists} `$DataDirectory\$0\$1\*.*`
	${AndIfNot} ${FileExists} `$2\*.*`
		ClearErrors
		Rename `$DataDirectory\$0` $2
		${If} ${Errors}
			${DebugMsg} "Could not move Data\$0 aside to take it over; left as it is."
		${EndIf}
	${EndIf}
	${If} ${FileExists} `$2\*.*`
	${AndIfNot} ${FileExists} `$DataDirectory\$0\$1\*.*`
		CreateDirectory `$DataDirectory\$0`
		ClearErrors
		Rename $2 `$DataDirectory\$0\$1`
		${If} ${Errors}
			${DebugMsg} "Could not move Data\$0.migrating to Data\$0\$1."
		${EndIf}
	${EndIf}
	Pop $2
FunctionEnd

Function FL_Migrate
	Push $0
	Push $1
	StrCpy $0 AppData
	StrCpy $1 Image-Line
	Call FL_MigrateFolder
	StrCpy $0 ProgramData
	StrCpy $1 `${CLOUDDIR}`
	Call FL_MigrateFolder
	Pop $1
	Pop $0
FunctionEnd

; Registry

; Imports Data\settings\$0 when it exists. Sets $0 to true when it did.
Function FL_Import
	${If} ${FileExists} `$DataDirectory\settings\$0`
		nsExec::ExecToStack `"$SYSDIR\reg.exe" import "$DataDirectory\settings\$0"`
		Pop $0
		Pop $0
		StrCpy $0 true
	${Else}
		StrCpy $0 false
	${EndIf}
FunctionEnd

; Journals HKCU\Software\Image-Line and replaces it with the package's copy.
; Until Image-Line.reg has been saved once, the files earlier packages (and
; App\DefaultData) used are imported instead.
Function FL_LoadKey
	Push $0
	${Journal::RegKey} FLStudio HKCU `${ILKEY}` $0
	${If} $0 != ""
		StrCpy $FLKeyLoaded true
		DeleteRegKey HKCU `${ILKEY}`
		StrCpy $0 `${ILREG}`
		Call FL_Import
		${If} $0 != true
			StrCpy $0 FLStudio.reg
			Call FL_Import
			StrCpy $0 ILReg.reg
			Call FL_Import
		${EndIf}
	${EndIf}
	Pop $0
FunctionEnd

; Saves HKCU\Software\Image-Line to Data\settings\Image-Line.reg. The new
; export replaces the old one only once it is complete. Only after a session
; that loaded the key: when the launcher only cleans up after a crash, crash
; recovery has already put back what was there before (an installed FL
; Studio's settings, or nothing), and that must not be saved over Data.
Function FL_SaveKey
	Push $0
	${Journal::RegKeyExists} HKCU `${ILKEY}` $0
	${If} $0 == 1
	${AndIf} $FLKeyLoaded == true
		CreateDirectory `$DataDirectory\settings`
		Delete `$DataDirectory\settings\${ILREG}.new`
		nsExec::ExecToStack `"$SYSDIR\reg.exe" export "HKCU\${ILKEY}" "$DataDirectory\settings\${ILREG}.new" /y`
		Pop $0
		Pop $0
		${If} ${FileExists} `$DataDirectory\settings\${ILREG}.new`
			Delete `$DataDirectory\settings\${ILREG}`
			Rename `$DataDirectory\settings\${ILREG}.new` `$DataDirectory\settings\${ILREG}`
		${EndIf}
	${EndIf}
	Pop $0
FunctionEnd

; Journals every key listed in [FLStudioRegistry]. Each entry is a full key
; path starting with HKCU\ or HKLM\.
Function FL_JournalKeys
	Push $0
	Push $1
	Push $2
	Push $3
	Push $R0
	StrCpy $R0 1
	${Do}
		ClearErrors
		${ReadLauncherConfig} $1 FLStudioRegistry $R0
		${IfThen} ${Errors} ${|} ${ExitDo} ${|}
		StrCpy $2 $1 5
		StrCpy $3 $1 "" 5
		${If} $2 == "HKCU\"
			${Journal::RegKey} FLStudio HKCU $3 $0
		${ElseIf} $2 == "HKLM\"
			${Journal::RegKey} FLStudio HKLM $3 $0
		${Else}
			${InvalidValueError} [FLStudioRegistry]:$R0 $1
		${EndIf}
		IntOp $R0 $R0 + 1
	${Loop}
	Pop $R0
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; FL Cloud Plugins

; Links %ProgramData%\FL Cloud Plugins to Data\ProgramData\FL Cloud Plugins,
; journaled under its own name so a link that can't be made doesn't touch
; anything else in the journal. Skipped quietly when the folder that is
; there can't be moved aside (it belongs to an installed FL Studio and the
; launcher has no administrator rights) or Symlinks=false.
Function FL_LinkCloud
	Push $0
	Push $1
	Push $2
	Push $3
	${ReadUserConfig} $0 Symlinks
	${If} $0 != false
		ExpandEnvStrings $1 `%PROGRAMDATA%\${CLOUDDIR}`
		StrCpy $2 `$DataDirectory\ProgramData\${CLOUDDIR}`
		StrCpy $3 ""
		CreateDirectory $2
		System::Call `kernel32::GetFileAttributes(t "$1") i .r0`
		${If} $0 <> -1
			IntOp $0 $0 & 0x400
			${If} $0 <> 0
				; A link that isn't ours (crash recovery already removed any
				; we left behind).
				${DebugMsg} "$1 is a link already; left as it is."
				Goto FL_LinkCloud_End
			${EndIf}
			StrCpy $3 `$1.BackupBy${APPNAME}`
			${If} ${FileExists} $3
				${DebugMsg} "$3 is left from an earlier run; $1 not linked."
				Goto FL_LinkCloud_End
			${EndIf}
		${EndIf}
		${Journal::Record} FLCloud LINK $1 $3 $2 ""
		${If} $3 != ""
			ClearErrors
			Rename $1 $3
			${If} ${Errors}
				${Journal::Discard} FLCloud
				${DebugMsg} "Could not move $1 aside (no rights to it); it stays in use."
				Goto FL_LinkCloud_End
			${EndIf}
		${EndIf}
		nsExec::ExecToStack `"$SYSDIR\cmd.exe" /c mklink /J "$1" "$2"`
		Pop $0
		Pop $0
		System::Call `kernel32::GetFileAttributes(t "$1") i .r0`
		${If} $0 = -1
			${Journal::Discard} FLCloud
			${If} $3 != ""
				Rename $3 $1
			${EndIf}
			${DebugMsg} "Could not create the junction $1 -> $2."
		${EndIf}
	${EndIf}
	FL_LinkCloud_End:
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Hooks

; Core segment, after it picked the executable: the scaled build on request.
!macro UnProExecInit
	${ReadUserConfig} $0 Scaled
	${If} $0 == true
		${GetParent} $ProgramExecutable $0
		${If} ${FileExists} `$EXEDIR\App\$0\${FLSCALED}`
			StrCpy $ProgramExecutable `$0\${FLSCALED}`
		${EndIf}
	${EndIf}
!macroend

${SegmentFile}

${Segment.OnInit}
	!ifndef FL_TEST
		${If} $Arch == x86
			MessageBox MB_ICONSTOP|MB_TOPMOST "FL Studio needs 64-bit Windows.$\r$\n$\r$\n${PORTABLEAPPNAME} can't run on this computer."
			Quit
		${EndIf}
	!endif
!macroend

${SegmentPrePrimary}
	Call FL_Migrate
	Call FL_LoadKey
	Call FL_JournalKeys
	Call FL_LinkCloud
!macroend

${SegmentPostPrimary}
	Call FL_SaveKey
	${Journal::HasEntries} FLCloud $R0
	${If} $R0 > 0
		${Journal::Rollback} FLCloud
	${EndIf}
	${Journal::HasEntries} FLStudio $R0
	${If} $R0 > 0
		${Journal::Rollback} FLStudio
	${EndIf}
!macroend
