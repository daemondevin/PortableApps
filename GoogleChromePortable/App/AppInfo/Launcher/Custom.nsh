; Google Chrome Portable custom code for PortableApps Compiler.
; For support, visit the GitHub project:
; https://github.com/daemondevin/pac-man
;
; Chrome runs from App\Chrome-bin with its user data in Data\profile. What
; this file adds:
;
;   Install        The package doesn't ship Chrome. The first launch offers to
;                  download it from Google: the launcher asks Google's update
;                  server (the one Chrome's own updater uses) for the current
;                  stable build, downloads it, checks its SHA-256 and Google's
;                  signature, and unpacks it with 7-Zip.
;   Updates        The same, before Chrome starts, at most every UpdateInterval
;                  days. The swap is journaled, so a crash halfway puts the old
;                  Chrome back.
;   Language       Follows the PortableApps.com Platform's language (or the
;                  Language in GoogleChromePortable.ini) with --lang.
;   Moving         Paths stored in the profiles' Preferences are updated when
;                  the package moves.
;   Leftovers      HKCU\Software\Google\Chrome is journaled and put back, the
;                  folders Chrome may create in %LOCALAPPDATA% and %APPDATA% are
;                  removed again, and so is a "Make default" registration.
;   Version        The version that ran is written to appinfo.ini.

; Defines
!define GC_BIN      `$EXEDIR\App\Chrome-bin`
!define GC_STAGE    `$EXEDIR\App\ChromeUpdate`
!define GC_PROFILE  `${DATA}\profile`
!define GC_APPID    `{8A69D345-D564-463C-AFF1-A69D9E530F96}`
!define GC_OMAHA    `https://tools.google.com/service/update2`
!define GC_SIGNER   `Google LLC`

; Variables
Var GCVersion       ; the version on offer
Var GCUrl           ; where it's downloaded from
Var GCHash          ; its SHA-256, from Google's update server
Var GCLang          ; the --lang for this launch, or ""

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

; Chrome's side

; $R2 = the value of the XML attribute that follows $R1 (up to the closing
; quote) in the file $R0, or "".
Function GC_Attr
	Push $0
	Push $1
	Push $2
	Push $3
	StrCpy $R2 ""
	StrCpy $3 ""
	ClearErrors
	FileOpen $0 $R0 r
	${IfNot} ${Errors}
		${Do}
			ClearErrors
			FileRead $0 $1
			${IfThen} ${Errors} ${|} ${Break} ${|}
			; The end of the previous read goes in front, in case the
			; attribute was cut in two.
			StrCpy $1 `$3$1`
			StrCpy $3 $1 "" -400
			${WordFind} $1 $R1 "E+1}" $2
			${IfNot} ${Errors}
				${WordFind} $2 `"` "E+1" $R2
				${IfNot} ${Errors}
					${Break}
				${EndIf}
				StrCpy $R2 ""
			${EndIf}
		${Loop}
		FileClose $0
	${EndIf}
	ClearErrors
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Asks Google's update server for the current Chrome for build $R0 (x64 or
; x86) on the UpdateChannel in GoogleChromePortable.ini. Sets $GCVersion,
; $GCUrl and $GCHash. $R2 = ok, or why not.
Function GC_Query
	Push $R0
	Push $R1
	Push $R3
	Push $0
	Push $1
	Push $2
	ClearErrors
	${ReadUserConfig} $0 UpdateChannel
	${If} $0 != beta
	${AndIf} $0 != dev
		StrCpy $0 stable
	${EndIf}
	${If} $R0 == x64
		StrCpy $1 `x64-$0-statsdef_1`
	${Else}
		StrCpy $1 `$0-arch_x86-statsdef_1`
	${EndIf}
	CreateDirectory `${GC_STAGE}`
	StrCpy $2 `<?xml version="1.0" encoding="UTF-8"?><request protocol="3.0" updater="Omaha" ismachine="0" installsource="ondemand" dedup="cr"><os platform="win" version="10.0" arch="$R0"/><app appid="${GC_APPID}" version="" ap="$1" lang="en" brand="GCEA" installage="-1"><updatecheck/></app></request>`
	${ReadUserConfig} $R0 UpdateServer
	${IfThen} $R0 == "" ${|} StrCpy $R0 `${GC_OMAHA}` ${|}
	StrCpy $R1 $2
	StrCpy $R2 `${GC_STAGE}\update.xml`
	Call BR_Post
	StrCpy $GCVersion ""
	${If} $R3 == ok
		StrCpy $R0 `${GC_STAGE}\update.xml`
		StrCpy $R1 `<manifest version="`
		Call GC_Attr
		StrCpy $GCVersion $R2
		StrCpy $R1 `hash_sha256="`
		Call GC_Attr
		StrCpy $GCHash $R2
		StrCpy $R1 ` name="`
		Call GC_Attr
		StrCpy $0 $R2
		; Prefer a secure download location.
		StrCpy $R1 `codebase="https://`
		Call GC_Attr
		${If} $R2 != ""
			StrCpy $GCUrl `https://$R2$0`
		${Else}
			StrCpy $R1 `codebase="`
			Call GC_Attr
			StrCpy $GCUrl `$R2$0`
		${EndIf}
		${If} $GCVersion == ""
		${OrIf} $GCHash == ""
		${OrIf} $0 == ""
			StrCpy $R2 "Google's update server didn't offer a version"
			StrCpy $GCVersion ""
		${Else}
			StrCpy $R2 ok
		${EndIf}
	${Else}
		StrCpy $R2 $R3
	${EndIf}
	Delete `${GC_STAGE}\update.xml`
	ClearErrors
	Pop $2
	Pop $1
	Pop $0
	Pop $R3
	Pop $R1
	Pop $R0
