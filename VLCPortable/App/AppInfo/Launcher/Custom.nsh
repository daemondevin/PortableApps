; VLC Media Player Portable custom code for PortableApps Compiler.
; For support, visit the GitHub project:
; https://github.com/daemondevin/pac-man
;
; VLC runs from App\vlc. It keeps everything of yours (vlcrc, the
; interface's settings, the media library, album art, extensions and skins
; you add) in a folder named portable next to vlc.exe when there is one, so
; Data\VLC is moved there for each session and back afterward. What this
; file adds:
;
;   Install         A package without VLC offers to download it: the newest
;                   release's zip from download.videolan.org, the 64-bit
;                   build or, on 32-bit Windows, the 32-bit one. The zip is
;                   checked against the SHA-256 VideoLAN publishes next to it
;                   and vlc.exe against VideoLAN's signature, then unpacked
;                   with Windows' own tar.exe, or 7-Zip.
;   Updates         The same, before VLC starts, at most every UpdateInterval
;                   days, keeping the build in use. VLC's own update notice is
;                   turned off while the launcher checks.
;   Settings        Data\VLC goes into App\vlc\portable for the session and
;                   back afterward; a folder left there by a session that
;                   didn't close properly is taken back first.
;   Older layout    PortableApps.com's Data\settings\vlcrc, ml.xspf and
;                   vlc-qt-interface.ini move into Data\VLC.
;   Language        VLC keeps its language in the registry; the launcher
;                   keeps it in the package, puts it there for the session,
;                   and follows the PortableApps.com Platform's language when
;                   that changes, or the Language in VLCPortable.ini.
;   Moving          Paths in vlcrc, the interface's recent files and the media
;                   library are updated when the package moves.
;   Java            A portable Java in the Platform's CommonFiles is named by
;                   JAVA_HOME for Blu-ray menus when there's no other.
;   Leftovers       HKCU\Software\VideoLAN and %APPDATA%\vlc (crash dumps) are
;                   journaled and undone.
;   Version         The version of vlc.exe is written to appinfo.ini.

; Defines
!define VL_APP      `$EXEDIR\App\vlc`
!define VL_PORT     `$EXEDIR\App\vlc\portable`
!define VL_DATA     `${DATA}\VLC`
!define VL_STAGE    `$EXEDIR\App\vlcUpdate`
!define VL_INFO     `$EXEDIR\App\AppInfo\appinfo.ini`
!define VL_REG      `Software\VideoLAN\VLC`
!define VL_RELEASE  `https://download.videolan.org/pub/videolan/vlc/`
!define VL_SIGNER   `VideoLAN`

; Variables
Var VLVersion       ; the version on offer (3.0.24)
Var VLDigest        ; the zip's SHA-256 as VideoLAN publishes it
Var VLBase          ; where the releases are (ReleaseURL), ending in /
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
Function VL_JournalDir
	${IfNot} ${FileExists} `$R0\*.*`
		${Journal::Record} VLCPortable DIR $R0 "" $R1 ""
	${EndIf}
FunctionEnd

; Moves what's in the folder $R0 into the folder $R1, replacing what's
; there.
Function VL_MoveContents
	Push $0
	Push $1
	${If} ${FileExists} `$R0\*.*`
		CreateDirectory $R1
		FindFirst $0 $1 `$R0\*`
		${DoWhile} $1 != ""
			${If} $1 != "."
			${AndIf} $1 != ".."
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

; $R1 = the machine the program file $R0 is built for: x86, x64, arm64, or
; "" when it can't be read.
Function VL_Machine
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

; $R1 = 1 when $R0 is a version made of digits and dots (3.0.24), else 0.
Function VL_IsVersion
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

; $R1 = 1 when $R0 is 64 hexadecimal digits, else 0.
Function VL_IsSha256
	Push $0
	StrCpy $R1 0
	StrLen $0 $R0
	${If} $0 = 64
		${StrFilter} $R0 "1" "abcdefABCDEF" "" $0
		${IfThen} $0 S== $R0 ${|} StrCpy $R1 1 ${|}
	${EndIf}
	Pop $0
FunctionEnd

; Settings folder

