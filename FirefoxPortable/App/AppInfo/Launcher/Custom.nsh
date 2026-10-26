; Firefox Portable custom code for PortableApps Compiler.
; For support, visit the GitHub project:
; https://github.com/daemondevin/pac-man
;
; Firefox runs from App\Firefox64 (or App\Firefox, the 32-bit edition) with
; the profile in Data\profile. What this file adds:
;
;   Install        The package doesn't ship Firefox. The first launch offers
;                  to download it from Mozilla, in the PortableApps.com
;                  Platform's language when there is one.
;   Updates        The launcher keeps Firefox up to date itself: it asks
;                  Mozilla for the latest version (release or ESR), downloads
;                  the full installer from archive.mozilla.org, checks it
;                  against Mozilla's published SHA-512 checksums, unpacks it
;                  with the installer's own /ExtractDir and swaps it in. The
;                  swap is journaled, so a crash halfway puts the old Firefox
;                  back. Firefox's own updater is turned off by policy: it
;                  would write to %ProgramData% and needs the maintenance
;                  service.
;   Moving         When the package moves (another folder or drive letter),
;                  the paths stored in the profile are updated, and the add-on
;                  and startup caches that hold old paths are cleared.
;   Leftovers      Firefox names some registry values and folders after a hash
;                  of its install folder (FoxHash computes the same one). Those,
;                  and the folders it creates in %APPDATA%, %LOCALAPPDATA% and
;                  %ProgramData%, are journaled and removed again; an installed
;                  Firefox's own entries are put back exactly as they were.
;   Version        The version of the Firefox that ran is written to
;                  appinfo.ini, so the PortableApps.com Platform shows it.

!addplugindir /x86-unicode `${PACKAGE}\App\AppInfo\Launcher\Plugins`

; Defines
!define FF_APP          `$EXEDIR\App`
!define FF_STAGE        `$EXEDIR\App\FirefoxUpdate`
!define FF_PROFILE      `${DATA}\profile`
!define FF_INFO         `$EXEDIR\App\AppInfo\appinfo.ini`
!define FF_VERSIONS     `https://product-details.mozilla.org/1.0/firefox_versions.json`
!define FF_ARCHIVE      `https://archive.mozilla.org/pub/firefox/releases`
; Firefox's folder in %ProgramData% (the update root since Firefox 92).
!define FF_UPDATEROOT   `Mozilla-1de4eec8-1241-4177-a864-e594e8d1fb38`
!define FF_POLICIES     `{"policies": {"DisableAppUpdate": true, "DontCheckDefaultBrowser": true, "DisableDefaultBrowserAgent": true}}`

; Variables
Var FFVersion       ; the version on offer, as Mozilla names it (157.0, 140.5.0esr)
Var FFLocale        ; the locale it's downloaded in (en-US, de, pt-BR)
Var FFSums          ; Mozilla's SHA512SUMS for $FFVersion, downloaded
Var FFHash          ; the install hash of the Firefox that runs
Var FFDir           ; the folder of the Firefox that runs

; Small helpers

; $R0 = days since 1601, from the system clock.
Function FF_Today
	Push $0
	System::Call `kernel32::GetSystemTimeAsFileTime(*l .r0)`
	System::Int64Op $0 / 864000000000
	Pop $R0
	Pop $0
FunctionEnd

; Downloads $R0 to the file $R1. $R2 = ok, or the error code.
Function FF_Download
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

; $R2 = the string value of the key $R1 in the JSON file $R0, or "".
Function FF_JsonString
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
			; key was cut in two.
			StrCpy $1 `$3$1`
			StrCpy $3 $1 "" -96
			${WordFind} $1 `"$R1"` "E+1}" $2
			${IfNot} ${Errors}
				${WordFind} $2 `"` "E+2" $R2
				${IfThen} ${Errors} ${|} StrCpy $R2 "" ${|}
				${Break}
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

; $R2 = the SHA-512 for $R1 (win64/de/Firefox Setup 157.0.exe) in the
; SHA512SUMS file $R0, or "".
Function FF_SumOf
	Push $0
	Push $1
	Push $2
	Push $3
	StrCpy $R2 ""
	StrCpy $3 `  $R1`
	StrLen $2 $3
	IntOp $2 0 - $2
	ClearErrors
	FileOpen $0 $R0 r
	${IfNot} ${Errors}
		${Do}
			ClearErrors
			FileRead $0 $1
			${IfThen} ${Errors} ${|} ${Break} ${|}
			${TrimNewLines} $1 $1
			StrCpy $3 $1 "" $2
			${If} $3 S== `  $R1`
				StrCpy $R2 $1 128
				${Break}
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

