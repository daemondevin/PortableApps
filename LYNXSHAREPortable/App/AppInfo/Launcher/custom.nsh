; LYNX SHARE Portable custom code for PortableApps Compiler.
; For support, visit the GitHub project:
; https://github.com/daemondevin/pac-man
;
; LYNX SHARE keeps everything it writes (settings, plugin list, autosaves,
; caches, crash logs, templates) in the folder LYNX_PROFILE_DIR names, which
; the launcher INI points at Data\Profile. What this file adds:
;
;   Updates    Before LYNX SHARE starts, at most every UpdateInterval days,
;              the release list on GitHub (Ka1-S/LYNX-SHARE) is checked. Every
;              LYNX SHARE release so far is a pre-release, so the newest one
;              is taken, pre-release or not. A newer one is downloaded as its
;              Windows zip and checked against the SHA-256 in the release's
;              SHA256SUMS.txt (and the one GitHub records for the zip, when
;              there is one), unpacked with Windows' own tar.exe or 7-Zip,
;              and swapped in. The swap is journaled, so a crash halfway puts
;              the old LYNX SHARE back. A package without LYNX SHARE offers to
;              download it the same way. While the launcher does the
;              updating, LYNX SHARE's own automatic check is turned off.
;   Leftovers  The empty %APPDATA%\LYNX folder LYNX SHARE creates at start is
;              journaled and removed again.
;   Version    The version that ran is written to appinfo.ini.

; Defines
!define LX_APP      `$EXEDIR\App\LYNX`
!define LX_EXE      `${LX_APP}\LYNX.exe`
!define LX_STAGE    `$EXEDIR\App\LYNXUpdate`
!define LX_RELEASES `https://api.github.com/repos/Ka1-S/LYNX-SHARE/releases?per_page=5`
!define LX_UPDATES  `$DataDirectory\Profile\LYNX\updates.txt`

; Variables
Var LXTag           ; the release on offer (v0.1.21-alpha)
Var LXVersion       ; its version as the file names have it (0.1.21-alpha)
Var LXZipURL        ; its Windows zip
Var LXSumsURL       ; its SHA256SUMS.txt
Var LXDigest        ; the zip's SHA-256 as GitHub records it, or ""

; Shared update helpers (from the browser packages)

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

; $R2 = 1 when version $R0 is newer than $R1, else 0.
Function BR_IsNewer
	${If} $R1 == ""
		StrCpy $R2 1
	${Else}
		${VersionCompare} $R0 $R1 $R2
		${IfThen} $R2 != 1 ${|} StrCpy $R2 0 ${|}
	${EndIf}
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

; LYNX SHARE's side

; $R1 = the version of the program file $R0, as 0.1.21.0, or "".
Function LX_FileVersion
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

; $R1 = the numbers of the version $R0, without a suffix: 0.1.21 for
; 0.1.21-alpha. LYNX.exe carries only the numbers.
Function LX_Numbers
	Push $0
	Push $1
	StrCpy $R1 $R0
	StrCpy $0 0
	${Do}
		StrCpy $1 $R0 1 $0
		${If} $1 == ""
			${ExitDo}
		${ElseIf} $1 == "-"
		${OrIf} $1 == "+"
		${OrIf} $1 == " "
			StrCpy $R1 $R0 $0
			${ExitDo}
		${EndIf}
		IntOp $0 $0 + 1
	${Loop}
	Pop $1
	Pop $0
FunctionEnd