FunctionEnd

; $R0 = 7z.exe of a 7-Zip on this computer or next to the package, or "".
Function GC_Find7z
	Push $0
	Push $1
	StrCpy $R0 ""
	${GetParent} $EXEDIR $1
	Push $R0
	Call BR_HostArch
	StrCpy $0 $R0
	Pop $R0
	${If} ${FileExists} `$EXEDIR\App\7-Zip\7z.exe`
		StrCpy $R0 `$EXEDIR\App\7-Zip\7z.exe`
	${ElseIf} ${FileExists} `$1\7-ZipPortable\App\7-Zip64\7z.exe`
	${AndIf} $0 == x64
		StrCpy $R0 `$1\7-ZipPortable\App\7-Zip64\7z.exe`
	${ElseIf} ${FileExists} `$1\7-ZipPortable\App\7-Zip\7z.exe`
		StrCpy $R0 `$1\7-ZipPortable\App\7-Zip\7z.exe`
	${Else}
		SetRegView 64
		ReadRegStr $0 HKLM `SOFTWARE\7-Zip` Path
		SetRegView lastused
		${If} $0 == ""
			ReadRegStr $0 HKLM `SOFTWARE\7-Zip` Path
		${EndIf}
		${If} $0 == ""
			ReadRegStr $0 HKCU `SOFTWARE\7-Zip` Path
		${EndIf}
		${If} $0 != ""
		${AndIf} ${FileExists} `$0\7z.exe`
			StrCpy $R0 `$0\7z.exe`
		${ElseIf} ${FileExists} `$PROGRAMFILES64\7-Zip\7z.exe`
			StrCpy $R0 `$PROGRAMFILES64\7-Zip\7z.exe`
		${ElseIf} ${FileExists} `$PROGRAMFILES32\7-Zip\7z.exe`
			StrCpy $R0 `$PROGRAMFILES32\7-Zip\7z.exe`
		${EndIf}
	${EndIf}
	ClearErrors
	Pop $1
	Pop $0
FunctionEnd

