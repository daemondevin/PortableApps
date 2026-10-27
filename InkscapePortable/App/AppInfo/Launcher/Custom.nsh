; Inkscape Portable custom code for PortableApps Compiler.
; For support, visit the GitHub project:
; https://github.com/daemondevin/pac-man
;
; Inkscape runs from App\Inkscape. Its profile (preferences, extensions,
; palettes, templates...) is in Data\Inkscape through INKSCAPE_PROFILE_DIR,
; and what GTK and GLib keep for the user (recent files, settings, caches)
; is in Data\GLib through the XDG_*_HOME variables, so nothing has to be
; moved in and out. What this file adds:
;
;   Fonts          A fontconfig file is written to Data\GLib for every
;                  launch and used through FONTCONFIG_FILE. It loads
;                  Inkscape's own configuration, adds the fonts in Data\Fonts
;                  and the PortableApps.com Platform's Data\Fonts folder, and
;                  keeps fontconfig's cache in Data\GLib\cache instead of
;                  %LOCALAPPDATA%.
;   Ghostscript    PostScript and EPS import need Ghostscript. One in
;                  PortableApps\CommonFiles\Ghostscript, in App\Ghostscript, or
;                  installed is put on the PATH for Inkscape (with GSC naming
;                  its console program, which ps2pdf runs).
;   Python         PYTHONHOME and PYTHONPATH of an installed Python are cleared
;                  for Inkscape, so its extensions run on its own Python.
;   Language       Follows the PortableApps.com Platform's language when that
;                  changes, or the Language in InkscapePortable.ini. A
;                  language picked in Inkscape stays until then.
;   Moving         Paths in preferences.xml and the recent files list are
;                  updated when the package moves.
;   Older layout   A package that kept the profile in Data\settings, the
;                  recent files in Data and the font cache in Data\fontconfig
;                  is moved to this layout once.
;   Leftovers      Folders Inkscape, GTK or Ghostscript may still create in
;                  %APPDATA% and %LOCALAPPDATA%, and Ghostscript's registry key,
;                  are journaled and removed again.
;   Version        The version of inkscape.exe is written to appinfo.ini.

; Defines
!define IK_APP      `$EXEDIR\App\Inkscape`
!define IK_PROFILE  `${DATA}\Inkscape`
!define IK_GLIB     `${DATA}\GLib`
!define IK_INFO     `$EXEDIR\App\AppInfo\appinfo.ini`

; Variables
Var IKGhostscript   ; the Ghostscript folder used, or ""
Var IKMigrated      ; 1 when the older layout was moved this launch

; Helpers

; Journals a folder that may be created: removed again if it isn't there
; yet. $R0 = the folder, $R1 = recursive to remove it with its contents.
Function IK_JournalDir
	${IfNot} ${FileExists} `$R0\*.*`
		${Journal::Record} InkscapePortable DIR $R0 "" $R1 ""
	${EndIf}
FunctionEnd

; Journals a file that may be created: removed again if it isn't there yet.
Function IK_JournalFile
	${IfNot} ${FileExists} $R0
		${Journal::Record} InkscapePortable FILE $R0 "" "" ""
	${EndIf}
FunctionEnd

; Moves the file or folder $R0 to $R1 when $R1 isn't there yet.
Function IK_MoveOnce
	${If} ${FileExists} $R0
	${AndIfNot} ${FileExists} $R1
		Rename $R0 $R1
	${EndIf}
	ClearErrors
FunctionEnd

; Older layout

; Data\settings held the profile next to the launcher's own settings,
; Data\recently-used.xbel and Data\fontconfig were moved to %LOCALAPPDATA%
; for each session, and Data\01-portableapps.conf into Inkscape's fonts
; folder.
Function IK_Migrate
	Push $R0
	Push $R1
	Push $0
	Push $1
	${If} ${FileExists} `${DATA}\settings\preferences.xml`
	${AndIfNot} ${FileExists} `${IK_PROFILE}\*.*`
		CreateDirectory `${IK_PROFILE}`
		FindFirst $0 $1 `${DATA}\settings\*`
		${DoWhile} $1 != ""
			${If} $1 != "."
			${AndIf} $1 != ".."
			${AndIf} $1 != `${APPNAME}Settings.ini`
				Rename `${DATA}\settings\$1` `${IK_PROFILE}\$1`
			${EndIf}
			FindNext $0 $1
		${Loop}
		FindClose $0
		StrCpy $IKMigrated 1
	${EndIf}
	CreateDirectory `${IK_GLIB}\data`
	CreateDirectory `${IK_GLIB}\cache`
	StrCpy $R0 `${DATA}\recently-used.xbel`
	StrCpy $R1 `${IK_GLIB}\data\recently-used.xbel`
	Call IK_MoveOnce
	StrCpy $R0 `${DATA}\fontconfig\cache`
	StrCpy $R1 `${IK_GLIB}\cache\fontconfig`
	Call IK_MoveOnce
	RMDir `${DATA}\fontconfig`
	; That configuration is written fresh for every launch now.
	Delete `${DATA}\01-portableapps.conf`
	Delete `${IK_APP}\etc\fonts\conf.d\01-portableapps.conf`
	ClearErrors
	Pop $1
	Pop $0
	Pop $R1
	Pop $R0