; Asks GitHub for LYNX SHARE's newest release. Every release so far is a
; pre-release, which GitHub's "latest" never names, so the release list is
; read and its first entry, the newest, is taken. Sets $LXTag, $LXVersion,
; $LXZipURL and $LXSumsURL and, when GitHub records it, $LXDigest.
; $R2 = ok, or why not.
;
; GitHub's answer may come as one long line, so it's read in pieces, with
; the end of each piece kept for the next, and white space taken out. The
; zip is found by its download URL (/LYNX-0.1.21-alpha-windows-x64.zip"),
; not its "name", which comes earlier in the same asset. Each asset gives its
; "digest" a little before its "browser_download_url"; a digest only counts
; when no other asset's download URL comes between them.
Function LX_LatestRelease
	Push $R0
	Push $R1
	Push $R4
	Push $0
	Push $1
	Push $2
	Push $3
	Push $4
	ClearErrors
	${ReadUserConfig} $0 ReleaseURL
	StrCpy $R4 $0
	${IfThen} $0 == "" ${|} StrCpy $0 `${LX_RELEASES}` ${|}
	CreateDirectory `${LX_STAGE}`
	StrCpy $R0 $0
	StrCpy $R1 `${LX_STAGE}\releases.json`
	Call BR_Download
	StrCpy $LXTag ""
	StrCpy $LXVersion ""
	StrCpy $LXZipURL ""
	StrCpy $LXSumsURL ""
	StrCpy $LXDigest ""
	${If} $R2 == ok
		StrCpy $2 ""
		StrCpy $4 ""
		FileOpen $0 $R1 r
		${Do}
			ClearErrors
			FileRead $0 $1 650
			${IfThen} ${Errors} ${|} ${Break} ${|}
			${WordReplace} $1 " " "" "+" $1
			${WordReplace} $1 "$\t" "" "+" $1
			${WordReplace} $1 "$\r" "" "+" $1
			${WordReplace} $1 "$\n" "" "+" $1
			StrCpy $2 `$2$1`
			${If} $LXTag == ""
				ClearErrors
				${WordFind} `x$2` `"tag_name":"` "E+1}" $3
				${IfNot} ${Errors}
					${WordFind} `x$3` `"` "E+1{" $3
					${IfNot} ${Errors}
						StrCpy $LXTag $3 "" 1
						StrCpy $LXVersion $LXTag
						StrCpy $3 $LXVersion 1
						${IfThen} $3 == v ${|} StrCpy $LXVersion $LXVersion "" 1 ${|}
						; The end of the zip's download URL.
						StrCpy $4 `/LYNX-`
						StrCpy $4 `$4$LXVersion`
						StrCpy $4 `$4-windows-x64.zip"`
					${EndIf}
				${EndIf}
			${EndIf}
			${If} $4 != ""
			${AndIf} $LXZipURL == ""
				ClearErrors
				${WordFind} `x$2` $4 "E+1{" $3
				${IfNot} ${Errors}
					; The URL is what follows the last "browser_download_url"
					; before it.
					${WordFind} `x$3` `"browser_download_url":"` "E-1}" $1
					${IfNot} ${Errors}
						StrCpy $LXSumsURL `$1/SHA256SUMS.txt`
						StrCpy $LXZipURL $4 -1
						StrCpy $LXZipURL `$1$LXZipURL`
					${EndIf}
					; The last digest before that URL's start, unless another
					; asset's URL follows it.
					${WordFind} `x$3` `"browser_download_url":"` "E-1{" $3
					${IfNot} ${Errors}
						${WordFind} `x$3` `"digest":"sha256:` "E-1}" $1
						${IfNot} ${Errors}
							ClearErrors
							${WordFind} `x$1` `"browser_download_url"` "E+1" $R1
							${If} ${Errors}
								StrCpy $1 $1 64
								${StrFilter} $1 "1" "abcdefABCDEF" "" $R1
								StrLen $R0 $1
								${If} $R1 S== $1
								${AndIf} $R0 = 64
									${StrFilter} $1 "-" "" "" $LXDigest
								${EndIf}
							${EndIf}
						${EndIf}
					${EndIf}
					; Only a GitHub download URL is taken, unless ReleaseURL names
					; another source (a mirror) to trust.
					StrCpy $1 $LXZipURL 19
					${If} $1 != "https://github.com/"
					${AndIf} $R4 == ""
						StrCpy $LXZipURL ""
						StrCpy $LXSumsURL ""
						StrCpy $LXDigest ""
					${EndIf}
				${EndIf}
			${EndIf}
			StrCpy $2 $2 "" -350
		${Loop}
		FileClose $0
		${If} $LXTag == ""
			StrCpy $R2 "GitHub didn't name a LYNX SHARE release"
		${ElseIf} $LXZipURL == ""
			StrCpy $R2 "LYNX SHARE $LXVersion on GitHub has no Windows zip"
		${Else}
			StrCpy $R2 ok
		${EndIf}
	${Else}
		StrCpy $R2 "GitHub couldn't be reached ($R2)"
	${EndIf}
	Delete `${LX_STAGE}\releases.json`
	ClearErrors
	Pop $4
	Pop $3
	Pop $2
	Pop $1
	Pop $0
	Pop $R4
	Pop $R1
	Pop $R0
FunctionEnd

; $R3 = the SHA-256 SHA256SUMS.txt ($R0, downloaded) gives for the file
; name $R1, in lower case, or "".
Function LX_SumFor
	Push $0
	Push $1
	Push $2
	Push $3
	StrCpy $R3 ""
	StrLen $3 $R1
	ClearErrors
	FileOpen $0 $R0 r
	${IfNot} ${Errors}
		${Do}
			ClearErrors
			FileRead $0 $1
			${IfThen} ${Errors} ${|} ${ExitDo} ${|}
			${TrimNewLines} $1 $1
			; "<64 hex>  <name>", or "<64 hex> *<name>" (binary mode)
			StrCpy $2 $1 "" -$3
			${If} $2 == $R1
				IntOp $2 $3 + 1
				StrCpy $2 $1 1 -$2
				${If} $2 == " "
				${OrIf} $2 == "*"
					StrCpy $1 $1 64
					${StrFilter} $1 "1" "abcdefABCDEF" "" $2
					StrLen $3 $1
					${If} $2 S== $1
					${AndIf} $3 = 64
						${StrFilter} $1 "-" "" "" $R3
					${EndIf}
					${ExitDo}
				${EndIf}
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

; $R0 = 7z.exe of a 7-Zip on this computer or next to the package, or "".
Function LX_Find7z
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

; Unpacks the zip $R0 into the folder $R1, with tar.exe (Windows 10 1803 and
; later) or 7-Zip. $R2 = ok, or why not.
Function LX_Unzip
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
		Call LX_Find7z
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

; Downloads, checks and unpacks LYNX SHARE $LXVersion in the staging folder.
; $R2 = ok, or why not; $R3 = the new LYNX SHARE folder.
Function LX_Fetch
	Push $R0
	Push $R1
	Push $0
	Push $1
	Push $2
	StrCpy $2 `${LX_STAGE}\LYNX.zip`
	RMDir /r `${LX_STAGE}\files`
	; The checksums first: without one, nothing is downloaded.
	StrCpy $R0 $LXSumsURL
	StrCpy $R1 `${LX_STAGE}\SHA256SUMS.txt`
	Call BR_Download
	StrCpy $1 ""
	${If} $R2 == ok
		StrCpy $R0 `${LX_STAGE}\SHA256SUMS.txt`
		StrCpy $R1 `LYNX-`
		StrCpy $R1 `$R1$LXVersion`
		StrCpy $R1 `$R1-windows-x64.zip`
		Push $R3
		Call LX_SumFor
		StrCpy $1 $R3
		Pop $R3
	${EndIf}
	${If} $1 == ""
	${AndIf} $LXDigest == ""
		StrCpy $R2 "the release has no checksum for its Windows zip"
		Goto LX_Fetch_End
	${EndIf}
	${If} $1 != ""
	${AndIf} $LXDigest != ""
	${AndIf} $1 != $LXDigest
		StrCpy $R2 "SHA256SUMS.txt and GitHub give different checksums for the zip"
		Goto LX_Fetch_End
	${EndIf}
	${IfThen} $1 == "" ${|} StrCpy $1 $LXDigest ${|}
	Banner::show `Downloading LYNX SHARE $LXVersion from GitHub...`
	StrCpy $R0 $LXZipURL
	StrCpy $R1 $2
	Call BR_Download
	Banner::destroy
	${If} $R2 != ok
		StrCpy $R2 "LYNX SHARE couldn't be downloaded ($R2)"
		Goto LX_Fetch_End
	${EndIf}
	StrCpy $R0 $2
	StrCpy $R1 0x800C
	StrCpy $R2 32
	Push $R3
	Call BR_HashFile
	StrCpy $0 $R3
	Pop $R3
	${If} $0 != $1
		StrCpy $R2 "the download doesn't match its checksum"
		Goto LX_Fetch_End
	${EndIf}
	Banner::show `Unpacking LYNX SHARE $LXVersion...`
	StrCpy $R0 $2
	StrCpy $R1 `${LX_STAGE}\files`
	Call LX_Unzip
	Banner::destroy
	${If} $R2 != ok
		Goto LX_Fetch_End
	${EndIf}
	; LYNX.exe at the top of the zip, or in one folder (LYNX-<version>-windows-x64).
	StrCpy $R3 `${LX_STAGE}\files`
	${IfNot} ${FileExists} `$R3\LYNX.exe`
		FindFirst $0 $1 `${LX_STAGE}\files\*`
		${DoWhile} $1 != ""
			${If} ${FileExists} `${LX_STAGE}\files\$1\LYNX.exe`
				StrCpy $R3 `${LX_STAGE}\files\$1`
			${EndIf}
			FindNext $0 $1
		${Loop}
		FindClose $0
	${EndIf}
	; The version on offer: 0.1.21-alpha is LYNX.exe 0.1.21.0.
	StrCpy $R0 `$R3\LYNX.exe`
	Call LX_FileVersion
	StrCpy $0 $R1
	StrCpy $R0 $LXVersion
	Call LX_Numbers
	${IfNot} ${FileExists} `$R3\LYNX.exe`
		StrCpy $R2 "the download doesn't hold LYNX SHARE"
	${Else}
		${VersionCompare} $R1 $0 $1
		${If} $1 != 0
			StrCpy $R2 "the download holds LYNX SHARE $0, not $LXVersion"
		${Else}
			StrCpy $R2 ok
		${EndIf}
	${EndIf}
	LX_Fetch_End:
	Delete $2
	Delete `${LX_STAGE}\SHA256SUMS.txt`
	ClearErrors
	Pop $2
	Pop $1
	Pop $0
	Pop $R1
	Pop $R0
FunctionEnd

; Nothing in the program folder needs carrying over: everything LYNX SHARE
; writes is in Data\Profile.
Function BR_Preserve
FunctionEnd

; Shows why an install or update failed. $R2 is the reason; $R4 is
; downloaded or updated.
Function LX_Failed
	${If} $R4 == updated
		MessageBox MB_OK|MB_ICONEXCLAMATION `LYNX SHARE couldn't be updated: $R2.$\r$\n$\r$\nThe LYNX SHARE you have starts as it is. The update is offered again at the next check.`
	${Else}
		MessageBox MB_OK|MB_ICONEXCLAMATION `LYNX SHARE couldn't be $R4: $R2.`
	${EndIf}
FunctionEnd

; $R0 = true on 64-bit Windows, which LYNX SHARE needs.
Function LX_Is64
	Push $0
	ReadEnvStr $0 PROCESSOR_ARCHITEW6432
	${IfThen} $0 == "" ${|} ReadEnvStr $0 PROCESSOR_ARCHITECTURE ${|}
	${If} $0 == x86
		StrCpy $R0 false
	${Else}
		StrCpy $R0 true
	${EndIf}
	Pop $0
FunctionEnd

; Records the release now in the package, so appinfo.ini shows it with its
; suffix (0.1.21-alpha); LYNX.exe itself only carries 0.1.21.
Function LX_RecordVersion
	Push $R0
	Push $R1
	StrCpy $R0 `${LX_EXE}`
	Call LX_FileVersion
	${If} $R1 != ""
		WriteINIStr `$EXEDIR\App\AppInfo\appinfo.ini` Version PackageVersion $R1
		WriteINIStr `$EXEDIR\App\AppInfo\appinfo.ini` Version DisplayVersion $LXVersion
	${EndIf}
	ClearErrors
	Pop $R1
	Pop $R0
FunctionEnd

; A package without LYNX.exe: offers to download it.
Function LX_FirstInstall
	Push $R0
	Push $R2
	Push $R3
	Push $R4
	StrCpy $R4 downloaded
	MessageBox MB_YESNO|MB_ICONQUESTION `LYNX SHARE isn't in this package.$\r$\n$\r$\nDownload the newest release from GitHub now? It's about 17 MB, and it's checked against the release's checksums before it's used.` IDYES LX_FirstInstall_Go
	Call Unload
	Quit
	LX_FirstInstall_Go:
	Call LX_Is64
	${If} $R0 != true
		StrCpy $R2 "LYNX SHARE needs 64-bit Windows"
	${Else}
		Call LX_LatestRelease
		${If} $R2 == ok
			Call LX_Fetch
		${EndIf}
	${EndIf}
	${If} $R2 == ok
		CreateDirectory `${LX_APP}`
		CopyFiles /SILENT `$R3\*.*` `${LX_APP}`
		${IfNot} ${FileExists} `${LX_EXE}`
			StrCpy $R2 "the new LYNX SHARE couldn't be copied into place"
		${EndIf}
	${EndIf}
	RMDir /r `${LX_STAGE}`
	${If} $R2 == ok
		Call LX_RecordVersion
		Call BR_UpdateChecked
	${Else}
		Call LX_Failed
		Call Unload
		Quit
	${EndIf}
	Pop $R4
	Pop $R3
	Pop $R2
	Pop $R0
FunctionEnd

; Updates LYNX SHARE when there's a newer release on GitHub.
Function LX_UpdateCheck
	Push $R0
	Push $R1
	Push $R2
	Push $R3
	Push $R4
	Push $0
	StrCpy $R4 updated
	Call BR_UpdateDue
	Call LX_Is64
	${If} $R2 = 1
	${AndIf} $R0 == true
		Call LX_LatestRelease
		${If} $R2 == ok
			Call BR_UpdateChecked
			StrCpy $R0 `${LX_EXE}`
			Call LX_FileVersion
			StrCpy $0 $R1
			StrCpy $R0 $LXVersion
			Call LX_Numbers
			StrCpy $R0 $R1
			StrCpy $R1 $0
			Call BR_IsNewer
			${If} $R2 = 1
				${ReadUserConfig} $R2 UpdateCheck
				StrCpy $R1 yes
				${If} $R2 != auto
					MessageBox MB_YESNO|MB_ICONQUESTION `LYNX SHARE $LXVersion is available. This package has LYNX SHARE $0.$\r$\n$\r$\nUpdate now? It's downloaded from GitHub (about 17 MB) and checked before LYNX SHARE starts.$\r$\n$\r$\nNo starts LYNX SHARE $0 as it is.` IDYES +2
					StrCpy $R1 no
				${EndIf}
				${If} $R1 == yes
					; The staging folder goes if the launcher stops halfway.
					${Journal::Record} BrowserStage DIR `${LX_STAGE}` "" recursive ""
					Call LX_Fetch
					${If} $R2 == ok
						StrCpy $R0 LYNX
						StrCpy $R1 $R3
						Call BR_Swap
					${EndIf}
					${If} $R2 == ok
						Call LX_RecordVersion
					${Else}
						Call LX_Failed
					${EndIf}
					${Journal::Rollback} BrowserStage
				${EndIf}
			${EndIf}
		${EndIf}
	${EndIf}
	RMDir /r `${LX_STAGE}`
	ClearErrors
	Pop $0
	Pop $R4
	Pop $R3
	Pop $R2
	Pop $R1
	Pop $R0
FunctionEnd

; While the launcher updates LYNX SHARE (UpdateCheck isn't off), LYNX SHARE's
; own automatic check is turned off: its Update button would only save the
; zip, not install it. Its other settings in updates.txt are kept; Help >
; Check for updates still works. With UpdateCheck=off the file is left alone.
Function LX_NoSelfUpdate
	Push $0
	Push $1
	Push $2
	Push $3
	${ReadUserConfig} $0 UpdateCheck
	${If} $0 != off
		CreateDirectory `$DataDirectory\Profile\LYNX`
		StrCpy $3 "automatic=0$\n"
		ClearErrors
		FileOpen $0 `${LX_UPDATES}` r
		${IfNot} ${Errors}
			${Do}
				ClearErrors
				FileRead $0 $1
				${IfThen} ${Errors} ${|} ${ExitDo} ${|}
				${TrimNewLines} $1 $1
				StrCpy $2 $1 10
				${If} $2 != "automatic="
				${AndIf} $1 != ""
					StrCpy $3 `$3$1$\n`
				${EndIf}
			${Loop}
			FileClose $0
		${EndIf}
		FileOpen $0 `${LX_UPDATES}` w
		FileWrite $0 $3
		FileClose $0
	${EndIf}
	ClearErrors
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; After each session: when LYNX.exe's version isn't the one appinfo.ini
; shows (a build you copied in), appinfo.ini is brought up to date.
Function LX_WriteVersion
	Push $R0
	Push $R1
	Push $0
	StrCpy $R0 `${LX_EXE}`
	Call LX_FileVersion
	ReadINIStr $0 `$EXEDIR\App\AppInfo\appinfo.ini` Version PackageVersion
	${If} $R1 != ""
	${AndIf} $R1 != $0
	${AndIf} $R1 != "0.0.0.0"
		WriteINIStr `$EXEDIR\App\AppInfo\appinfo.ini` Version PackageVersion $R1
		StrCpy $R0 $R1
		; 0.1.22.0 shows as 0.1.22
		StrCpy $0 $R1 2 -2
		${IfThen} $0 == ".0" ${|} StrCpy $R0 $R1 -2 ${|}
		WriteINIStr `$EXEDIR\App\AppInfo\appinfo.ini` Version DisplayVersion $R0
	${EndIf}
	ClearErrors
	Pop $0
	Pop $R1
	Pop $R0
FunctionEnd

${SegmentFile}

; Init runs before the launcher looks for LYNX.exe, so a package without
; LYNX SHARE can get one first.
${SegmentInit}
	StrCpy $R0 LYNX
	StrCpy $R1 LYNX.exe
	Call BR_Repair
	RMDir /r `${LX_STAGE}`
	${IfNot} ${FileExists} `${LX_EXE}`
		Call LX_FirstInstall
	${EndIf}
!macroend

${SegmentPrePrimary}
	Call LX_UpdateCheck
	Call LX_NoSelfUpdate
	; LYNX SHARE creates an empty %APPDATA%\LYNX at start even when its
	; profile is elsewhere. It's removed again if it wasn't there before (and
	; only while it's empty).
	${IfNot} ${FileExists} `$APPDATA\LYNX\*.*`
		${Journal::Record} LYNX DIR `$APPDATA\LYNX` "" "" ""
	${EndIf}
!macroend

${SegmentPostPrimary}
	${Journal::Rollback} LYNX
	Call LX_WriteVersion
!macroend