; PortableApps.com's package kept vlcrc and ml.xspf in Data\settings (with
; its launcher's settings) and moved vlc-qt-interface.ini next to vlc.exe for
; each session. They're where VLC keeps them in its portable folder now.
Function VL_Migrate
	CreateDirectory `${VL_DATA}`
	${If} ${FileExists} `${DATA}\settings\vlcrc`
	${AndIfNot} ${FileExists} `${VL_DATA}\vlcrc`
		Rename `${DATA}\settings\vlcrc` `${VL_DATA}\vlcrc`
	${EndIf}
	${If} ${FileExists} `${DATA}\settings\ml.xspf`
	${AndIfNot} ${FileExists} `${VL_DATA}\ml.xspf`
		Rename `${DATA}\settings\ml.xspf` `${VL_DATA}\ml.xspf`
	${EndIf}
	${If} ${FileExists} `${DATA}\settings\vlc-qt-interface.ini`
	${AndIfNot} ${FileExists} `${VL_DATA}\vlc\vlc-qt-interface.ini`
		CreateDirectory `${VL_DATA}\vlc`
		Rename `${DATA}\settings\vlc-qt-interface.ini` `${VL_DATA}\vlc\vlc-qt-interface.ini`
	${EndIf}
	ClearErrors
FunctionEnd

; App\vlc\portable goes back to Data\VLC: after each session, and before
; the next one in case the last one didn't close properly (what's there is
; newer than what's in Data).
Function VL_Out
	Push $R0
	Push $R1
	${If} ${FileExists} `${VL_PORT}\*.*`
		${IfNot} ${FileExists} `${VL_DATA}\*.*`
			Rename `${VL_PORT}` `${VL_DATA}`
		${Else}
			StrCpy $R0 `${VL_PORT}`
			StrCpy $R1 `${VL_DATA}`
			Call VL_MoveContents
			RMDir `${VL_PORT}`
		${EndIf}
	${EndIf}
	ClearErrors
	Pop $R1
	Pop $R0
FunctionEnd

; Data\VLC becomes App\vlc\portable for the session.
Function VL_In
	CreateDirectory `${VL_DATA}`
	RMDir `${VL_PORT}`
	${IfNot} ${FileExists} `${VL_PORT}\*.*`
		Rename `${VL_DATA}` `${VL_PORT}`
	${EndIf}
	ClearErrors
FunctionEnd

; Install and updates

; $R0 = the VideoLAN build for this computer: win32 on 32-bit Windows, else
; win64 (VLC 3 has no ARM64 build; Windows on ARM runs the x64 one).
Function VL_HostBuild
	Push $0
	ReadEnvStr $0 PROCESSOR_ARCHITEW6432
	${IfThen} $0 == "" ${|} ReadEnvStr $0 PROCESSOR_ARCHITECTURE ${|}
	${If} $0 == x86
		StrCpy $R0 win32
	${Else}
		StrCpy $R0 win64
	${EndIf}
	Pop $0
FunctionEnd

; $R0 = the build of the VLC in the package (win32 or win64), else the one
; for this computer.
Function VL_Build
	Push $R1
	StrCpy $R0 `${VL_APP}\vlc.exe`
	Call VL_Machine
	${If} $R1 == x86
		StrCpy $R0 win32
	${ElseIf} $R1 == ""
		Call VL_HostBuild
	${Else}
		StrCpy $R0 win64
	${EndIf}
	Pop $R1
FunctionEnd

; $R1 = the version of the VLC in the folder $R0 (3.0.24), or "".
Function VL_InstalledVersion
	Push $R0
	StrCpy $R0 `$R0\vlc.exe`
	StrCpy $R1 ""
	${If} ${FileExists} $R0
		Call BR_FileVersion
		${WordFind} $R1 "." "E-1{" $R0
		${IfNot} ${Errors}
			StrCpy $R1 $R0
		${EndIf}
	${EndIf}
	ClearErrors
	Pop $R0
FunctionEnd

