; WinRAR Portable custom code for PortableApps Compiler.
; For support, visit the GitHub project:
; https://github.com/daemondevin/pac-man
;
; WinRAR runs from App\WinRAR. With a WinRAR.ini next to WinRAR.exe it keeps
; its settings there instead of the registry, and with Global\AppData=0 in
; it, it keeps its registration key, themes and log next to WinRAR.exe
; instead of %APPDATA%\WinRAR. What this file adds:
;
;   Install         A package without WinRAR offers to download it: the
;                   newest release's installer from rarlab.com (64-bit, or
;                   32-bit on 32-bit Windows; English, or the language in
;                   InstallerLanguage). The installer and WinRAR.exe must be
;                   signed by win.rar GmbH; the installer is unpacked, not
;                   run, with WinRAR's own UnRAR.exe or 7-Zip.
;   Updates         The same, before WinRAR starts, at most every
;                   UpdateInterval days, keeping the build in use. The swap is
;                   journaled, so a crash halfway puts the old WinRAR back.
;   Settings        Data\WinRAR holds WinRAR.ini, your rarreg.key, Themes,
;                   settings.reg and rar.log; they're moved next to WinRAR.exe
;                   for the session and back afterward. Ones left there by a
;                   session that didn't close properly are taken back first.
;   Global settings Global\AppData=0 is set in WinRAR.ini, and
;                   Global\Integration follows Integration in
;                   WinRARPortable.ini: off (the default), WinRAR doesn't
;                   touch the registry at all.
;   Integration     When it's on, what WinRAR's Integration settings write
;                   (file types, the shell extension, context menus, App
;                   Paths) is journaled and undone.
;   Leftovers       HKCU\Software\WinRAR and %APPDATA%\WinRAR are journaled
;                   and undone.
;   Version         The version of WinRAR.exe is written to appinfo.ini.
;
; The registration key is only ever moved, never read.

; Defines
!define WR_APP      `$EXEDIR\App\WinRAR`
!define WR_DATA     `${DATA}\WinRAR`
!define WR_INFO     `$EXEDIR\App\AppInfo\appinfo.ini`
!define WR_EXT32    `{B41DB860-64E4-11D2-9906-E49FADC173CA}`
!define WR_EXT64    `{B41DB860-8EE4-11D2-9906-E49FADC173CA}`
!define WR_STAGE    `$EXEDIR\App\WinRARUpdate`
!define WR_LIST     `https://www.rarlab.com/download.htm`
!define WR_DOWNLOAD `https://www.rarlab.com/rar`
!define WR_SIGNER   `win.rar GmbH`

; Variables
Var WRIntegration   ; 1 when Integration=true, else 0
Var WRVersion       ; the version on offer (7.13)
Var WRFile          ; its installer's name (winrar-x64-713.exe)

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

; Settings

; The files and folders WinRAR keeps next to WinRAR.exe with
; Global\AppData=0. _CALL is a function taking $R2 = the name.
!macro WR_Items _CALL
	StrCpy $R2 WinRAR.ini
	Call ${_CALL}
	StrCpy $R2 rarreg.key
	Call ${_CALL}
	StrCpy $R2 Themes
	Call ${_CALL}
	StrCpy $R2 settings.reg
	Call ${_CALL}
	StrCpy $R2 rar.log
	Call ${_CALL}
!macroend

; Moves the item $R2 from $R0 to $R1, replacing what's there.
Function WR_MoveItem
	${If} ${FileExists} `$R0\$R2`
		${If} ${FileExists} `$R1\$R2\*.*`
			RMDir /r `$R1\$R2`
		${Else}
			Delete `$R1\$R2`
		${EndIf}
		Rename `$R0\$R2` `$R1\$R2`
	${EndIf}
	ClearErrors
FunctionEnd

; WinRAR's files go back to Data\WinRAR: after each session, and before the
; next one in case the last one didn't close properly (what's next to
; WinRAR.exe then is newer than what's in Data).
Function WR_Out
	Push $R0
	Push $R1
	Push $R2
	CreateDirectory `${WR_DATA}`
	StrCpy $R0 `${WR_APP}`
	StrCpy $R1 `${WR_DATA}`
	!insertmacro WR_Items WR_MoveItem
	Pop $R2
	Pop $R1
	Pop $R0