; $R1 = the SHA-512 of the file $R0 in lower case hexadecimal, or "".
Function FF_Sha512
	Push $0
	Push $1
	Push $2
	Push $3
	Push $4
	Push $5
	Push $6
	Push $8
	Push $9
	StrCpy $R1 ""
	; PROV_RSA_AES, CRYPT_VERIFYCONTEXT
	System::Call `advapi32::CryptAcquireContextW(*p .r0, p 0, p 0, i 24, i 0xF0000000) i .r9`
	${If} $9 <> 0
		; CALG_SHA_512
		System::Call `advapi32::CryptCreateHash(p r0, i 0x800E, p 0, i 0, *p .r1) i .r9`
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
					System::Call `advapi32::CryptGetHashParam(p r1, i 2, p r3, *i 64 r4, i 0) i .r9`
					${If} $9 <> 0
					${AndIf} $4 = 64
						StrCpy $5 0
						${Do}
							IntOp $6 $3 + $5
							System::Call `*$6(&i1 .r2)`
							IntOp $2 $2 & 0xFF
							IntFmt $2 "%02x" $2
							StrCpy $R1 `$R1$2`
							IntOp $5 $5 + 1
						${LoopUntil} $5 = 64
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

; $R1 = the Firefox version in the folder $R0 (from application.ini), or "".
Function FF_InstalledVersion
	StrCpy $R1 ""
	${If} ${FileExists} `$R0\firefox.exe`
		ReadINIStr $R1 `$R0\application.ini` App Version
	${EndIf}
	ClearErrors
FunctionEnd

; $R2 = 1 when version $R0 is newer than $R1, else 0. ESR versions carry an
; "esr" suffix that's ignored.
Function FF_IsNewer
	Push $0
	Push $1
	${WordReplace} $R0 "esr" "" "+" $0
	${WordReplace} $R1 "esr" "" "+" $1
	${If} $1 == ""
		StrCpy $R2 1
	${Else}
		${VersionCompare} $0 $1 $R2
		${IfThen} $R2 != 1 ${|} StrCpy $R2 0 ${|}
	${EndIf}
	Pop $1
	Pop $0
FunctionEnd

; $R0 = win64 or win32, the build to download on this computer.
Function FF_HostArch
	Push $0
	ReadEnvStr $0 PROCESSOR_ARCHITEW6432
	${If} $0 == ""
		ReadEnvStr $0 PROCESSOR_ARCHITECTURE
	${EndIf}
	${If} $0 == x86
		StrCpy $R0 win32
	${Else}
		StrCpy $R0 win64
	${EndIf}
	Pop $0
FunctionEnd

; Mozilla's side

; Sets $FFVersion to the latest version on the channel chosen in
; FirefoxPortable.ini. $R2 = ok, or why not.
Function FF_LatestVersion
	Push $R0
	Push $R1
	Push $0
	Push $1
	ClearErrors
	${ReadUserConfig} $0 UpdateChannel
	${ReadUserConfig} $1 VersionsURL
	${IfThen} $1 == "" ${|} StrCpy $1 `${FF_VERSIONS}` ${|}
	CreateDirectory `${FF_STAGE}`
	System::Call `kernel32::GetTickCount() i .r0`
	StrCpy $R0 `$1?t=$0`
	StrCpy $R1 `${FF_STAGE}\firefox_versions.json`
	Call FF_Download
	StrCpy $FFVersion ""
	${If} $R2 == ok
		${ReadUserConfig} $0 UpdateChannel
		StrCpy $R0 `${FF_STAGE}\firefox_versions.json`
		${If} $0 == esr
			StrCpy $R1 FIREFOX_ESR
		${Else}
			StrCpy $R1 LATEST_FIREFOX_VERSION
		${EndIf}
		Call FF_JsonString
		StrCpy $FFVersion $R2
		${If} $FFVersion == ""
			StrCpy $R2 "Mozilla's version list didn't name a version"
		${Else}
			StrCpy $R2 ok
		${EndIf}
	${Else}
		StrCpy $R2 "Mozilla's version list couldn't be downloaded ($R2)"
	${EndIf}
	Delete `${FF_STAGE}\firefox_versions.json`
	ClearErrors
	Pop $1
	Pop $0
	Pop $R1
	Pop $R0
FunctionEnd

; Downloads SHA512SUMS for $FFVersion to $FFSums. $R2 = ok, or why not.
Function FF_GetSums
	Push $R0
	Push $R1
	Push $0
	${ReadUserConfig} $0 ArchiveURL
	${IfThen} $0 == "" ${|} StrCpy $0 `${FF_ARCHIVE}` ${|}
	CreateDirectory `${FF_STAGE}`
	StrCpy $R0 `$0/$FFVersion/SHA512SUMS`
	StrCpy $R1 `${FF_STAGE}\SHA512SUMS`
	StrCpy $FFSums $R1
	Call FF_Download
	${If} $R2 != ok
		StrCpy $R2 "Mozilla's checksums couldn't be downloaded ($R2)"
	${EndIf}
	ClearErrors
	Pop $0
	Pop $R1
	Pop $R0
FunctionEnd

