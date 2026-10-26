; Opera Portable custom code for PortableApps Compiler.
; For support, visit the GitHub project:
; https://github.com/daemondevin/pac-man
;
; Opera runs from App\Opera with its user data in Data\profile. What this
; file adds:
;
;   Install        The package doesn't ship Opera (its license doesn't allow
;                  passing it on). The first launch offers to download it from
;                  Opera's server: the newest version in Opera's release
;                  folder, checked against Opera's signature (and its
;                  published SHA-256 when there is one), then installed into
;                  the package with the installer's own --copyonly mode, which
;                  copies the files and registers nothing.
;   Updates        The same, before Opera starts, at most every UpdateInterval
;                  days. The swap is journaled, so a crash halfway puts the old
;                  Opera back. Opera's own updater is set aside: it would
;                  install into the package without the launcher.
;   Language       Follows the PortableApps.com Platform's language (or the
;                  Language in OperaPortable.ini) with --lang.
;   Moving         Paths in the profile's Preferences and Opera's
;                  installation_status.json are updated when the package moves.
;   Leftovers      HKCU\Software\Opera Software is journaled and put back, the
;                  folders Opera may create in %APPDATA% and %LOCALAPPDATA% are
;                  removed again, and so is a "Make default" registration.
;   Version        The version that ran is written to appinfo.ini.

; Defines
!define OP_APP      `$EXEDIR\App\Opera`
!define OP_STAGE    `$EXEDIR\App\OperaUpdate`
!define OP_PROFILE  `${DATA}\profile`
!define OP_RELEASES `https://get.geo.opera.com/pub/opera/desktop`
!define OP_SIGNER   `Opera Norway AS`

; Variables
Var OPVersion       ; the version on offer
Var OPLang          ; the --lang for this launch, or ""

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

; Opera's side

; Sets $OPVersion to the newest version in Opera's release folder (or the
; ArchiveURL in OperaPortable.ini). $R2 = ok, or why not.
Function OP_LatestVersion
	Push $R0
	Push $R1
	Push $0
	Push $1
	Push $2
	Push $3
	ClearErrors
	${ReadUserConfig} $0 ArchiveURL
	${IfThen} $0 == "" ${|} StrCpy $0 `${OP_RELEASES}` ${|}
	CreateDirectory `${OP_STAGE}`
	StrCpy $R0 `$0/`
	StrCpy $R1 `${OP_STAGE}\releases.html`
	Call BR_Download
	StrCpy $OPVersion ""
	${If} $R2 == ok
		; Every link to a folder named like 137.0.6036.39 is a release.
		FileOpen $0 $R1 r
		${Do}
			ClearErrors
			FileRead $0 $1
			${IfThen} ${Errors} ${|} ${Break} ${|}
			${Do}
				ClearErrors
				${WordFind} $1 `href="` "E+1}" $1
				${IfThen} ${Errors} ${|} ${Break} ${|}
				${WordFind} $1 `/"` "E+1" $2
				${IfThen} ${Errors} ${|} ${Continue} ${|}
				; Four numbers and nothing else.
				${WordFind} $2 "." "#" $3
				${If} $3 == 4
					${WordFind} $2 "." "+1" $3
					IntOp $3 $3 + 0
					${If} $3 > 0
						Push $R0
						Push $R1
						Push $R2
						StrCpy $R0 $2
						StrCpy $R1 $OPVersion
						Call BR_IsNewer
						${IfThen} $R2 = 1 ${|} StrCpy $OPVersion $2 ${|}
						Pop $R2
						Pop $R1
						Pop $R0
					${EndIf}
				${EndIf}
			${Loop}
		${Loop}
		FileClose $0
		${If} $OPVersion == ""
			StrCpy $R2 "Opera's release folder didn't list a version"
		${Else}
			StrCpy $R2 ok
		${EndIf}
	${Else}
		StrCpy $R2 "Opera's release folder couldn't be read ($R2)"
	${EndIf}
	Delete `${OP_STAGE}\releases.html`
	ClearErrors
	Pop $3
	Pop $2
	Pop $1
	Pop $0
	Pop $R1
	Pop $R0
