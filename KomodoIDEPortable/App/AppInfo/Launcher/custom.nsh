; Komodo Portable custom code for PortableApps Compiler, shared by Komodo
; Edit Portable and Komodo IDE Portable.
; For support, visit the GitHub project:
; https://github.com/daemondevin/pac-man
;
; What lives here and why:
;   Leftovers  Komodo's settings go to Data through KOMODO_USERDATADIR (set
;              in the launcher ini), but Komodo and the Mozilla platform it is
;              built on still make a few folders of their own (crash reports,
;              the update folder). Each folder listed in [KomodoFolders] that
;              doesn't exist yet is journaled before Komodo starts, so it is
;              removed when Komodo closes, or on the next launch after a
;              crash. Folders that already exist (from an installed Komodo)
;              are left alone.
;   Data       The KOMODO_USERDATADIR folder is made before Komodo starts, so
;              Komodo finds it on the first launch too.
;   Mozilla    %APPDATA%\Mozilla is also where Firefox and Thunderbird keep
;              their profiles, so it is only removed when Komodo made it and
;              nothing but Komodo's leftovers is in it.

; Variables
Var KomodoMozilla

; Defines
!define MOZDIR      `$APPDATA\Mozilla`

; Functions

; Journals folder $0 for removal when it doesn't exist yet. What is recorded
; is the topmost folder that is missing (for %APPDATA%\ActiveState\Komodo
; Edit, that is %APPDATA%\ActiveState when ActiveState isn't there either),
; so everything Komodo makes below it goes too.
Function KO_JournalFolder
	Push $1
	Push $2
	${IfNot} ${FileExists} `$0\*.*`
		StrCpy $1 $0
		${Do}
			${GetParent} $1 $2
			${If} $2 == ""
			${OrIf} ${FileExists} `$2\*.*`
				${ExitDo}
			${EndIf}
			StrCpy $1 $2
		${Loop}
		${Journal::Record} Komodo DIR $1 "" recursive ""
	${EndIf}
	Pop $2
	Pop $1
FunctionEnd

; Journals every folder listed in [KomodoFolders]. Environment variables in
; the paths are expanded.
Function KO_JournalFolders
	Push $0
	Push $R0
	StrCpy $R0 1
	${Do}
		ClearErrors
		${ReadLauncherConfig} $0 KomodoFolders $R0
		${IfThen} ${Errors} ${|} ${ExitDo} ${|}
		ExpandEnvStrings $0 $0
		Call KO_JournalFolder
		IntOp $R0 $R0 + 1
	${Loop}
	Pop $R0
	Pop $0
FunctionEnd

; Notes whether %APPDATA%\Mozilla is Komodo's to remove. If it isn't there
; yet, an empty one is journaled for removal, so a crash doesn't leave it
; behind; whatever Komodo puts in it is dealt with in KO_Mozilla.
Function KO_MozillaBefore
	StrCpy $KomodoMozilla false
	${IfNot} ${FileExists} `${MOZDIR}\*.*`
		StrCpy $KomodoMozilla true
		${Journal::Record} Komodo DIR `${MOZDIR}` "" "" ""
	${EndIf}
FunctionEnd

; Removes %APPDATA%\Mozilla when Komodo made it, unless a Mozilla program
; started using it meanwhile.
Function KO_Mozilla
	${If} $KomodoMozilla == true
	${AndIfNot} ${FileExists} `${MOZDIR}\Firefox\*.*`
	${AndIfNot} ${FileExists} `${MOZDIR}\Thunderbird\*.*`
	${AndIfNot} ${FileExists} `${MOZDIR}\SeaMonkey\*.*`
		RMDir /r `${MOZDIR}`
	${EndIf}
FunctionEnd

; Hooks

${SegmentFile}

${SegmentPrePrimary}
	ReadEnvStr $0 KOMODO_USERDATADIR
	${If} $0 != ""
		CreateDirectory $0
	${EndIf}
	Call KO_JournalFolders
	Call KO_MozillaBefore
!macroend

${SegmentPostPrimary}
	Call KO_Mozilla
	${Journal::HasEntries} Komodo $R0
	${If} $R0 > 0
		${Journal::Rollback} Komodo
	${EndIf}
!macroend
