; Tabby Portable custom code for PortableApps Compiler.
; For support, visit the GitHub project:
; https://github.com/daemondevin/pac-man
;
; Tabby runs from App\Tabby, with its configuration, plugins and everything
; else it keeps in Data\Tabby (--user-data-dir). What this file adds:
;
;   Install        The first launch offers to download Tabby: the newest
;                  release on GitHub (Eugeny/tabby), as Tabby's own portable
;                  zip. The zip is checked against the SHA-256 GitHub records
;                  for it (when GitHub gives one) and Tabby.exe against Tabby's
;                  signature (syslink GmbH), then unpacked with Windows' own
;                  tar.exe, or 7-Zip.
;   Updates        The same, before Tabby starts, at most every UpdateInterval
;                  days. The swap is journaled, so a crash halfway puts the old
;                  Tabby back. Tabby's own update check is turned off in its
;                  configuration while the launcher does the updating.
;   Moving         Paths in config.yaml (private keys, working folders) are
;                  updated when the package moves.
;   Leftovers      Tabby's shell integration ("Open Tabby here") and startup
;                  entry are journaled and removed again, and so are the
;                  folders it may create in %APPDATA% and %LOCALAPPDATA%.
;   Version        The version that ran is written to appinfo.ini.

; Defines
!define TB_APP      `$EXEDIR\App\Tabby`
!define TB_STAGE    `$EXEDIR\App\TabbyUpdate`
!define TB_DATA     `${DATA}\Tabby`
!define TB_RELEASE  `https://api.github.com/repos/Eugeny/tabby/releases/latest`
!define TB_DOWNLOAD `https://github.com/Eugeny/tabby/releases/download`
!define TB_SIGNER   `syslink GmbH`

; Variables
Var TBVersion       ; the version on offer (1.0.230)
Var TBDigest        ; the zip's SHA-256 as GitHub records it, or ""

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

; Tabby's side

; $R1 = the Tabby version in the folder $R0, from its core plugin's
; package.json, without a -nightly suffix; "" when there's no Tabby.
Function TB_InstalledVersion
	Push $0
	Push $1
	StrCpy $R1 ""
	ClearErrors
	${If} ${FileExists} `$R0\Tabby.exe`
		FileOpen $0 `$R0\resources\builtin-plugins\tabby-core\package.json` r
		${IfNot} ${Errors}
			${Do}
				ClearErrors
				FileRead $0 $1
				${IfThen} ${Errors} ${|} ${Break} ${|}
				${WordFind} $1 `"version"` "E+1}" $1
				${IfNot} ${Errors}
					${WordFind} $1 `"` "E+2" $R1
					${IfThen} ${Errors} ${|} StrCpy $R1 "" ${|}
					${Break}
				${EndIf}
			${Loop}
			FileClose $0
			${WordFind} $R1 "-" "+1" $R1
		${EndIf}
	${EndIf}
	ClearErrors
	Pop $1
	Pop $0
FunctionEnd

