; Blender Portable custom code for PortableApps Compiler.
; For support, visit the GitHub project:
; https://github.com/daemondevin/pac-man
;
; Blender runs from App\Blender through blender-launcher.exe, its own
; starter without a console window. Its user folders (preferences, startup
; file, add-ons, extensions, presets) are in Data\Blender through the
; BLENDER_USER_* variables, and its caches are moved in and out of
; %LOCALAPPDATA% for each session. What this file adds:
;
;   Install         A package without Blender offers to download it: the
;                   newest release's portable zip from download.blender.org,
;                   for x64 or ARM64. The zip is checked against the SHA-256
;                   blender.org publishes for it and blender.exe against the
;                   Blender Foundation's signature, then unpacked with
;                   Windows' own tar.exe, or 7-Zip.
;   Updates         The same, before Blender starts, at most every
;                   UpdateInterval days: the newest release, or with
;                   UpdateTrack=series only the newest of the series in use
;                   (5.2.x, for an LTS). The swap is journaled, so a crash
;                   halfway puts the old Blender back.
;   Adding Blender  A Blender in App\Blender64, or an unpacked zip's
;                   blender-<version>-windows-<arch> folder in App or
;                   App\Blender, is moved into App\Blender.
;   User folders    Created before each launch: Blender ignores a variable
;                   naming a folder that isn't there and falls back to
;                   %APPDATA%.
;   Older layout    The Data\user_* folders and Data\LocalAppDataBlender of
;                   PortableApps.com's package, and a portable folder in
;                   App\Blender, are moved to Data\Blender once.
;   Moving          Paths in the bookmarks and recent files lists are updated
;                   when the package moves.
;   Leftovers       The .blend file association and thumbnail handler that
;                   Preferences > System > Register writes, and the folders
;                   Blender may create in the user profile and on C:, are
;                   journaled and undone.
;   Version         The version of blender.exe is written to appinfo.ini.

; Defines
!define BL_APP      `$EXEDIR\App\Blender`
!define BL_STAGE    `$EXEDIR\App\BlenderUpdate`
!define BL_USER     `${DATA}\Blender`
!define BL_INFO     `$EXEDIR\App\AppInfo\appinfo.ini`
!define BL_CLASSES  `Software\Classes`
!define BL_THUMB    `{D45F043D-F17F-4e8a-8435-70971D9FA46D}`
!define BL_RELEASE  `https://download.blender.org/release/`
!define BL_SIGNER   `Blender Foundation`
; Free space an install or update needs: the zip and the unpacked Blender.
!define BL_NEED_MB  2500

; Variables
Var BLVersion       ; the version on offer (5.2.1)
Var BLFolder        ; its release folder URL (.../release/Blender5.2/)
Var BLDigest        ; the zip's SHA-256 as blender.org publishes it
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
; yet. $R0 = the folder, $R1 = recursive to remove it with its contents,
; empty to remove it only while it's empty.
Function BL_JournalDir
	${IfNot} ${FileExists} `$R0\*.*`
		${Journal::Record} BlenderPortable DIR $R0 "" $R1 ""
	${EndIf}
FunctionEnd

; Moves the folder $R0 to $R1 when $R1 isn't there yet.
Function BL_MoveOnce
	${If} ${FileExists} `$R0\*.*`
	${AndIfNot} ${FileExists} `$R1\*.*`
		RMDir $R1
		Rename $R0 $R1
	${EndIf}
	ClearErrors
FunctionEnd

; Adding Blender

; $R0 = the first blender-* folder in $R0 that holds blender.exe, or "".
Function BL_FindUnpacked
	Push $0
	Push $1
	StrCpy $1 ""
	FindFirst $0 $R1 `$R0\blender-*`
	${DoWhile} $R1 != ""
		${If} ${FileExists} `$R0\$R1\blender.exe`
			StrCpy $1 `$R0\$R1`
			${Break}
		${EndIf}
		FindNext $0 $R1
	${Loop}
	FindClose $0
	StrCpy $R0 $1
	ClearErrors
	Pop $1
	Pop $0
FunctionEnd