FunctionEnd

; Data\WinRAR's files go next to WinRAR.exe for the session.
Function WR_In
	Push $R0
	Push $R1
	Push $R2
	StrCpy $R0 `${WR_DATA}`
	StrCpy $R1 `${WR_APP}`
	!insertmacro WR_Items WR_MoveItem
	Pop $R2
	Pop $R1
	Pop $R0
FunctionEnd

; Global settings

; Writes Data\WinRAR\WinRAR.ini with Global\AppData=0 and Global\Integration
; from Integration in WinRARPortable.ini at the top, followed by the rest of
; the file as it was. WinRAR.ini is UTF-16LE text; a new one gets a byte
; order mark, and WinRAR adds its settings to it on exit.
Function WR_GlobalSettings
	Push $0
	Push $1
	Push $2
	Push $3
	Push $4
	Push $5
	IntFmt $5 "%c" 0xFEFF
	StrCpy $3 `${WR_DATA}\WinRAR.ini`
	CreateDirectory `${WR_DATA}`
	FileOpen $0 `$3.new` w
	FileWriteUTF16LE /BOM $0 `Global\AppData=0$\r$\n`
	FileWriteUTF16LE $0 `Global\Integration=$WRIntegration$\r$\n`
	ClearErrors
	FileOpen $1 $3 r
	${IfNot} ${Errors}
		${Do}
			ClearErrors
			FileReadUTF16LE $1 $2
			${IfThen} ${Errors} ${|} ${Break} ${|}
			${TrimNewLines} $2 $2
			; A byte order mark read as a character is dropped.
			StrCpy $4 $2 1
			${IfThen} $4 S== $5 ${|} StrCpy $2 $2 "" 1 ${|}
			${If} $2 S== "Global\AppData=0"
			${OrIf} $2 S== "Global\AppData=1"
			${OrIf} $2 S== "Global\Integration=0"
			${OrIf} $2 S== "Global\Integration=1"
			${OrIf} $2 == ""
				${Continue}
			${EndIf}
			FileWriteUTF16LE $0 `$2$\r$\n`
		${Loop}
		FileClose $1
	${EndIf}
	FileClose $0
	Delete $3
	Rename `$3.new` $3
	ClearErrors
	Pop $5
	Pop $4
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Integration

; The keys WinRAR's Integration settings write under Classes ($R0, of HKCU
; or HKLM in $R1): its file types, its shell extension (32- and 64-bit),
; and the shell's handler entries named WinRAR and WinRAR32.
!macro WR_ClassKey _KEY
	${If} $R1 == HKLM
		${Journal::RegKey} WinRARPortable HKLM `$R0\${_KEY}` $0
	${Else}
		${Journal::RegKey} WinRARPortable HKCU `$R0\${_KEY}` $0
	${EndIf}
!macroend
!macro WR_Handler _KEY
	!insertmacro WR_ClassKey `${_KEY}\WinRAR`
	!insertmacro WR_ClassKey `${_KEY}\WinRAR32`
!macroend
Function WR_JournalClasses
	Push $0
	!insertmacro WR_ClassKey WinRAR
	!insertmacro WR_ClassKey WinRAR.ZIP
	!insertmacro WR_ClassKey WinRAR.REV
	!insertmacro WR_ClassKey `CLSID\${WR_EXT32}`
	!insertmacro WR_ClassKey `CLSID\${WR_EXT64}`
	!insertmacro WR_ClassKey `Applications\WinRAR.exe`
	!insertmacro WR_Handler `*\shellex\ContextMenuHandlers`
	!insertmacro WR_Handler `Folder\shellex\ContextMenuHandlers`
	!insertmacro WR_Handler `Folder\shellex\DragDropHandlers`
	!insertmacro WR_Handler `Drive\shellex\DragDropHandlers`
	!insertmacro WR_Handler `lnkfile\shellex\ContextMenuHandlers`
	!insertmacro WR_Handler `exefile\shellex\PropertySheetHandlers`
	Pop $0
FunctionEnd