; Asks GitHub for Tabby's latest release. Sets $TBVersion and, when GitHub
; records it, $TBDigest for the portable zip of build $R0 (x64 or arm64).
; $R2 = ok, or why not.
Function TB_LatestRelease
	Push $R0
	Push $R1
	Push $0
	Push $1
	Push $2
	Push $3
	Push $4
	StrCpy $4 $R0
	ClearErrors
	${ReadUserConfig} $0 ReleaseURL
	${IfThen} $0 == "" ${|} StrCpy $0 `${TB_RELEASE}` ${|}
	CreateDirectory `${TB_STAGE}`
	StrCpy $R0 $0
	StrCpy $R1 `${TB_STAGE}\release.json`
	Call BR_Download
	StrCpy $TBVersion ""
	StrCpy $TBDigest ""
	${If} $R2 == ok
		; tag_name gives the version. Each asset lists its digest before its
		; download URL; a digest only counts for the asset it's in, so it's
		; forgotten at the start of every asset ("url" of an asset).
		StrCpy $2 ""
		FileOpen $0 $R1 r
		${Do}
			ClearErrors
			FileRead $0 $1
			${IfThen} ${Errors} ${|} ${Break} ${|}
			${If} $TBVersion == ""
				${WordFind} $1 `"tag_name"` "E+1}" $3
				${IfNot} ${Errors}
					${WordFind} $3 `"` "E+2" $3
					${IfNot} ${Errors}
						StrCpy $TBVersion $3
						StrCpy $3 $TBVersion 1
						${IfThen} $3 == v ${|} StrCpy $TBVersion $TBVersion "" 1 ${|}
					${EndIf}
				${EndIf}
			${EndIf}
			ClearErrors
			${WordFind} $1 `/releases/assets/` "E+1" $3
			${IfNot} ${Errors}
				StrCpy $2 ""
			${EndIf}
			ClearErrors
			${WordFind} $1 `"sha256:` "E+1}" $3
			${IfNot} ${Errors}
				${WordFind} $3 `"` "+1" $2
			${EndIf}
			ClearErrors
			${WordFind} $1 `"browser_download_url"` "E+1}" $3
			${IfNot} ${Errors}
				${WordFind} $3 `/tabby-$TBVersion-portable-$4.zip"` "E+1" $3
				${IfNot} ${Errors}
					StrCpy $TBDigest $2
				${EndIf}
			${EndIf}
		${Loop}
		FileClose $0
		${If} $TBVersion == ""
			StrCpy $R2 "GitHub didn't name a Tabby release"
		${Else}
			StrCpy $R2 ok
		${EndIf}
	${Else}
		StrCpy $R2 "GitHub couldn't be reached ($R2)"
	${EndIf}
	Delete `${TB_STAGE}\release.json`
	ClearErrors
	Pop $4
	Pop $3
	Pop $2
	Pop $1
	Pop $0
	Pop $R1
	Pop $R0
FunctionEnd

; $R0 = 7z.exe of a 7-Zip on this computer or next to the package, or "".
Function TB_Find7z
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
Function TB_Unzip
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
		Call TB_Find7z
		${If} $R0 != ""
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

; Downloads, checks and unpacks Tabby $TBVersion for build $R0 in the
; staging folder. $R2 = ok, or why not; $R3 = the new Tabby folder.
Function TB_Fetch
	Push $R0
	Push $R1
	Push $0
	Push $1
	Push $2
	${ReadUserConfig} $0 DownloadURL
	${IfThen} $0 == "" ${|} StrCpy $0 `${TB_DOWNLOAD}` ${|}
	StrCpy $1 `tabby-$TBVersion-portable-$R0.zip`
	StrCpy $2 `${TB_STAGE}\$1`
	RMDir /r `${TB_STAGE}\files`
	Banner::show `Downloading Tabby $TBVersion from GitHub...`
	StrCpy $R0 `$0/v$TBVersion/$1`
	StrCpy $R1 $2
	Call BR_Download
	Banner::destroy
	${If} $R2 != ok
		StrCpy $R2 "Tabby couldn't be downloaded ($R2)"
		Goto TB_Fetch_End
	${EndIf}
	${If} $TBDigest != ""
		StrCpy $R0 $2
		StrCpy $R1 0x800C
		StrCpy $R2 32
		Push $R3
		Call BR_HashFile
		StrCpy $0 $R3
		Pop $R3
		${If} $0 != $TBDigest
			StrCpy $R2 "the download doesn't match the checksum GitHub records for it"
			Goto TB_Fetch_End
		${EndIf}
	${EndIf}
	Banner::show `Unpacking Tabby $TBVersion...`
	StrCpy $R0 $2
	StrCpy $R1 `${TB_STAGE}\files`
	Call TB_Unzip
	Banner::destroy
	${If} $R2 != ok
		Goto TB_Fetch_End
	${EndIf}
	; Tabby.exe at the top of the zip, or in one folder.
	StrCpy $R3 `${TB_STAGE}\files`
	${IfNot} ${FileExists} `$R3\Tabby.exe`
		FindFirst $0 $1 `${TB_STAGE}\files\*`
		${DoWhile} $1 != ""
			${If} ${FileExists} `${TB_STAGE}\files\$1\Tabby.exe`
				StrCpy $R3 `${TB_STAGE}\files\$1`
			${EndIf}
			FindNext $0 $1
		${Loop}
		FindClose $0
	${EndIf}
	; Signed by Tabby's publisher, and trusted by Windows.
	StrCpy $R0 `$R3\Tabby.exe`
	Call BR_Signer
	StrCpy $R0 $R3
	Push $R1
	Call TB_InstalledVersion
	StrCpy $0 $R1
	Pop $R1
	${If} $0 == ""
		StrCpy $R2 "the download doesn't hold Tabby"
	${ElseIf} $R1 != `${TB_SIGNER}`
		StrCpy $R2 "Tabby.exe isn't signed by ${TB_SIGNER}"
	${ElseIf} $0 != $TBVersion
		StrCpy $R2 "the download holds Tabby $0, not $TBVersion"
	${Else}
		StrCpy $R2 ok
	${EndIf}
	TB_Fetch_End:
	Delete $2
	ClearErrors
	Pop $2
	Pop $1
	Pop $0
	Pop $R1
	Pop $R0
