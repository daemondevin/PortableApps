; HeidiSQL Portable custom code for PortableApps Compiler.
; For support, visit the GitHub project:
; https://github.com/daemondevin/pac-man
;
; HeidiSQL runs in its own portable mode, with --psettings naming
; Data\settings\portable_settings.txt. The launcher INI moves its folders and
; tabs.ini in and out of App\HeidiSQL and updates paths when the package
; moves. What this file adds:
;
;   Updates    Before HeidiSQL starts, at most every UpdateInterval days, the
;              latest release on GitHub (HeidiSQL/HeidiSQL) is checked. A
;              newer one is downloaded as the 64-bit portable zip, checked
;              against the SHA-256 GitHub records for it (when GitHub gives
;              one) and heidisql.exe against its author's signature (Ansgar
;              Becker), unpacked with Windows' own tar.exe or 7-Zip, and
;              swapped in. The swap is journaled, so a crash halfway puts the
;              old HeidiSQL back. A package without HeidiSQL offers to
;              download it the same way.
;   Settings   HeidiSQL only takes --psettings when the file exists, so an
;              empty one is made the first time.
;   Adopting   Settings and folders from a plain portable HeidiSQL, copied
;              into App\HeidiSQL, are moved into Data the first time.
;   Leftovers  While it runs, portable HeidiSQL keeps its settings in a
;              registry key of its own, HKCU\Software\HeidiSQL Portable <PID>,
;              and deletes it when it closes. A key left by a HeidiSQL that
;              crashed is removed once no process with that PID is running.
;   Version    The version that ran is written to appinfo.ini.

; Defines
!define HS_APP       `$EXEDIR\App\HeidiSQL`
!define HS_EXE       `${HS_APP}\heidisql.exe`
!define HS_STAGE     `$EXEDIR\App\HeidiSQLUpdate`
!define HS_KEYPREFIX `HeidiSQL Portable `
!define HS_RELEASE   `https://api.github.com/repos/HeidiSQL/HeidiSQL/releases/latest`
!define HS_SIGNER    `Ansgar Becker`

; Variables
Var HSVersion       ; the release on offer (12.22)
Var HSZipURL        ; its 64-bit portable zip
Var HSDigest        ; the zip's SHA-256 as GitHub records it, or ""

; Moves $R0 (a file or folder name) from App\HeidiSQL to $R1 in Data, when
; it's in App\HeidiSQL and not in Data yet.
Function HS_AdoptOne
	${If} ${FileExists} `${HS_APP}\$R0`
	${AndIfNot} ${FileExists} `$R1`
		Rename `${HS_APP}\$R0` `$R1`
	${EndIf}
	ClearErrors
FunctionEnd

; Settings and folders a plain portable HeidiSQL keeps next to heidisql.exe
; are taken into Data, so they aren't lost or overwritten by the session's.
Function HS_Adopt
	CreateDirectory `$DataDirectory\settings`
	StrCpy $R0 portable_settings.txt
	StrCpy $R1 `$DataDirectory\settings\portable_settings.txt`
	Call HS_AdoptOne
	StrCpy $R0 tabs.ini
	StrCpy $R1 `$DataDirectory\settings\tabs.ini`
	Call HS_AdoptOne
	StrCpy $R0 Snippets
	StrCpy $R1 `$DataDirectory\Snippets`
	Call HS_AdoptOne
	StrCpy $R0 Backups
	StrCpy $R1 `$DataDirectory\Backups`
	Call HS_AdoptOne
	StrCpy $R0 Logs
	StrCpy $R1 `$DataDirectory\Logs`
	Call HS_AdoptOne
	StrCpy $R0 Sessionlogs
	StrCpy $R1 `$DataDirectory\Sessionlogs`
	Call HS_AdoptOne
	StrCpy $R0 Highlighters
	StrCpy $R1 `$DataDirectory\Highlighters`
	Call HS_AdoptOne
FunctionEnd