; A registry value: journaled with its current data, so it's put back, or
; removed when it wasn't there. $R1 = HKCU or HKLM, $R2 = key, $R3 = value.
Function WR_JournalValue
	Push $0
	ClearErrors
	${If} $R1 == HKLM
		ReadRegStr $0 HKLM $R2 $R3
	${Else}
		ReadRegStr $0 HKCU $R2 $R3
	${EndIf}
	${If} ${Errors}
		StrCpy $0 ""
	${Else}
		StrCpy $0 `STR:$0`
	${EndIf}
	${Journal::Record} WinRARPortable REGVALUE $R1 $R2 $R3 $0
	ClearErrors
	Pop $0
FunctionEnd

; Remembers which extensions in Classes ($R0 of $R1) open with WinRAR (a
; default value starting with WinRAR), under the setting $R2, so the ones a
; session adds can be cleared afterward.
Function WR_AssocSnapshot
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
			StrCpy $3 $3 6
			${IfThen} $3 == WinRAR ${|} StrCpy $2 `$2$1|` ${|}
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

; Extensions in $R0 of $R1 that open with WinRAR now but didn't when
; WR_AssocSnapshot ran under $R2 lose that default value (the key goes when
; that leaves it empty). Also run on the launch after a crash.
Function WR_AssocRestore
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
				StrCpy $3 $3 6
				${If} $3 == WinRAR
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
				DeleteRegValue HKLM `$R0\$1` ""
				DeleteRegKey /ifempty HKLM `$R0\$1`
			${Else}
				DeleteRegValue HKCU `$R0\$1` ""
				DeleteRegKey /ifempty HKCU `$R0\$1`
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

; Extension snapshots for HKCU, and HKLM when running as administrator.
; _CALL is Restore or Snapshot.
!macro WR_Associations _CALL
	Push $R0
	Push $R1
	Push $R2
	Push $0
	StrCpy $R0 `Software\Classes`
	StrCpy $R1 HKCU
	StrCpy $R2 SnapAssocHKCU
	Call WR_Assoc${_CALL}
	System::Call `shell32::IsUserAnAdmin() i .r0`
	${If} $0 <> 0
		StrCpy $R0 `SOFTWARE\Classes`
		StrCpy $R1 HKLM
		StrCpy $R2 SnapAssocHKLM
		Call WR_Assoc${_CALL}
	${EndIf}
	Pop $0
	Pop $R2
	Pop $R1
	Pop $R0
!macroend

; What WinRAR's Integration settings write, for HKCU, and HKLM when running
; as administrator (where WinRAR writes then).
Function WR_JournalIntegration
	Push $R0
	Push $R1
	Push $R2
	Push $R3
	Push $0
	StrCpy $R1 HKCU
	StrCpy $R0 `Software\Classes`
	Call WR_JournalClasses
	${Journal::RegKey} WinRARPortable HKCU `Software\Microsoft\Windows\CurrentVersion\App Paths\WinRAR.exe` $0
	StrCpy $R2 `Software\RegisteredApplications`
	StrCpy $R3 WinRAR
	Call WR_JournalValue
	StrCpy $R2 `Software\Microsoft\Windows\CurrentVersion\Shell Extensions\Approved`
	StrCpy $R3 `${WR_EXT32}`
	Call WR_JournalValue
	StrCpy $R3 `${WR_EXT64}`
	Call WR_JournalValue
	System::Call `shell32::IsUserAnAdmin() i .r0`
	${If} $0 <> 0
		StrCpy $R1 HKLM
		StrCpy $R0 `SOFTWARE\Classes`
		Call WR_JournalClasses
		${Journal::RegKey} WinRARPortable HKLM `SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\WinRAR.exe` $0
		${Journal::RegKey} WinRARPortable HKLM `SOFTWARE\WinRAR` $0
		StrCpy $R2 `SOFTWARE\RegisteredApplications`
		StrCpy $R3 WinRAR
		Call WR_JournalValue
		StrCpy $R2 `SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Approved`
		StrCpy $R3 `${WR_EXT32}`
		Call WR_JournalValue
		StrCpy $R3 `${WR_EXT64}`
		Call WR_JournalValue
	${EndIf}
	!insertmacro WR_Associations Restore
	!insertmacro WR_Associations Snapshot
	ClearErrors
	Pop $0
	Pop $R3
	Pop $R2
	Pop $R1
	Pop $R0