FunctionEnd

; Nothing in the program folder needs carrying over: plugins and settings
; are in Data\Tabby.
Function BR_Preserve
FunctionEnd

; Shows why an install or update failed. $R2 is the reason; $R4 is
; downloaded or updated.
Function TB_Failed
	${If} $R4 == updated
		MessageBox MB_OK|MB_ICONEXCLAMATION `Tabby couldn't be updated: $R2.$\r$\n$\r$\nThe Tabby you have starts as it is. The update is offered again next time.`
	${Else}
		MessageBox MB_OK|MB_ICONEXCLAMATION `Tabby couldn't be $R4: $R2.`
	${EndIf}
FunctionEnd

; $R0 = the Tabby build for this computer (x64 or arm64), or "" on 32-bit
; Windows, which Tabby doesn't support.
Function TB_Arch
	Push $0
	ReadEnvStr $0 PROCESSOR_ARCHITEW6432
	${IfThen} $0 == "" ${|} ReadEnvStr $0 PROCESSOR_ARCHITECTURE ${|}
	${If} $0 == ARM64
		StrCpy $R0 arm64
	${ElseIf} $0 == x86
		StrCpy $R0 ""
	${Else}
		StrCpy $R0 x64
	${EndIf}
	Pop $0
FunctionEnd

; The first launch: the package has no Tabby yet.
Function TB_FirstInstall
	Push $R0
	Push $R2
	Push $R3
	Push $R4
	StrCpy $R4 downloaded
	MessageBox MB_YESNO|MB_ICONQUESTION `Tabby isn't in this package yet.$\r$\n$\r$\nDownload the latest release from GitHub now? It's about 150 MB, and it's checked (Tabby's signature, and GitHub's checksum when there is one) before it's used.` IDYES TB_FirstInstall_Go
	Call Unload
	Quit
	TB_FirstInstall_Go:
	Call TB_Arch
	${If} $R0 == ""
		StrCpy $R2 "Tabby needs 64-bit Windows"
	${Else}
		Call TB_LatestRelease
		${If} $R2 == ok
			Call TB_Fetch
		${EndIf}
	${EndIf}
	${If} $R2 == ok
		RMDir /r `${TB_APP}`
		ClearErrors
		Rename $R3 `${TB_APP}`
		${If} ${Errors}
			StrCpy $R2 "the new Tabby couldn't be moved into place"
		${EndIf}
	${EndIf}
	RMDir /r `${TB_STAGE}`
	${If} $R2 == ok
		Call BR_UpdateChecked
	${Else}
		Call TB_Failed
		Call Unload
		Quit
	${EndIf}
	Pop $R4
	Pop $R3
	Pop $R2
	Pop $R0
FunctionEnd