FunctionEnd

; $R0 = the registry and scheduled task state the Opera installer could
; change, remembered (snapshot) or cleaned up (remove), per $R5.
!macro OP_InstallerTraces _CALL
	StrCpy $R4 key
	StrCpy $R0 `Software\Microsoft\Windows\CurrentVersion\Uninstall`
	StrCpy $R1 Opera
	StrCpy $R2 SnapUninstall
	Call ${_CALL}
	StrCpy $R4 value
	StrCpy $R0 `Software\Microsoft\Windows\CurrentVersion\Run`
	StrCpy $R2 SnapRun
	Call ${_CALL}
!macroend

; Runs the Opera installer $R0 into the folder $R1 in copy-only mode, and
; removes anything it registered anyway. $R2 = ok, or why not.
Function OP_RunInstaller
	Push $R0
	Push $R1
	Push $R4
	Push $0
	Push $1
	Push $2
	StrCpy $1 $R0
	StrCpy $2 $R1
	${Journal::RegKeyExists} HKCU `Software\Opera Software` $0
	Push $0
	!insertmacro OP_InstallerTraces BR_Snapshot
	ExecWait `"$1" --silent --copyonly=1 --singleprofile=1 --allusers=0 --launchopera=0 --setdefaultbrowser=0 --desktopshortcut=0 --startmenushortcut=0 --pintotaskbar=0 "--installfolder=$2"` $0
	!insertmacro OP_InstallerTraces BR_RemoveNew
	Pop $0
	${If} $0 = 0
		DeleteRegKey HKCU `Software\Opera Software`
	${EndIf}
	; Opera's own updater would update the package behind the launcher's back.
	${If} ${FileExists} `$2\autoupdate\opera_autoupdate.exe`
		Delete `$2\autoupdate\opera_autoupdate.exe.disabled`
		Rename `$2\autoupdate\opera_autoupdate.exe` `$2\autoupdate\opera_autoupdate.exe.disabled`
	${EndIf}
	StrCpy $R0 `$2\opera.exe`
	Call BR_FileVersion
	${If} $R1 == ""
		StrCpy $R2 "the installer didn't install Opera"
	${ElseIf} $R1 != $OPVersion
		StrCpy $R2 "the installer installed Opera $R1, not $OPVersion"
	${Else}
		StrCpy $R2 ok
	${EndIf}
	ClearErrors
	Pop $2
	Pop $1
	Pop $0
	Pop $R4
	Pop $R1
	Pop $R0
FunctionEnd

; $R2 = ok when $R0 is 64 hexadecimal digits, else "".
Function OP_IsHex
	Push $0
	Push $1
	StrCpy $R2 ""
	StrLen $0 $R0
	${If} $0 = 64
		StrCpy $R2 ok
		StrCpy $0 0
		${Do}
			StrCpy $1 $R0 1 $0
			${IfThen} $1 == "" ${|} ${Break} ${|}
			${WordFind} "x0123456789abcdefABCDEF" $1 "E+1" $1
			${If} ${Errors}
				StrCpy $R2 ""
				${Break}
			${EndIf}
			IntOp $0 $0 + 1
		${Loop}
	${EndIf}
	ClearErrors
	Pop $1
	Pop $0
FunctionEnd