FunctionEnd

; Install and updates

; $R1 = the machine the program file $R0 is built for: x86, x64, arm64, or
; "" when it can't be read.
Function WR_Machine
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

; $R0 = the build for WinRAR's installer names: x32 on 32-bit Windows, else
; x64 (WinRAR has no ARM64 build; Windows on ARM runs the x64 one).
Function WR_HostBuild
	Push $0
	ReadEnvStr $0 PROCESSOR_ARCHITEW6432
	${IfThen} $0 == "" ${|} ReadEnvStr $0 PROCESSOR_ARCHITECTURE ${|}
	${If} $0 == x86
		StrCpy $R0 x32
	${Else}
		StrCpy $R0 x64
	${EndIf}
	Pop $0
FunctionEnd

; $R0 = the build of the WinRAR in the package (x32 or x64), else the one
; for this computer.
Function WR_Build
	Push $R1
	StrCpy $R0 `${WR_APP}\WinRAR.exe`
	Call WR_Machine
	${If} $R1 == x86
		StrCpy $R0 x32
	${ElseIf} $R1 == ""
		Call WR_HostBuild
	${Else}
		StrCpy $R0 x64
	${EndIf}
	Pop $R1
FunctionEnd

; $R1 = the version of the WinRAR in the folder $R0 (7.13), or "".
Function WR_InstalledVersion
	Push $0
	Push $1
	Push $2
	StrCpy $R1 ""
	ClearErrors
	GetDllVersion `$R0\WinRAR.exe` $0 $1
	${IfNot} ${Errors}
		IntOp $2 $0 >> 16
		IntOp $2 $2 & 0xFFFF
		IntOp $1 $0 & 0xFFFF
		IntFmt $1 "%02d" $1
		StrCpy $R1 `$2.$1`
	${EndIf}
	ClearErrors
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Finds the newest WinRAR for build $R0 (x64 or x32) on rarlab.com's
; download page: its links name the English installers
; /rar/winrar-x64-713.exe (7.13); betas (713b1) and other languages (713d)
; don't count. Sets $WRVersion and $WRFile, the installer in the language
; InstallerLanguage names (d for German: winrar-x64-713d.exe). The page is
; read in pieces, with the end of each kept for the next. $R2 = ok, or why
; not.
Function WR_LatestRelease
	Push $R0
	Push $R1
	Push $0
	Push $1
	Push $2
	Push $3
	Push $4
	Push $5
	StrCpy $5 $R0
	StrCpy $WRVersion ""
	StrCpy $WRFile ""
	ClearErrors
	${ReadUserConfig} $0 ReleaseURL
	${IfThen} $0 == "" ${|} StrCpy $0 `${WR_LIST}` ${|}
	CreateDirectory `${WR_STAGE}`
	StrCpy $R0 $0
	StrCpy $R1 `${WR_STAGE}\download.htm`
	Call BR_Download
	${If} $R2 != ok
		StrCpy $R2 "rarlab.com couldn't be reached ($R2)"
		Goto WR_LatestRelease_End
	${EndIf}
	; $3 = the highest number found, as written (713).
	StrCpy $3 ""
	StrCpy $2 ""
	FileOpen $0 $R1 r
	${Do}
		ClearErrors
		FileRead $0 $1 700
		${IfThen} ${Errors} ${|} ${Break} ${|}
		StrCpy $2 `$2$1`
		StrCpy $4 1
		${Do}
			ClearErrors
			${WordFind} `x$2` `winrar-$5-` "E+$4}" $1
			${IfThen} ${Errors} ${|} ${Break} ${|}
			${WordFind} `x$1` `.exe` "E+1{" $1
			${IfNot} ${Errors}
				StrCpy $1 $1 "" 1
				${StrFilter} $1 "1" "" "" $R0
				${If} $1 != ""
				${AndIf} $R0 S== $1
					${If} $3 == ""
					${OrIf} $1 > $3
						StrCpy $3 $1
					${EndIf}
				${EndIf}
			${EndIf}
			IntOp $4 $4 + 1
		${Loop}
		StrCpy $2 $2 "" -100
	${Loop}
	FileClose $0
	${If} $3 == ""
		StrCpy $R2 "rarlab.com's download page names no WinRAR $5 installer"
		Goto WR_LatestRelease_End
	${EndIf}
	; 713 is 7.13, 1001 would be 10.01.
	StrCpy $1 $3 -2
	StrCpy $2 $3 "" -2
	StrCpy $WRVersion `$1.$2`
	ClearErrors
	${ReadUserConfig} $1 InstallerLanguage
	StrCpy $WRFile `winrar-$5-$3$1.exe`
	StrCpy $R2 ok
	WR_LatestRelease_End:
	Delete `${WR_STAGE}\download.htm`
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
Function WR_Find7z
	Push $0
	Push $1
	StrCpy $R0 ""
	${GetParent} $EXEDIR $1
	${If} ${FileExists} `$1\7-ZipPortable\App\7-Zip64\7z.exe`
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