; Updates Tabby when there's a newer release.
Function TB_UpdateCheck
	Push $R0
	Push $R1
	Push $R2
	Push $R3
	Push $R4
	Push $0
	StrCpy $R4 updated
	Call BR_UpdateDue
	Call TB_Arch
	${If} $R2 = 1
	${AndIf} $R0 != ""
		Call TB_LatestRelease
		${If} $R2 == ok
			Call BR_UpdateChecked
			Push $R0
			StrCpy $R0 `${TB_APP}`
			Call TB_InstalledVersion
			StrCpy $0 $R1
			StrCpy $R0 $TBVersion
			Call BR_IsNewer
			Pop $R0
			${If} $R2 = 1
				${ReadUserConfig} $R2 UpdateCheck
				StrCpy $R1 yes
				${If} $R2 != auto
					MessageBox MB_YESNO|MB_ICONQUESTION `Tabby $TBVersion is available. This package has Tabby $0.$\r$\n$\r$\nUpdate now? It's downloaded from GitHub (about 150 MB) and checked before Tabby starts.$\r$\n$\r$\nNo starts Tabby $0 as it is.` IDYES +2
					StrCpy $R1 no
				${EndIf}
				${If} $R1 == yes
					; The staging folder goes if the launcher stops halfway.
					${Journal::Record} BrowserStage DIR `${TB_STAGE}` "" recursive ""
					Call TB_Fetch
					${If} $R2 == ok
						StrCpy $R0 Tabby
						StrCpy $R1 $R3
						Call BR_Swap
					${EndIf}
					${IfThen} $R2 != ok ${|} Call TB_Failed ${|}
					${Journal::Rollback} BrowserStage
				${EndIf}
			${EndIf}
		${EndIf}
	${EndIf}
	RMDir /r `${TB_STAGE}`
	ClearErrors
	Pop $0
	Pop $R4
	Pop $R3
	Pop $R2
	Pop $R1
	Pop $R0
FunctionEnd