; Downloads and checks Opera $OPVersion for build $R0 (x64 or x86), and
; installs it in the staging folder. $R2 = ok, or why not; $R3 = the new
; Opera folder.
Function OP_Fetch
	Push $R0
	Push $R1
	Push $0
	Push $1
	Push $2
	Push $3
	${ReadUserConfig} $0 ArchiveURL
	${IfThen} $0 == "" ${|} StrCpy $0 `${OP_RELEASES}` ${|}
	StrCpy $1 `Opera_$OPVersion`
	${If} $R0 == x64
		StrCpy $1 `$1_Setup_x64.exe`
	${Else}
		StrCpy $1 `$1_Setup.exe`
	${EndIf}
	StrCpy $3 `$0/$OPVersion/win/$1`
	StrCpy $2 `${OP_STAGE}\$1`
	RMDir /r `${OP_STAGE}\Opera`
	Banner::show `Downloading Opera $OPVersion from Opera...`
	StrCpy $R0 $3
	StrCpy $R1 $2
	Call BR_Download
	Banner::destroy
	${If} $R2 != ok
		StrCpy $R2 "Opera couldn't be downloaded ($R2)"
		Goto OP_Fetch_End
	${EndIf}
	; Opera publishes a SHA-256 next to some installers; when it's there,
	; the download has to match it.
	StrCpy $R0 `$3.sha256sum`
	StrCpy $R1 `${OP_STAGE}\sha256sum`
	Call BR_Download
	${If} $R2 == ok
		FileOpen $0 $R1 r
		FileRead $0 $1
		FileClose $0
		StrCpy $1 $1 64
		; Only a real checksum counts (a server error page doesn't).
		StrCpy $R0 $1
		Call OP_IsHex
	${EndIf}
	${If} $R2 == ok
		StrCpy $R0 $2
		StrCpy $R1 0x800C
		StrCpy $R2 32
		Push $R3
		Call BR_HashFile
		StrCpy $0 $R3
		Pop $R3
		${If} $0 != $1
			StrCpy $R2 "the download doesn't match Opera's published checksum"
			Goto OP_Fetch_End
		${EndIf}
	${EndIf}
	; Signed by Opera, and trusted by Windows.
	StrCpy $R0 $2
	Call BR_Signer
	${If} $R1 != `${OP_SIGNER}`
		StrCpy $R2 "the download isn't signed by ${OP_SIGNER}"
		Goto OP_Fetch_End
	${EndIf}
	Banner::show `Installing Opera $OPVersion into the package...`
	StrCpy $R0 $2
	StrCpy $R1 `${OP_STAGE}\Opera`
	Call OP_RunInstaller
	Banner::destroy
	StrCpy $R3 `${OP_STAGE}\Opera`
	${If} $R2 == ok
		; installation_status.json names the folder Opera was installed in.
		Push $R7
		Push $R8
		Push $R9
		StrCpy $R7 `$R3\installation_status.json`
		StrCpy $R8 `$R3\`
		StrCpy $R9 `${OP_APP}\`
		Call BR_ReplacePath
		Pop $R9
		Pop $R8
		Pop $R7
	${EndIf}
	OP_Fetch_End:
	Delete $2
	Delete `${OP_STAGE}\sha256sum`
	ClearErrors
	Pop $3
	Pop $2
	Pop $1
	Pop $0
	Pop $R1
	Pop $R0
FunctionEnd

; Nothing in the Opera folder needs carrying over to a new version.
Function BR_Preserve
FunctionEnd

; Shows why an install or update failed. $R2 is the reason; $R4 is
; downloaded or updated.
Function OP_Failed
	${If} $R4 == updated
		MessageBox MB_OK|MB_ICONEXCLAMATION `Opera couldn't be updated: $R2.$\r$\n$\r$\nThe Opera you have starts as it is. The update is offered again next time.`
	${Else}
		MessageBox MB_OK|MB_ICONEXCLAMATION `Opera couldn't be $R4: $R2.`
	${EndIf}
FunctionEnd

; The first launch: the package has no Opera yet.
Function OP_FirstInstall
	Push $R0
	Push $R2
	Push $R3
	Push $R4
	StrCpy $R4 downloaded
	MessageBox MB_YESNO|MB_ICONQUESTION `Opera isn't in this package yet.$\r$\n$\r$\nDownload it from Opera now? It's about 120 MB. Opera's signature is checked before it's installed into the package.$\r$\n$\r$\nBy using Opera you agree to Opera's terms of service (legal.opera.com/terms).` IDYES OP_FirstInstall_Go
	Call Unload
	Quit
	OP_FirstInstall_Go:
	Call OP_LatestVersion
	${If} $R2 == ok
		Call BR_HostArch
		Call OP_Fetch
	${EndIf}
	${If} $R2 == ok
		RMDir /r `${OP_APP}`
		ClearErrors
		Rename $R3 `${OP_APP}`
		${If} ${Errors}
			StrCpy $R2 "the new Opera couldn't be moved into place"
		${EndIf}
	${EndIf}
	RMDir /r `${OP_STAGE}`
	${If} $R2 == ok
		Call BR_UpdateChecked
	${Else}
		Call OP_Failed
		Call Unload
		Quit
	${EndIf}
	Pop $R4
	Pop $R3
	Pop $R2
	Pop $R0
FunctionEnd

; Updates Opera when there's a newer one.
Function OP_UpdateCheck
	Push $R0
	Push $R1
	Push $R2
	Push $R3
	Push $R4
	Push $0
	StrCpy $R4 updated
	Call BR_UpdateDue
	${If} $R2 = 1
		Call OP_LatestVersion
		${If} $R2 == ok
			Call BR_UpdateChecked
			StrCpy $R0 `${OP_APP}\opera.exe`
			Call BR_FileVersion
			StrCpy $0 $R1
			StrCpy $R0 $OPVersion
			Call BR_IsNewer
			${If} $R2 = 1
				${ReadUserConfig} $R2 UpdateCheck
				StrCpy $R1 yes
				${If} $R2 != auto
					MessageBox MB_YESNO|MB_ICONQUESTION `Opera $OPVersion is available. This package has Opera $0.$\r$\n$\r$\nUpdate now? It's downloaded from Opera (about 120 MB) and checked before Opera starts.$\r$\n$\r$\nNo starts Opera $0 as it is.` IDYES +2
					StrCpy $R1 no
				${EndIf}
				${If} $R1 == yes
					; The staging folder goes if the launcher stops halfway.
					${Journal::Record} BrowserStage DIR `${OP_STAGE}` "" recursive ""
					Call BR_HostArch
					Call OP_Fetch
					${If} $R2 == ok
						StrCpy $R0 Opera
						StrCpy $R1 $R3
						Call BR_Swap
					${EndIf}
					${IfThen} $R2 != ok ${|} Call OP_Failed ${|}
					${Journal::Rollback} BrowserStage
				${EndIf}
			${EndIf}
		${EndIf}
	${EndIf}
	RMDir /r `${OP_STAGE}`
	ClearErrors
	Pop $0
	Pop $R4
	Pop $R3
	Pop $R2
	Pop $R1
	Pop $R0
FunctionEnd

; Paths Opera stores: the profile's Preferences (Opera keeps them in the
; user data folder itself, and in any extra profile folder), and the
; install folder in installation_status.json. $R8 and $R9 are set by
; BR_UpdatePaths.
Function BR_PathFiles
	Push $0
	Push $1
	Push $R7
	StrCpy $R7 `${OP_PROFILE}\Preferences`
	Call BR_ReplacePath
	FindFirst $0 $1 `${OP_PROFILE}\*`
	${DoWhile} $1 != ""
		${If} ${FileExists} `${OP_PROFILE}\$1\Preferences`
			StrCpy $R7 `${OP_PROFILE}\$1\Preferences`
			Call BR_ReplacePath
		${EndIf}
		FindNext $0 $1
	${Loop}
	FindClose $0
	StrCpy $R7 `${OP_APP}\installation_status.json`
	Call BR_ReplacePath
	ClearErrors
	Pop $R7
	Pop $1
	Pop $0
