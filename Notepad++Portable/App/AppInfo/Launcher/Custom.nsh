; Notepad++ Portable custom code for PortableApps Compiler.
; For support, visit the GitHub project:
; https://github.com/daemondevin/pac-man
;
; Notepad++ runs from App\Notepad++ with -settingsDir pointing at
; Data\Config, so its settings, sessions, themes, user defined languages,
; macros and backups are kept there. What this file adds:
;
;   Install          A package without Notepad++ offers to download it: the
;                    newest release's portable zip from GitHub
;                    (notepad-plus-plus/notepad-plus-plus), for x64, ARM64 or
;                    x86. The zip is checked against the SHA-256 the release
;                    notes publish for it and notepad++.exe against Notepad++'s
;                    signature, then unpacked with Windows' own tar.exe, or
;                    7-Zip.
;   Updates          The same, before Notepad++ starts, at most every
;                    UpdateInterval days, for the build in use. Plugins you
;                    installed are carried over. The swap is journaled, so a
;                    crash halfway puts the old Notepad++ back.
;   Settings folder  doLocalConf.xml keeps Notepad++ out of %APPDATA%, and
;                    cloud\choice (rewritten for every launch) makes it look
;                    for themes in Data\Config as well, which -settingsDir
;                    alone doesn't.
;   Plugin settings  Plugins keep theirs in App\Notepad++\plugins\Config
;                    whatever the settings folder is, so they're moved in from
;                    Data\Config\plugins\config for each session and back
;                    afterward. Plugins Admin's own list stays with Notepad++.
;   Session          A session.xml written next to notepad++.exe (Notepad++
;                    restarted by Plugins Admin, without -settingsDir) is
;                    taken into Data\Config.
;   Older layout     PortableApps.com's App\Notepad++64 becomes App\Notepad++
;                    on 64-bit Windows; their 32-bit App\Notepad++ is kept as
;                    App\Notepad++32. Data\themes and Data\toolbarIcons move
;                    into Data\Config.
;   Language         Follows the PortableApps.com Platform's language when that
;                    changes, or the Language in Notepad++Portable.ini.
;   Moving           Paths in the session, config.xml, shortcuts.xml and the
;                    Explorer plugin's settings are updated when the package
;                    moves.
;   Leftovers        Folders in %APPDATA% and %LOCALAPPDATA%, the Open with
;                    entry and, when run as administrator, the file
;                    associations set in Preferences are journaled and undone.
;   Version          The version of notepad++.exe is written to appinfo.ini.

; Defines
!define NP_APP      `$EXEDIR\App\Notepad++`
!define NP_CONF     `${DATA}\Config`
!define NP_PCONF    `${DATA}\Config\plugins\config`
!define NP_APCONF   `$EXEDIR\App\Notepad++\plugins\Config`
!define NP_LIST     `nppPluginList.dll`
!define NP_INFO     `$EXEDIR\App\AppInfo\appinfo.ini`
!define NP_TYPE     `Notepad++_file`
!define NP_STAGE    `$EXEDIR\App\Notepad++Update`
!define NP_RELEASE  `https://api.github.com/repos/notepad-plus-plus/notepad-plus-plus/releases/latest`
!define NP_DOWNLOAD `https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download`
!define NP_SIGNER   `NOTEPAD++`

; Variables
Var NPAdopted       ; 1 when App\Notepad++64 became App\Notepad++ this launch
Var NPVersion       ; the version on offer (8.9.8)
Var NPTag           ; its release tag (v8.9.8)
Var NPDigest        ; the zip's SHA-256 from the release notes

; Shared browser helpers

; $R0 = days since 1601, from the system clock.
Function BR_Today
	Push $0
	System::Call `kernel32::GetSystemTimeAsFileTime(*l .r0)`
	System::Int64Op $0 / 864000000000
	Pop $R0
	Pop $0
FunctionEnd

; Downloads $R0 to the file $R1. $R2 = ok, or the error code.
Function BR_Download
	Push $0
	Delete $R1
	System::Call `ole32::CoInitialize(p 0)`
	System::Call `wininet::DeleteUrlCacheEntryW(w R0) i .r0`
	System::Call `urlmon::URLDownloadToFileW(p 0, w R0, w R1, i 0, p 0) i .r0`
	${If} $0 = 0
	${AndIf} ${FileExists} $R1
		StrCpy $R2 ok
	${Else}
		IntFmt $R2 "error 0x%08X" $0
	${EndIf}
	Pop $0
FunctionEnd

; Sends the text $R1 to the URL $R0 as an HTTP POST and saves the answer to
; the file $R2, with WinHTTP (built into Windows). $R3 = ok, or why not.
Function BR_Post
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
	StrCpy $R3 "the update server couldn't be reached"
	; Split the URL: https://host[:port]/path
	StrCpy $9 0x00800000
	StrCpy $8 443
	${WordFind} $R0 "://" "+1" $0
	${If} $0 == http
		StrCpy $9 0
		StrCpy $8 80
	${EndIf}
	${WordFind} $R0 "://" "+1}" $1
	${WordFind} $1 "/" "+1" $2
	${WordFind} $1 "/" "+1}" $3
	StrCpy $3 `/$3`
	${WordFind} $2 ":" "E+2" $4
	${IfNot} ${Errors}
		StrCpy $8 $4
		${WordFind} $2 ":" "+1" $2
	${EndIf}
	ClearErrors
	; WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY (4) on Windows 8.1 and later,
	; else the default proxy (0).
	System::Call `winhttp::WinHttpOpen(w "PortableApps Compiler", i 4, p 0, p 0, i 0) p .r0`
	${If} $0 = 0
		System::Call `winhttp::WinHttpOpen(w "PortableApps Compiler", i 0, p 0, p 0, i 0) p .r0`
	${EndIf}
	${If} $0 <> 0
		System::Call `winhttp::WinHttpConnect(p r0, w r2, i r8, i 0) p .r1`
		${If} $1 <> 0
			System::Call `winhttp::WinHttpOpenRequest(p r1, w "POST", w r3, p 0, p 0, p 0, i r9) p .r2`
			${If} $2 <> 0
				StrLen $5 $R1
				System::Call `*(&m$5 R1) p .r6`
				System::Call `winhttp::WinHttpSendRequest(p r2, w "Content-Type: application/xml", i -1, p r6, i r5, i r5, p 0) i .r7`
				${If} $7 <> 0
					System::Call `winhttp::WinHttpReceiveResponse(p r2, p 0) i .r7`
				${EndIf}
				System::Free $6
				${If} $7 <> 0
					; WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER
					System::Call `winhttp::WinHttpQueryHeaders(p r2, i 0x20000013, p 0, *i .r4, *i 4, p 0) i .r7`
					${If} $4 = 200
						Delete $R2
						System::Call `kernel32::CreateFileW(w R2, i 0x40000000, i 0, p 0, i 2, i 0, p 0) p .r5`
						${If} $5 <> -1
							System::Alloc 65536
							Pop $6
							${Do}
								System::Call `winhttp::WinHttpReadData(p r2, p r6, i 65536, *i .r7) i .r4`
								${IfThen} $4 = 0 ${|} ${Break} ${|}
								${IfThen} $7 = 0 ${|} ${Break} ${|}
								System::Call `kernel32::WriteFile(p r5, p r6, i r7, *i .r4, p 0)`
							${Loop}
							System::Free $6
							System::Call `kernel32::CloseHandle(p r5)`
							StrCpy $R3 ok
						${EndIf}
					${Else}
						StrCpy $R3 "the update server answered $4"
					${EndIf}
				${EndIf}
				System::Call `winhttp::WinHttpCloseHandle(p r2)`
			${EndIf}
			System::Call `winhttp::WinHttpCloseHandle(p r1)`
		${EndIf}
		System::Call `winhttp::WinHttpCloseHandle(p r0)`
	${EndIf}
	ClearErrors
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