; $R3 = the highest version in the directory listing $R0 found between $R1
; and $R2 in its links (href="vlc- and -win64.zip" give 3.0.24 for
; vlc-3.0.24-win64.zip), or "". The listing is read in pieces, with the end
; of each piece kept for the next, so how it's laid out doesn't matter.
Function VL_Highest
	Push $R0
	Push $R1
	Push $0
	Push $1
	Push $2
	Push $3
	Push $4
	StrCpy $R3 ""
	StrCpy $3 $R1
	StrCpy $2 ""
	ClearErrors
	FileOpen $0 $R0 r
	${IfNot} ${Errors}
		${Do}
			ClearErrors
			FileRead $0 $1 700
			${IfThen} ${Errors} ${|} ${Break} ${|}
			StrCpy $2 `$2$1`
			StrCpy $4 1
			${Do}
				ClearErrors
				${WordFind} `x$2` $3 "E+$4}" $1
				${IfThen} ${Errors} ${|} ${Break} ${|}
				${WordFind} `x$1` $R2 "E+1{" $R0
				${IfNot} ${Errors}
					StrCpy $R0 $R0 "" 1
					Call VL_IsVersion
					${If} $R1 = 1
						${If} $R3 == ""
							StrCpy $R3 $R0
						${Else}
							${VersionCompare} $R0 $R3 $1
							${IfThen} $1 = 1 ${|} StrCpy $R3 $R0 ${|}
						${EndIf}
					${EndIf}
				${EndIf}
				IntOp $4 $4 + 1
			${Loop}
			StrCpy $2 $2 "" -200
		${Loop}
		FileClose $0
	${EndIf}
	ClearErrors
	Pop $4
	Pop $3
	Pop $2
	Pop $1
	Pop $0
	Pop $R1
	Pop $R0
FunctionEnd

; Finds the newest VLC for build $R0 (win32 or win64) in the last folder of
; VideoLAN's releases, and the zip's checksum next to it in that version's
; folder: sets $VLVersion, $VLDigest and $VLBase. $R2 = ok, or why not.
Function VL_LatestRelease
	Push $R0
	Push $R1
	Push $R3
	Push $0
	Push $1
	Push $2
	StrCpy $2 $R0
	StrCpy $VLVersion ""
	StrCpy $VLDigest ""
	ClearErrors
	${ReadUserConfig} $VLBase ReleaseURL
	${IfThen} $VLBase == "" ${|} StrCpy $VLBase `${VL_RELEASE}` ${|}
	StrCpy $1 $VLBase 1 -1
	${IfThen} $1 != "/" ${|} StrCpy $VLBase `$VLBase/` ${|}
	CreateDirectory `${VL_STAGE}`
	StrCpy $1 `last/$2/`
	StrCpy $R0 `$VLBase$1`
	StrCpy $R1 `${VL_STAGE}\last.html`
	Call BR_Download
	${If} $R2 != ok
		StrCpy $R2 "VideoLAN couldn't be reached ($R2)"
		Goto VL_LatestRelease_End
	${EndIf}
	StrCpy $R0 $R1
	StrCpy $R1 `href="vlc-`
	StrCpy $R2 `-$2.zip"`
	Call VL_Highest
	${If} $R3 == ""
		StrCpy $R2 "VideoLAN's release list has no VLC zip for $2"
		Goto VL_LatestRelease_End
	${EndIf}
	StrCpy $VLVersion $R3
	; vlc-3.0.24-win64.zip.sha256: <checksum>, then the file name.
	StrCpy $1 `vlc-$VLVersion-$2.zip.sha256`
	StrCpy $R0 `$VLBase$VLVersion/$2/$1`
	StrCpy $R1 `${VL_STAGE}\sha256.txt`
	Call BR_Download
	${If} $R2 == ok
		FileOpen $0 $R1 r
		FileRead $0 $1 64
		FileClose $0
		StrCpy $R0 $1
		Call VL_IsSha256
		${IfThen} $R1 = 1 ${|} ${StrFilter} $R0 "-" "" "" $VLDigest ${|}
	${EndIf}
	${If} $VLDigest == ""
		StrCpy $R2 "VideoLAN's checksum for VLC $VLVersion couldn't be read"
	${Else}
		StrCpy $R2 ok
	${EndIf}
	VL_LatestRelease_End:
	Delete `${VL_STAGE}\last.html`
	Delete `${VL_STAGE}\sha256.txt`
	ClearErrors
	Pop $2
	Pop $1
	Pop $0
	Pop $R3
	Pop $R1
	Pop $R0
FunctionEnd

; $R0 = 7z.exe of a 7-Zip on this computer or next to the package, or "".
Function VL_Find7z
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
Function VL_Unzip
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
		Call VL_Find7z
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