FunctionEnd

; A profile from a package that kept it in Data\profile\data is moved up
; to Data\profile.
Function OP_MoveProfile
	${If} ${FileExists} `${OP_PROFILE}\data\Preferences`
	${AndIfNot} ${FileExists} `${OP_PROFILE}\Preferences`
		Rename `${OP_PROFILE}\data` `${DATA}\profile.moving`
		RMDir `${OP_PROFILE}`
		Rename `${DATA}\profile.moving` `${OP_PROFILE}`
	${EndIf}
	; Opera's own updater stays set aside.
	${If} ${FileExists} `${OP_APP}\autoupdate\opera_autoupdate.exe`
		Delete `${OP_APP}\autoupdate\opera_autoupdate.exe.disabled`
		Rename `${OP_APP}\autoupdate\opera_autoupdate.exe` `${OP_APP}\autoupdate\opera_autoupdate.exe.disabled`
	${EndIf}
	ClearErrors
FunctionEnd

; What Opera's "Make default" registers in HKCU, by name prefix.
!macro OP_Registrations _CALL
	StrCpy $R4 key
	StrCpy $R0 `Software\Classes`
	StrCpy $R1 Opera
	StrCpy $R2 SnapClasses
	Call ${_CALL}
	StrCpy $R0 `Software\Clients\StartMenuInternet`
	StrCpy $R2 SnapStartMenu
	Call ${_CALL}
	StrCpy $R4 value
	StrCpy $R0 `Software\RegisteredApplications`
	StrCpy $R2 SnapRegApps
	Call ${_CALL}