; $R3 = the hash of the file $R0 in lower case hexadecimal, or "". $R1 is
; the CryptoAPI algorithm (0x800C SHA-256, 0x800E SHA-512), $R2 its size in
; bytes.
Function BR_HashFile
	Push $0
	Push $1
	Push $2
	Push $3
	Push $4
	Push $5
	Push $6
	Push $8
	Push $9
	StrCpy $R3 ""
	; PROV_RSA_AES, CRYPT_VERIFYCONTEXT
	System::Call `advapi32::CryptAcquireContextW(*p .r0, p 0, p 0, i 24, i 0xF0000000) i .r9`
	${If} $9 <> 0
		System::Call `advapi32::CryptCreateHash(p r0, i R1, p 0, i 0, *p .r1) i .r9`
		${If} $9 <> 0
			; GENERIC_READ, FILE_SHARE_READ, OPEN_EXISTING
			System::Call `kernel32::CreateFileW(w R0, i 0x80000000, i 1, p 0, i 3, i 0, p 0) p .r2`
			${If} $2 <> -1
				System::Alloc 1048576
				Pop $3
				StrCpy $8 ok
				${Do}
					System::Call `kernel32::ReadFile(p r2, p r3, i 1048576, *i .r4, p 0) i .r9`
					${If} $9 = 0
						StrCpy $8 fail
						${Break}
					${EndIf}
					${IfThen} $4 = 0 ${|} ${Break} ${|}
					System::Call `advapi32::CryptHashData(p r1, p r3, i r4, i 0) i .r9`
					${If} $9 = 0
						StrCpy $8 fail
						${Break}
					${EndIf}
				${Loop}
				System::Call `kernel32::CloseHandle(p r2)`
				${If} $8 == ok
					; HP_HASHVAL
					System::Call `advapi32::CryptGetHashParam(p r1, i 2, p r3, *i R2 r4, i 0) i .r9`
					${If} $9 <> 0
					${AndIf} $4 = $R2
						StrCpy $5 0
						${Do}
							IntOp $6 $3 + $5
							System::Call `*$6(&i1 .r2)`
							IntOp $2 $2 & 0xFF
							IntFmt $2 "%02x" $2
							StrCpy $R3 `$R3$2`
							IntOp $5 $5 + 1
						${LoopUntil} $5 = $R2
					${EndIf}
				${EndIf}
				System::Free $3
			${EndIf}
			System::Call `advapi32::CryptDestroyHash(p r1)`
		${EndIf}
		System::Call `advapi32::CryptReleaseContext(p r0, i 0)`
	${EndIf}
	Pop $9
	Pop $8
	Pop $6
	Pop $5
	Pop $4
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; $R1 = the name of whoever signed the file $R0, when Windows trusts the
; signature (WinVerifyTrust), or "" when it isn't signed or isn't trusted.
Function BR_Signer
	Push $0
	Push $1
	Push $2
	Push $3
	Push $4
	Push $5
	StrCpy $R1 ""
	!ifdef BR_TEST_NO_SIGNATURES
		; Test builds only: the stand-in installers aren't signed.
		StrCpy $R1 "${BR_TEST_NO_SIGNATURES}"
	!else
	; WINTRUST_FILE_INFO: cbStruct, path, handle, subject
	System::Call `*(i 16, w R0, p 0, p 0) p .r0`
	; WINTRUST_DATA: cbStruct, policy, SIP, WTD_UI_NONE, WTD_REVOKE_NONE,
	; WTD_CHOICE_FILE, file, WTD_STATEACTION_VERIFY, state, URL, flags, UI
	; context, signature settings
	System::Call `*(i 52, p 0, p 0, i 2, i 0, i 1, p r0, i 1, p 0, p 0, i 0, i 0, p 0) p .r1`
	; WINTRUST_ACTION_GENERIC_VERIFY_V2
	System::Call `*(i 0x00AAC56B, &i2 0xCD44, &i2 0x11D0, &i1 0x8C, &i1 0xC2, &i1 0x00, &i1 0xC0, &i1 0x4F, &i1 0xC2, &i1 0x95, &i1 0xEE) p .r2`
	System::Call `wintrust::WinVerifyTrust(p -1, p r2, p r1) i .r3`
	${If} $3 = 0
		System::Call `*$1(i, p, p, i, i, i, p, i, p .r4)`
		System::Call `wintrust::WTHelperProvDataFromStateData(p r4) p .r4`
		${If} $4 <> 0
			System::Call `wintrust::WTHelperGetProvSignerFromChain(p r4, i 0, i 0, i 0) p .r4`
			${If} $4 <> 0
				; CRYPT_PROVIDER_SGNR: cbStruct, sftVerifyAsOf, csCertChain,
				; pasCertChain; CRYPT_PROVIDER_CERT: cbStruct, pCert
				System::Call `*$4(i, l, i, p .r5)`
				${If} $5 <> 0
					System::Call `*$5(i, p .r5)`
					; CERT_NAME_SIMPLE_DISPLAY_TYPE
					System::Call `crypt32::CertGetNameStringW(p r5, i 4, i 0, p 0, w .R1, i ${NSIS_MAX_STRLEN})`
				${EndIf}
			${EndIf}
		${EndIf}
	${EndIf}
	; WTD_STATEACTION_CLOSE
	System::Call `*$1(i 52, p 0, p 0, i 2, i 0, i 1, p r0, i 2)`
	System::Call `wintrust::WinVerifyTrust(p -1, p r2, p r1)`
	System::Free $2
	System::Free $1
	System::Free $0
	!endif
	Pop $5
	Pop $4
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; $R2 = 1 when version $R0 is newer than $R1, else 0.
Function BR_IsNewer
	${If} $R1 == ""
		StrCpy $R2 1
	${Else}
		${VersionCompare} $R0 $R1 $R2
		${IfThen} $R2 != 1 ${|} StrCpy $R2 0 ${|}
	${EndIf}
FunctionEnd

; $R0 = x64 or x86, the build for this computer.
Function BR_HostArch
	Push $0
	ReadEnvStr $0 PROCESSOR_ARCHITEW6432
	${If} $0 == ""
		ReadEnvStr $0 PROCESSOR_ARCHITECTURE
	${EndIf}
	${If} $0 == x86
		StrCpy $R0 x86
	${Else}
		StrCpy $R0 x64
	${EndIf}
	Pop $0
FunctionEnd

; $R1 = the version of the program file $R0 (1.2.3.4), or "".
Function BR_FileVersion
	Push $0
	Push $1
	Push $2
	Push $3
	StrCpy $R1 ""
	ClearErrors
	GetDllVersion $R0 $0 $1
	${IfNot} ${Errors}
		IntOp $2 $0 >> 16
		IntOp $2 $2 & 0xFFFF
		IntOp $3 $0 & 0xFFFF
		StrCpy $R1 `$2.$3`
		IntOp $2 $1 >> 16
		IntOp $2 $2 & 0xFFFF
		IntOp $3 $1 & 0xFFFF
		StrCpy $R1 `$R1.$2.$3`
	${EndIf}
	ClearErrors
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Picks the interface language: $R0 is the folder of the browser's
; <language>.pak files. $R1 = the Language in the user's INI, else the
; PortableApps.com Platform's language when started from it, else "". Only a
; language there's a file for is taken.
Function BR_Language
	Push $0
	Push $1
	Push $2
	StrCpy $R1 ""
	ClearErrors
	${ReadUserConfig} $0 Language
	${If} $0 != ""
		${IfThen} ${FileExists} `$R0\$0.pak` ${|} StrCpy $R1 $0 ${|}
	${Else}
		ReadEnvStr $1 PAL:_IgnoreLanguage
		${If} $1 != true
			; pt_BR is pt-BR; then the bare language; English is en-US.
			ReadEnvStr $1 PAL:LanguageGlibc
			${WordReplace} $1 "_" "-" "+" $1
			ReadEnvStr $2 PAL:LanguageCode
			${If} $1 != ""
			${AndIf} ${FileExists} `$R0\$1.pak`
				StrCpy $R1 $1
			${ElseIf} $2 != ""
			${AndIf} ${FileExists} `$R0\$2.pak`
				StrCpy $R1 $2
			${ElseIf} $2 == en
				StrCpy $R1 en-US
			${EndIf}
		${EndIf}
	${EndIf}
	ClearErrors
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Swaps the program folder App\$R0 for $R1. The old one is kept as
; $R0.previous until the new one is in place; the journal puts it back if
; the launcher stops halfway. $R2 = ok, or why not. Call BR_Preserve
; (defined by the package) to carry files over.
Function BR_Swap
	Push $0
	Push $1
	Push $R1
	StrCpy $0 `$EXEDIR\App\$R0`
	StrCpy $1 `$EXEDIR\App\$R0.previous`
	RMDir /r $1
	${Journal::Record} BrowserSwap CMD `"$SYSDIR\cmd.exe" /c if exist "$1\*" (rd /s /q "$0" 2>nul & move /y "$1" "$0")` "0" "" ""
	ClearErrors
	Rename $0 $1
	${If} ${Errors}
		${Journal::Discard} BrowserSwap
		StrCpy $R2 "the program folder is in use"
	${Else}
		Rename $R1 $0
		${If} ${Errors}
			${Journal::Rollback} BrowserSwap
			StrCpy $R2 "the new version couldn't be moved into place"
		${Else}
			Push $R0
			StrCpy $R0 $1
			StrCpy $R1 $0
			Call BR_Preserve
			Pop $R0
			${Journal::Discard} BrowserSwap
			RMDir /r $1
			StrCpy $R2 ok
		${EndIf}
	${EndIf}
	ClearErrors
	Pop $R1
	Pop $1
	Pop $0