; Downloads, checks and unpacks VLC $VLVersion for build $R0 (win32 or
; win64) in the staging folder. $R2 = ok, or why not; $R3 = the new VLC
; folder.
Function VL_Fetch
	Push $R0
	Push $R1
	Push $0
	Push $1
	Push $2
	StrCpy $1 `vlc-$VLVersion-$R0.zip`
	StrCpy $2 `${VL_STAGE}\$1`
	RMDir /r `${VL_STAGE}\files`
	Banner::show `Downloading VLC $VLVersion from VideoLAN...`
	StrCpy $R0 `$VLBase$VLVersion/$R0/$1`
	StrCpy $R1 $2
	Call BR_Download
	Banner::destroy
	${If} $R2 != ok
		StrCpy $R2 "VLC couldn't be downloaded ($R2)"
		Goto VL_Fetch_End
	${EndIf}
	StrCpy $R0 $2
	StrCpy $R1 0x800C
	StrCpy $R2 32
	Push $R3
	Call BR_HashFile
	StrCpy $0 $R3
	Pop $R3
	${If} $0 != $VLDigest
		StrCpy $R2 "the download doesn't match the checksum VideoLAN publishes for it"
		Goto VL_Fetch_End
	${EndIf}
	Banner::show `Unpacking VLC $VLVersion...`
	StrCpy $R0 $2
	StrCpy $R1 `${VL_STAGE}\files`
	Call VL_Unzip
	Banner::destroy
	${If} $R2 != ok
		Goto VL_Fetch_End
	${EndIf}
	; vlc.exe in the zip's one folder (vlc-3.0.24), or at the top.
	StrCpy $R3 `${VL_STAGE}\files`
	${IfNot} ${FileExists} `$R3\vlc.exe`
		FindFirst $0 $1 `${VL_STAGE}\files\*`
		${DoWhile} $1 != ""
			${If} ${FileExists} `${VL_STAGE}\files\$1\vlc.exe`
				StrCpy $R3 `${VL_STAGE}\files\$1`
			${EndIf}
			FindNext $0 $1
		${Loop}
		FindClose $0
	${EndIf}
	; Signed by VideoLAN, and trusted by Windows.
	StrCpy $R0 `$R3\vlc.exe`
	Call BR_Signer
	StrCpy $1 $R1
	StrCpy $R0 $R3
	Call VL_InstalledVersion
	StrCpy $0 $R1
	${If} $0 == ""
		StrCpy $R2 "the download doesn't hold VLC"
	${ElseIf} $1 != `${VL_SIGNER}`
		StrCpy $R2 "vlc.exe isn't signed by ${VL_SIGNER}"
	${Else}
		${VersionCompare} $0 $VLVersion $1
		${If} $1 != 0
			StrCpy $R2 "the download holds VLC $0, not $VLVersion"
		${Else}
			StrCpy $R2 ok
		${EndIf}
	${EndIf}
	VL_Fetch_End:
	Delete $2
	ClearErrors
	Pop $2
	Pop $1
	Pop $0
	Pop $R1
	Pop $R0
FunctionEnd