; $R2 = 1 when Firefox $FFVersion is offered in locale $R1 for build $R0.
Function FF_HasLocale
	Push $R0
	Push $R1
	StrCpy $R1 `$R0/$R1/Firefox Setup $FFVersion.exe`
	StrCpy $R0 $FFSums
	Call FF_SumOf
	${If} $R2 != ""
		StrCpy $R2 1
	${Else}
		StrCpy $R2 0
	${EndIf}
	Pop $R1
	Pop $R0
FunctionEnd

; Sets $FFLocale for build $R0: the Locale in FirefoxPortable.ini, else the
; locale the package already has, else the PortableApps.com Platform's
; language, else en-US. Each one is only taken when Mozilla offers it.
Function FF_PickLocale
	Push $R1
	Push $R2
	Push $0
	Push $1
	StrCpy $FFLocale ""
	ClearErrors
	${ReadUserConfig} $R1 Locale
	${If} $R1 != ""
		Call FF_HasLocale
		${IfThen} $R2 = 1 ${|} StrCpy $FFLocale $R1 ${|}
	${EndIf}
	${If} $FFLocale == ""
		${ReadSettings} $R1 FirefoxLocale
		${If} $R1 != ""
			Call FF_HasLocale
			${IfThen} $R2 = 1 ${|} StrCpy $FFLocale $R1 ${|}
		${EndIf}
	${EndIf}
	ReadEnvStr $0 PAL:_IgnoreLanguage
	${If} $FFLocale == ""
	${AndIf} $0 != true
		; pt_BR becomes pt-BR; then the bare language (de), then the
		; language with its main country (sv-SE, es-ES, nb-NO).
		ReadEnvStr $R1 PAL:LanguageGlibc
		${WordReplace} $R1 "_" "-" "+" $R1
		${If} $R1 != ""
			Call FF_HasLocale
			${IfThen} $R2 = 1 ${|} StrCpy $FFLocale $R1 ${|}
		${EndIf}
		ReadEnvStr $1 PAL:LanguageCode
		${If} $FFLocale == ""
		${AndIf} $1 != ""
			StrCpy $R1 $1
			Call FF_HasLocale
			${IfThen} $R2 = 1 ${|} StrCpy $FFLocale $R1 ${|}
		${EndIf}
		${If} $FFLocale == ""
		${AndIf} $1 != ""
			${NewStrCase} $0 $1 U
			StrCpy $R1 `$1-$0`
			Call FF_HasLocale
			${IfThen} $R2 = 1 ${|} StrCpy $FFLocale $R1 ${|}
		${EndIf}
	${EndIf}
	${IfThen} $FFLocale == "" ${|} StrCpy $FFLocale en-US ${|}
	ClearErrors
	Pop $1
	Pop $0
	Pop $R2
	Pop $R1
FunctionEnd

; Downloads and checks Firefox $FFVersion ($FFLocale) for build $R0, and
; unpacks it in the staging folder. $R2 = ok, or why not; $R3 = the folder
; holding the new firefox.exe.
Function FF_Fetch
	Push $R0
	Push $R1
	Push $0
	Push $1
	Push $2
	Push $3
	${ReadUserConfig} $0 ArchiveURL
	${IfThen} $0 == "" ${|} StrCpy $0 `${FF_ARCHIVE}` ${|}
	StrCpy $1 `${FF_STAGE}\$R0`
	RMDir /r $1
	CreateDirectory `$1`
	StrCpy $2 `$1\Firefox Setup $FFVersion.exe`
	StrCpy $3 $R0
	Banner::show `Downloading Firefox $FFVersion ($FFLocale) from Mozilla...`
	StrCpy $R0 `$0/$FFVersion/$3/$FFLocale/Firefox%20Setup%20$FFVersion.exe`
	StrCpy $R1 $2
	Call FF_Download
	Banner::destroy
	${If} $R2 == ok
		; The checksum Mozilla publishes for exactly this file.
		StrCpy $R0 $FFSums
		StrCpy $R1 `$3/$FFLocale/Firefox Setup $FFVersion.exe`
		Call FF_SumOf
		StrCpy $0 $R2
		StrCpy $R0 $2
		Call FF_Sha512
		${If} $0 == ""
			StrCpy $R2 "Mozilla's checksums don't list Firefox $FFVersion ($3, $FFLocale)"
		${ElseIf} $R1 != $0
			StrCpy $R2 "the download doesn't match Mozilla's checksum"
		${Else}
			; The full installer unpacks itself and stops.
			Banner::show `Unpacking Firefox $FFVersion...`
			ExecWait `"$2" /ExtractDir="$1\files"` $0
			Banner::destroy
			${If} ${FileExists} `$1\files\core\firefox.exe`
				StrCpy $R3 `$1\files\core`
			${Else}
				StrCpy $R3 `$1\files`
			${EndIf}
			StrCpy $R0 $R3
			Call FF_InstalledVersion
			${WordReplace} $FFVersion "esr" "" "+" $0
			${If} $R1 == ""
				StrCpy $R2 "the installer couldn't be unpacked"
			${ElseIf} $R1 != $0
				StrCpy $R2 "the installer holds Firefox $R1, not $FFVersion"
			${Else}
				StrCpy $R2 ok
			${EndIf}
		${EndIf}
		Delete $2
	${Else}
		StrCpy $R2 "Firefox couldn't be downloaded ($R2)"
	${EndIf}
	ClearErrors
	Pop $3
	Pop $2
	Pop $1
	Pop $0
	Pop $R1
	Pop $R0