; Saves the Chrome archive inside the installer $R0 (a resource of the
; installer program) to the file $R1. $R2 = ok, or "".
Function GC_SaveArchive
	Push $0
	Push $1
	Push $2
	Push $3
	Push $4
	StrCpy $R2 ""
	; LOAD_LIBRARY_AS_DATAFILE | LOAD_LIBRARY_AS_IMAGE_RESOURCE
	System::Call `kernel32::LoadLibraryExW(w R0, p 0, i 0x22) p .r0`
	${If} $0 <> 0
		; The archive is CHROME.PACKED.7Z (type B7) in the usual installer,
		; CHROME.7Z in the uncompressed one.
		System::Call `kernel32::FindResourceW(p r0, w "CHROME.PACKED.7Z", w "B7") p .r1`
		${If} $1 = 0
			System::Call `kernel32::FindResourceW(p r0, w "CHROME.7Z", w "B7") p .r1`
		${EndIf}
		${If} $1 = 0
			System::Call `kernel32::FindResourceW(p r0, w "CHROME.7Z", w "BN") p .r1`
		${EndIf}
		${If} $1 = 0
			System::Call `kernel32::FindResourceW(p r0, w "CHROME.7Z", w "BL") p .r1`
		${EndIf}
		${If} $1 <> 0
			System::Call `kernel32::SizeofResource(p r0, p r1) i .r2`
			System::Call `kernel32::LoadResource(p r0, p r1) p .r3`
			System::Call `kernel32::LockResource(p r3) p .r3`
			${If} $3 <> 0
			${AndIf} $2 > 0
				Delete $R1
				System::Call `kernel32::CreateFileW(w R1, i 0x40000000, i 0, p 0, i 2, i 0, p 0) p .r4`
				${If} $4 <> -1
					System::Call `kernel32::WriteFile(p r4, p r3, i r2, *i .r1, p 0) i .r3`
					System::Call `kernel32::CloseHandle(p r4)`
					${IfThen} $3 <> 0 ${|} StrCpy $R2 ok ${|}
				${EndIf}
			${EndIf}
		${EndIf}
		System::Call `kernel32::FreeLibrary(p r0)`
	${EndIf}
	ClearErrors
	Pop $4
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Downloads and checks Chrome $GCVersion, and unpacks it in the staging
; folder. $R2 = ok, or why not; $R3 = the new Chrome-bin folder.
Function GC_Fetch
	Push $R0
	Push $R1
	Push $0
	Push $1
	Push $2
	Push $3
	Call GC_Find7z
	StrCpy $3 $R0
	${If} $3 == ""
		StrCpy $R2 "unpacking Chrome needs 7-Zip. Put 7-Zip Portable next to this package (in the same PortableApps folder), or install 7-Zip"
		Goto GC_Fetch_End
	${EndIf}
	StrCpy $1 `${GC_STAGE}\files`
	RMDir /r $1
	CreateDirectory $1
	StrCpy $2 `${GC_STAGE}\chrome_installer.exe`
	Banner::show `Downloading Google Chrome $GCVersion from Google...`
	StrCpy $R0 $GCUrl
	StrCpy $R1 $2
	Call BR_Download
	Banner::destroy
	${If} $R2 != ok
		StrCpy $R2 "Chrome couldn't be downloaded ($R2)"
		Goto GC_Fetch_End
	${EndIf}
	; The SHA-256 Google's update server gave for this file.
	StrCpy $R0 $2
	StrCpy $R1 0x800C
	StrCpy $R2 32
	Push $R3
	Call BR_HashFile
	StrCpy $0 $R3
	Pop $R3
	${If} $0 != $GCHash
		StrCpy $R2 "the download doesn't match the checksum Google's update server gave"
		Goto GC_Fetch_End
	${EndIf}
	; Signed by Google, and trusted by Windows.
	Call BR_Signer
	${If} $R1 != `${GC_SIGNER}`
		StrCpy $R2 "the download isn't signed by ${GC_SIGNER}"
		Goto GC_Fetch_End
	${EndIf}
	Banner::show `Unpacking Google Chrome $GCVersion...`
	StrCpy $R1 `${GC_STAGE}\chrome.packed.7z`
	Call GC_SaveArchive
	${If} $R2 == ok
		; chrome.packed.7z holds chrome.7z, which holds Chrome-bin.
		nsExec::ExecToStack `"$3" x -y "-o${GC_STAGE}\outer" "$R1"`
		Pop $0
		Pop $R0
		Delete $R1
		${If} ${FileExists} `${GC_STAGE}\outer\chrome.7z`
			nsExec::ExecToStack `"$3" x -y "-o$1" "${GC_STAGE}\outer\chrome.7z"`
			Pop $0
			Pop $R0
		${ElseIf} ${FileExists} `${GC_STAGE}\outer\Chrome-bin\chrome.exe`
			Rename `${GC_STAGE}\outer\Chrome-bin` `$1\Chrome-bin`
		${EndIf}
		RMDir /r `${GC_STAGE}\outer`
	${EndIf}
	Banner::destroy
	Delete $2
	StrCpy $R3 `$1\Chrome-bin`
	StrCpy $R0 `$R3\chrome.exe`
	Call BR_FileVersion
	${If} $R1 == ""
		StrCpy $R2 "the installer couldn't be unpacked"
	${ElseIf} $R1 != $GCVersion
		StrCpy $R2 "the installer holds Chrome $R1, not $GCVersion"
	${Else}
		StrCpy $R2 ok
	${EndIf}
	GC_Fetch_End:
	ClearErrors
	Pop $3
	Pop $2
	Pop $1
	Pop $0
	Pop $R1
	Pop $R0