FunctionEnd

; Files kept in Data\settings (images, templates) are in Data\Inkscape after
; IK_Migrate; the paths to them follow (after the package paths are
; current).
Function IK_MigratedPaths
	${If} $IKMigrated == 1
		Push $R8
		Push $R9
		StrCpy $R8 `${DATA}\settings\`
		StrCpy $R9 `${IK_PROFILE}\`
		Call IK_ReplacePath
		Pop $R9
		Pop $R8
	${EndIf}
FunctionEnd

; Fonts

; Writes Data\GLib\fonts.conf for this launch. The cache folder comes first:
; fontconfig writes its cache to the first one it can write to, and
; Inkscape's own configuration names %LOCALAPPDATA%\fontconfig\cache.
Function IK_FontConfig
	Push $0
	Push $1
	CreateDirectory `${DATA}\Fonts`
	CreateDirectory `${IK_GLIB}\cache\fontconfig`
	FileOpen $0 `${IK_GLIB}\fonts.conf` w
	FileWrite $0 `<?xml version="1.0"?>$\r$\n<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">$\r$\n`
	FileWrite $0 `<!-- Written by the Inkscape Portable launcher for each launch; changes are lost. Put your own settings in Data\GLib\config\fontconfig\fonts.conf. -->$\r$\n<fontconfig>$\r$\n`
	FileWrite $0 `	<cachedir>${IK_GLIB}\cache\fontconfig</cachedir>$\r$\n`
	FileWrite $0 `	<include ignore_missing="no">${IK_APP}\etc\fonts\fonts.conf</include>$\r$\n`
	FileWrite $0 `	<dir>${DATA}\Fonts</dir>$\r$\n`
	${GetParent} $EXEDIR $1
	${If} ${FileExists} `$1\PortableApps.com\Data\Fonts\*.*`
		FileWrite $0 `	<dir>$1\PortableApps.com\Data\Fonts</dir>$\r$\n`
	${EndIf}
	FileWrite $0 `</fontconfig>$\r$\n`
	FileClose $0
	ClearErrors
	Pop $1
	Pop $0
FunctionEnd

; Ghostscript

; $R0 = a Ghostscript folder to check; $R1 = its console program, or "".
Function IK_GhostscriptExe
	StrCpy $R1 ""
	${If} ${FileExists} `$R0\bin\gswin64c.exe`
		StrCpy $R1 `$R0\bin\gswin64c.exe`
	${ElseIf} ${FileExists} `$R0\bin\gswin32c.exe`
		StrCpy $R1 `$R0\bin\gswin32c.exe`
	${EndIf}
FunctionEnd

; Finds Ghostscript: the PortableApps.com Platform's CommonFiles, this
; package's App\Ghostscript, then an installed one (newest version in the
; registry). Puts its bin and lib folders on the PATH and names its console
; program in GSC, which Ghostscript's ps2pdf scripts run.
Function IK_Ghostscript
	Push $R0
	Push $R1
	Push $0
	Push $1
	Push $2
	StrCpy $IKGhostscript ""
	${GetParent} $EXEDIR $0
	StrCpy $R0 `$0\CommonFiles\Ghostscript`
	Call IK_GhostscriptExe
	${If} $R1 == ""
		StrCpy $R0 `$EXEDIR\App\Ghostscript`
		Call IK_GhostscriptExe
	${EndIf}
	${If} $R1 == ""
		; HKLM\SOFTWARE\GPL Ghostscript\<version>, GS_DLL = <folder>\bin\gsdll64.dll
		SetRegView 64
		StrCpy $0 0
		StrCpy $2 ""
		${Do}
			EnumRegKey $1 HKLM `SOFTWARE\GPL Ghostscript` $0
			${IfThen} $1 == "" ${|} ${Break} ${|}
			ReadRegStr $1 HKLM `SOFTWARE\GPL Ghostscript\$1` GS_DLL
			${IfThen} $1 != "" ${|} StrCpy $2 $1 ${|}
			IntOp $0 $0 + 1
		${Loop}
		SetRegView lastused
		${If} $2 != ""
			${GetParent} $2 $R0
			${GetParent} $R0 $R0
			Call IK_GhostscriptExe
		${EndIf}
	${EndIf}
	${If} $R1 != ""
		StrCpy $IKGhostscript $R0
		ReadEnvStr $0 PATH
		System::Call `kernel32::SetEnvironmentVariable(t "PATH", t "$R0\bin;$R0\lib;$0")`
		${GetFileName} $R1 $1
		${GetBaseName} $1 $1
		System::Call `kernel32::SetEnvironmentVariable(t "GSC", t "$1")`
		System::Call `kernel32::SetEnvironmentVariable(t "GS_PROG", t "$R1")`
	${EndIf}
	ClearErrors
	Pop $2
	Pop $1
	Pop $0
	Pop $R1
	Pop $R0