; Tabby's own portable mode keeps its data in a "data" folder next to
; Tabby.exe. A package made from Tabby's portable zip, unpacked straight
; into the package folder, has that folder where Data is (Windows doesn't
; tell data from Data), so Tabby's files are moved into Data\Tabby. A data
; folder next to App\Tabby\Tabby.exe is taken in too.
Function TB_Adopt
	${If} ${FileExists} `${DATA}\config.yaml`
	${AndIfNot} ${FileExists} `${TB_DATA}\*.*`
		Rename `${DATA}` `$EXEDIR\Data.moving`
		CreateDirectory `${DATA}`
		Rename `$EXEDIR\Data.moving` `${TB_DATA}`
		; The launcher's own settings stay in Data.
		${If} ${FileExists} `${TB_DATA}\settings\*.*`
			Rename `${TB_DATA}\settings` `${DATA}\settings`
		${EndIf}
		; Files kept in the data folder (keys, for one) are in Data\Tabby now.
		Push $0
		Push $1
		${ReplaceInFile} `${TB_DATA}\config.yaml` `$EXEDIR\data\` `${TB_DATA}\`
		${WordReplace} `$EXEDIR\data\` "\" "/" "+" $0
		${WordReplace} `${TB_DATA}\` "\" "/" "+" $1
		${ReplaceInFile} `${TB_DATA}\config.yaml` $0 $1
		Pop $1
		Pop $0
	${EndIf}
	${If} ${FileExists} `${TB_APP}\data\config.yaml`
	${AndIfNot} ${FileExists} `${TB_DATA}\config.yaml`
		CreateDirectory `${DATA}`
		RMDir `${TB_DATA}`
		Rename `${TB_APP}\data` `${TB_DATA}`
	${EndIf}
	ClearErrors
FunctionEnd

; Turns Tabby's own update check off in config.yaml while the launcher
; checks (UpdateCheck isn't off).
Function TB_NoSelfUpdate
	Push $0
	Push $1
	Push $2
	ClearErrors
	${ReadUserConfig} $0 UpdateCheck
	${If} $0 != off
	${AndIf} ${FileExists} `${TB_DATA}\config.yaml`
		StrCpy $2 0
		FileOpen $0 `${TB_DATA}\config.yaml` r
		${Do}
			ClearErrors
			FileRead $0 $1
			${IfThen} ${Errors} ${|} ${Break} ${|}
			StrCpy $1 $1 23
			${If} $1 S== `enableAutomaticUpdates:`
				StrCpy $2 1
				${Break}
			${EndIf}
		${Loop}
		FileClose $0
		${If} $2 = 1
			${ReplaceInFile} `${TB_DATA}\config.yaml` `enableAutomaticUpdates: true` `enableAutomaticUpdates: false`
		${Else}
			FileOpen $0 `${TB_DATA}\config.yaml` a
			FileSeek $0 0 END
			FileWrite $0 `$\r$\nenableAutomaticUpdates: false$\r$\n`
			FileClose $0
		${EndIf}
	${EndIf}
	ClearErrors
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Paths in config.yaml, as written (D:\Apps\) and with forward slashes.
; $R8 and $R9 are set by BR_UpdatePaths.
Function BR_PathFiles
	Push $0
	Push $1
	${If} ${FileExists} `${TB_DATA}\config.yaml`
		${ReplaceInFile} `${TB_DATA}\config.yaml` $R8 $R9
		${WordReplace} $R8 "\" "/" "+" $0
		${WordReplace} $R9 "\" "/" "+" $1
		${ReplaceInFile} `${TB_DATA}\config.yaml` $0 $1
	${EndIf}
	ClearErrors
	Pop $1
	Pop $0
FunctionEnd

; Journals what Tabby can leave in Windows.
Function TB_JournalWindows
	Push $R0
	Push $R1
	Push $0
	Push $1
	Push $2
	; Settings > Shell integration: "Open Tabby here" and "Paste path into
	; Tabby" in Explorer's context menus.
	${Journal::RegKey} BrowserPortable HKCU `Software\Classes\Directory\Background\shell\Tabby` $0
	${Journal::RegKey} BrowserPortable HKCU `Software\Classes\Directory\shell\Tabby` $0
	${Journal::RegKey} BrowserPortable HKCU `Software\Classes\*\shell\Tabby` $0
	; Run at startup.
	StrCpy $1 `Software\Microsoft\Windows\CurrentVersion\Run`
	ClearErrors
	ReadRegStr $2 HKCU $1 Tabby
	${If} ${Errors}
		StrCpy $2 ""
	${Else}
		StrCpy $2 `STR:$2`
	${EndIf}
	${Journal::Record} BrowserPortable REGVALUE HKCU $1 Tabby $2
	StrCpy $R1 recursive
	StrCpy $R0 `$APPDATA\tabby`
	Call BR_JournalDir
	StrCpy $R0 `$LOCALAPPDATA\tabby-updater`
	Call BR_JournalDir
	ClearErrors
	Pop $2
	Pop $1
	Pop $0
	Pop $R1
	Pop $R0
FunctionEnd

; Hooks

${SegmentFile}

; Init runs before the launcher looks for Tabby.exe, so a package without
; Tabby can get one first.
${SegmentInit}
	StrCpy $R0 Tabby
	StrCpy $R1 Tabby.exe
	Call BR_Repair
	RMDir /r `${TB_STAGE}`
	Call TB_Adopt
	${IfNot} ${FileExists} `${TB_APP}\Tabby.exe`
		Call TB_FirstInstall
	${EndIf}
!macroend

${SegmentPrePrimary}
	Call TB_UpdateCheck
	CreateDirectory `${TB_DATA}`
	Call TB_NoSelfUpdate
	Call BR_UpdatePaths
	Call TB_JournalWindows
!macroend

${SegmentPostPrimary}
	${Journal::HasEntries} BrowserPortable $R0
	${If} $R0 > 0
		${Journal::Rollback} BrowserPortable
	${EndIf}
	StrCpy $R0 `${TB_APP}`
	Call TB_InstalledVersion
	Call BR_WriteVersion
!macroend