FunctionEnd

; Copies what people add to a Firefox folder from $R0 (the old one) to $R1
; (the new one): the distribution folder (policies, bundled add-ons),
; preference files in defaults\pref other than Mozilla's own, and AutoConfig
; files (*.cfg).
Function FF_Preserve
	Push $0
	Push $1
	${If} ${FileExists} `$R0\distribution\*.*`
		CreateDirectory `$R1\distribution`
		CopyFiles /SILENT `$R0\distribution\*.*` `$R1\distribution`
		; PortableApps.com's package brands Firefox as its own distribution
		; (a bookmark, and "portableapps" in Firefox's distribution ID);
		; that isn't carried over.
		ReadINIStr $0 `$R1\distribution\distribution.ini` Global id
		${If} $0 == portableapps
			Delete `$R1\distribution\distribution.ini`
		${EndIf}
	${EndIf}
	FindFirst $0 $1 `$R0\defaults\pref\*.js`
	${DoWhile} $1 != ""
		${If} $1 != channel-prefs.js
			CopyFiles /SILENT `$R0\defaults\pref\$1` `$R1\defaults\pref`
		${EndIf}
		FindNext $0 $1
	${Loop}
	FindClose $0
	FindFirst $0 $1 `$R0\*.cfg`
	${DoWhile} $1 != ""
		CopyFiles /SILENT `$R0\$1` `$R1`
		FindNext $0 $1
	${Loop}
	FindClose $0
	ClearErrors
	Pop $1
	Pop $0
FunctionEnd

; Swaps the Firefox in App\$R0 for the one in $R1. The old folder is kept as
; $R0.previous until the new one is in place; the journal puts it back if
; the launcher stops halfway. $R2 = ok, or why not.
Function FF_Swap
	Push $0
	Push $1
	Push $R1
	StrCpy $0 `${FF_APP}\$R0`
	StrCpy $1 `${FF_APP}\$R0.previous`
	RMDir /r $1
	${Journal::Record} FirefoxSwap CMD `"$SYSDIR\cmd.exe" /c if exist "$1\firefox.exe" (rd /s /q "$0" 2>nul & move /y "$1" "$0")` "0" "" ""
	ClearErrors
	Rename $0 $1
	${If} ${Errors}
		${Journal::Discard} FirefoxSwap
		StrCpy $R2 "Firefox's folder is in use"
	${Else}
		Rename $R1 $0
		${If} ${Errors}
			${Journal::Rollback} FirefoxSwap
			StrCpy $R2 "the new Firefox couldn't be moved into place"
		${Else}
			Push $R0
			StrCpy $R0 $1
			StrCpy $R1 $0
			Call FF_Preserve
			Pop $R0
			${Journal::Discard} FirefoxSwap
			RMDir /r $1
			StrCpy $R2 ok
		${EndIf}
	${EndIf}
	ClearErrors
	Pop $R1
	Pop $1
	Pop $0
FunctionEnd

; Install and update

; A launch that stopped between the two renames of a swap leaves no
; firefox.exe and a .previous folder; that's put back before the launcher
; looks for Firefox. Leftovers of a download are removed.
Function FF_Repair
	${If} ${FileExists} `${FF_APP}\Firefox64.previous\firefox.exe`
	${AndIfNot} ${FileExists} `${FF_APP}\Firefox64\firefox.exe`
		RMDir /r `${FF_APP}\Firefox64`
		Rename `${FF_APP}\Firefox64.previous` `${FF_APP}\Firefox64`
	${EndIf}
	${If} ${FileExists} `${FF_APP}\Firefox.previous\firefox.exe`
	${AndIfNot} ${FileExists} `${FF_APP}\Firefox\firefox.exe`
		RMDir /r `${FF_APP}\Firefox`
		Rename `${FF_APP}\Firefox.previous` `${FF_APP}\Firefox`
	${EndIf}
	ClearErrors
FunctionEnd

; Shows why an install or update failed. $R2 is the reason.
Function FF_Failed
	${If} $R4 == updated
		MessageBox MB_OK|MB_ICONEXCLAMATION `Firefox couldn't be updated: $R2.$\r$\n$\r$\nThe Firefox you have starts as it is. The update is offered again next time.`
	${Else}
		MessageBox MB_OK|MB_ICONEXCLAMATION `Firefox couldn't be $R4: $R2.$\r$\n$\r$\nCheck the internet connection and try again later.`
	${EndIf}
FunctionEnd

; The first launch: the package has no Firefox yet.
Function FF_FirstInstall
	Push $R0
	Push $R2
	Push $R3
	Push $R4
	StrCpy $R4 downloaded
	MessageBox MB_YESNO|MB_ICONQUESTION `Firefox isn't in this package yet.$\r$\n$\r$\nDownload it from Mozilla now? It's about 80 MB, and it's checked against Mozilla's published checksums before it's used.` IDYES FF_FirstInstall_Go
	Call Unload
	Quit
	FF_FirstInstall_Go:
	Call FF_LatestVersion
	${If} $R2 == ok
		Call FF_GetSums
	${EndIf}
	${If} $R2 == ok
		Call FF_HostArch
		Call FF_PickLocale
		Call FF_Fetch
	${EndIf}
	${If} $R2 == ok
		${If} $R0 == win64
			StrCpy $R0 `${FF_APP}\Firefox64`
		${Else}
			StrCpy $R0 `${FF_APP}\Firefox`
		${EndIf}
		RMDir /r $R0
		ClearErrors
		Rename $R3 $R0
		${If} ${Errors}
			StrCpy $R2 "the new Firefox couldn't be moved into place"
		${EndIf}
	${EndIf}
	RMDir /r `${FF_STAGE}`
	${If} $R2 == ok
		; The settings folder doesn't exist yet on a first launch.
		CreateDirectory `${DATA}\settings`
		${WriteSettings} $FFLocale FirefoxLocale
		Call FF_Today
		${WriteSettings} $R0 LastUpdateCheck
	${Else}
		Call FF_Failed
		Call Unload
		Quit
	${EndIf}
	Pop $R4
	Pop $R3
	Pop $R2
	Pop $R0
FunctionEnd

; Updates the Firefox in the package when Mozilla has a newer one, or when
; FirefoxPortable.ini asks for another locale. Asks first with
; UpdateCheck=ask, doesn't with auto, never checks with off; checks at most
; once every UpdateInterval days.
Function FF_UpdateCheck
	Push $R0
	Push $R1
	Push $R2
	Push $R3
	Push $R4
	Push $0
	Push $1
	Push $2
	Push $3
	StrCpy $R4 updated
	ClearErrors
	${ReadUserConfig} $0 UpdateCheck
	${IfThen} $0 == "" ${|} StrCpy $0 ask ${|}
	${ReadUserConfig} $1 Locale
	${ReadSettings} $2 FirefoxLocale
	StrCpy $3 0
	${If} $1 != ""
	${AndIf} $1 != $2
		StrCpy $3 1
	${EndIf}
	${If} $0 == off
		Goto FF_UpdateCheck_End
	${EndIf}
	; Not more often than every UpdateInterval days, unless the locale is
	; to change.
	${If} $3 = 0
		${ReadUserConfig} $1 UpdateInterval
		${IfThen} $1 == "" ${|} StrCpy $1 1 ${|}
		${ReadSettings} $2 LastUpdateCheck
		Call FF_Today
		${If} $2 != ""
			IntOp $2 $R0 - $2
			${If} $2 < $1
			${AndIf} $2 >= 0
				Goto FF_UpdateCheck_End
			${EndIf}
		${EndIf}
	${EndIf}
	Call FF_LatestVersion
	${If} $R2 != ok
		; Offline, or Mozilla didn't answer: try again next launch.
		Goto FF_UpdateCheck_End
	${EndIf}
	Call FF_Today
	${WriteSettings} $R0 LastUpdateCheck
	StrCpy $R0 $FFDir
	Call FF_InstalledVersion
	StrCpy $R0 $FFVersion
	Call FF_IsNewer
	${If} $R2 = 0
	${AndIf} $3 = 0
		Goto FF_UpdateCheck_End
	${EndIf}
	${If} $0 == ask
		${If} $R2 = 1
			MessageBox MB_YESNO|MB_ICONQUESTION `Firefox $FFVersion is available. This package has Firefox $R1.$\r$\n$\r$\nUpdate now? It's downloaded from Mozilla (about 80 MB) and checked against Mozilla's published checksums before Firefox starts.$\r$\n$\r$\nNo starts Firefox $R1 as it is.` IDYES FF_UpdateCheck_Go
		${Else}
			MessageBox MB_YESNO|MB_ICONQUESTION `FirefoxPortable.ini asks for Firefox in another language.$\r$\n$\r$\nDownload Firefox $FFVersion in that language from Mozilla now (about 80 MB)?` IDYES FF_UpdateCheck_Go
		${EndIf}
		Goto FF_UpdateCheck_End
	${EndIf}
	FF_UpdateCheck_Go:
	; The staging folder goes if the launcher stops halfway.
	${Journal::Record} FirefoxStage DIR `${FF_STAGE}` "" recursive ""
	Call FF_GetSums
	${If} $R2 == ok
		Call FF_HostArch
		${If} ${FileExists} `${FF_APP}\Firefox64\firefox.exe`
			StrCpy $R0 win64
		${Else}
			StrCpy $R0 win32
		${EndIf}
		Call FF_PickLocale
		; Every edition in the package is updated.
		${If} ${FileExists} `${FF_APP}\Firefox64\firefox.exe`
			StrCpy $R0 win64
			Call FF_Fetch
			${If} $R2 == ok
				StrCpy $R0 Firefox64
				StrCpy $R1 $R3
				Call FF_Swap
			${EndIf}
		${EndIf}
		${If} $R2 == ok
		${AndIf} ${FileExists} `${FF_APP}\Firefox\firefox.exe`
			StrCpy $R0 win32
			Call FF_Fetch
			${If} $R2 == ok
				StrCpy $R0 Firefox
				StrCpy $R1 $R3
				Call FF_Swap
			${EndIf}
		${EndIf}
	${EndIf}
	${If} $R2 == ok
		${WriteSettings} $FFLocale FirefoxLocale
	${Else}
		Call FF_Failed
	${EndIf}
	${Journal::Rollback} FirefoxStage
	FF_UpdateCheck_End:
	RMDir /r `${FF_STAGE}`
	ClearErrors
	Pop $3
	Pop $2
	Pop $1
	Pop $0
	Pop $R4
	Pop $R3
	Pop $R2
	Pop $R1
	Pop $R0
FunctionEnd

; Turns Firefox's own updater off with an enterprise policy in each edition,
; unless a policies.json of your own is there already.
Function FF_Policies
	Push $0
	Push $1
	Push $2
	Push $3
	StrCpy $2 Firefox64
	${Do}
		StrCpy $0 `${FF_APP}\$2\distribution\policies.json`
		${If} ${FileExists} `${FF_APP}\$2\firefox.exe`
			StrCpy $1 ""
			${If} ${FileExists} $0
				ClearErrors
				FileOpen $3 $0 r
				FileRead $3 $1
				FileClose $3
				${TrimNewLines} $1 $1
				${IfThen} $1 S== `${FF_POLICIES}` ${|} StrCpy $1 "" ${|}
			${EndIf}
			${If} $1 == ""
				CreateDirectory `${FF_APP}\$2\distribution`
				FileOpen $1 $0 w
				FileWrite $1 `${FF_POLICIES}$\r$\n`
				FileClose $1
			${EndIf}
		${EndIf}
		${IfThen} $2 == Firefox ${|} ${Break} ${|}
		StrCpy $2 Firefox
	${Loop}
	ClearErrors
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Moving the package

!macro FF_ReplaceIn _FILE
	${If} ${FileExists} `${FF_PROFILE}\${_FILE}`
		${ReplaceInFile} `${FF_PROFILE}\${_FILE}` $0 $1
		${ReplaceInFile} `${FF_PROFILE}\${_FILE}` `file:///$2` `file:///$3`
	${EndIf}
!macroend

; Replaces the path $R8 with $R9 (both ending in a backslash) in the profile,
; in the forms Firefox stores paths in: JSON-escaped (D:\\Apps\\) and as file
; URLs (file:///D:/Apps/).
Function FF_ReplacePath
	Push $0
	Push $1
	Push $2
	Push $3
	${WordReplace} $R8 "\" "\\" "+" $0
	${WordReplace} $R9 "\" "\\" "+" $1
	${WordReplace} $R8 "\" "/" "+" $2
	${WordReplace} $2 " " "%20" "+" $2
	${WordReplace} $R9 "\" "/" "+" $3
	${WordReplace} $3 " " "%20" "+" $3
	!insertmacro FF_ReplaceIn prefs.js
	!insertmacro FF_ReplaceIn extensions.json
	!insertmacro FF_ReplaceIn handlers.json
	${If} ${FileExists} `${FF_PROFILE}\pkcs11.txt`
		${ReplaceInFile} `${FF_PROFILE}\pkcs11.txt` $R8 $R9
	${EndIf}
	ClearErrors
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; When the package has moved, updates the profile's stored paths: those into
; the package first, then, if the drive letter changed, the others on that
; drive. The caches that hold paths are cleared; Firefox rebuilds them.
Function FF_UpdatePaths
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
	StrCpy $1 0
	${If} $R8 != $R9
	${AndIf} $R8 != ""
		StrCpy $R8 `$R8\`
		StrCpy $R9 `$R9\`
		Call FF_ReplacePath
		StrCpy $1 1
	${EndIf}
	StrCpy $3 $0 1 1
	StrCpy $R7 $2 1 1
	${If} $0 != $2
	${AndIf} $3 == ":"
	${AndIf} $R7 == ":"
		StrCpy $R8 `$0\`
		StrCpy $R9 `$2\`
		Call FF_ReplacePath
		StrCpy $1 1
	${EndIf}
	${If} $1 = 1
		Delete `${FF_PROFILE}\addonStartup.json.lz4`
		Delete `${FF_PROFILE}\compatibility.ini`
		RMDir /r `${FF_PROFILE}\startupCache`
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

; What Firefox leaves in Windows

; Journals a folder Firefox may create: removed again if it isn't there yet.
; $R0 = the folder, $R1 = recursive to remove it with its contents.
Function FF_JournalDir
	${IfNot} ${FileExists} `$R0\*.*`
		${Journal::Record} FirefoxPortable DIR $R0 "" $R1 ""
	${EndIf}
FunctionEnd

; Journals a file Firefox may create: removed again if it isn't there yet.
Function FF_JournalFile
	${IfNot} ${FileExists} $R0
		${Journal::Record} FirefoxPortable FILE $R0 "" "" ""
	${EndIf}
FunctionEnd

; Journals a registry value in HKCU: put back as it was afterward.
; $R0 = key, $R1 = value name.
Function FF_JournalValue
	Push $0
	Push $1
	Push $2
	; RRF_RT_ANY | RRF_NOEXPAND: only ask for the type.
	System::Call `advapi32::RegGetValueW(p 0x80000001, w R0, w R1, i 0x1000FFFF, *i .r1, p 0, p 0) i .r0`
	${If} $0 <> 0
		StrCpy $2 ""
	${Else}
		ReadRegStr $2 HKCU $R0 $R1
		${If} $1 = 1
			StrCpy $2 `STR:$2`
		${ElseIf} $1 = 2
			StrCpy $2 `EXP:$2`
		${Else}
			Goto FF_JournalValue_End
		${EndIf}
	${EndIf}
	${Journal::Record} FirefoxPortable REGVALUE HKCU $R0 $R1 $2
	FF_JournalValue_End:
	ClearErrors
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

; Journals the "Open with" entry Firefox adds for a file type when it's made
; the default browser.
!macro FF_JournalOpenWith _EXT _PROGID
	StrCpy $R0 `Software\Classes\.${_EXT}\OpenWithProgids`
	StrCpy $R1 `${_PROGID}-$FFHash`
	Call FF_JournalValue
!macroend

; Journals everything Firefox can leave behind for the Firefox in $FFDir.
Function FF_JournalWindows
	Push $R0
	Push $R1
	Push $0
	Push $1
	; HKCU\Software\Mozilla\Firefox holds the per-install values (TaskBarIDs,
	; Launcher, PreXULSkeletonUISettings, Installer); it's exported and put
	; back as a whole, so an installed Firefox's values come back unchanged.
	${Journal::RegKey} FirefoxPortable HKCU `Software\Mozilla\Firefox` $0
	${Journal::RegKey} FirefoxPortable HKCU `Software\mozilla.org` $0
	; Made the default browser: its file types and browser registration.
	${Journal::RegKey} FirefoxPortable HKCU `Software\Classes\FirefoxHTML-$FFHash` $0
	${Journal::RegKey} FirefoxPortable HKCU `Software\Classes\FirefoxURL-$FFHash` $0
	${Journal::RegKey} FirefoxPortable HKCU `Software\Classes\FirefoxPDF-$FFHash` $0
	${Journal::RegKey} FirefoxPortable HKCU `Software\Clients\StartMenuInternet\Firefox-$FFHash` $0
	StrCpy $R0 `Software\RegisteredApplications`
	StrCpy $R1 `Firefox-$FFHash`
	Call FF_JournalValue
	!insertmacro FF_JournalOpenWith htm FirefoxHTML
	!insertmacro FF_JournalOpenWith html FirefoxHTML
	!insertmacro FF_JournalOpenWith shtml FirefoxHTML
	!insertmacro FF_JournalOpenWith xht FirefoxHTML
	!insertmacro FF_JournalOpenWith xhtml FirefoxHTML
	!insertmacro FF_JournalOpenWith svg FirefoxHTML
	!insertmacro FF_JournalOpenWith webp FirefoxHTML
	!insertmacro FF_JournalOpenWith avif FirefoxHTML
	!insertmacro FF_JournalOpenWith pdf FirefoxPDF
	; Update root, profile counts and locks in %ProgramData%.
	ReadEnvStr $0 ProgramData
	${If} $0 != ""
		StrCpy $R1 ""
		StrCpy $R0 `$0\${FF_UPDATEROOT}`
		Call FF_JournalDir
		StrCpy $R0 `$0\${FF_UPDATEROOT}\updates`
		Call FF_JournalDir
		StrCpy $R1 recursive
		StrCpy $R0 `$0\${FF_UPDATEROOT}\updates\$FFHash`
		Call FF_JournalDir
		StrCpy $R0 `$0\${FF_UPDATEROOT}\profile_count_$FFHash.json`
		Call FF_JournalFile
		StrCpy $R0 `$0\${FF_UPDATEROOT}\UpdateLock-$FFHash`
		Call FF_JournalFile
	${EndIf}
	; %APPDATA%: pending telemetry pings, and the folders around them.
	StrCpy $R1 ""
	StrCpy $R0 `$APPDATA\Mozilla`
	Call FF_JournalDir
	StrCpy $R0 `$APPDATA\Mozilla\Extensions`
	Call FF_JournalDir
	StrCpy $R0 `$APPDATA\Mozilla\Firefox`
	Call FF_JournalDir
	StrCpy $R0 `$APPDATA\Mozilla\Firefox\Profiles`
	Call FF_JournalDir
	StrCpy $R0 `$APPDATA\Mozilla\Firefox\profiles.ini`
	Call FF_JournalFile
	StrCpy $R0 `$APPDATA\Mozilla\Firefox\installs.ini`
	Call FF_JournalFile
	StrCpy $R1 recursive
	StrCpy $R0 `$APPDATA\Mozilla\Firefox\Pending Pings`
	Call FF_JournalDir
	StrCpy $R0 `$APPDATA\Mozilla\Firefox\Crash Reports`
	Call FF_JournalDir
	; %LOCALAPPDATA% and LocalLow: caches and the sandbox's temporary folder.
	StrCpy $R1 ""
	StrCpy $R0 `$LOCALAPPDATA\Mozilla`
	Call FF_JournalDir
	StrCpy $R0 `$LOCALAPPDATA\Mozilla\Firefox`
	Call FF_JournalDir
	StrCpy $R1 recursive
	StrCpy $R0 `$LOCALAPPDATA\Mozilla\Firefox\Profiles`
	Call FF_JournalDir
	StrCpy $R0 `$LOCALAPPDATA\Mozilla\updates`
	Call FF_JournalDir
	StrCpy $R0 `$PROFILE\AppData\LocalLow\Mozilla`
	Call FF_JournalDir
	Pop $1
	Pop $0
	Pop $R1
	Pop $R0
FunctionEnd

; Writes the version of the Firefox that ran to appinfo.ini.
Function FF_WriteVersion
	Push $R0
	Push $R1
	Push $0
	Push $1
	Push $2
	StrCpy $R0 $FFDir
	Call FF_InstalledVersion
	${If} $R1 != ""
		; Four numbers for PackageVersion: 157.0 becomes 157.0.0.0.
		StrCpy $0 0
		StrCpy $1 0
		${Do}
			StrCpy $2 $R1 1 $1
			${IfThen} $2 == "." ${|} IntOp $0 $0 + 1 ${|}
			IntOp $1 $1 + 1
		${LoopUntil} $2 == ""
		StrCpy $1 $R1
		${DoWhile} $0 < 3
			StrCpy $1 `$1.0`
			IntOp $0 $0 + 1
		${Loop}
		ReadINIStr $2 `${FF_INFO}` Version DisplayVersion
		${If} $2 != $R1
			WriteINIStr `${FF_INFO}` Version PackageVersion $1
			WriteINIStr `${FF_INFO}` Version DisplayVersion $R1
		${EndIf}
	${EndIf}
	ClearErrors
	Pop $2
	Pop $1
	Pop $0
	Pop $R1
	Pop $R0
FunctionEnd

; Hooks

${SegmentFile}

; Init runs before the launcher looks for firefox.exe, so a package without
; Firefox can get one first.
${SegmentInit}
	Call FF_Repair
	RMDir /r `${FF_STAGE}`
	${IfNot} ${FileExists} `${FF_APP}\Firefox64\firefox.exe`
	${AndIfNot} ${FileExists} `${FF_APP}\Firefox\firefox.exe`
		Call FF_FirstInstall
	${EndIf}
!macroend

; Custom runs first in PrePrimary, after crash recovery and before anything
; else changes.
${SegmentPrePrimary}
	; The folder of the Firefox that's about to run.
	StrCpy $FFDir `${FF_APP}\$ProgramExecutable`
	${GetParent} $FFDir $FFDir
	Call FF_UpdateCheck
	Call FF_Policies
	CreateDirectory `${FF_PROFILE}`
	Call FF_UpdatePaths
	FoxHash::InstallHash $FFDir
	Pop $FFHash
	Call FF_JournalWindows
!macroend

${SegmentPostPrimary}
	; Firefox records its install hash in TaskBarIDs. If it differs from the
	; one computed (a path spelled differently), that one's folders go too.
	ReadRegStr $0 HKCU `Software\Mozilla\Firefox\TaskBarIDs` $FFDir
	${Journal::HasEntries} FirefoxPortable $R0
	${If} $R0 > 0
		${Journal::Rollback} FirefoxPortable
	${EndIf}
	${If} $0 != ""
	${AndIf} $0 != $FFHash
		ReadEnvStr $1 ProgramData
		RMDir /r `$1\${FF_UPDATEROOT}\updates\$0`
		Delete `$1\${FF_UPDATEROOT}\profile_count_$0.json`
		Delete `$1\${FF_UPDATEROOT}\UpdateLock-$0`
		RMDir `$1\${FF_UPDATEROOT}\updates`
		RMDir `$1\${FF_UPDATEROOT}`
		DeleteRegKey HKCU `Software\Classes\FirefoxHTML-$0`
		DeleteRegKey HKCU `Software\Classes\FirefoxURL-$0`
		DeleteRegKey HKCU `Software\Classes\FirefoxPDF-$0`
		DeleteRegKey HKCU `Software\Clients\StartMenuInternet\Firefox-$0`
		DeleteRegValue HKCU `Software\RegisteredApplications` `Firefox-$0`
	${EndIf}
	Call FF_WriteVersion
!macroend