FunctionEnd

; Language

; Sets Inkscape's interface language in preferences.xml: the Language in
; InkscapePortable.ini, else the PortableApps.com Platform's language when
; it's not the one it was last time. Only a language Inkscape has a
; translation folder for is set.
Function IK_Language
	Push $0
	Push $1
	Push $2
	Push $3
	Push $R0
	ClearErrors
	${ReadUserConfig} $0 Language
	StrCpy $R0 ""
	${If} $0 != ""
		StrCpy $R0 $0
	${Else}
		ReadEnvStr $1 PAL:_IgnoreLanguage
		ReadEnvStr $0 PAL:LanguageGlibc
		${ReadSettings} $3 InkscapeLanguageFrom
		${If} $1 != true
		${AndIf} $0 != ""
		${AndIf} $0 != $3
			${WriteSettings} $0 InkscapeLanguageFrom
			; pt_BR, else the bare language (de).
			${If} ${FileExists} `${IK_APP}\share\locale\$0\*.*`
				StrCpy $R0 $0
			${Else}
				ReadEnvStr $1 PAL:LanguageCode
				${If} $1 != ""
				${AndIf} ${FileExists} `${IK_APP}\share\locale\$1\*.*`
					StrCpy $R0 $1
				${ElseIf} $1 == en
					; English is Inkscape's own language.
					StrCpy $R0 en_US
				${EndIf}
			${EndIf}
		${EndIf}
	${EndIf}
	${If} $R0 != ""
	${AndIf} ${FileExists} `${IK_PROFILE}\preferences.xml`
		!ifdef XML_ENABLED
			; nsisXML: $0 is the document, $1 the node found, $2 how many.
			nsisXML::create
			nsisXML::load `${IK_PROFILE}\preferences.xml`
			nsisXML::select `/inkscape/group[@id="ui"]`
			${If} $2 <> 0
				nsisXML::setAttribute language $R0
				nsisXML::release $1
				nsisXML::save `${IK_PROFILE}\preferences.xml`
			${EndIf}
			nsisXML::release $0
		!endif
	${EndIf}
	ClearErrors
	Pop $R0
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Moving the package