; HeidiSQL ignores --psettings when the file isn't there.
Function HS_SettingsFile
	${IfNot} ${FileExists} `$DataDirectory\settings\portable_settings.txt`
		CreateDirectory `$DataDirectory\settings`
		FileOpen $0 `$DataDirectory\settings\portable_settings.txt` w
		FileClose $0
	${EndIf}
	ClearErrors
FunctionEnd

; Deletes HKCU\Software\HeidiSQL Portable <PID> keys whose process is gone.
; A running HeidiSQL's key is left alone, and so is any key whose PID
; belongs to a running process, whatever it is.
Function HS_StaleKeys
	Push $0
	Push $1
	Push $2
	Push $3
	StrLen $3 `${HS_KEYPREFIX}`
	StrCpy $0 0
	${Do}
		ClearErrors
		EnumRegKey $1 HKCU Software $0
		${If} ${Errors}
		${OrIf} $1 == ""
			${ExitDo}
		${EndIf}
		StrCpy $2 $1 $3
		${If} $2 == `${HS_KEYPREFIX}`
			StrCpy $2 $1 "" $3
			IntOp $1 $2 + 0
			${If} $1 > 0
			${AndIf} `$1` == $2
				; PROCESS_QUERY_LIMITED_INFORMATION
				System::Call `kernel32::OpenProcess(i 0x1000, i 0, i r1)p.r1`
				${If} $1 = 0
					StrCpy $1 `${HS_KEYPREFIX}$2`
					DeleteRegKey HKCU `Software\$1`
					; The next key now has this index.
					${Continue}
				${EndIf}
				System::Call `kernel32::CloseHandle(p r1)`
			${EndIf}
		${EndIf}
		IntOp $0 $0 + 1
	${Loop}
	ClearErrors
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Writes the version of heidisql.exe to appinfo.ini: 12.22.0.7382 as
; PackageVersion, and 12.22 as DisplayVersion, the way HeidiSQL numbers its
; releases. A newer nightly build installed by HeidiSQL's own updater shows
; up here too.
Function HS_WriteVersion
	Push $0
	Push $1
	Push $2
	Push $3
	ClearErrors
	GetDllVersion `${HS_EXE}` $0 $1
	${IfNot} ${Errors}
		IntOp $2 $0 >> 16
		IntOp $2 $2 & 0xFFFF
		IntOp $3 $0 & 0xFFFF
		StrCpy $3 `$2.$3`
		IntOp $2 $1 >> 16
		IntOp $2 $2 & 0xFFFF
		StrCpy $0 `$3.$2`
		IntOp $2 $1 & 0xFFFF
		StrCpy $0 `$0.$2`
		ReadINIStr $1 `$EXEDIR\App\AppInfo\appinfo.ini` Version PackageVersion
		${If} $0 != $1
		${AndIf} $0 != "0.0.0.0"
			WriteINIStr `$EXEDIR\App\AppInfo\appinfo.ini` Version PackageVersion $0
			WriteINIStr `$EXEDIR\App\AppInfo\appinfo.ini` Version DisplayVersion $3
		${EndIf}
	${EndIf}
	ClearErrors
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

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

; Updates

; $R1 = the version of the program file $R0, as 12.22.0.7382, or "".
Function HS_FileVersion
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