; Unpacks WinRAR's installer $R0 (a self-extracting RAR archive) into the
; folder $R1 without running it: with the package's own UnRAR.exe, or
; 7-Zip. $R2 = ok, or why not.
Function WR_Unpack
	Push $R0
	Push $0
	Push $1
	StrCpy $1 $R0
	CreateDirectory $R1
	StrCpy $R2 "the installer couldn't be unpacked (WinRAR's UnRAR.exe or 7-Zip is needed)"
	${If} ${FileExists} `${WR_APP}\UnRAR.exe`
		; -cfg- ignores settings, -idq is quiet. The folder ends in a
		; backslash, doubled so it doesn't escape the closing quote.
		nsExec::ExecToStack `"${WR_APP}\UnRAR.exe" x -y -cfg- -idq "$1" "$R1\\"`
		Pop $0
		Pop $R0
		${IfThen} $0 == 0 ${|} StrCpy $R2 ok ${|}
	${EndIf}
	${If} $R2 != ok
		Call WR_Find7z
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

; Downloads, checks and unpacks WinRAR $WRVersion ($WRFile) in the staging
; folder. rarlab.com publishes no checksums, so the installer itself must be
; signed by win.rar GmbH before it's unpacked, and WinRAR.exe in it too.
; $R2 = ok, or why not; $R3 = the new WinRAR folder.
Function WR_Fetch
	Push $R0
	Push $R1
	Push $0
	Push $1
	Push $2
	ClearErrors
	${ReadUserConfig} $0 DownloadURL
	${IfThen} $0 == "" ${|} StrCpy $0 `${WR_DOWNLOAD}` ${|}
	StrCpy $2 `${WR_STAGE}\$WRFile`
	RMDir /r `${WR_STAGE}\files`
	Banner::show `Downloading WinRAR $WRVersion from rarlab.com...`
	StrCpy $R0 `$0/$WRFile`
	StrCpy $R1 $2
	Call BR_Download
	Banner::destroy
	${If} $R2 != ok
		StrCpy $R2 "WinRAR couldn't be downloaded ($R2)"
		Goto WR_Fetch_End
	${EndIf}
	StrCpy $R0 $2
	Call BR_Signer
	${If} $R1 != `${WR_SIGNER}`
		StrCpy $R2 "the installer isn't signed by ${WR_SIGNER}"
		Goto WR_Fetch_End
	${EndIf}
	StrCpy $R0 $2
	StrCpy $R1 `${WR_STAGE}\files`
	Call WR_Unpack
	${If} $R2 != ok
		Goto WR_Fetch_End
	${EndIf}
	StrCpy $R3 `${WR_STAGE}\files`
	StrCpy $R0 `$R3\WinRAR.exe`
	Call BR_Signer
	StrCpy $1 $R1
	StrCpy $R0 $R3
	Call WR_InstalledVersion
	StrCpy $0 $R1
	${If} $0 == ""
		StrCpy $R2 "the installer doesn't hold WinRAR"
	${ElseIf} $1 != `${WR_SIGNER}`
		StrCpy $R2 "WinRAR.exe isn't signed by ${WR_SIGNER}"
	${Else}
		${VersionCompare} $0 $WRVersion $1
		${If} $1 != 0
			StrCpy $R2 "the installer holds WinRAR $0, not $WRVersion"
		${Else}
			StrCpy $R2 ok
		${EndIf}
	${EndIf}
	WR_Fetch_End:
	Delete $2
	ClearErrors
	Pop $2
	Pop $1
	Pop $0
	Pop $R1
	Pop $R0