; Replaces the path $R8 with $R9 (both ending in a backslash) as written in
; preferences.xml (D:\Apps\), and as file URLs in the recent files list
; (file:///D:/Apps/).
Function IK_ReplacePath
	Push $0
	Push $1
	${If} ${FileExists} `${IK_PROFILE}\preferences.xml`
		${ReplaceInFile} `${IK_PROFILE}\preferences.xml` $R8 $R9
	${EndIf}
	${If} ${FileExists} `${IK_GLIB}\data\recently-used.xbel`
		${WordReplace} $R8 "\" "/" "+" $0
		${WordReplace} $0 " " "%20" "+" $0
		${WordReplace} $R9 "\" "/" "+" $1
		${WordReplace} $1 " " "%20" "+" $1
		${ReplaceInFile} `${IK_GLIB}\data\recently-used.xbel` `file:///$0` `file:///$1`
	${EndIf}
	ClearErrors
	Pop $1
	Pop $0
FunctionEnd

; When the package has moved: first the paths into the package, then, if
; the drive letter changed, the other paths on that drive.
Function IK_UpdatePaths
	Push $0
	Push $1
	Push $2
	Push $3
	Push $R7
	Push $R8
	Push $R9
	ReadEnvStr $0 PAL:LastDrive
	ReadEnvStr $1 PAL:LastPackagePartialDir
	ReadEnvStr $2 PAL:Drive
	ReadEnvStr $3 PAL:PackagePartialDir
	StrCpy $R8 `$0$1`
	StrCpy $R9 `$2$3`
	StrCpy $1 $R8 1 -1
	${IfThen} $1 == "\" ${|} StrCpy $R8 $R8 -1 ${|}
	StrCpy $1 $R9 1 -1
	${IfThen} $1 == "\" ${|} StrCpy $R9 $R9 -1 ${|}
	${If} $R8 != $R9
	${AndIf} $R8 != ""
		StrCpy $R8 `$R8\`
		StrCpy $R9 `$R9\`
		Call IK_ReplacePath
	${EndIf}
	StrCpy $3 $0 1 1
	StrCpy $R7 $2 1 1
	${If} $0 != $2
	${AndIf} $3 == ":"
	${AndIf} $R7 == ":"
		StrCpy $R8 `$0\`
		StrCpy $R9 `$2\`
		Call IK_ReplacePath
	${EndIf}
	ClearErrors
	Pop $R9
	Pop $R8
	Pop $R7
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Leftovers

Function IK_JournalWindows
	Push $R0
	Push $R1
	StrCpy $R1 recursive
	; Inkscape's own profile folder, if something still uses %APPDATA%.
	StrCpy $R0 `$APPDATA\inkscape`
	Call IK_JournalDir
	; fontconfig's and GTK's defaults in %LOCALAPPDATA%.
	StrCpy $R0 `$LOCALAPPDATA\fontconfig`
	Call IK_JournalDir
	StrCpy $R0 `$LOCALAPPDATA\gtk-3.0`
	Call IK_JournalDir
	StrCpy $R0 `$LOCALAPPDATA\recently-used.xbel`
	Call IK_JournalFile
	; Ghostscript can note itself in HKCU.
	${Journal::RegKey} InkscapePortable HKCU `Software\GPL Ghostscript` $R0
	Pop $R1
	Pop $R0
FunctionEnd

; Writes the version of inkscape.exe to appinfo.ini: 1.4.4.0 as
; PackageVersion, 1.4.4 as DisplayVersion.
Function IK_WriteVersion
	Push $0
	Push $1
	Push $2
	Push $3
	Push $4
	ClearErrors
	GetDllVersion `${IK_APP}\bin\inkscape.exe` $0 $1
	${IfNot} ${Errors}
		IntOp $2 $0 >> 16
		IntOp $2 $2 & 0xFFFF
		IntOp $3 $0 & 0xFFFF
		IntOp $4 $1 >> 16
		IntOp $4 $4 & 0xFFFF
		IntOp $1 $1 & 0xFFFF
		StrCpy $0 `$2.$3.$4`
		ReadINIStr $2 `${IK_INFO}` Version DisplayVersion
		${If} $0 != $2
		${AndIf} $0 != "0.0.0"
			WriteINIStr `${IK_INFO}` Version PackageVersion `$0.$1`
			WriteINIStr `${IK_INFO}` Version DisplayVersion $0
		${EndIf}
	${EndIf}
	ClearErrors
	Pop $4
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Hooks

${SegmentFile}

; Inkscape no longer has a 32-bit build.
${Segment.onInit}
	Push $0
	ReadEnvStr $0 PROCESSOR_ARCHITEW6432
	${IfThen} $0 == "" ${|} ReadEnvStr $0 PROCESSOR_ARCHITECTURE ${|}
	${If} $0 == x86
		MessageBox MB_OK|MB_ICONSTOP `Inkscape needs 64-bit Windows; this computer runs 32-bit Windows.`
		Pop $0
		Abort
	${EndIf}
	Pop $0
!macroend

${SegmentPrePrimary}
	Call IK_Migrate
	CreateDirectory `${IK_PROFILE}`
	CreateDirectory `${IK_GLIB}\config`
	Call IK_FontConfig
	Call IK_UpdatePaths
	Call IK_MigratedPaths
	Call IK_Language
	Call IK_JournalWindows
!macroend

; Every launch, the second one too: the variables are set for the process
; about to start.
${SegmentPreExec}
	Call IK_Ghostscript
	; An installed Python's settings would make Inkscape's extensions run
	; with the wrong library.
	System::Call `kernel32::SetEnvironmentVariable(t "PYTHONHOME", p 0)`
	System::Call `kernel32::SetEnvironmentVariable(t "PYTHONPATH", p 0)`
!macroend

${SegmentPostPrimary}
	${Journal::HasEntries} InkscapePortable $R0
	${If} $R0 > 0
		${Journal::Rollback} InkscapePortable
	${EndIf}
	Call IK_WriteVersion
!macroend