; Asks GitHub for HeidiSQL's latest release. Sets $HSVersion (12.22, from the
; tag v12.22), $HSZipURL (the 64-bit portable zip) and, when GitHub records
; it, $HSDigest (the zip's SHA-256). $R2 = ok, or why not.
;
; GitHub's answer may come as one long line, so it's read in pieces, with
; the end of each piece kept for the next, and white space taken out. The
; zip is found by its download URL (/HeidiSQL_12.22_64_Portable.zip"), not
; its "name", which comes earlier in the same asset. Each asset gives its
; "digest" a little before its "browser_download_url"; a digest only counts
; when no other asset's download URL comes between them.
Function HS_LatestRelease
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
	${IfThen} $0 == "" ${|} StrCpy $0 `${HS_RELEASE}` ${|}
	CreateDirectory `${HS_STAGE}`
	StrCpy $R0 $0
	StrCpy $R1 `${HS_STAGE}\release.json`
	Call BR_Download
	StrCpy $HSVersion ""
	StrCpy $HSZipURL ""
	StrCpy $HSDigest ""
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
			${If} $HSVersion == ""
				ClearErrors
				${WordFind} `x$2` `"tag_name":"` "E+1}" $3
				${IfNot} ${Errors}
					${WordFind} `x$3` `"` "E+1{" $3
					${IfNot} ${Errors}
						StrCpy $HSVersion $3 "" 1
						StrCpy $3 $HSVersion 1
						${IfThen} $3 == v ${|} StrCpy $HSVersion $HSVersion "" 1 ${|}
						; The end of the zip's download URL.
						StrCpy $4 `/HeidiSQL_`
						StrCpy $4 `$4$HSVersion`
						StrCpy $4 `$4_64_Portable.zip"`
					${EndIf}
				${EndIf}
			${EndIf}
			${If} $4 != ""
			${AndIf} $HSZipURL == ""
				ClearErrors
				${WordFind} `x$2` $4 "E+1{" $3
				${IfNot} ${Errors}
					; The URL is what follows the last "browser_download_url"
					; before it.
					${WordFind} `x$3` `"browser_download_url":"` "E-1}" $1
					${IfNot} ${Errors}
						StrCpy $HSZipURL $4 -1
						StrCpy $HSZipURL `$1$HSZipURL`
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
									${StrFilter} $1 "-" "" "" $HSDigest
								${EndIf}
							${EndIf}
						${EndIf}
					${EndIf}
					; Only a GitHub download URL is taken, unless ReleaseURL names
					; another source (a mirror) to trust.
					StrCpy $1 $HSZipURL 19
					${If} $1 != "https://github.com/"
					${AndIf} $R4 == ""
						StrCpy $HSZipURL ""
						StrCpy $HSDigest ""
					${EndIf}
				${EndIf}
			${EndIf}
			StrCpy $2 $2 "" -350
		${Loop}
		FileClose $0
		${If} $HSVersion == ""
			StrCpy $R2 "GitHub didn't name a HeidiSQL release"
		${ElseIf} $HSZipURL == ""
			StrCpy $R2 "HeidiSQL $HSVersion on GitHub has no 64-bit portable zip"
		${Else}
			StrCpy $R2 ok
		${EndIf}
	${Else}
		StrCpy $R2 "GitHub couldn't be reached ($R2)"
	${EndIf}
	Delete `${HS_STAGE}\release.json`
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

; $R0 = 7z.exe of a 7-Zip on this computer or next to the package, or "".
Function HS_Find7z
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
Function HS_Unzip
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
		Call HS_Find7z
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

; Downloads, checks and unpacks HeidiSQL $HSVersion in the staging folder.
; $R2 = ok, or why not; $R3 = the new HeidiSQL folder.
Function HS_Fetch
	Push $R0
	Push $R1
	Push $0
	Push $1
	Push $2
	StrCpy $2 `${HS_STAGE}\HeidiSQL.zip`
	RMDir /r `${HS_STAGE}\files`
	Banner::show `Downloading HeidiSQL $HSVersion from GitHub...`
	StrCpy $R0 $HSZipURL
	StrCpy $R1 $2
	Call BR_Download
	Banner::destroy
	${If} $R2 != ok
		StrCpy $R2 "HeidiSQL couldn't be downloaded ($R2)"
		Goto HS_Fetch_End
	${EndIf}
	${If} $HSDigest != ""
		StrCpy $R0 $2
		StrCpy $R1 0x800C
		StrCpy $R2 32
		Push $R3
		Call BR_HashFile
		StrCpy $0 $R3
		Pop $R3
		${If} $0 != $HSDigest
			StrCpy $R2 "the download doesn't match the checksum GitHub records for it"
			Goto HS_Fetch_End
		${EndIf}
	${EndIf}
	Banner::show `Unpacking HeidiSQL $HSVersion...`
	StrCpy $R0 $2
	StrCpy $R1 `${HS_STAGE}\files`
	Call HS_Unzip
	Banner::destroy
	${If} $R2 != ok
		Goto HS_Fetch_End
	${EndIf}
	; heidisql.exe at the top of the zip, or in one folder.
	StrCpy $R3 `${HS_STAGE}\files`
	${IfNot} ${FileExists} `$R3\heidisql.exe`
		FindFirst $0 $1 `${HS_STAGE}\files\*`
		${DoWhile} $1 != ""
			${If} ${FileExists} `${HS_STAGE}\files\$1\heidisql.exe`
				StrCpy $R3 `${HS_STAGE}\files\$1`
			${EndIf}
			FindNext $0 $1
		${Loop}
		FindClose $0
	${EndIf}
	; Signed by HeidiSQL's author and trusted by Windows, and the version on
	; offer: 12.22 is 12.22.0.7382.
	StrCpy $R0 `$R3\heidisql.exe`
	Call BR_Signer
	StrCpy $1 $R1
	Call HS_FileVersion
	StrLen $0 $HSVersion
	StrCpy $0 $R1 $0
	StrLen $2 $HSVersion
	StrCpy $2 $R1 1 $2
	${IfNot} ${FileExists} `$R3\heidisql.exe`
		StrCpy $R2 "the download doesn't hold HeidiSQL"
	${ElseIf} $1 != `${HS_SIGNER}`
		StrCpy $R2 "heidisql.exe isn't signed by ${HS_SIGNER}"
	${ElseIf} $0 != $HSVersion
	${OrIf} $2 != "."
		StrCpy $R2 "the download holds HeidiSQL $R1, not $HSVersion"
	${Else}
		StrCpy $R2 ok
	${EndIf}
	HS_Fetch_End:
	Delete `${HS_STAGE}\HeidiSQL.zip`
	ClearErrors
	Pop $2
	Pop $1
	Pop $0
	Pop $R1
	Pop $R0
FunctionEnd

; Carries over what the user added to the program folder that a new HeidiSQL
; doesn't bring: translations (the locale folder), which the portable zip
; doesn't include. Nothing else is there at this point; settings and the
; other folders are in Data until the launcher moves them in.
; $R0 = the old folder, $R1 = the new one.
Function BR_Preserve
	${If} ${FileExists} `$R0\locale\*.*`
	${AndIfNot} ${FileExists} `$R1\locale\*.*`
		Rename `$R0\locale` `$R1\locale`
	${EndIf}
	ClearErrors
FunctionEnd

; Shows why an install or update failed. $R2 is the reason; $R4 is
; downloaded or updated.
Function HS_Failed
	${If} $R4 == updated
		MessageBox MB_OK|MB_ICONEXCLAMATION `HeidiSQL couldn't be updated: $R2.$\r$\n$\r$\nThe HeidiSQL you have starts as it is. The update is offered again at the next check.`
	${Else}
		MessageBox MB_OK|MB_ICONEXCLAMATION `HeidiSQL couldn't be $R4: $R2.`
	${EndIf}
FunctionEnd

; $R0 = true on 64-bit Windows, which HeidiSQL's portable build needs.
Function HS_Is64
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

; A package without heidisql.exe: offers to download it.
Function HS_FirstInstall
	Push $R0
	Push $R2
	Push $R3
	Push $R4
	StrCpy $R4 downloaded
	MessageBox MB_YESNO|MB_ICONQUESTION `HeidiSQL isn't in this package.$\r$\n$\r$\nDownload the latest release from GitHub now? It's about 30 MB, and it's checked (HeidiSQL's signature, and GitHub's checksum when there is one) before it's used.` IDYES HS_FirstInstall_Go
	Call Unload
	Quit
	HS_FirstInstall_Go:
	Call HS_Is64
	${If} $R0 != true
		StrCpy $R2 "HeidiSQL's portable build needs 64-bit Windows"
	${Else}
		Call HS_LatestRelease
		${If} $R2 == ok
			Call HS_Fetch
		${EndIf}
	${EndIf}
	${If} $R2 == ok
		; Settings or folders already in App\HeidiSQL are kept.
		CreateDirectory `${HS_APP}`
		CopyFiles /SILENT `$R3\*.*` `${HS_APP}`
		${IfNot} ${FileExists} `${HS_EXE}`
			StrCpy $R2 "the new HeidiSQL couldn't be copied into place"
		${EndIf}
	${EndIf}
	RMDir /r `${HS_STAGE}`
	${If} $R2 == ok
		Call BR_UpdateChecked
	${Else}
		Call HS_Failed
		Call Unload
		Quit
	${EndIf}
	Pop $R4
	Pop $R3
	Pop $R2
	Pop $R0
FunctionEnd

; Updates HeidiSQL when there's a newer release on GitHub. A nightly build
; HeidiSQL installed itself counts by its own version, so it's only replaced
; by a release that's newer still.
Function HS_UpdateCheck
	Push $R0
	Push $R1
	Push $R2
	Push $R3
	Push $R4
	Push $0
	StrCpy $R4 updated
	Call BR_UpdateDue
	Call HS_Is64
	${If} $R2 = 1
	${AndIf} $R0 == true
		Call HS_LatestRelease
		${If} $R2 == ok
			Call BR_UpdateChecked
			StrCpy $R0 `${HS_EXE}`
			Call HS_FileVersion
			StrCpy $0 $R1
			StrCpy $R0 $HSVersion
			Call BR_IsNewer
			${If} $R2 = 1
				${ReadUserConfig} $R2 UpdateCheck
				StrCpy $R1 yes
				${If} $R2 != auto
					MessageBox MB_YESNO|MB_ICONQUESTION `HeidiSQL $HSVersion is available. This package has HeidiSQL $0.$\r$\n$\r$\nUpdate now? It's downloaded from GitHub (about 30 MB) and checked before HeidiSQL starts.$\r$\n$\r$\nNo starts HeidiSQL $0 as it is.` IDYES +2
					StrCpy $R1 no
				${EndIf}
				${If} $R1 == yes
					; The staging folder goes if the launcher stops halfway.
					${Journal::Record} BrowserStage DIR `${HS_STAGE}` "" recursive ""
					Call HS_Fetch
					${If} $R2 == ok
						StrCpy $R0 HeidiSQL
						StrCpy $R1 $R3
						Call BR_Swap
					${EndIf}
					${IfThen} $R2 != ok ${|} Call HS_Failed ${|}
					${Journal::Rollback} BrowserStage
				${EndIf}
			${EndIf}
		${EndIf}
	${EndIf}
	RMDir /r `${HS_STAGE}`
	ClearErrors
	Pop $0
	Pop $R4
	Pop $R3
	Pop $R2
	Pop $R1
	Pop $R0
FunctionEnd

${SegmentFile}

; Init runs before the launcher looks for heidisql.exe, so a package without
; HeidiSQL can get one first.
${SegmentInit}
	StrCpy $R0 HeidiSQL
	StrCpy $R1 heidisql.exe
	Call BR_Repair
	RMDir /r `${HS_STAGE}`
	${IfNot} ${FileExists} `${HS_EXE}`
		Call HS_FirstInstall
	${EndIf}
!macroend

; Runs before FileWrite and DirectoriesMove, so what's adopted is moved and
; updated like the rest. Adopting comes before the update, so nothing of the
; user's is in App\HeidiSQL when it's swapped.
${SegmentPrePrimary}
	Call HS_Adopt
	Call HS_UpdateCheck
	Call HS_SettingsFile
!macroend

${SegmentPostPrimary}
	Call HS_StaleKeys
	Call HS_WriteVersion
!macroend