FunctionEnd

; Nothing of yours is left in the old WinRAR folder at an update: WinRAR.ini,
; the key and themes are in Data then.
Function BR_Preserve
FunctionEnd

; The shared helpers' path update isn't used here.
Function BR_PathFiles
FunctionEnd

; Shows why an install or update failed. $R2 is the reason; $R4 is
; downloaded or updated.
Function WR_Failed
	${If} $R4 == updated
		MessageBox MB_OK|MB_ICONEXCLAMATION `WinRAR couldn't be updated: $R2.$\r$\n$\r$\nThe WinRAR you have starts as it is. The update is offered again at the next check.`
	${Else}
		MessageBox MB_OK|MB_ICONEXCLAMATION `WinRAR couldn't be downloaded: $R2.$\r$\n$\r$\nYou can also download WinRAR from win-rar.com and extract the installer into this package's App\WinRAR folder (see Other\Source\README.md).`
	${EndIf}
FunctionEnd

; The first launch: the package has no WinRAR yet.
Function WR_FirstInstall
	Push $R0
	Push $R2
	Push $R3
	Push $R4
	StrCpy $R4 downloaded
	MessageBox MB_YESNO|MB_ICONQUESTION `WinRAR isn't in this package yet.$\r$\n$\r$\nDownload the latest WinRAR from rarlab.com now? It's about 4 MB. The installer is checked (win.rar GmbH's signature) and unpacked into the package, not run. Unpacking it needs 7-Zip on this computer or next to this package.$\r$\n$\r$\nWinRAR is shareware: free to try for 40 days, then it needs a license, which you add as rarreg.key.$\r$\n$\r$\nNo stops here.` IDYES WR_FirstInstall_Go
	Call Unload
	Quit
	WR_FirstInstall_Go:
	Call WR_HostBuild
	Call WR_LatestRelease
	${If} $R2 == ok
		Call WR_Fetch
	${EndIf}
	${If} $R2 == ok
		RMDir /r `${WR_APP}`
		ClearErrors
		Rename $R3 `${WR_APP}`
		${If} ${Errors}
			StrCpy $R2 "the new WinRAR couldn't be moved into place"
		${EndIf}
	${EndIf}
	RMDir /r `${WR_STAGE}`
	${If} $R2 == ok
		Call BR_UpdateChecked
	${Else}
		Call WR_Failed
		Call Unload
		Quit
	${EndIf}
	Pop $R4
	Pop $R3
	Pop $R2
	Pop $R0
FunctionEnd

; Updates WinRAR when there's a newer release, keeping the build in use.
Function WR_UpdateCheck
	Push $R0
	Push $R1
	Push $R2
	Push $R3
	Push $R4
	Push $0
	StrCpy $R4 updated
	Call BR_UpdateDue
	${If} $R2 = 1
		Call WR_Build
		Call WR_LatestRelease
		${If} $R2 == ok
			Call BR_UpdateChecked
			Push $R0
			StrCpy $R0 `${WR_APP}`
			Call WR_InstalledVersion
			StrCpy $0 $R1
			StrCpy $R0 $WRVersion
			Call BR_IsNewer
			Pop $R0
			${If} $R2 = 1
				${ReadUserConfig} $R2 UpdateCheck
				StrCpy $R1 yes
				${If} $R2 != auto
					MessageBox MB_YESNO|MB_ICONQUESTION `WinRAR $WRVersion is available. This package has WinRAR $0.$\r$\n$\r$\nUpdate now? It's downloaded from rarlab.com (about 4 MB) and checked before WinRAR starts. Your settings and registration key are kept.$\r$\n$\r$\nNo starts WinRAR $0 as it is.` IDYES +2
					StrCpy $R1 no
				${EndIf}
				${If} $R1 == yes
					; The staging folder goes if the launcher stops halfway.
					${Journal::Record} BrowserStage DIR `${WR_STAGE}` "" recursive ""
					Call WR_Fetch
					${If} $R2 == ok
						StrCpy $R0 WinRAR
						StrCpy $R1 $R3
						Call BR_Swap
					${EndIf}
					${IfThen} $R2 != ok ${|} Call WR_Failed ${|}
					${Journal::Rollback} BrowserStage
				${EndIf}
			${EndIf}
		${EndIf}
	${EndIf}
	RMDir /r `${WR_STAGE}`
	ClearErrors
	Pop $0
	Pop $R4
	Pop $R3
	Pop $R2
	Pop $R1
	Pop $R0
