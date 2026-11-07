; Android Studio Portable custom code for PortableApps Compiler.
; For support, visit the GitHub project:
; https://github.com/daemondevin/pac-man
;
; Android Studio runs from App\AndroidStudio. The environment variables in
; the launcher's INI keep the Android SDK, the SDK tools' settings and AVDs,
; and Gradle's caches in Data; what this file adds:
;
;   IDE folders     Data\AndroidStudio\idea.properties (named by
;                   STUDIO_PROPERTIES) is written for every launch, so the
;                   IDE's settings, caches, plugins and logs follow the
;                   package. Lines you add to it are kept.
;   Runtime         Android Studio runs on its own Java (jbr), not one that
;                   JAVA_HOME or JDK_HOME name, and ANDROID_SDK_HOME is
;                   cleared, as it would point the tools elsewhere.
;   Adding          The zip's android-studio folder, in App or in
;                   App\AndroidStudio, is moved into App\AndroidStudio.
;   Moving          Paths in the IDE's settings (the SDK, JDKs, recent
;                   projects) and in the AVDs are updated when the package
;                   moves.
;   Background      Gradle and Kotlin daemons and the adb server keep running
;                   after Android Studio closes, from files in the package;
;                   they're stopped (StopDaemons=false keeps them).
;   Leftovers       Folders the IDE and the tools may still create in the user
;                   profile, and the Java preferences the IDE writes to the
;                   registry, are journaled and undone.
;   Version         The version in product-info.json is written to
;                   appinfo.ini.

; Defines
!define AS_APP      `$EXEDIR\App\AndroidStudio`
!define AS_IDE      `${DATA}\AndroidStudio`
!define AS_INFO     `$EXEDIR\App\AppInfo\appinfo.ini`
!define AS_PREFS    `Software\JavaSoft\Prefs`
!if ${NSIS_PTR_SIZE} > 4
	!define AS_PE32SIZE 568
!else
	!define AS_PE32SIZE 556
!endif

; Variables
Var ASVersion       ; version in product-info.json (2025.1.2)
Var ASSuffix        ; its versionSuffix (Patch 1), or ""
Var ASDataDir       ; dataDirectoryName (AndroidStudio2025.1.2)

; Helpers

; Journals a folder that may be created: removed again if it isn't there
; yet. $R0 = the folder, $R1 = recursive to remove it with its contents.
Function AS_JournalDir
	${IfNot} ${FileExists} `$R0\*.*`
		${Journal::Record} AndroidStudioPortable DIR $R0 "" $R1 ""
	${EndIf}
FunctionEnd

; Adding Android Studio

; $R0 = the android-studio folder in $R0 that holds bin\studio64.exe, or "".
Function AS_FindUnpacked
	${If} ${FileExists} `$R0\android-studio\bin\studio64.exe`
		StrCpy $R0 `$R0\android-studio`
	${Else}
		StrCpy $R0 ""
	${EndIf}
FunctionEnd

; The zip unpacks to a folder named android-studio. In App\AndroidStudio it
; becomes App\AndroidStudio itself; in App it's renamed.
Function AS_Adopt
	Push $R0
	${IfNot} ${FileExists} `${AS_APP}\bin\studio64.exe`
		StrCpy $R0 `${AS_APP}`
		Call AS_FindUnpacked
		${If} $R0 != ""
			Rename `${AS_APP}` `${AS_APP}.unpacked`
			Rename `${AS_APP}.unpacked\android-studio` `${AS_APP}`
			RMDir `${AS_APP}.unpacked`
		${Else}
			StrCpy $R0 `$EXEDIR\App`
			Call AS_FindUnpacked
			${If} $R0 != ""
				RMDir `${AS_APP}`
				Rename $R0 `${AS_APP}`
			${EndIf}
		${EndIf}
	${EndIf}
	ClearErrors
	Pop $R0
FunctionEnd

; $R1 = the string value of the key $R0 ("version") in the JSON line $1,
; as written, or "" when the line doesn't have it.
Function AS_JsonValue
	Push $2
	StrCpy $R1 ""
	ClearErrors
	${WordFind} `x$1` `"$R0"` "E+1}" $2
	${IfNot} ${Errors}
		; : "2025.1.2", -> 2025.1.2", -> 2025.1.2
		${WordFind} `x$2` `"` "E+1}" $2
		${IfNot} ${Errors}
			${WordFind} `x$2` `"` "E+1{" $2
			${IfNot} ${Errors}
				StrCpy $R1 $2 "" 1
			${EndIf}
		${EndIf}
	${EndIf}
	ClearErrors
	Pop $2