; Puts a Blender that isn't in App\Blender yet there: PortableApps.com's
; App\Blender64, or the folder Blender's zip unpacks to, in App\Blender or
; in App.
Function BL_Adopt
	Push $R0
	Push $R1
	${IfNot} ${FileExists} `${BL_APP}\blender.exe`
		${If} ${FileExists} `$EXEDIR\App\Blender64\blender.exe`
			RMDir `${BL_APP}`
			Rename `$EXEDIR\App\Blender64` `${BL_APP}`
		${Else}
			StrCpy $R0 `${BL_APP}`
			Call BL_FindUnpacked
			${If} $R0 != ""
				; App\Blender\blender-5.2.0-windows-x64 becomes App\Blender.
				Rename `${BL_APP}` `${BL_APP}.unpacked`
				${GetFileName} $R0 $R1
				Rename `${BL_APP}.unpacked\$R1` `${BL_APP}`
				RMDir `${BL_APP}.unpacked`
			${Else}
				StrCpy $R0 `$EXEDIR\App`
				Call BL_FindUnpacked
				${If} $R0 != ""
					RMDir `${BL_APP}`
					Rename $R0 `${BL_APP}`
				${EndIf}
			${EndIf}
		${EndIf}
	${EndIf}
	ClearErrors
	Pop $R1
	Pop $R0
FunctionEnd

; User folders

; PortableApps.com's package kept the user folders as Data\user_config,
; user_scripts, user_extensions and user_datafiles, and the caches as
; Data\LocalAppDataBlender. Blender 4.2 and later also use a portable folder
; next to blender.exe, with the same folders in it.
!macro BL_MigrateFolder _NAME
	StrCpy $R0 `${DATA}\user_${_NAME}`
	StrCpy $R1 `${BL_USER}\${_NAME}`
	Call BL_MoveOnce
	StrCpy $R0 `${BL_APP}\portable\${_NAME}`
	Call BL_MoveOnce
!macroend
Function BL_Migrate
	Push $R0
	Push $R1
	CreateDirectory `${BL_USER}`
	!insertmacro BL_MigrateFolder config
	!insertmacro BL_MigrateFolder scripts
	!insertmacro BL_MigrateFolder extensions
	!insertmacro BL_MigrateFolder datafiles
	RMDir `${BL_APP}\portable`
	StrCpy $R0 `${DATA}\LocalAppDataBlender`
	StrCpy $R1 `${BL_USER}\local`
	Call BL_MoveOnce
	ClearErrors
	Pop $R1
	Pop $R0
FunctionEnd

; Blender only uses BLENDER_USER_* folders that exist.
Function BL_UserFolders
	CreateDirectory `${BL_USER}\config`
	CreateDirectory `${BL_USER}\scripts`
	CreateDirectory `${BL_USER}\extensions`
	CreateDirectory `${BL_USER}\datafiles`
FunctionEnd

; Moving the package

; The bookmarks and recent files lists hold plain Windows paths. $R8 and
; $R9 are set by BR_UpdatePaths.
Function BR_PathFiles
	${If} ${FileExists} `${BL_USER}\config\bookmarks.txt`
		${ReplaceInFile} `${BL_USER}\config\bookmarks.txt` $R8 $R9
	${EndIf}
	${If} ${FileExists} `${BL_USER}\config\recent-files.txt`
		${ReplaceInFile} `${BL_USER}\config\recent-files.txt` $R8 $R9
	${EndIf}
	ClearErrors
FunctionEnd

; Leftovers