FunctionEnd

; Copies what people add to Chrome-bin from $R0 (the old one) to $R1 (the
; new one): spell checking dictionaries and initial preferences.
Function BR_Preserve
	${If} ${FileExists} `$R0\Dictionaries\*.*`
		CreateDirectory `$R1\Dictionaries`
		CopyFiles /SILENT `$R0\Dictionaries\*.*` `$R1\Dictionaries`
	${EndIf}
	${If} ${FileExists} `$R0\initial_preferences`
		CopyFiles /SILENT `$R0\initial_preferences` $R1
	${EndIf}
	${If} ${FileExists} `$R0\master_preferences`
		CopyFiles /SILENT `$R0\master_preferences` $R1
	${EndIf}
	ClearErrors
FunctionEnd

; Shows why an install or update failed. $R2 is the reason; $R4 is
; downloaded or updated.
Function GC_Failed
	${If} $R4 == updated
		MessageBox MB_OK|MB_ICONEXCLAMATION `Google Chrome couldn't be updated: $R2.$\r$\n$\r$\nThe Chrome you have starts as it is. The update is offered again next time.`
	${Else}
		MessageBox MB_OK|MB_ICONEXCLAMATION `Google Chrome couldn't be $R4: $R2.`
	${EndIf}
FunctionEnd

; The first launch: the package has no Chrome yet.
Function GC_FirstInstall
	Push $R0
	Push $R2
	Push $R3
	Push $R4
	StrCpy $R4 downloaded
	MessageBox MB_YESNO|MB_ICONQUESTION `Google Chrome isn't in this package yet.$\r$\n$\r$\nDownload it from Google now? It's about 120 MB. It's checked against the checksum Google's update server gives and Google's signature before it's used, and unpacked with 7-Zip.$\r$\n$\r$\nBy using Chrome you agree to Google's Terms of Service (policies.google.com/terms).` IDYES GC_FirstInstall_Go
	Call Unload
	Quit
	GC_FirstInstall_Go:
	Call BR_HostArch
	Call GC_Query
	${If} $R2 == ok
		Call GC_Fetch
	${EndIf}
	${If} $R2 == ok
		RMDir /r `${GC_BIN}`
		ClearErrors
		Rename $R3 `${GC_BIN}`
		${If} ${Errors}
			StrCpy $R2 "the new Chrome couldn't be moved into place"
		${EndIf}
	${EndIf}
	RMDir /r `${GC_STAGE}`
	${If} $R2 == ok
		Call BR_UpdateChecked
	${Else}
		Call GC_Failed
		Call Unload
		Quit
	${EndIf}
	Pop $R4
	Pop $R3
	Pop $R2
	Pop $R0
FunctionEnd

; Updates Chrome when Google has a newer one.
Function GC_UpdateCheck
	Push $R0
	Push $R1
	Push $R2
	Push $R3
	Push $R4
	Push $0
	StrCpy $R4 updated
	Call BR_UpdateDue
	${If} $R2 = 1
		Call BR_HostArch
		Call GC_Query
		${If} $R2 == ok
			Call BR_UpdateChecked
			StrCpy $R0 `${GC_BIN}\chrome.exe`
			Call BR_FileVersion
			StrCpy $0 $R1
			StrCpy $R0 $GCVersion
			Call BR_IsNewer
			${If} $R2 = 1
				${ReadUserConfig} $R2 UpdateCheck
				StrCpy $R1 yes
				${If} $R2 != auto
					MessageBox MB_YESNO|MB_ICONQUESTION `Google Chrome $GCVersion is available. This package has Chrome $0.$\r$\n$\r$\nUpdate now? It's downloaded from Google (about 120 MB) and checked before Chrome starts.$\r$\n$\r$\nNo starts Chrome $0 as it is.` IDYES +2
					StrCpy $R1 no
				${EndIf}
				${If} $R1 == yes
					; The staging folder goes if the launcher stops halfway.
					${Journal::Record} BrowserStage DIR `${GC_STAGE}` "" recursive ""
					Call GC_Fetch
					${If} $R2 == ok
						StrCpy $R0 Chrome-bin
						StrCpy $R1 $R3
						Call BR_Swap
					${EndIf}
					${IfThen} $R2 != ok ${|} Call GC_Failed ${|}
					${Journal::Rollback} BrowserStage
				${EndIf}
			${EndIf}
		${EndIf}
	${EndIf}
	RMDir /r `${GC_STAGE}`
	ClearErrors
	Pop $0
	Pop $R4
	Pop $R3
	Pop $R2
	Pop $R1
	Pop $R0