FunctionEnd

; Reads version, versionSuffix and dataDirectoryName from
; App\AndroidStudio\product-info.json (the first of each: the product's).
Function AS_ProductInfo
	Push $R0
	Push $R1
	Push $0
	Push $1
	StrCpy $ASVersion ""
	StrCpy $ASSuffix ""
	StrCpy $ASDataDir ""
	ClearErrors
	FileOpen $0 `${AS_APP}\product-info.json` r
	${IfNot} ${Errors}
		${Do}
			ClearErrors
			FileRead $0 $1
			${IfThen} ${Errors} ${|} ${Break} ${|}
			${If} $ASVersion == ""
				StrCpy $R0 version
				Call AS_JsonValue
				StrCpy $ASVersion $R1
			${EndIf}
			${If} $ASSuffix == ""
				StrCpy $R0 versionSuffix
				Call AS_JsonValue
				StrCpy $ASSuffix $R1
			${EndIf}
			${If} $ASDataDir == ""
				StrCpy $R0 dataDirectoryName
				Call AS_JsonValue
				StrCpy $ASDataDir $R1
			${EndIf}
		${Loop}
		FileClose $0
	${EndIf}
	ClearErrors
	Pop $1
	Pop $0
	Pop $R1
	Pop $R0
FunctionEnd

; IDE folders

; Writes Data\AndroidStudio\idea.properties: the config, system, plugins and
; log folders in Data, with forward slashes (a backslash is an escape in a
; properties file). Other lines in it are kept.
Function AS_Properties
	Push $0
	Push $1
	Push $2
	Push $3
	Push $4
	CreateDirectory `${AS_IDE}`
	${WordReplace} `${AS_IDE}` "\" "/" "+" $3
	StrCpy $4 `${AS_IDE}\idea.properties`
	FileOpen $0 `$4.new` w
	FileWrite $0 `# Written by the Android Studio Portable launcher for every launch: the$\r$\n`
	FileWrite $0 `# four paths below follow the package. Lines you add are kept.$\r$\n`
	FileWrite $0 `idea.config.path=$3/config$\r$\n`
	FileWrite $0 `idea.system.path=$3/system$\r$\n`
	FileWrite $0 `idea.plugins.path=$3/plugins$\r$\n`
	FileWrite $0 `idea.log.path=$3/log$\r$\n`
	ClearErrors
	FileOpen $1 $4 r
	${IfNot} ${Errors}
		${Do}
			ClearErrors
			FileRead $1 $2
			${IfThen} ${Errors} ${|} ${Break} ${|}
			${TrimNewLines} $2 $2
			StrCpy $3 $2 17
			${If} $2 == ""
			${OrIf} $3 == "idea.config.path="
			${OrIf} $3 == "idea.system.path="
			${OrIf} $3 == "idea.plugins.path"
			${OrIf} $3 == "# Written by the "
			${OrIf} $3 == "# four paths belo"
				${Continue}
			${EndIf}
			StrCpy $3 $2 14
			${IfThen} $3 == "idea.log.path=" ${|} ${Continue} ${|}
			FileWrite $0 `$2$\r$\n`
		${Loop}
		FileClose $1
	${EndIf}
	FileClose $0
	Delete $4
	Rename `$4.new` $4
	ClearErrors
	Pop $4
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Every launch: the IDE's own Java, and no ANDROID_SDK_HOME (an older
; variable that would point the tools' settings elsewhere).
Function AS_Env
	${If} ${FileExists} `${AS_APP}\jbr\bin\java.exe`
		System::Call `kernel32::SetEnvironmentVariable(t "STUDIO_JDK", t "${AS_APP}\jbr")`
	${EndIf}
	System::Call `kernel32::SetEnvironmentVariable(t "ANDROID_SDK_HOME", p 0)`
FunctionEnd

; Moving the package

; Replaces the path $R8 with $R9 (both ending in a backslash) in the file
; $R7, as written and with forward slashes.
Function AS_ReplaceIn
	Push $0
	Push $1
	${ReplaceInFile} $R7 $R8 $R9
	${WordReplace} $R8 "\" "/" "+" $0
	${WordReplace} $R9 "\" "/" "+" $1
	${ReplaceInFile} $R7 $0 $1
	ClearErrors
	Pop $1
	Pop $0
FunctionEnd

; Replaces $R8 with $R9 in every file matching $R6 (a folder and a wildcard,
; such as ...\options\*.xml).
Function AS_ReplaceInAll
	Push $R7
	Push $0
	Push $1
	Push $2
	${GetParent} $R6 $2
	FindFirst $0 $1 $R6
	${DoWhile} $1 != ""
		StrCpy $R7 `$2\$1`
		${IfNot} ${FileExists} `$R7\*.*`
			Call AS_ReplaceIn
		${EndIf}
		FindNext $0 $1
	${Loop}
	FindClose $0
	ClearErrors
	Pop $2
	Pop $1
	Pop $0
	Pop $R7
FunctionEnd

; The IDE's settings (SDK and JDK locations, recent projects, the default
; project folder) and the AVDs' .ini files, which name their folders.
Function AS_PathFiles
	Push $R6
	StrCpy $R6 `${AS_IDE}\config\options\*.xml`
	Call AS_ReplaceInAll
	StrCpy $R6 `${DATA}\.android\avd\*.ini`
	Call AS_ReplaceInAll
	Pop $R6