FunctionEnd

; Leftovers

Function WR_JournalWindows
	Push $R0
	Push $0
	; WinRAR's own key (Software\WinRAR\Paths, AppData is read from the
	; registry even with WinRAR.ini), and %APPDATA%\WinRAR.
	${Journal::RegKey} WinRARPortable HKCU `Software\WinRAR` $0
	${Journal::RegKey} WinRARPortable HKCU `Software\WinRAR SFX` $0
	${IfNot} ${FileExists} `$APPDATA\WinRAR\*.*`
		${Journal::Record} WinRARPortable DIR `$APPDATA\WinRAR` "" recursive ""
	${EndIf}
	${If} $WRIntegration = 1
		Call WR_JournalIntegration
	${EndIf}
	ClearErrors
	Pop $0
	Pop $R0
FunctionEnd

; Writes the version of WinRAR.exe to appinfo.ini: 6.21.0.0 as
; PackageVersion, 6.21 as DisplayVersion.
Function WR_WriteVersion
	Push $0
	Push $1
	Push $2
	Push $3
	ClearErrors
	GetDllVersion `${WR_APP}\WinRAR.exe` $0 $1
	${IfNot} ${Errors}
		IntOp $2 $0 >> 16
		IntOp $2 $2 & 0xFFFF
		IntOp $3 $0 & 0xFFFF
		StrCpy $0 `$2.$3`
		ReadINIStr $2 `${WR_INFO}` Version DisplayVersion
		${If} $0 != $2
		${AndIf} $0 != "0.0"
			WriteINIStr `${WR_INFO}` Version PackageVersion `$0.0.0`
			WriteINIStr `${WR_INFO}` Version DisplayVersion $0
		${EndIf}
	${EndIf}
	ClearErrors
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Hooks

${SegmentFile}

; Init runs before the launcher looks for WinRAR, so a package without
; WinRAR can get one first.
${SegmentInit}
	; A launch that stopped between the two renames of a swap leaves an empty
	; App\$R0 and a $R0.previous folder; that's put back. $R1 is a file that a
	; complete program folder has.
	StrCpy $R0 WinRAR
	StrCpy $R1 WinRAR.exe
	${If} ${FileExists} `$EXEDIR\App\$R0.previous\$R1`
	${AndIfNot} ${FileExists} `$EXEDIR\App\$R0\$R1`
		RMDir /r `$EXEDIR\App\$R0`
		Rename `$EXEDIR\App\$R0.previous` `$EXEDIR\App\$R0`
	${EndIf}
	ClearErrors
	RMDir /r `${WR_STAGE}`
	${IfNot} ${FileExists} `${WR_APP}\WinRAR.exe`
		Call WR_FirstInstall
	${EndIf}
!macroend

; Your files go to Data before an update swaps the program folder.
${SegmentPrePrimary}
	Push $0
	ClearErrors
	${ReadUserConfig} $0 Integration
	${If} $0 == true
		StrCpy $WRIntegration 1
	${Else}
		StrCpy $WRIntegration 0
	${EndIf}
	Pop $0
	Call WR_Out
	Call WR_UpdateCheck
	Call WR_GlobalSettings
	Call WR_JournalWindows
	Call WR_In
!macroend

${SegmentPostPrimary}
	Call WR_Out
	${If} $WRIntegration = 1
		!insertmacro WR_Associations Restore
	${EndIf}
	${Journal::HasEntries} WinRARPortable $R0
	${If} $R0 > 0
		${Journal::Rollback} WinRARPortable
	${EndIf}
	Call WR_WriteVersion
!macroend