FunctionEnd

; Paths Chrome stores: the download folder and other paths in every
; profile's Preferences. $R8 and $R9 are set by BR_UpdatePaths.
Function BR_PathFiles
	Push $0
	Push $1
	Push $R7
	FindFirst $0 $1 `${GC_PROFILE}\*`
	${DoWhile} $1 != ""
		${If} ${FileExists} `${GC_PROFILE}\$1\Preferences`
			StrCpy $R7 `${GC_PROFILE}\$1\Preferences`
			Call BR_ReplacePath
		${EndIf}
		FindNext $0 $1
	${Loop}
	FindClose $0
	ClearErrors
	Pop $R7
	Pop $1
	Pop $0
FunctionEnd

; What Chrome's "Make default" registers in HKCU, by name prefix.
!macro GC_Registrations _CALL
	StrCpy $R4 key
	StrCpy $R0 `Software\Classes`
	StrCpy $R1 ChromeHTML
	StrCpy $R2 SnapClassesHTML
	Call ${_CALL}
	StrCpy $R1 ChromePDF
	StrCpy $R2 SnapClassesPDF
	Call ${_CALL}
	StrCpy $R0 `Software\Clients\StartMenuInternet`
	StrCpy $R1 `Google Chrome`
	StrCpy $R2 SnapStartMenu
	Call ${_CALL}
	StrCpy $R4 value
	StrCpy $R0 `Software\RegisteredApplications`
	StrCpy $R2 SnapRegApps
	Call ${_CALL}
!macroend

; Journals what Chrome can leave in Windows.
Function GC_JournalWindows
	Push $R0
	Push $R1
	Push $R2
	Push $R4
	Push $0
	; Chrome's own key: put back exactly as it was (an installed Chrome's).
	${Journal::RegKey} BrowserPortable HKCU `Software\Google\Chrome` $0
	${Journal::RegKeyExists} HKCU `Software\Google` $0
	${If} $0 = 0
		${Journal::RegKey} BrowserPortable HKCU `Software\Google` $0
	${EndIf}
	StrCpy $R1 ""
	StrCpy $R0 `$LOCALAPPDATA\Google`
	Call BR_JournalDir
	StrCpy $R0 `$APPDATA\Google`
	Call BR_JournalDir
	StrCpy $R1 recursive
	StrCpy $R0 `$LOCALAPPDATA\Google\Chrome`
	Call BR_JournalDir
	; A crashed session's registrations go first, then the current ones
	; are remembered.
	!insertmacro GC_Registrations BR_RemoveNew
	!insertmacro GC_Registrations BR_Snapshot
	Pop $0
	Pop $R4
	Pop $R2
	Pop $R1
	Pop $R0
FunctionEnd

; Hooks

${SegmentFile}

; Init runs before the launcher looks for chrome.exe, so a package without
; Chrome can get one first.
${SegmentInit}
	StrCpy $R0 Chrome-bin
	StrCpy $R1 chrome.exe
	Call BR_Repair
	RMDir /r `${GC_STAGE}`
	${IfNot} ${FileExists} `${GC_BIN}\chrome.exe`
		Call GC_FirstInstall
	${EndIf}
!macroend

${SegmentPrePrimary}
	Call GC_UpdateCheck
	CreateDirectory `${GC_PROFILE}`
	Call BR_UpdatePaths
	Call GC_JournalWindows
	; The language for this launch, from the version folder's Locales.
	StrCpy $R0 `${GC_BIN}\chrome.exe`
	Call BR_FileVersion
	StrCpy $R0 `${GC_BIN}\$R1\Locales`
	Call BR_Language
	StrCpy $GCLang $R1
!macroend

${SegmentPreExecPrimary}
	${If} $GCLang != ""
		StrCpy $ExecString `$ExecString --lang=$GCLang`
	${EndIf}
!macroend

${SegmentPostPrimary}
	!insertmacro GC_Registrations BR_RemoveNew
	${Journal::HasEntries} BrowserPortable $R0
	${If} $R0 > 0
		${Journal::Rollback} BrowserPortable
	${EndIf}
	StrCpy $R0 `${GC_BIN}\chrome.exe`
	Call BR_FileVersion
	Call BR_WriteVersion
!macroend