!macroend

; Journals what Opera can leave in Windows.
Function OP_JournalWindows
	Push $R0
	Push $R1
	Push $R2
	Push $R4
	Push $0
	; Opera's own key: put back exactly as it was (an installed Opera's).
	${Journal::RegKey} BrowserPortable HKCU `Software\Opera Software` $0
	StrCpy $R1 recursive
	StrCpy $R0 `$APPDATA\Opera Software`
	Call BR_JournalDir
	StrCpy $R0 `$LOCALAPPDATA\Opera Software`
	Call BR_JournalDir
	; A crashed session's registrations go first, then the current ones
	; are remembered.
	!insertmacro OP_Registrations BR_RemoveNew
	!insertmacro OP_Registrations BR_Snapshot
	Pop $0
	Pop $R4
	Pop $R2
	Pop $R1
	Pop $R0
FunctionEnd

; Hooks

${SegmentFile}

; Init runs before the launcher looks for opera.exe, so a package without
; Opera can get one first.
${SegmentInit}
	StrCpy $R0 Opera
	StrCpy $R1 opera.exe
	Call BR_Repair
	RMDir /r `${OP_STAGE}`
	${IfNot} ${FileExists} `${OP_APP}\opera.exe`
		Call OP_FirstInstall
	${EndIf}
!macroend

${SegmentPrePrimary}
	Call OP_UpdateCheck
	Call OP_MoveProfile
	CreateDirectory `${OP_PROFILE}`
	Call BR_UpdatePaths
	Call OP_JournalWindows
	; The language for this launch, from the version folder's localization.
	StrCpy $R0 `${OP_APP}\opera.exe`
	Call BR_FileVersion
	StrCpy $R0 `${OP_APP}\$R1\localization`
	Call BR_Language
	StrCpy $OPLang $R1
!macroend

${SegmentPreExecPrimary}
	${If} $OPLang != ""
		StrCpy $ExecString `$ExecString --lang=$OPLang`
	${EndIf}
!macroend

${SegmentPostPrimary}
	!insertmacro OP_Registrations BR_RemoveNew
	${Journal::HasEntries} BrowserPortable $R0
	${If} $R0 > 0
		${Journal::Rollback} BrowserPortable
	${EndIf}
	StrCpy $R0 `${OP_APP}\opera.exe`
	Call BR_FileVersion
	Call BR_WriteVersion
!macroend