; After an update, skins and Lua extensions you added to the old VLC folder
; (ones the new VLC doesn't bring) go into the new one. $R0 is the old VLC
; folder, $R1 the new one.
!macro VL_Carry _SUB
	FindFirst $0 $1 `$R0\${_SUB}\*`
	${DoWhile} $1 != ""
		${If} $1 != "."
		${AndIf} $1 != ".."
		${AndIfNot} ${FileExists} `$R1\${_SUB}\$1`
			CreateDirectory `$R1\${_SUB}`
			Rename `$R0\${_SUB}\$1` `$R1\${_SUB}\$1`
		${EndIf}
		FindNext $0 $1
	${Loop}
	FindClose $0
!macroend
Function BR_Preserve
	Push $0
	Push $1
	!insertmacro VL_Carry skins
	!insertmacro VL_Carry lua\extensions
	!insertmacro VL_Carry lua\playlist
	!insertmacro VL_Carry lua\intf
	!insertmacro VL_Carry lua\sd
	ClearErrors
	Pop $1
	Pop $0
FunctionEnd

; Builds VLC's plugin cache (plugins\plugins.dat) for the VLC in the folder
; $R0, so VLC doesn't scan all its plugins at every start.
Function VL_CacheGen
	Push $0
	${If} ${FileExists} `$R0\vlc-cache-gen.exe`
		nsExec::Exec `"$R0\vlc-cache-gen.exe" "$R0\plugins"`
		Pop $0
	${EndIf}
	ClearErrors
	Pop $0
FunctionEnd

; Shows why an install or update failed. $R2 is the reason; $R4 is
; downloaded or updated.
Function VL_Failed
	${If} $R4 == updated
		MessageBox MB_OK|MB_ICONEXCLAMATION `VLC couldn't be updated: $R2.$\r$\n$\r$\nThe VLC you have starts as it is. The update is offered again at the next check.`
	${Else}
		MessageBox MB_OK|MB_ICONEXCLAMATION `VLC couldn't be downloaded: $R2.$\r$\n$\r$\nYou can also download VLC's zip from videolan.org and unpack it into this package's App\vlc folder.`
	${EndIf}
FunctionEnd

; The first launch: the package has no VLC yet.
Function VL_FirstInstall
	Push $R0
	Push $R2
	Push $R3
	Push $R4
	StrCpy $R4 downloaded
	MessageBox MB_YESNO|MB_ICONQUESTION `VLC isn't in this package yet.$\r$\n$\r$\nDownload the latest VLC from VideoLAN now? It's about 45 MB, and it's checked (VideoLAN's checksum and signature) before it's used.$\r$\n$\r$\nNo stops here. You can also unpack VLC's zip into this package's App\vlc folder yourself.` IDYES VL_FirstInstall_Go
	Call Unload
	Quit
	VL_FirstInstall_Go:
	Call VL_HostBuild
	Call VL_LatestRelease
	${If} $R2 == ok
		Call VL_Fetch
	${EndIf}
	${If} $R2 == ok
		RMDir /r `${VL_APP}`
		ClearErrors
		Rename $R3 `${VL_APP}`
		${If} ${Errors}
			StrCpy $R2 "the new VLC couldn't be moved into place"
		${EndIf}
	${EndIf}
	RMDir /r `${VL_STAGE}`
	${If} $R2 == ok
		StrCpy $R0 `${VL_APP}`
		Call VL_CacheGen
		Call BR_UpdateChecked
	${Else}
		Call VL_Failed
		Call Unload
		Quit
	${EndIf}
	Pop $R4
	Pop $R3
	Pop $R2
	Pop $R0
FunctionEnd

; Updates VLC when there's a newer release, keeping the build in use.
Function VL_UpdateCheck
	Push $R0
	Push $R1
	Push $R2
	Push $R3
	Push $R4
	Push $0
	StrCpy $R4 updated
	Call BR_UpdateDue
	${If} $R2 = 1
		Call VL_Build
		Call VL_LatestRelease
		${If} $R2 == ok
			Call BR_UpdateChecked
			Push $R0
			StrCpy $R0 `${VL_APP}`
			Call VL_InstalledVersion
			StrCpy $0 $R1
			StrCpy $R0 $VLVersion
			Call BR_IsNewer
			Pop $R0
			${If} $R2 = 1
				${ReadUserConfig} $R2 UpdateCheck
				StrCpy $R1 yes
				${If} $R2 != auto
					MessageBox MB_YESNO|MB_ICONQUESTION `VLC $VLVersion is available. This package has VLC $0.$\r$\n$\r$\nUpdate now? It's downloaded from VideoLAN (about 45 MB) and checked before VLC starts. Your settings are kept.$\r$\n$\r$\nNo starts VLC $0 as it is.` IDYES +2
					StrCpy $R1 no
				${EndIf}
				${If} $R1 == yes
					; The staging folder goes if the launcher stops halfway.
					${Journal::Record} BrowserStage DIR `${VL_STAGE}` "" recursive ""
					Call VL_Fetch
					${If} $R2 == ok
						StrCpy $R0 vlc
						StrCpy $R1 $R3
						Call BR_Swap
					${EndIf}
					${If} $R2 == ok
						StrCpy $R0 `${VL_APP}`
						Call VL_CacheGen
					${Else}
						Call VL_Failed
					${EndIf}
					${Journal::Rollback} BrowserStage
				${EndIf}
			${EndIf}
		${EndIf}
	${EndIf}
	RMDir /r `${VL_STAGE}`
	ClearErrors
	Pop $0
	Pop $R4
	Pop $R3
	Pop $R2
	Pop $R1
	Pop $R0
FunctionEnd

; Language

; $R0 = VLC's code for the PortableApps.com Platform's language, among the
; ones in App\vlc\locale, or "".
Function VL_PlatformLanguage
	Push $0
	Push $1
	StrCpy $R0 ""
	ReadEnvStr $0 PAL:LanguageGlibc
	ReadEnvStr $1 PAL:LanguageCode
	${If} $0 != ""
	${AndIf} ${FileExists} `${VL_APP}\locale\$0\*.*`
		StrCpy $R0 $0
	${ElseIf} $1 != ""
	${AndIf} ${FileExists} `${VL_APP}\locale\$1\*.*`
		StrCpy $R0 $1
	${ElseIf} $1 == pt
		StrCpy $R0 pt_PT
	${ElseIf} $1 == zh
		StrCpy $R0 zh_CN
	${ElseIf} $1 == en
		StrCpy $R0 en
	${EndIf}
	${If} $R0 == pt_PT
	${OrIf} $R0 == zh_CN
		${IfNotThen} ${FileExists} `${VL_APP}\locale\$R0\*.*` ${|} StrCpy $R0 "" ${|}
	${EndIf}
	Pop $1
	Pop $0
FunctionEnd

; VLC reads its language (Preferences > Interface > Language) from
; HKCU\Software\VideoLAN\VLC, Lang. The launcher keeps it in its settings
; and puts it there for the session (the key is journaled, so an installed
; VLC's comes back): the Language in VLCPortable.ini, else the Platform's
; when that's not the one it was last time, else the one picked last time.
Function VL_Language
	Push $R0
	Push $0
	Push $1
	; HKCU\Software\VideoLAN is journaled in VL_JournalWindows first.
	ClearErrors
	${ReadUserConfig} $R0 Language
	${If} $R0 == ""
		ReadEnvStr $1 PAL:_IgnoreLanguage
		ReadEnvStr $0 PAL:LanguageGlibc
		${ReadSettings} $R0 LanguageFrom
		${If} $1 != true
		${AndIf} $0 != ""
		${AndIf} $0 != $R0
			${WriteSettings} $0 LanguageFrom
			Call VL_PlatformLanguage
			${IfThen} $R0 != "" ${|} ${WriteSettings} $R0 VLCLang ${|}
		${EndIf}
		${ReadSettings} $R0 VLCLang
	${EndIf}
	${If} $R0 != ""
	${AndIf} $R0 != auto
		WriteRegStr HKCU `${VL_REG}` Lang $R0
	${Else}
		DeleteRegValue HKCU `${VL_REG}` Lang
	${EndIf}
	ClearErrors
	Pop $1
	Pop $0
	Pop $R0
FunctionEnd

; Keeps the language picked in VLC's preferences, before the registry is
; put back.
Function VL_SaveLanguage
	Push $0
	ClearErrors
	ReadRegStr $0 HKCU `${VL_REG}` Lang
	${If} ${Errors}
		StrCpy $0 ""
	${EndIf}
	CreateDirectory `${SET}`
	${WriteSettings} $0 VLCLang
	ClearErrors
	Pop $0
FunctionEnd

; Moving the package

; Replaces the path $R8 with $R9 (both ending in a backslash) in the file
; $R7: as written (D:\Media\), with doubled backslashes (Qt's settings),
; with forward slashes (D:/Media/), and as file URLs with spaces as %20.
Function VL_ReplaceIn
	Push $0
	Push $1
	${If} ${FileExists} $R7
		${ReplaceInFile} $R7 $R8 $R9
		${WordReplace} $R8 "\" "\\" "+" $0
		${WordReplace} $R9 "\" "\\" "+" $1
		${ReplaceInFile} $R7 $0 $1
		${WordReplace} $R8 "\" "/" "+" $0
		${WordReplace} $R9 "\" "/" "+" $1
		${ReplaceInFile} $R7 $0 $1
		${WordReplace} $0 " " "%20" "+" $0
		${WordReplace} $1 " " "%20" "+" $1
		${ReplaceInFile} $R7 `file:///$0` `file:///$1`
	${EndIf}
	ClearErrors
	Pop $1
	Pop $0
FunctionEnd

; Called by BR_UpdatePaths with $R8 and $R9 set, while Data\VLC is in Data.
Function BR_PathFiles
	Push $R7
	StrCpy $R7 `${VL_DATA}\vlcrc`
	Call VL_ReplaceIn
	StrCpy $R7 `${VL_DATA}\vlc\vlc-qt-interface.ini`
	Call VL_ReplaceIn
	StrCpy $R7 `${VL_DATA}\ml.xspf`
	Call VL_ReplaceIn
	Pop $R7
FunctionEnd

; Java

; Blu-ray menus (BD-J) run on Java, which libbluray loads into VLC: it finds
; an installed Java itself, and one named by JAVA_HOME. Without either, a
; portable Java in the PortableApps.com Platform's CommonFiles is named, of
; the same build as VLC (jvm.dll is loaded into vlc.exe).
Function VL_Java
	Push $R0
	Push $0
	Push $1
	ReadEnvStr $0 JAVA_HOME
	${If} $0 == ""
	${OrIfNot} ${FileExists} `$0\bin\*.*`
		${GetParent} $EXEDIR $1
		StrCpy $0 ""
		Call VL_Build
		${If} $R0 == win64
			${IfThen} ${FileExists} `$1\CommonFiles\Java64\bin\server\jvm.dll` ${|} StrCpy $0 `$1\CommonFiles\Java64` ${|}
		${Else}
			${IfThen} ${FileExists} `$1\CommonFiles\Java\bin\client\jvm.dll` ${|} StrCpy $0 `$1\CommonFiles\Java` ${|}
			${If} $0 == ""
			${AndIf} ${FileExists} `$1\CommonFiles\Java\bin\server\jvm.dll`
				StrCpy $0 `$1\CommonFiles\Java`
			${EndIf}
		${EndIf}
		${If} $0 != ""
			System::Call `kernel32::SetEnvironmentVariable(t "JAVA_HOME", t "$0")`
		${EndIf}
	${EndIf}
	Pop $1
	Pop $0
	Pop $R0
FunctionEnd

; Leftovers

Function VL_JournalWindows
	Push $R0
	Push $R1
	Push $0
	; Where VLC keeps its language (and an installed VLC its own).
	${Journal::RegKey} VLCPortable HKCU `Software\VideoLAN` $0
	; Crash dumps, and anything else still using the default folder.
	StrCpy $R1 recursive
	StrCpy $R0 `$APPDATA\vlc`
	Call VL_JournalDir
	ClearErrors
	Pop $0
	Pop $R1
	Pop $R0
FunctionEnd

; Writes the version of vlc.exe to appinfo.ini: 3.0.24.0 as PackageVersion,
; 3.0.24 as DisplayVersion.
Function VL_WriteVersion
	Push $0
	Push $1
	Push $2
	Push $3
	Push $4
	ClearErrors
	GetDllVersion `${VL_APP}\vlc.exe` $0 $1
	${IfNot} ${Errors}
		IntOp $2 $0 >> 16
		IntOp $2 $2 & 0xFFFF
		IntOp $3 $0 & 0xFFFF
		IntOp $4 $1 >> 16
		IntOp $4 $4 & 0xFFFF
		IntOp $1 $1 & 0xFFFF
		StrCpy $0 `$2.$3.$4`
		ReadINIStr $2 `${VL_INFO}` Version DisplayVersion
		${If} $0 != $2
		${AndIf} $0 != "0.0.0"
			WriteINIStr `${VL_INFO}` Version PackageVersion `$0.$1`
			WriteINIStr `${VL_INFO}` Version DisplayVersion $0
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

; Init runs before the launcher looks for VLC, so a package without VLC
; can get one first.
${SegmentInit}
	StrCpy $R0 vlc
	StrCpy $R1 vlc.exe
	Call BR_Repair
	RMDir /r `${VL_STAGE}`
	${IfNot} ${FileExists} `${VL_APP}\vlc.exe`
		Call VL_FirstInstall
	${EndIf}
!macroend

; Data\VLC is in Data for the update and the path updates, and goes into
; App\vlc\portable last.
${SegmentPrePrimary}
	Call VL_Migrate
	Call VL_Out
	Call VL_UpdateCheck
	Call BR_UpdatePaths
	Call VL_JournalWindows
	Call VL_Language
	Call VL_In
!macroend

; Every launch: Java for Blu-ray menus, and VLC's own update notice, which
; offers its installer (it would install VLC into Program Files), is off
; while the launcher checks.
${SegmentPreExec}
	Call VL_Java
	Push $0
	ClearErrors
	${ReadUserConfig} $0 UpdateCheck
	${If} $0 != off
		StrCpy $ExecString `$ExecString --no-qt-updates-notif`
	${EndIf}
	Pop $0
!macroend

${SegmentPostPrimary}
	Call VL_Out
	Call VL_SaveLanguage
	${Journal::HasEntries} VLCPortable $R0
	${If} $R0 > 0
		${Journal::Rollback} VLCPortable
	${EndIf}
	Call VL_WriteVersion
!macroend