FunctionEnd

; When the package has moved: first the paths into the package, then, if
; the drive letter changed, the other paths on that drive.
Function AS_UpdatePaths
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
		Call AS_PathFiles
	${EndIf}
	StrCpy $3 $0 1 1
	StrCpy $R7 $2 1 1
	${If} $0 != $2
	${AndIf} $3 == ":"
	${AndIf} $R7 == ":"
		StrCpy $R8 `$0\`
		StrCpy $R9 `$2\`
		Call AS_PathFiles
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

; Background processes

; Stops the adb server (gracefully, with adb kill-server) and then every
; process still running from the package: Gradle and Kotlin daemons on the
; IDE's Java, for one. The launcher itself is left alone.
Function AS_StopDaemons
	Push $0
	Push $1
	Push $2
	Push $3
	Push $4
	Push $5
	Push $6
	Push $7
	ClearErrors
	${ReadUserConfig} $0 StopDaemons
	${If} $0 != false
		${If} ${FileExists} `${DATA}\Sdk\platform-tools\adb.exe`
			nsExec::Exec `"${DATA}\Sdk\platform-tools\adb.exe" kill-server`
			Pop $0
		${EndIf}
		System::Call `kernel32::GetCurrentProcessId() i .r5`
		StrLen $7 `$EXEDIR\`
		; TH32CS_SNAPPROCESS
		System::Call `kernel32::CreateToolhelp32Snapshot(i 2, i 0) p .r0`
		${If} $0 <> -1
			System::Alloc ${AS_PE32SIZE}
			Pop $1
			System::Call `*$1(i ${AS_PE32SIZE})`
			System::Call `kernel32::Process32FirstW(p r0, p r1) i .r2`
			${DoWhile} $2 <> 0
				; PROCESSENTRY32W: dwSize, cntUsage, th32ProcessID
				System::Call `*$1(i, i, i .r3)`
				${If} $3 <> $5
				${AndIf} $3 <> 0
					; PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_TERMINATE
					System::Call `kernel32::OpenProcess(i 0x1001, i 0, i r3) p .r4`
					${If} $4 <> 0
						StrCpy $6 ""
						System::Call `kernel32::QueryFullProcessImageNameW(p r4, i 0, w .r6, *i ${NSIS_MAX_STRLEN})`
						StrCpy $6 $6 $7
						${If} $6 == `$EXEDIR\`
							System::Call `kernel32::TerminateProcess(p r4, i 1)`
							System::Call `kernel32::WaitForSingleObject(p r4, i 5000)`
						${EndIf}
						System::Call `kernel32::CloseHandle(p r4)`
					${EndIf}
				${EndIf}
				System::Call `*$1(i ${AS_PE32SIZE})`
				System::Call `kernel32::Process32NextW(p r0, p r1) i .r2`
			${Loop}
			System::Free $1
			System::Call `kernel32::CloseHandle(p r0)`
		${EndIf}
	${EndIf}
	ClearErrors
	Pop $7
	Pop $6
	Pop $5
	Pop $4
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Leftovers

Function AS_JournalWindows
	Push $R0
	Push $R1
	Push $0
	StrCpy $R1 recursive
	; The IDE's default folders, if anything still uses them. The Google
	; folders go too when they weren't there before (consent choices and
	; such are kept there).
	StrCpy $R0 `$APPDATA\Google`
	Call AS_JournalDir
	StrCpy $R0 `$LOCALAPPDATA\Google`
	Call AS_JournalDir
	${If} $ASDataDir != ""
		StrCpy $R0 `$APPDATA\Google\$ASDataDir`
		Call AS_JournalDir
		StrCpy $R0 `$LOCALAPPDATA\Google\$ASDataDir`
		Call AS_JournalDir
	${EndIf}
	StrCpy $R0 `$APPDATA\JetBrains`
	Call AS_JournalDir
	StrCpy $R0 `$LOCALAPPDATA\JetBrains`
	Call AS_JournalDir
	; The tools' defaults: settings, Gradle, the Kotlin daemon, Skia.
	StrCpy $R0 `$PROFILE\.android`
	Call AS_JournalDir
	StrCpy $R0 `$PROFILE\.gradle`
	Call AS_JournalDir
	StrCpy $R0 `$PROFILE\.skiko`
	Call AS_JournalDir
	StrCpy $R0 `$LOCALAPPDATA\kotlin`
	Call AS_JournalDir
	; Java preferences the IDE keeps in the registry.
	${Journal::RegKeyExists} HKCU `Software\JavaSoft` $0
	${If} $0 = 0
		${Journal::RegKey} AndroidStudioPortable HKCU `Software\JavaSoft` $0
	${Else}
		${Journal::RegKey} AndroidStudioPortable HKCU `${AS_PREFS}\jetbrains` $0
		${Journal::RegKey} AndroidStudioPortable HKCU `${AS_PREFS}\google` $0
		${Journal::RegKey} AndroidStudioPortable HKCU `${AS_PREFS}\com` $0
	${EndIf}
	ClearErrors
	Pop $0
	Pop $R1
	Pop $R0
FunctionEnd

; Writes the version to appinfo.ini: 2025.1.2.0 as PackageVersion, and
; 2025.1.2 (with its suffix, such as Patch 1) as DisplayVersion.
Function AS_WriteVersion
	Push $0
	Push $1
	Call AS_ProductInfo
	${If} $ASVersion != ""
		StrCpy $0 $ASVersion
		${WordFind} $0 "." "#" $1
		${If} $1 < 4
			StrCpy $0 `$0.0`
		${EndIf}
		StrCpy $1 $ASVersion
		${IfThen} $ASSuffix != "" ${|} StrCpy $1 `$1 $ASSuffix` ${|}
		WriteINIStr `${AS_INFO}` Version PackageVersion $0
		WriteINIStr `${AS_INFO}` Version DisplayVersion $1
	${EndIf}
	ClearErrors
	Pop $1
	Pop $0
FunctionEnd

; Hooks

${SegmentFile}

; Before the launcher looks for Android Studio: it has no 32-bit build, and
; a freshly unpacked zip is moved into place first.
${Segment.onInit}
	Push $0
	ReadEnvStr $0 PROCESSOR_ARCHITEW6432
	${IfThen} $0 == "" ${|} ReadEnvStr $0 PROCESSOR_ARCHITECTURE ${|}
	${If} $0 == x86
		MessageBox MB_OK|MB_ICONSTOP `Android Studio needs 64-bit Windows; this computer runs 32-bit Windows.`
		Pop $0
		Abort
	${EndIf}
	Pop $0
	Call AS_Adopt
!macroend

${SegmentPrePrimary}
	Call AS_ProductInfo
	Call AS_Properties
	CreateDirectory `${DATA}\Sdk`
	CreateDirectory `${DATA}\.android\avd`
	CreateDirectory `${DATA}\.gradle`
	Call AS_UpdatePaths
	Call AS_JournalWindows
!macroend

${SegmentPreExec}
	Call AS_Env
!macroend

${SegmentPostPrimary}
	Call AS_StopDaemons
	${Journal::HasEntries} AndroidStudioPortable $R0
	${If} $R0 > 0
		${Journal::Rollback} AndroidStudioPortable
	${EndIf}
	Call AS_WriteVersion
!macroend