; Remembers which keys in HKCU\Software\Classes start with blender. (the
; file type Register writes is named for the version, blender.5.2), so the
; ones a session adds can be removed afterward.
Function BL_Snapshot
	Push $0
	Push $1
	Push $2
	Push $3
	StrCpy $2 "|"
	StrCpy $0 0
	${Do}
		EnumRegKey $1 HKCU `${BL_CLASSES}` $0
		${IfThen} $1 == "" ${|} ${Break} ${|}
		StrCpy $3 $1 8
		${IfThen} $3 == "blender." ${|} StrCpy $2 `$2$1|` ${|}
		IntOp $0 $0 + 1
	${Loop}
	CreateDirectory `${SET}`
	${WriteSettings} $2 SnapClasses
	ClearErrors
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Removes the blender.* keys that weren't there when BL_Snapshot ran, and
; forgets the snapshot. Also run on the launch after a crash.
Function BL_RemoveNew
	Push $0
	Push $1
	Push $2
	Push $3
	Push $4
	${ReadSettings} $2 SnapClasses
	${If} $2 != ""
		StrCpy $4 ""
		StrCpy $0 0
		${Do}
			EnumRegKey $1 HKCU `${BL_CLASSES}` $0
			${IfThen} $1 == "" ${|} ${Break} ${|}
			StrCpy $3 $1 8
			${If} $3 == "blender."
				ClearErrors
				${WordFind} `x$2` `|$1|` "E+1" $3
				${IfThen} ${Errors} ${|} StrCpy $4 `$4$1|` ${|}
			${EndIf}
			IntOp $0 $0 + 1
		${Loop}
		${Do}
			ClearErrors
			${WordFind} $4 "|" "E+1" $1
			${IfThen} ${Errors} ${|} ${Break} ${|}
			${IfThen} $1 == "" ${|} ${Break} ${|}
			DeleteRegKey HKCU `${BL_CLASSES}\$1`
			${WordFind} $4 "|" "+1}" $4
		${Loop}
		DeleteINIStr `${SETINI}` `${APPNAME}Settings` SnapClasses
	${EndIf}
	ClearErrors
	Pop $4
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Journals what Blender can leave in Windows. Keys that were there before
; (an installed Blender's) are put back as they were.
Function BL_JournalWindows
	Push $R0
	Push $R1
	; Preferences > System > Register: the .blend file type, the older
	; blendfile type, Open with entries and the thumbnail handler
	; BlendThumb.dll registers.
	${Journal::RegKey} BlenderPortable HKCU `${BL_CLASSES}\.blend` $R0
	${Journal::RegKey} BlenderPortable HKCU `${BL_CLASSES}\blendfile` $R0
	${Journal::RegKey} BlenderPortable HKCU `${BL_CLASSES}\Applications\blender-launcher.exe` $R0
	${Journal::RegKey} BlenderPortable HKCU `${BL_CLASSES}\Applications\blender.exe` $R0
	${Journal::RegKey} BlenderPortable HKCU `${BL_CLASSES}\CLSID\${BL_THUMB}` $R0
	; A crashed session's blender.* types go first, then the current ones
	; are remembered.
	Call BL_RemoveNew
	Call BL_Snapshot
	; Blender's own folders, if something still uses the defaults.
	StrCpy $R1 recursive
	StrCpy $R0 `$APPDATA\Blender Foundation`
	Call BL_JournalDir
	; The file browser's thumbnails.
	StrCpy $R0 `$PROFILE\.thumbnails`
	Call BL_JournalDir
	; Blender's default render output, /tmp\, is C:\tmp. Renders saved there
	; are yours, so it's only removed while it's empty.
	StrCpy $R1 ""
	StrCpy $R0 `C:\tmp`
	Call BL_JournalDir
	Pop $R1
	Pop $R0
FunctionEnd

; Writes the version of blender.exe to appinfo.ini: 5.2.0.0 as
; PackageVersion, 5.2.0 as DisplayVersion.
Function BL_WriteVersion
	Push $0
	Push $1
	Push $2
	Push $3
	Push $4
	ClearErrors
	GetDllVersion `${BL_APP}\blender.exe` $0 $1
	${IfNot} ${Errors}
		IntOp $2 $0 >> 16
		IntOp $2 $2 & 0xFFFF
		IntOp $3 $0 & 0xFFFF
		IntOp $4 $1 >> 16
		IntOp $4 $4 & 0xFFFF
		IntOp $1 $1 & 0xFFFF
		StrCpy $0 `$2.$3.$4`
		ReadINIStr $2 `${BL_INFO}` Version DisplayVersion
		${If} $0 != $2
		${AndIf} $0 != "0.0.0"
			WriteINIStr `${BL_INFO}` Version PackageVersion `$0.$1`
			WriteINIStr `${BL_INFO}` Version DisplayVersion $0
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

; $R1 = 1 when $R0 is a version made of digits and dots (5.2.1), else 0.
Function BL_IsVersion
	Push $0
	Push $1
	StrCpy $R1 0
	${StrFilter} $R0 "1" "." "" $0
	StrCpy $1 $R0 1
	${If} $R0 != ""
	${AndIf} $0 S== $R0
	${AndIf} $1 != "."
		StrCpy $R1 1
	${EndIf}
	Pop $1
	Pop $0
FunctionEnd

; Reads the directory listing $R0 and sets $R3 to the highest version found
; between $R1 and $R2 in its links (href="Blender and /" give 5.2 for the
; folder Blender5.2/), or "".
Function BL_Highest
	Push $R0
	Push $R1
	Push $0
	Push $1
	Push $2
	StrCpy $R3 ""
	StrCpy $2 $R1
	FileOpen $0 $R0 r
	${IfNot} ${Errors}
		${Do}
			ClearErrors
			FileRead $0 $1
			${IfThen} ${Errors} ${|} ${Break} ${|}
			${WordFind} `x$1` $2 "E+1}" $1
			${IfThen} ${Errors} ${|} ${Continue} ${|}
			${WordFind} `$1` $R2 "E+1{" $R0
			${IfThen} ${Errors} ${|} ${Continue} ${|}
			Call BL_IsVersion
			${If} $R1 = 1
				${If} $R3 == ""
					StrCpy $R3 $R0
				${Else}
					${VersionCompare} $R0 $R3 $1
					${IfThen} $1 = 1 ${|} StrCpy $R3 $R0 ${|}
				${EndIf}
			${EndIf}
		${Loop}
		FileClose $0
	${EndIf}
	ClearErrors
	Pop $2
	Pop $1
	Pop $0
	Pop $R1
	Pop $R0
FunctionEnd

; $R1 = the version of the Blender in the folder $R0 (5.2.1), or "".
Function BL_InstalledVersion
	Push $R0
	StrCpy $R0 `$R0\blender.exe`
	StrCpy $R1 ""
	${If} ${FileExists} $R0
		Call BR_FileVersion
		; 5.2.1.0 is 5.2.1.
		${WordFind} $R1 "." "E-1{" $R0
		${IfNot} ${Errors}
			StrCpy $R1 $R0
		${EndIf}
	${EndIf}
	ClearErrors
	Pop $R0
FunctionEnd

; Finds the newest Blender for build $R0 (x64 or arm64): sets $BLVersion,
; $BLFolder and $BLDigest. With UpdateTrack=series and Blender in the
; package, only that series' folder (Blender5.2) is looked in. $R2 = ok,
; or why not.
Function BL_LatestRelease
	Push $R0
	Push $R1
	Push $R3
	Push $0
	Push $1
	Push $2
	Push $3
	StrCpy $3 $R0
	StrCpy $BLVersion ""
	StrCpy $BLFolder ""
	StrCpy $BLDigest ""
	ClearErrors
	${ReadUserConfig} $0 ReleaseURL
	${IfThen} $0 == "" ${|} StrCpy $0 `${BL_RELEASE}` ${|}
	StrCpy $1 $0 1 -1
	${IfThen} $1 != "/" ${|} StrCpy $0 `$0/` ${|}
	CreateDirectory `${BL_STAGE}`
	; The series: the one in use, or the newest folder.
	StrCpy $2 ""
	${ReadUserConfig} $1 UpdateTrack
	${If} $1 == series
		StrCpy $R0 `${BL_APP}`
		Call BL_InstalledVersion
		${WordFind} $R1 "." "E-1{" $2
		${IfThen} ${Errors} ${|} StrCpy $2 "" ${|}
	${EndIf}
	${If} $2 == ""
		StrCpy $R0 $0
		StrCpy $R1 `${BL_STAGE}\release.html`
		Call BR_Download
		${If} $R2 != ok
			StrCpy $R2 "blender.org couldn't be reached ($R2)"
			Goto BL_LatestRelease_End
		${EndIf}
		StrCpy $R0 $R1
		StrCpy $R1 `href="Blender`
		StrCpy $R2 `/"`
		Call BL_Highest
		StrCpy $2 $R3
		${If} $2 == ""
			StrCpy $R2 "blender.org's release list names no Blender"
			Goto BL_LatestRelease_End
		${EndIf}
	${EndIf}
	StrCpy $1 `Blender$2/`
	StrCpy $BLFolder `$0$1`
	; The newest zip for this build in that folder.
	StrCpy $R0 $BLFolder
	StrCpy $R1 `${BL_STAGE}\folder.html`
	Call BR_Download
	${If} $R2 != ok
		StrCpy $R2 "blender.org couldn't be reached ($R2)"
		Goto BL_LatestRelease_End
	${EndIf}
	StrCpy $R0 $R1
	StrCpy $R1 `href="blender-`
	StrCpy $R2 `-windows-$3.zip"`
	Call BL_Highest
	${If} $R3 == ""
		StrCpy $R2 "blender.org has no Blender $2 zip for Windows $3"
		Goto BL_LatestRelease_End
	${EndIf}
	StrCpy $BLVersion $R3
	; blender-5.2.1.sha256 lists the checksum of every download, as
	; sha256sum writes them: <checksum>  <file name>.
	StrCpy $1 `blender-$BLVersion.sha256`
	StrCpy $R0 `$BLFolder$1`
	StrCpy $R1 `${BL_STAGE}\sha256.txt`
	Call BR_Download
	${If} $R2 == ok
		FileOpen $0 $R1 r
		${Do}
			ClearErrors
			FileRead $0 $1
			${IfThen} ${Errors} ${|} ${Break} ${|}
			${WordFind} `x$1` `blender-$BLVersion-windows-$3.zip` "E+1" $2
			${IfNot} ${Errors}
				StrCpy $2 $1 64
				${StrFilter} $2 "-" "" "" $BLDigest
				${Break}
			${EndIf}
		${Loop}
		FileClose $0
	${EndIf}
	StrLen $0 $BLDigest
	${If} $0 <> 64
		StrCpy $BLDigest ""
		StrCpy $R2 "blender.org's checksum for Blender $BLVersion couldn't be read"
	${Else}
		StrCpy $R2 ok
	${EndIf}
	BL_LatestRelease_End:
	Delete `${BL_STAGE}\release.html`
	Delete `${BL_STAGE}\folder.html`
	Delete `${BL_STAGE}\sha256.txt`
	ClearErrors
	Pop $3
	Pop $2
	Pop $1
	Pop $0
	Pop $R3
	Pop $R1
	Pop $R0
FunctionEnd

; $R0 = 7z.exe of a 7-Zip on this computer or next to the package, or "".
Function BL_Find7z
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
Function BL_Unzip
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
		Call BL_Find7z
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

; $R2 = ok when the drive the package is on has room for an install or
; update, else why not. A drive that won't say counts as having room.
Function BL_SpaceCheck
	Push $0
	Push $1
	StrCpy $R2 ok
	System::Call `kernel32::GetDiskFreeSpaceExW(w "$EXEDIR", *l .r0, p 0, p 0) i .r1`
	${If} $1 <> 0
		System::Int64Op $0 / 1048576
		Pop $0
		${If} $0 < ${BL_NEED_MB}
			StrCpy $R2 "the drive has $0 MB free, and about ${BL_NEED_MB} MB is needed"
		${EndIf}
	${EndIf}
	Pop $1
	Pop $0
FunctionEnd

; Downloads, checks and unpacks Blender $BLVersion for build $R0 in the
; staging folder. $R2 = ok, or why not; $R3 = the new Blender folder.
Function BL_Fetch
	Push $R0
	Push $R1
	Push $0
	Push $1
	Push $2
	StrCpy $2 ""
	Call BL_SpaceCheck
	${If} $R2 != ok
		Goto BL_Fetch_End
	${EndIf}
	StrCpy $1 `blender-$BLVersion-windows-$R0.zip`
	StrCpy $2 `${BL_STAGE}\$1`
	RMDir /r `${BL_STAGE}\files`
	Banner::show `Downloading Blender $BLVersion from blender.org...`
	StrCpy $R0 `$BLFolder$1`
	StrCpy $R1 $2
	Call BR_Download
	Banner::destroy
	${If} $R2 != ok
		StrCpy $R2 "Blender couldn't be downloaded ($R2)"
		Goto BL_Fetch_End
	${EndIf}
	Banner::show `Checking Blender $BLVersion...`
	StrCpy $R0 $2
	StrCpy $R1 0x800C
	StrCpy $R2 32
	Push $R3
	Call BR_HashFile
	StrCpy $0 $R3
	Pop $R3
	Banner::destroy
	${If} $0 != $BLDigest
		StrCpy $R2 "the download doesn't match the checksum blender.org publishes for it"
		Goto BL_Fetch_End
	${EndIf}
	Banner::show `Unpacking Blender $BLVersion...`
	StrCpy $R0 $2
	StrCpy $R1 `${BL_STAGE}\files`
	Call BL_Unzip
	Banner::destroy
	; The zip is no longer needed: room for the unpacked files.
	Delete $2
	${If} $R2 != ok
		Goto BL_Fetch_End
	${EndIf}
	; blender.exe in the zip's one folder (blender-5.2.1-windows-x64), or at
	; the top.
	StrCpy $R3 `${BL_STAGE}\files`
	${IfNot} ${FileExists} `$R3\blender.exe`
		StrCpy $R0 `${BL_STAGE}\files`
		Push $R1
		Call BL_FindUnpacked
		Pop $R1
		${IfThen} $R0 != "" ${|} StrCpy $R3 $R0 ${|}
	${EndIf}
	; Signed by the Blender Foundation, and trusted by Windows.
	StrCpy $R0 `$R3\blender.exe`
	Call BR_Signer
	StrCpy $1 $R1
	StrCpy $R0 $R3
	Call BL_InstalledVersion
	StrCpy $0 $R1
	${If} $0 == ""
		StrCpy $R2 "the download doesn't hold Blender"
	${ElseIf} $1 != `${BL_SIGNER}`
		StrCpy $R2 "blender.exe isn't signed by the ${BL_SIGNER}"
	${Else}
		${VersionCompare} $0 $BLVersion $1
		${If} $1 != 0
			StrCpy $R2 "the download holds Blender $0, not $BLVersion"
		${ElseIfNot} ${FileExists} `$R3\blender-launcher.exe`
			StrCpy $R2 "the download doesn't hold blender-launcher.exe"
		${Else}
			StrCpy $R2 ok
		${EndIf}
	${EndIf}
	BL_Fetch_End:
	${IfThen} $2 != "" ${|} Delete $2 ${|}
	ClearErrors
	Pop $2
	Pop $1
	Pop $0
	Pop $R1
	Pop $R0
FunctionEnd

; Blender keeps nothing of yours in its program folder: everything is in
; Data\Blender. A portable folder (Blender's own portable mode) has been
; moved there already.
Function BR_Preserve
FunctionEnd

; Shows why an install or update failed. $R2 is the reason; $R4 is
; downloaded or updated.
Function BL_Failed
	${If} $R4 == updated
		MessageBox MB_OK|MB_ICONEXCLAMATION `Blender couldn't be updated: $R2.$\r$\n$\r$\nThe Blender you have starts as it is. The update is offered again at the next check.`
	${Else}
		MessageBox MB_OK|MB_ICONEXCLAMATION `Blender couldn't be downloaded: $R2.$\r$\n$\r$\nYou can also download Blender's portable zip from blender.org/download and unpack it into this package's App folder.`
	${EndIf}
FunctionEnd

; $R0 = the Blender build for this computer (x64 or arm64).
Function BL_Arch
	Push $0
	ReadEnvStr $0 PROCESSOR_ARCHITEW6432
	${IfThen} $0 == "" ${|} ReadEnvStr $0 PROCESSOR_ARCHITECTURE ${|}
	${If} $0 == ARM64
		StrCpy $R0 arm64
	${Else}
		StrCpy $R0 x64
	${EndIf}
	Pop $0
FunctionEnd

; The first launch: the package has no Blender yet.
Function BL_FirstInstall
	Push $R0
	Push $R2
	Push $R3
	Push $R4
	StrCpy $R4 downloaded
	MessageBox MB_YESNO|MB_ICONQUESTION `Blender isn't in this package yet.$\r$\n$\r$\nDownload the latest Blender from blender.org now? It's about 400 MB (about 2 GB unpacked), and it's checked (blender.org's checksum and the Blender Foundation's signature) before it's used.$\r$\n$\r$\nNo stops here. You can also unpack Blender's portable zip into this package's App folder yourself.` IDYES BL_FirstInstall_Go
	Call Unload
	Quit
	BL_FirstInstall_Go:
	Call BL_Arch
	Call BL_LatestRelease
	${If} $R2 == ok
		Call BL_Fetch
	${EndIf}
	${If} $R2 == ok
		RMDir /r `${BL_APP}`
		ClearErrors
		Rename $R3 `${BL_APP}`
		${If} ${Errors}
			StrCpy $R2 "the new Blender couldn't be moved into place"
		${EndIf}
	${EndIf}
	RMDir /r `${BL_STAGE}`
	${If} $R2 == ok
		Call BR_UpdateChecked
	${Else}
		Call BL_Failed
		Call Unload
		Quit
	${EndIf}
	Pop $R4
	Pop $R3
	Pop $R2
	Pop $R0
FunctionEnd

; Updates Blender when there's a newer release.
Function BL_UpdateCheck
	Push $R0
	Push $R1
	Push $R2
	Push $R3
	Push $R4
	Push $0
	StrCpy $R4 updated
	Call BR_UpdateDue
	${If} $R2 = 1
		Call BL_Arch
		Call BL_LatestRelease
		${If} $R2 == ok
			Call BR_UpdateChecked
			Push $R0
			StrCpy $R0 `${BL_APP}`
			Call BL_InstalledVersion
			StrCpy $0 $R1
			StrCpy $R0 $BLVersion
			Call BR_IsNewer
			Pop $R0
			${If} $R2 = 1
				${ReadUserConfig} $R2 UpdateCheck
				StrCpy $R1 yes
				${If} $R2 != auto
					MessageBox MB_YESNO|MB_ICONQUESTION `Blender $BLVersion is available. This package has Blender $0.$\r$\n$\r$\nUpdate now? It's downloaded from blender.org (about 400 MB) and checked before Blender starts. Your preferences, add-ons and extensions in Data are kept.$\r$\n$\r$\nNo starts Blender $0 as it is.` IDYES +2
					StrCpy $R1 no
				${EndIf}
				${If} $R1 == yes
					; The staging folder goes if the launcher stops halfway.
					${Journal::Record} BrowserStage DIR `${BL_STAGE}` "" recursive ""
					Call BL_Fetch
					${If} $R2 == ok
						StrCpy $R0 Blender
						StrCpy $R1 $R3
						Call BR_Swap
					${EndIf}
					${IfThen} $R2 != ok ${|} Call BL_Failed ${|}
					${Journal::Rollback} BrowserStage
				${EndIf}
			${EndIf}
		${EndIf}
	${EndIf}
	RMDir /r `${BL_STAGE}`
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

; Before the launcher looks for Blender: Blender has no 32-bit build, and a
; Blender added the older way is moved into place first.
${Segment.onInit}
	Push $0
	ReadEnvStr $0 PROCESSOR_ARCHITEW6432
	${IfThen} $0 == "" ${|} ReadEnvStr $0 PROCESSOR_ARCHITECTURE ${|}
	${If} $0 == x86
		MessageBox MB_OK|MB_ICONSTOP `Blender needs 64-bit Windows; this computer runs 32-bit Windows.`
		Pop $0
		Abort
	${EndIf}
	Pop $0
	Call BL_Adopt
!macroend

; Init runs before the launcher looks for Blender, so a package without
; Blender can get one first.
${SegmentInit}
	StrCpy $R0 Blender
	StrCpy $R1 blender.exe
	Call BR_Repair
	RMDir /r `${BL_STAGE}`
	${IfNot} ${FileExists} `${BL_APP}\blender.exe`
		Call BL_FirstInstall
	${EndIf}
!macroend

; The older layout first: a portable folder in App\Blender has to be out of
; it before an update swaps the folder, and Data\Blender\local in place
; before the caches are moved in.
${SegmentPrePrimary}
	Call BL_Migrate
	Call BL_UpdateCheck
	Call BR_UpdatePaths
	Call BL_JournalWindows
!macroend

; Every launch, the second one too.
${SegmentPreExec}
	Call BL_UserFolders
!macroend

${SegmentPostPrimary}
	Call BL_RemoveNew
	${Journal::HasEntries} BlenderPortable $R0
	${If} $R0 > 0
		${Journal::Rollback} BlenderPortable
	${EndIf}
	Call BL_WriteVersion
!macroend