FunctionEnd

; A launch that stopped between the two renames of a swap leaves an empty
; App\$R0 and a $R0.previous folder; that's put back. $R1 is a file that a
; complete program folder has.
Function BR_Repair
	${If} ${FileExists} `$EXEDIR\App\$R0.previous\$R1`
	${AndIfNot} ${FileExists} `$EXEDIR\App\$R0\$R1`
		RMDir /r `$EXEDIR\App\$R0`
		Rename `$EXEDIR\App\$R0.previous` `$EXEDIR\App\$R0`
	${EndIf}
	ClearErrors
FunctionEnd

; Journals a folder the browser may create: removed again if it isn't there
; yet. $R0 = the folder, $R1 = recursive to remove it with its contents.
Function BR_JournalDir
	${IfNot} ${FileExists} `$R0\*.*`
		${Journal::Record} BrowserPortable DIR $R0 "" $R1 ""
	${EndIf}
FunctionEnd

; $1 = the name of subkey (or value, when $R4 is value) number $0 of
; HKCU\$R0, or "" past the last one.
!macro BR_EnumReg
	${If} $R4 == value
		EnumRegValue $1 HKCU $R0 $0
	${Else}
		EnumRegKey $1 HKCU $R0 $0
	${EndIf}
!macroend

; Remembers which subkeys of HKCU\$R0 (or values, when $R4 is value) start
; with $R1, under the setting $R2, so the ones the browser adds can be
; removed afterward: their names end in a per-install suffix that can't be
; known in advance.
Function BR_Snapshot
	Push $0
	Push $1
	Push $2
	Push $3
	Push $5
	StrLen $3 $R1
	StrCpy $2 "|"
	StrCpy $0 0
	${Do}
		!insertmacro BR_EnumReg
		${IfThen} $1 == "" ${|} ${Break} ${|}
		StrCpy $5 $1 $3
		${IfThen} $5 == $R1 ${|} StrCpy $2 `$2$1|` ${|}
		IntOp $0 $0 + 1
	${Loop}
	CreateDirectory `${SET}`
	${WriteSettings} $2 $R2
	ClearErrors
	Pop $5
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Removes the subkeys of HKCU\$R0 (or values, when $R4 is value) starting
; with $R1 that weren't there when BR_Snapshot remembered them under $R2,
; then forgets the snapshot. Nothing happens without a snapshot.
Function BR_RemoveNew
	Push $0
	Push $1
	Push $2
	Push $3
	Push $4
	Push $5
	${ReadSettings} $2 $R2
	${If} $2 != ""
		StrLen $3 $R1
		StrCpy $4 ""
		StrCpy $0 0
		${Do}
			!insertmacro BR_EnumReg
			${IfThen} $1 == "" ${|} ${Break} ${|}
			StrCpy $5 $1 $3
			${If} $5 == $R1
				ClearErrors
				${WordFind} `x$2` `|$1|` "E+1" $5
				${IfThen} ${Errors} ${|} StrCpy $4 `$4$1|` ${|}
			${EndIf}
			IntOp $0 $0 + 1
		${Loop}
		${Do}
			ClearErrors
			${WordFind} $4 "|" "E+1" $1
			${IfThen} ${Errors} ${|} ${Break} ${|}
			${IfThen} $1 == "" ${|} ${Break} ${|}
			${If} $R4 == value
				DeleteRegValue HKCU $R0 $1
			${Else}
				DeleteRegKey HKCU `$R0\$1`
			${EndIf}
			${WordFind} $4 "|" "+1}" $4
		${Loop}
		DeleteINIStr `${SETINI}` `${APPNAME}Settings` $R2
	${EndIf}
	ClearErrors
	Pop $5
	Pop $4
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Replaces the path $R8 with $R9 (both ending in a backslash) in the file
; $R7, in the JSON-escaped form Chromium browsers store paths in
; (D:\\Apps\\) and as file URLs (file:///D:/Apps/).
Function BR_ReplacePath
	Push $0
	Push $1
	Push $2
	Push $3
	${If} ${FileExists} $R7
		${WordReplace} $R8 "\" "\\" "+" $0
		${WordReplace} $R9 "\" "\\" "+" $1
		${WordReplace} $R8 "\" "/" "+" $2
		${WordReplace} $2 " " "%20" "+" $2
		${WordReplace} $R9 "\" "/" "+" $3
		${WordReplace} $3 " " "%20" "+" $3
		${ReplaceInFile} $R7 $0 $1
		${ReplaceInFile} $R7 `file:///$2` `file:///$3`
	${EndIf}
	ClearErrors
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Calls BR_PathFiles (defined by the package) with $R8 and $R9 set when the
; package has moved: first the paths into the package, then, if the drive
; letter changed, the other paths on that drive.
Function BR_UpdatePaths
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
		Call BR_PathFiles
	${EndIf}
	StrCpy $3 $0 1 1
	StrCpy $R7 $2 1 1
	${If} $0 != $2
	${AndIf} $3 == ":"
	${AndIf} $R7 == ":"
		StrCpy $R8 `$0\`
		StrCpy $R9 `$2\`
		Call BR_PathFiles
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

; Writes the version $R1 to appinfo.ini.
Function BR_WriteVersion
	Push $0
	${If} $R1 != ""
		ReadINIStr $0 `$EXEDIR\App\AppInfo\appinfo.ini` Version DisplayVersion
		${If} $0 != $R1
			WriteINIStr `$EXEDIR\App\AppInfo\appinfo.ini` Version PackageVersion $R1
			WriteINIStr `$EXEDIR\App\AppInfo\appinfo.ini` Version DisplayVersion $R1
		${EndIf}
	${EndIf}
	ClearErrors
	Pop $0
FunctionEnd

; Whether to check for an update now: $R2 = 1 or 0. UpdateCheck=off never
; does, and the others at most every UpdateInterval days.
Function BR_UpdateDue
	Push $R0
	Push $0
	Push $1
	StrCpy $R2 0
	ClearErrors
	${ReadUserConfig} $0 UpdateCheck
	${If} $0 != off
		${ReadUserConfig} $0 UpdateInterval
		${IfThen} $0 == "" ${|} StrCpy $0 1 ${|}
		${ReadSettings} $1 LastUpdateCheck
		Call BR_Today
		StrCpy $R2 1
		${If} $1 != ""
			IntOp $1 $R0 - $1
			${If} $1 < $0
			${AndIf} $1 >= 0
				StrCpy $R2 0
			${EndIf}
		${EndIf}
	${EndIf}
	ClearErrors
	Pop $1
	Pop $0
	Pop $R0
FunctionEnd

; Remembers that an update check was made today.
Function BR_UpdateChecked
	Push $R0
	CreateDirectory `${SET}`
	Call BR_Today
	${WriteSettings} $R0 LastUpdateCheck
	Pop $R0
FunctionEnd

; Helpers

; Journals a folder that may be created: removed again if it isn't there
; yet. $R0 = the folder, $R1 = recursive to remove it with its contents.
Function NP_JournalDir
	${IfNot} ${FileExists} `$R0\*.*`
		${Journal::Record} NppPortable DIR $R0 "" $R1 ""
	${EndIf}
FunctionEnd

; $R1 = 1 when this is 64-bit Windows (x64 or ARM64), else 0.
Function NP_Is64
	Push $0
	ReadEnvStr $0 PROCESSOR_ARCHITEW6432
	${IfThen} $0 == "" ${|} ReadEnvStr $0 PROCESSOR_ARCHITECTURE ${|}
	${If} $0 == x86
		StrCpy $R1 0
	${Else}
		StrCpy $R1 1
	${EndIf}
	Pop $0
FunctionEnd

; $R1 = the machine the program file $R0 is built for: x86, x64, arm64, or
; "" when it can't be read.
Function NP_Machine
	Push $0
	Push $1
	Push $2
	StrCpy $R1 ""
	ClearErrors
	FileOpen $0 $R0 r
	${IfNot} ${Errors}
		; e_lfanew at 0x3C, then "PE\0\0" and the machine.
		FileSeek $0 0x3C SET
		FileReadByte $0 $1
		FileReadByte $0 $2
		IntOp $2 $2 << 8
		IntOp $1 $1 | $2
		IntOp $1 $1 + 4
		FileSeek $0 $1 SET
		FileReadByte $0 $1
		FileReadByte $0 $2
		FileClose $0
		IntOp $2 $2 << 8
		IntOp $1 $1 | $2
		${If} $1 = 0x14C
			StrCpy $R1 x86
		${ElseIf} $1 = 0x8664
			StrCpy $R1 x64
		${ElseIf} $1 = 0xAA64
			StrCpy $R1 arm64
		${EndIf}
	${EndIf}
	ClearErrors
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Moves what's in the folder $R0 into the folder $R1, replacing what's
; there, except the file named $R2 (which stays where it is).
Function NP_MoveContents
	Push $0
	Push $1
	${If} ${FileExists} `$R0\*.*`
		CreateDirectory $R1
		FindFirst $0 $1 `$R0\*`
		${DoWhile} $1 != ""
			${If} $1 != "."
			${AndIf} $1 != ".."
			${AndIf} $1 != $R2
				${If} ${FileExists} `$R1\$1\*.*`
					RMDir /r `$R1\$1`
				${Else}
					Delete `$R1\$1`
				${EndIf}
				Rename `$R0\$1` `$R1\$1`
			${EndIf}
			FindNext $0 $1
		${Loop}
		FindClose $0
	${EndIf}
	ClearErrors
	Pop $1
	Pop $0
FunctionEnd

; Moves what's in the folder $R0 into the folder $R1 where $R1 doesn't
; have it yet, and removes $R0 when that empties it.
Function NP_MergeOnce
	Push $0
	Push $1
	${If} ${FileExists} `$R0\*.*`
		CreateDirectory $R1
		FindFirst $0 $1 `$R0\*`
		${DoWhile} $1 != ""
			${If} $1 != "."
			${AndIf} $1 != ".."
			${AndIfNot} ${FileExists} `$R1\$1`
				Rename `$R0\$1` `$R1\$1`
			${EndIf}
			FindNext $0 $1
		${Loop}
		FindClose $0
		RMDir $R0
	${EndIf}
	ClearErrors
	Pop $1
	Pop $0
FunctionEnd

; Adding Notepad++

; PortableApps.com's package had a 32-bit Notepad++ in App\Notepad++ and a
; 64-bit one in App\Notepad++64. On 64-bit Windows the 64-bit one becomes
; App\Notepad++, and the 32-bit one is kept as App\Notepad++32.
Function NP_Adopt
	Push $R0
	Push $R1
	StrCpy $NPAdopted 0
	Call NP_Is64
	${If} $R1 = 1
	${AndIf} ${FileExists} `$EXEDIR\App\Notepad++64\notepad++.exe`
		StrCpy $R0 `${NP_APP}\notepad++.exe`
		Call NP_Machine
		${If} $R1 == ""
		${OrIf} $R1 == x86
			${If} ${FileExists} `${NP_APP}\*.*`
			${AndIfNot} ${FileExists} `$EXEDIR\App\Notepad++32\*.*`
				Rename `${NP_APP}` `$EXEDIR\App\Notepad++32`
			${EndIf}
			ClearErrors
			RMDir `${NP_APP}`
			Rename `$EXEDIR\App\Notepad++64` `${NP_APP}`
			${IfNot} ${Errors}
				StrCpy $NPAdopted 1
			${EndIf}
		${EndIf}
	${EndIf}
	ClearErrors
	Pop $R1
	Pop $R0
FunctionEnd

; A 64-bit Notepad++ can't run on 32-bit Windows, nor an ARM64 one on x64.
Function NP_CheckBuild
	Push $R0
	Push $R1
	Push $0
	StrCpy $R0 `${NP_APP}\notepad++.exe`
	${If} ${FileExists} $R0
		Call NP_Machine
		StrCpy $0 $R1
		Call NP_Is64
		${If} $R1 = 0
		${AndIf} $0 != x86
		${AndIf} $0 != ""
			MessageBox MB_OK|MB_ICONSTOP `The Notepad++ in App\Notepad++ is the $0 build, which needs 64-bit Windows. On this computer, use Notepad++'s 32-bit portable zip.`
			Call Unload
			Quit
		${EndIf}
		ReadEnvStr $R1 PROCESSOR_ARCHITEW6432
		${IfThen} $R1 == "" ${|} ReadEnvStr $R1 PROCESSOR_ARCHITECTURE ${|}
		${If} $0 == arm64
		${AndIf} $R1 != ARM64
			MessageBox MB_OK|MB_ICONSTOP `The Notepad++ in App\Notepad++ is the ARM64 build, which needs Windows on ARM. On this computer, use Notepad++'s x64 portable zip.`
			Call Unload
			Quit
		${EndIf}
	${EndIf}
	ClearErrors
	Pop $0
	Pop $R1
	Pop $R0
FunctionEnd

; Settings folder

; Writes the text $R1 to the file $R0 as UTF-8, without a byte order mark,
; as Notepad++ reads cloud\choice.
Function NP_WriteUTF8
	Push $0
	Push $1
	Push $2
	Push $3
	; The UTF-8 length, then the bytes.
	System::Call `kernel32::WideCharToMultiByte(i 65001, i 0, w R1, i -1, p 0, i 0, p 0, p 0) i .r1`
	${If} $1 > 0
		System::Alloc $1
		Pop $2
		System::Call `kernel32::WideCharToMultiByte(i 65001, i 0, w R1, i -1, p r2, i r1, p 0, p 0)`
		IntOp $1 $1 - 1
		; GENERIC_WRITE, CREATE_ALWAYS
		System::Call `kernel32::CreateFileW(w R0, i 0x40000000, i 0, p 0, i 2, i 0, p 0) p .r0`
		${If} $0 <> -1
			System::Call `kernel32::WriteFile(p r0, p r2, i r1, *i .r3, p 0)`
			System::Call `kernel32::CloseHandle(p r0)`
		${EndIf}
		System::Free $2
	${EndIf}
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; doLocalConf.xml makes Notepad++ keep plugin settings next to it instead of
; in %APPDATA%; disableNppAutoUpdate.xml stops its updater, which would
; install Notepad++ into Program Files; cloud\choice names Data\Config, so
; themes there are found (-settingsDir alone leaves Notepad++ looking for
; them next to notepad++.exe when doLocalConf.xml is there).
Function NP_SettingsFolder
	Push $R0
	Push $R1
	Push $0
	CreateDirectory `${NP_CONF}`
	${IfNot} ${FileExists} `${NP_APP}\doLocalConf.xml`
		FileOpen $0 `${NP_APP}\doLocalConf.xml` w
		FileClose $0
	${EndIf}
	${IfNot} ${FileExists} `${NP_APP}\disableNppAutoUpdate.xml`
		FileOpen $0 `${NP_APP}\disableNppAutoUpdate.xml` w
		FileClose $0
	${EndIf}
	CreateDirectory `${NP_APP}\cloud`
	StrCpy $R0 `${NP_APP}\cloud\choice`
	StrCpy $R1 `${NP_CONF}`
	Call NP_WriteUTF8
	ClearErrors
	Pop $0
	Pop $R1
	Pop $R0
FunctionEnd

; Plugin settings

; Plugin settings in App\Notepad++\plugins\Config go to Data. Run after each
; session, and before the next one in case the last one didn't close
; properly.
Function NP_PluginConfOut
	Push $R0
	Push $R1
	Push $R2
	StrCpy $R0 `${NP_APCONF}`
	StrCpy $R1 `${NP_PCONF}`
	StrCpy $R2 `${NP_LIST}`
	Call NP_MoveContents
	Pop $R2
	Pop $R1
	Pop $R0
FunctionEnd

; Plugin settings in Data go into App\Notepad++\plugins\Config for the
; session. Plugins Admin's list (nppPluginList.dll) comes with Notepad++
; and stays there; one in Data is from PortableApps.com's package.
Function NP_PluginConfIn
	Push $R0
	Push $R1
	Push $R2
	CreateDirectory `${NP_PCONF}`
	${If} ${FileExists} `${NP_PCONF}\${NP_LIST}`
		${IfNot} ${FileExists} `${NP_APCONF}\${NP_LIST}`
			CreateDirectory `${NP_APCONF}`
			Rename `${NP_PCONF}\${NP_LIST}` `${NP_APCONF}\${NP_LIST}`
		${EndIf}
		Delete `${NP_PCONF}\${NP_LIST}`
	${EndIf}
	StrCpy $R0 `${NP_PCONF}`
	StrCpy $R1 `${NP_APCONF}`
	StrCpy $R2 `${NP_LIST}`
	Call NP_MoveContents
	Pop $R2
	Pop $R1
	Pop $R0
FunctionEnd

; Session

; Notepad++ started without -settingsDir (by Plugins Admin, after it
; installs a plugin) writes session.xml next to notepad++.exe. One written
; this session is the newest; one there before it is a leftover.
Function NP_SessionIn
	${If} ${FileExists} `${NP_APP}\session.xml`
		${IfNot} ${FileExists} `${NP_CONF}\session.xml`
			Rename `${NP_APP}\session.xml` `${NP_CONF}\session.xml`
		${Else}
			Delete `${NP_APP}\session.xml`
		${EndIf}
	${EndIf}
	ClearErrors
FunctionEnd

Function NP_SessionOut
	${If} ${FileExists} `${NP_APP}\session.xml`
		Delete `${NP_CONF}\session.xml`
		Rename `${NP_APP}\session.xml` `${NP_CONF}\session.xml`
	${EndIf}
	ClearErrors
FunctionEnd

; Older layout

; PortableApps.com's package moved Data\themes and Data\toolbarIcons next
; to notepad++.exe for each session; Notepad++ finds them in Data\Config.
Function NP_Migrate
	Push $R0
	Push $R1
	StrCpy $R0 `${DATA}\themes`
	StrCpy $R1 `${NP_CONF}\themes`
	Call NP_MergeOnce
	StrCpy $R0 `${DATA}\toolbarIcons`
	StrCpy $R1 `${NP_CONF}\toolbarIcons`
	Call NP_MergeOnce
	Pop $R1
	Pop $R0
FunctionEnd

; Language

; $R0 = the localization file (no .xml) for the PortableApps.com Platform
; language name $R0, as Notepad++ names it.
Function NP_LocaleFile
	${If} $R0 == SimpChinese
		StrCpy $R0 chineseSimplified
	${ElseIf} $R0 == TradChinese
		StrCpy $R0 taiwaneseMandarin
	${ElseIf} $R0 == PortugueseBR
		StrCpy $R0 brazilian_portuguese
	${ElseIf} $R0 == SpanishInternational
		StrCpy $R0 spanish
	${ElseIf} $R0 == EnglishGB
		StrCpy $R0 english
	${ElseIf} $R0 == Serbian
		StrCpy $R0 serbianCyrillic
	${ElseIf} $R0 == SerbianLatin
		StrCpy $R0 serbian
	${ElseIf} $R0 == NorwegianNynorsk
		StrCpy $R0 nynorsk
	${EndIf}
FunctionEnd

; Sets the interface language: the Language in Notepad++Portable.ini, else
; the PortableApps.com Platform's when it's not the one it was last time.
; Notepad++ reads it from nativeLang.xml in the settings folder, a copy of
; one of its localization files, as its own language setting does.
Function NP_Language
	Push $R0
	Push $0
	Push $1
	ClearErrors
	${ReadUserConfig} $R0 Language
	${If} $R0 == ""
		ReadEnvStr $1 PAL:_IgnoreLanguage
		ReadEnvStr $0 PAL:LanguageName
		${ReadSettings} $R0 LanguageFrom
		${If} $1 != true
		${AndIf} $0 != ""
		${AndIf} $0 != $R0
			${WriteSettings} $0 LanguageFrom
			StrCpy $R0 $0
			Call NP_LocaleFile
		${Else}
			StrCpy $R0 ""
		${EndIf}
	${EndIf}
	${If} $R0 != ""
	${AndIf} ${FileExists} `${NP_APP}\localization\$R0.xml`
		CopyFiles /SILENT `${NP_APP}\localization\$R0.xml` `${NP_CONF}`
		Delete `${NP_CONF}\nativeLang.xml`
		Rename `${NP_CONF}\$R0.xml` `${NP_CONF}\nativeLang.xml`
	${EndIf}
	ClearErrors
	Pop $1
	Pop $0
	Pop $R0
FunctionEnd

; Moving the package

; Replaces the path $R8 with $R9 in the file $R7: UTF-16 when it starts with
; a byte order mark (the Explorer plugin's), else as it's written, and in
; XML files also with & written as &amp;.
Function NP_ReplaceIn
	Push $0
	Push $1
	Push $2
	${If} ${FileExists} $R7
		StrCpy $2 ""
		FileOpen $0 $R7 r
		FileReadByte $0 $1
		${If} $1 = 0xFF
			FileReadByte $0 $1
			${IfThen} $1 = 0xFE ${|} StrCpy $2 u16 ${|}
		${EndIf}
		FileClose $0
		${If} $2 == u16
			${ReplaceInFileU16} $R7 $R8 $R9
		${Else}
			${ReplaceInFile} $R7 $R8 $R9
			StrCpy $2 $R7 4 -4
			${WordReplace} $R8 "&" "&amp;" "+" $0
			${If} $2 == .xml
			${AndIf} $0 != $R8
				${WordReplace} $R9 "&" "&amp;" "+" $1
				${ReplaceInFile} $R7 $0 $1
			${EndIf}
		${EndIf}
	${EndIf}
	ClearErrors
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; The files that hold paths. $R8 and $R9 end in a backslash.
Function NP_PathFiles
	Push $R7
	StrCpy $R7 `${NP_CONF}\session.xml`
	Call NP_ReplaceIn
	StrCpy $R7 `${NP_CONF}\config.xml`
	Call NP_ReplaceIn
	StrCpy $R7 `${NP_CONF}\shortcuts.xml`
	Call NP_ReplaceIn
	StrCpy $R7 `${NP_PCONF}\Explorer.ini`
	Call NP_ReplaceIn
	StrCpy $R7 `${NP_PCONF}\Favorites.dat`
	Call NP_ReplaceIn
	Pop $R7
FunctionEnd

; The shared helpers' path update (unused here; NP_UpdatePaths does it)
; calls this.
Function BR_PathFiles
	Call NP_PathFiles
FunctionEnd

; When the package has moved: first the paths into the package, then, if
; the drive letter changed, the other paths on that drive. After App\Notepad++64
; became App\Notepad++, paths into it follow.
Function NP_UpdatePaths
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
		Call NP_PathFiles
	${EndIf}
	StrCpy $3 $0 1 1
	StrCpy $R7 $2 1 1
	${If} $0 != $2
	${AndIf} $3 == ":"
	${AndIf} $R7 == ":"
		StrCpy $R8 `$0\`
		StrCpy $R9 `$2\`
		Call NP_PathFiles
	${EndIf}
	${If} $NPAdopted = 1
		StrCpy $R8 `$EXEDIR\App\Notepad++64\`
		StrCpy $R9 `${NP_APP}\`
		Call NP_PathFiles
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

; Remembers which extensions in the Classes key $R0 (of HKLM or HKCU, $R1)
; open with Notepad++ (default value Notepad++_file), under the setting
; $R2, so the ones a session adds can be put back afterward.
Function NP_AssocSnapshot
	Push $0
	Push $1
	Push $2
	Push $3
	StrCpy $2 "|"
	StrCpy $0 0
	${Do}
		${If} $R1 == HKLM
			EnumRegKey $1 HKLM $R0 $0
		${Else}
			EnumRegKey $1 HKCU $R0 $0
		${EndIf}
		${IfThen} $1 == "" ${|} ${Break} ${|}
		StrCpy $3 $1 1
		${If} $3 == "."
			${If} $R1 == HKLM
				ReadRegStr $3 HKLM `$R0\$1` ""
			${Else}
				ReadRegStr $3 HKCU `$R0\$1` ""
			${EndIf}
			${IfThen} $3 == `${NP_TYPE}` ${|} StrCpy $2 `$2$1|` ${|}
		${EndIf}
		IntOp $0 $0 + 1
	${Loop}
	CreateDirectory `${SET}`
	${WriteSettings} $2 $R2
	ClearErrors
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Extensions in $R0 of $R1 that open with Notepad++ now, but didn't when
; NP_AssocSnapshot ran under $R2, get their earlier file type back (which
; Notepad++ keeps as Notepad++_backup), or none. Also run on the launch after
; a crash.
Function NP_AssocRestore
	Push $0
	Push $1
	Push $2
	Push $3
	Push $4
	${ReadSettings} $2 $R2
	${If} $2 != ""
		StrCpy $4 ""
		StrCpy $0 0
		${Do}
			${If} $R1 == HKLM
				EnumRegKey $1 HKLM $R0 $0
			${Else}
				EnumRegKey $1 HKCU $R0 $0
			${EndIf}
			${IfThen} $1 == "" ${|} ${Break} ${|}
			StrCpy $3 $1 1
			${If} $3 == "."
				${If} $R1 == HKLM
					ReadRegStr $3 HKLM `$R0\$1` ""
				${Else}
					ReadRegStr $3 HKCU `$R0\$1` ""
				${EndIf}
				${If} $3 == `${NP_TYPE}`
					ClearErrors
					${WordFind} `x$2` `|$1|` "E+1" $3
					${IfThen} ${Errors} ${|} StrCpy $4 `$4$1|` ${|}
				${EndIf}
			${EndIf}
			IntOp $0 $0 + 1
		${Loop}
		${Do}
			ClearErrors
			${WordFind} $4 "|" "E+1" $1
			${IfThen} ${Errors} ${|} ${Break} ${|}
			${IfThen} $1 == "" ${|} ${Break} ${|}
			${If} $R1 == HKLM
				ReadRegStr $3 HKLM `$R0\$1` Notepad++_backup
				${If} $3 != ""
					WriteRegStr HKLM `$R0\$1` "" $3
					DeleteRegValue HKLM `$R0\$1` Notepad++_backup
				${Else}
					DeleteRegValue HKLM `$R0\$1` ""
					DeleteRegKey /ifempty HKLM `$R0\$1`
				${EndIf}
			${Else}
				ReadRegStr $3 HKCU `$R0\$1` Notepad++_backup
				${If} $3 != ""
					WriteRegStr HKCU `$R0\$1` "" $3
					DeleteRegValue HKCU `$R0\$1` Notepad++_backup
				${Else}
					DeleteRegValue HKCU `$R0\$1` ""
					DeleteRegKey /ifempty HKCU `$R0\$1`
				${EndIf}
			${EndIf}
			${WordFind} $4 "|" "+1}" $4
		${Loop}
		DeleteINIStr `${SETINI}` `${APPNAME}Settings` $R2
	${EndIf}
	ClearErrors
	Pop $4
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Preferences > File Association writes to HKEY_CLASSES_ROOT, which takes
; administrator rights, so it's only looked after when the launcher runs as
; administrator. $R3 = Restore or Snapshot.
!macro NP_Associations _CALL
	Push $R0
	Push $R1
	Push $R2
	Push $0
	System::Call `shell32::IsUserAnAdmin() i .r0`
	${If} $0 <> 0
		StrCpy $R0 `SOFTWARE\Classes`
		StrCpy $R1 HKLM
		StrCpy $R2 SnapAssocHKLM
		Call NP_Assoc${_CALL}
	${EndIf}
	StrCpy $R0 `Software\Classes`
	StrCpy $R1 HKCU
	StrCpy $R2 SnapAssocHKCU
	Call NP_Assoc${_CALL}
	Pop $0
	Pop $R2
	Pop $R1
	Pop $R0
!macroend

Function NP_JournalWindows
	Push $R0
	Push $R1
	Push $0
	; Notepad++'s file type, and Explorer's Open with entry.
	${Journal::RegKey} NppPortable HKCU `Software\Classes\${NP_TYPE}` $0
	${Journal::RegKey} NppPortable HKCU `Software\Classes\Applications\notepad++.exe` $0
	System::Call `shell32::IsUserAnAdmin() i .r0`
	${If} $0 <> 0
		${Journal::RegKey} NppPortable HKLM `SOFTWARE\Classes\${NP_TYPE}` $0
	${EndIf}
	; Extensions set to open with Notepad++: a crashed session's go first,
	; then the current ones are remembered.
	!insertmacro NP_Associations Restore
	!insertmacro NP_Associations Snapshot
	; Notepad++'s default settings folder, if anything still uses it.
	StrCpy $R1 recursive
	StrCpy $R0 `$APPDATA\Notepad++`
	Call NP_JournalDir
	StrCpy $R0 `$LOCALAPPDATA\Notepad++`
	Call NP_JournalDir
	ClearErrors
	Pop $0
	Pop $R1
	Pop $R0
FunctionEnd

; Writes the version of notepad++.exe to appinfo.ini: 8.9.8.1 as
; PackageVersion, and as DisplayVersion without a last .0 (8.9.8).
Function NP_WriteVersion
	Push $0
	Push $1
	Push $2
	Push $3
	Push $4
	ClearErrors
	GetDllVersion `${NP_APP}\notepad++.exe` $0 $1
	${IfNot} ${Errors}
		IntOp $2 $0 >> 16
		IntOp $2 $2 & 0xFFFF
		IntOp $3 $0 & 0xFFFF
		IntOp $4 $1 >> 16
		IntOp $4 $4 & 0xFFFF
		IntOp $1 $1 & 0xFFFF
		StrCpy $0 `$2.$3.$4.$1`
		StrCpy $2 `$2.$3.$4`
		${IfThen} $1 <> 0 ${|} StrCpy $2 $0 ${|}
		ReadINIStr $3 `${NP_INFO}` Version PackageVersion
		${If} $0 != $3
		${AndIf} $0 != "0.0.0.0"
			WriteINIStr `${NP_INFO}` Version PackageVersion $0
			WriteINIStr `${NP_INFO}` Version DisplayVersion $2
		${EndIf}
	${EndIf}
	ClearErrors
	Pop $4
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Install and updates

; $R1 = the version of the Notepad++ in the folder $R0 (8.9.8.1, or 8.9.8
; for 8.9.8.0), or "" when there's none.
Function NP_InstalledVersion
	Push $R0
	StrCpy $R0 `$R0\notepad++.exe`
	StrCpy $R1 ""
	${If} ${FileExists} $R0
		Call BR_FileVersion
		StrCpy $R0 $R1 2 -2
		${IfThen} $R0 == ".0" ${|} StrCpy $R1 $R1 -2 ${|}
	${EndIf}
	ClearErrors
	Pop $R0
FunctionEnd

; $R0 = the part of the zip name for a build: .x64, .arm64, or "" for x86
; (npp.8.9.8.portable.zip). $R0 comes in as x64, arm64 or x86.
Function NP_ZipSuffix
	${If} $R0 == x86
		StrCpy $R0 ""
	${Else}
		StrCpy $R0 `.$R0`
	${EndIf}
FunctionEnd

; $R0 = the build for this computer: x64, arm64 or x86.
Function NP_HostBuild
	Push $0
	ReadEnvStr $0 PROCESSOR_ARCHITEW6432
	${IfThen} $0 == "" ${|} ReadEnvStr $0 PROCESSOR_ARCHITECTURE ${|}
	${If} $0 == ARM64
		StrCpy $R0 arm64
	${ElseIf} $0 == x86
		StrCpy $R0 x86
	${Else}
		StrCpy $R0 x64
	${EndIf}
	Pop $0
FunctionEnd

; $R1 = 1 when $R0 is 64 hexadecimal digits, else 0.
Function NP_IsSha256
	Push $0
	StrCpy $R1 0
	StrLen $0 $R0
	${If} $0 = 64
		${StrFilter} $R0 "1" "abcdefABCDEF" "" $0
		${IfThen} $0 S== $R0 ${|} StrCpy $R1 1 ${|}
	${EndIf}
	Pop $0
FunctionEnd

; Asks GitHub for Notepad++'s latest release: sets $NPTag, $NPVersion and
; $NPDigest, the SHA-256 the release notes give for the portable zip of
; build $R0 (x64, arm64 or x86). $R2 = ok, or why not.
;
; GitHub's answer may come as one long line, so it's read in pieces, with
; the end of each piece kept for the next, and white space taken out:
; "tag_name": "v8.9.8" reads "tag_name":"v8.9.8" either way. The release
; notes list "<checksum>  <file name>" for every download.
Function NP_LatestRelease
	Push $R0
	Push $R1
	Push $0
	Push $1
	Push $2
	Push $3
	Push $4
	Push $5
	StrCpy $NPTag ""
	StrCpy $NPVersion ""
	StrCpy $NPDigest ""
	Call NP_ZipSuffix
	StrCpy $5 $R0
	ClearErrors
	${ReadUserConfig} $0 ReleaseURL
	${IfThen} $0 == "" ${|} StrCpy $0 `${NP_RELEASE}` ${|}
	CreateDirectory `${NP_STAGE}`
	StrCpy $R0 $0
	StrCpy $R1 `${NP_STAGE}\release.json`
	Call BR_Download
	${If} $R2 != ok
		StrCpy $R2 "GitHub couldn't be reached ($R2)"
		Goto NP_LatestRelease_End
	${EndIf}
	StrCpy $2 ""
	FileOpen $0 $R1 r
	${Do}
		ClearErrors
		FileRead $0 $1 800
		${IfThen} ${Errors} ${|} ${Break} ${|}
		${WordReplace} $1 " " "" "+" $1
		${WordReplace} $1 "$\t" "" "+" $1
		${WordReplace} $1 "$\r" "" "+" $1
		${WordReplace} $1 "$\n" "" "+" $1
		StrCpy $2 `$2$1`
		${If} $NPTag == ""
			ClearErrors
			${WordFind} `x$2` `"tag_name":"` "E+1}" $3
			${IfNot} ${Errors}
				${WordFind} `x$3` `"` "E+1{" $3
				${IfNot} ${Errors}
					StrCpy $NPTag $3 "" 1
					StrCpy $NPVersion $NPTag
					StrCpy $3 $NPVersion 1
					${IfThen} $3 == v ${|} StrCpy $NPVersion $NPVersion "" 1 ${|}
				${EndIf}
			${EndIf}
		${EndIf}
		${If} $NPVersion != ""
		${AndIf} $NPDigest == ""
			; Each place the zip's name comes, the 64 characters before it
			; are its checksum in the release notes.
			StrCpy $4 1
			${Do}
				ClearErrors
				${WordFind} `x$2` `npp.$NPVersion.portable$5.zip` "E+$4{" $3
				${IfThen} ${Errors} ${|} ${Break} ${|}
				StrCpy $R0 $3 64 -64
				Call NP_IsSha256
				${If} $R1 = 1
					${StrFilter} $R0 "-" "" "" $NPDigest
					${Break}
				${EndIf}
				IntOp $4 $4 + 1
			${Loop}
		${EndIf}
		StrCpy $2 $2 "" -200
	${Loop}
	FileClose $0
	${If} $NPVersion == ""
		StrCpy $R2 "GitHub didn't name a Notepad++ release"
	${ElseIf} $NPDigest == ""
		StrCpy $R2 "the release notes of Notepad++ $NPVersion give no checksum for its portable zip"
	${Else}
		StrCpy $R2 ok
	${EndIf}
	NP_LatestRelease_End:
	Delete `${NP_STAGE}\release.json`
	ClearErrors
	Pop $5
	Pop $4
	Pop $3
	Pop $2
	Pop $1
	Pop $0
	Pop $R1
	Pop $R0
FunctionEnd

; $R0 = 7z.exe of a 7-Zip on this computer or next to the package, or "".
Function NP_Find7z
	Push $0
	Push $1
	StrCpy $R0 ""
	${GetParent} $EXEDIR $1
	${If} ${FileExists} `$EXEDIR\App\7-Zip\7z.exe`
		StrCpy $R0 `$EXEDIR\App\7-Zip\7z.exe`
	${ElseIf} ${FileExists} `$1\7-ZipPortable\App\7-Zip64\7z.exe`
		StrCpy $R0 `$1\7-ZipPortable\App\7-Zip64\7z.exe`
	${ElseIf} ${FileExists} `$1\7-ZipPortable\App\7-Zip\7z.exe`
		StrCpy $R0 `$1\7-ZipPortable\App\7-Zip\7z.exe`
	${Else}
		SetRegView 64
		ReadRegStr $0 HKLM `SOFTWARE\7-Zip` Path
		SetRegView lastused
		${IfThen} $0 == "" ${|} ReadRegStr $0 HKCU `SOFTWARE\7-Zip` Path ${|}
		${If} $0 != ""
		${AndIf} ${FileExists} `$0\7z.exe`
			StrCpy $R0 `$0\7z.exe`
		${EndIf}
	${EndIf}
	ClearErrors
	Pop $1
	Pop $0
FunctionEnd

; Unpacks the zip $R0 into the folder $R1, with tar.exe (Windows 10 1803 and
; later) or 7-Zip. $R2 = ok, or why not.
Function NP_Unzip
	Push $R0
	Push $0
	Push $1
	StrCpy $1 $R0
	CreateDirectory $R1
	StrCpy $R2 "the download couldn't be unpacked (Windows' tar.exe or 7-Zip is needed)"
	${If} ${FileExists} `$SYSDIR\tar.exe`
		nsExec::ExecToStack `"$SYSDIR\tar.exe" -xf "$1" -C "$R1"`
		Pop $0
		Pop $R0
		${IfThen} $0 == 0 ${|} StrCpy $R2 ok ${|}
	${EndIf}
	${If} $R2 != ok
		Call NP_Find7z
		${If} $R0 != ""
			RMDir /r $R1
			CreateDirectory $R1
			nsExec::ExecToStack `"$R0" x -y "-o$R1" "$1"`
			Pop $0
			Pop $R0
			${IfThen} $0 == 0 ${|} StrCpy $R2 ok ${|}
		${EndIf}
	${EndIf}
	ClearErrors
	Pop $1
	Pop $0
	Pop $R0
FunctionEnd

; Downloads, checks and unpacks Notepad++ $NPVersion for build $R0 (x64,
; arm64 or x86) in the staging folder. $R2 = ok, or why not; $R3 = the new
; Notepad++ folder.
Function NP_Fetch
	Push $R0
	Push $R1
	Push $0
	Push $1
	Push $2
	Call NP_ZipSuffix
	${ReadUserConfig} $0 DownloadURL
	${IfThen} $0 == "" ${|} StrCpy $0 `${NP_DOWNLOAD}` ${|}
	StrCpy $1 `npp.$NPVersion.portable$R0.zip`
	StrCpy $2 `${NP_STAGE}\$1`
	RMDir /r `${NP_STAGE}\files`
	Banner::show `Downloading Notepad++ $NPVersion from GitHub...`
	StrCpy $R0 `$0/$NPTag/$1`
	StrCpy $R1 $2
	Call BR_Download
	Banner::destroy
	${If} $R2 != ok
		StrCpy $R2 "Notepad++ couldn't be downloaded ($R2)"
		Goto NP_Fetch_End
	${EndIf}
	StrCpy $R0 $2
	StrCpy $R1 0x800C
	StrCpy $R2 32
	Push $R3
	Call BR_HashFile
	StrCpy $0 $R3
	Pop $R3
	${If} $0 != $NPDigest
		StrCpy $R2 "the download doesn't match the checksum in the release notes"
		Goto NP_Fetch_End
	${EndIf}
	StrCpy $R0 $2
	StrCpy $R1 `${NP_STAGE}\files`
	Call NP_Unzip
	${If} $R2 != ok
		Goto NP_Fetch_End
	${EndIf}
	; The portable zip has notepad++.exe at the top; one folder in it is
	; taken too.
	StrCpy $R3 `${NP_STAGE}\files`
	${IfNot} ${FileExists} `$R3\notepad++.exe`
		FindFirst $0 $1 `${NP_STAGE}\files\*`
		${DoWhile} $1 != ""
			${If} ${FileExists} `${NP_STAGE}\files\$1\notepad++.exe`
				StrCpy $R3 `${NP_STAGE}\files\$1`
			${EndIf}
			FindNext $0 $1
		${Loop}
		FindClose $0
	${EndIf}
	; Signed by Notepad++, and trusted by Windows.
	StrCpy $R0 `$R3\notepad++.exe`
	Call BR_Signer
	StrCpy $1 $R1
	StrCpy $R0 $R3
	Call NP_InstalledVersion
	StrCpy $0 $R1
	${If} $0 == ""
		StrCpy $R2 "the download doesn't hold Notepad++"
	${ElseIf} $1 != `${NP_SIGNER}`
		StrCpy $R2 "notepad++.exe isn't signed by Notepad++"
	${Else}
		${VersionCompare} $0 $NPVersion $1
		${If} $1 != 0
			StrCpy $R2 "the download holds Notepad++ $0, not $NPVersion"
		${Else}
			StrCpy $R2 ok
		${EndIf}
	${EndIf}
	NP_Fetch_End:
	Delete $2
	ClearErrors
	Pop $2
	Pop $1
	Pop $0
	Pop $R1
	Pop $R0
FunctionEnd

; After an update, the plugins you installed (folders in the old plugins
; folder that the new Notepad++ doesn't bring) go into the new one. $R0 is
; the old Notepad++ folder, $R1 the new one.
Function BR_Preserve
	Push $0
	Push $1
	FindFirst $0 $1 `$R0\plugins\*`
	${DoWhile} $1 != ""
		${If} $1 != "."
		${AndIf} $1 != ".."
		${AndIf} $1 != Config
		${AndIf} ${FileExists} `$R0\plugins\$1\*.*`
		${AndIfNot} ${FileExists} `$R1\plugins\$1`
			CreateDirectory `$R1\plugins`
			Rename `$R0\plugins\$1` `$R1\plugins\$1`
		${EndIf}
		FindNext $0 $1
	${Loop}
	FindClose $0
	ClearErrors
	Pop $1
	Pop $0
FunctionEnd

; Shows why an install or update failed. $R2 is the reason; $R4 is
; downloaded or updated.
Function NP_Failed
	${If} $R4 == updated
		MessageBox MB_OK|MB_ICONEXCLAMATION `Notepad++ couldn't be updated: $R2.$\r$\n$\r$\nThe Notepad++ you have starts as it is. The update is offered again at the next check.`
	${Else}
		MessageBox MB_OK|MB_ICONEXCLAMATION `Notepad++ couldn't be downloaded: $R2.$\r$\n$\r$\nYou can also download Notepad++'s portable zip from notepad-plus-plus.org/downloads and unpack it into this package's App\Notepad++ folder.`
	${EndIf}
FunctionEnd

; The first launch: the package has no Notepad++ yet.
Function NP_FirstInstall
	Push $R0
	Push $R2
	Push $R3
	Push $R4
	StrCpy $R4 downloaded
	MessageBox MB_YESNO|MB_ICONQUESTION `Notepad++ isn't in this package yet.$\r$\n$\r$\nDownload the latest release from GitHub now? It's about 7 MB, and it's checked (the checksum in its release notes, and Notepad++'s signature) before it's used.$\r$\n$\r$\nNo stops here. You can also unpack Notepad++'s portable zip into this package's App\Notepad++ folder yourself.` IDYES NP_FirstInstall_Go
	Call Unload
	Quit
	NP_FirstInstall_Go:
	Call NP_HostBuild
	Call NP_LatestRelease
	${If} $R2 == ok
		Call NP_Fetch
	${EndIf}
	${If} $R2 == ok
		RMDir /r `${NP_APP}`
		ClearErrors
		Rename $R3 `${NP_APP}`
		${If} ${Errors}
			StrCpy $R2 "the new Notepad++ couldn't be moved into place"
		${EndIf}
	${EndIf}
	RMDir /r `${NP_STAGE}`
	${If} $R2 == ok
		Call BR_UpdateChecked
	${Else}
		Call NP_Failed
		Call Unload
		Quit
	${EndIf}
	Pop $R4
	Pop $R3
	Pop $R2
	Pop $R0
FunctionEnd

; Updates Notepad++ when there's a newer release, keeping the build in use
; (x64, arm64 or x86).
Function NP_UpdateCheck
	Push $R0
	Push $R1
	Push $R2
	Push $R3
	Push $R4
	Push $0
	StrCpy $R4 updated
	Call BR_UpdateDue
	${If} $R2 = 1
		StrCpy $R0 `${NP_APP}\notepad++.exe`
		Call NP_Machine
		StrCpy $R0 $R1
		${IfThen} $R0 == "" ${|} Call NP_HostBuild ${|}
		Call NP_LatestRelease
		${If} $R2 == ok
			Call BR_UpdateChecked
			Push $R0
			StrCpy $R0 `${NP_APP}`
			Call NP_InstalledVersion
			StrCpy $0 $R1
			StrCpy $R0 $NPVersion
			Call BR_IsNewer
			Pop $R0
			${If} $R2 = 1
				${ReadUserConfig} $R2 UpdateCheck
				StrCpy $R1 yes
				${If} $R2 != auto
					MessageBox MB_YESNO|MB_ICONQUESTION `Notepad++ $NPVersion is available. This package has Notepad++ $0.$\r$\n$\r$\nUpdate now? It's downloaded from GitHub (about 7 MB) and checked before Notepad++ starts. Your settings and the plugins you installed are kept.$\r$\n$\r$\nNo starts Notepad++ $0 as it is.` IDYES +2
					StrCpy $R1 no
				${EndIf}
				${If} $R1 == yes
					; The staging folder goes if the launcher stops halfway.
					${Journal::Record} BrowserStage DIR `${NP_STAGE}` "" recursive ""
					Call NP_Fetch
					${If} $R2 == ok
						StrCpy $R0 Notepad++
						StrCpy $R1 $R3
						Call BR_Swap
					${EndIf}
					${IfThen} $R2 != ok ${|} Call NP_Failed ${|}
					${Journal::Rollback} BrowserStage
				${EndIf}
			${EndIf}
		${EndIf}
	${EndIf}
	RMDir /r `${NP_STAGE}`
	ClearErrors
	Pop $0
	Pop $R4
	Pop $R3
	Pop $R2
	Pop $R1
	Pop $R0
FunctionEnd

; Hooks

${SegmentFile}

; Before anything looks for Notepad++: PortableApps.com's 64-bit Notepad++
; is moved into place first.
${Segment.onInit}
	Call NP_Adopt
!macroend

; Init runs before the launcher looks for Notepad++, so a package without
; Notepad++ can get one first.
${SegmentInit}
	StrCpy $R0 Notepad++
	StrCpy $R1 notepad++.exe
	Call BR_Repair
	RMDir /r `${NP_STAGE}`
	${IfNot} ${FileExists} `${NP_APP}\notepad++.exe`
		Call NP_FirstInstall
	${EndIf}
	Call NP_CheckBuild
!macroend

; Plugin settings and a stray session go to Data before an update swaps the
; program folder; the settings folder files are written after it.
${SegmentPrePrimary}
	Call NP_Migrate
	Call NP_PluginConfOut
	Call NP_SessionIn
	Call NP_UpdateCheck
	Call NP_SettingsFolder
	; Paths first: plugin settings are updated while they're in Data.
	Call NP_UpdatePaths
	Call NP_PluginConfIn
	Call NP_Language
	Call NP_JournalWindows
!macroend

${SegmentPostPrimary}
	Call NP_PluginConfOut
	Call NP_SessionOut
	!insertmacro NP_Associations Restore
	${Journal::HasEntries} NppPortable $R0
	${If} $R0 > 0
		${Journal::Rollback} NppPortable
	${EndIf}
	Call NP_WriteVersion
!macroend
