# Firefox Portable

A portable launcher for [Firefox](https://www.mozilla.org/firefox/), built with the [PortableApps Compiler][PACMAN] (pac-man). It keeps your profile in the package, installs Firefox from Mozilla on the first launch and keeps it up to date itself. Every change it makes to Windows is recorded first and undone when Firefox closes, or on the next launch if something went wrong.

Firefox and the Firefox logos are trademarks of the Mozilla Foundation. This package isn't made or endorsed by Mozilla; it runs Mozilla's own, unmodified Firefox builds.

 [PACMAN]: https://github.com/daemondevin/pac-man

## System Requirements

* Windows 10 or later (what current Firefox needs).
* An internet connection for the first launch and for updates.
* [PortableApps.com Platform](https://portableapps.com/download) (optional).

## First launch

The package doesn't include Firefox. The first launch offers to download it:

1. It asks Mozilla which version is current (`product-details.mozilla.org`).
2. It downloads the full Windows installer from `archive.mozilla.org`: the 64-bit edition on 64-bit Windows, the 32-bit one otherwise.
3. It checks the download against the SHA-512 checksum Mozilla publishes for that exact file. A download that doesn't match is never used.
4. It unpacks the installer with its own `/ExtractDir` option, which writes the program files to a folder and stops, without installing anything, and puts them in `App\Firefox64` (or `App\Firefox`).

Then Firefox starts. If you say no, or the download fails, nothing is left behind and the launcher stops.

## Updates

Firefox's built-in updater is turned off: it needs the Mozilla Maintenance Service or administrator rights for some updates, and writes its state to `%ProgramData%`. The launcher does the updating instead, the same way as the first install:

* Before Firefox starts, at most once every `UpdateInterval` days, it asks Mozilla for the latest version on your channel.
* If there's a newer one, it asks whether to update now (`UpdateCheck=ask`), or just does it (`UpdateCheck=auto`). Say no and Firefox starts as it is; you're asked again after the interval.
* The new Firefox is downloaded and checked as above, then swapped in. The old folder is kept until the new one is in place, and the swap is journaled: if the launcher is stopped halfway, the next launch puts the old Firefox back.
* Your additions to the Firefox folder are carried over: the `distribution` folder (your own policies, bundled add-ons), preference files in `defaults\pref` and AutoConfig files (`*.cfg`).
* If anything fails (no connection, a checksum that doesn't match), it says why and starts the Firefox you have.

Both editions are updated when the package has both. If you only use one, delete the other folder to halve the download.

To stop Firefox's own updater, the launcher puts a `policies.json` in each Firefox folder's `distribution` folder (it also turns off the default browser check and the default browser agent). Because of that policy, Firefox's settings page says **Your browser is being managed by your organization**. If you put your own `policies.json` there, the launcher leaves it alone; include `"DisableAppUpdate": true` in it.

## Configuration

`FirefoxPortable.ini`, next to the launcher, holds the user settings. If it gets damaged, or you want to go back to the defaults, copy `Other\Source\FirefoxPortable.ini` over it.

```INI
[FirefoxPortable]
AdditionalParameters=
UpdateCheck=ask
UpdateChannel=release
UpdateInterval=1
Locale=
```

| Key | Default | What it does |
| --- | --- | --- |
| `UpdateCheck` | `ask` | `ask` asks before updating, `auto` updates without asking, `off` never checks. |
| `UpdateChannel` | `release` | `release` or `esr` ([Extended Support Release](https://www.mozilla.org/firefox/enterprise/)). |
| `UpdateInterval` | `1` | Days between update checks. `0` checks on every launch. |
| `Locale` | empty | Firefox's language as Mozilla names it: `en-US`, `de`, `fr`, `pt-BR`, `es-ES`, `zh-CN`... Empty keeps the language you have. Setting another one downloads Firefox in that language on the next launch, without waiting for the interval. |
| `AdditionalParameters` | empty | Extra command line switches passed to Firefox. |
| `ArchiveURL`, `VersionsURL` | Mozilla's | Not in the file by default. Where releases and the version list are downloaded from, for a mirror of `archive.mozilla.org`. |

### Language

With `Locale` empty, the first download is in the PortableApps.com Platform's language when started from the Platform (`pt_BR` becomes `pt-BR`, German becomes `de`, Spanish becomes `es-ES`), and in `en-US` otherwise. Every choice is checked against the languages Mozilla offers for that version; one it doesn't offer falls back to the next. Updates keep the language the package has.

### ESR

Switching `UpdateChannel` to `esr` takes effect when the ESR version is newer than the Firefox you have: Firefox won't open a profile that a newer Firefox has used, so the launcher never installs an older version. Switching from release to ESR therefore waits for the next ESR, and from ESR to release happens on the next check.

## Data

| Folder | Contents |
| --- | --- |
| `Data\profile` | Your Firefox profile: bookmarks, history, passwords, add-ons, settings |
| `Data\CrashReports` | Crash reports, instead of `%APPDATA%\Mozilla\Firefox\Crash Reports` |
| `Data\settings` | The launcher's own state: the language and the last update check |

Firefox starts with `-profile "Data\profile"`, so it never uses or changes a profile of an installed Firefox, and both can run at the same time. The launcher cleans up once every `firefox.exe` has closed, so with an installed Firefox open too, that waits until it's closed as well.

When the package is started from another folder or drive letter, the paths Firefox stores in the profile (`prefs.js`, `extensions.json`, `handlers.json`, `pkcs11.txt`) are updated, first those into the package, then, if the drive letter changed, the others on the same drive. The caches that hold paths (`addonStartup.json.lz4`, `compatibility.ini`, `startupCache`) are cleared; Firefox rebuilds them on startup.

## What Firefox leaves in Windows, and how it's undone

Firefox names some of what it writes after a hash of its install folder. The launcher computes the same hash with a small plugin (`FoxHash`, source in `Other\Source\FoxHash`) and journals all of it before Firefox starts:

| Firefox writes | When Firefox closes |
| --- | --- |
| `HKCU\Software\Mozilla\Firefox` (taskbar IDs, launcher and startup window state) | Removed, or put back exactly as it was if you also have an installed Firefox |
| `%ProgramData%\Mozilla-1de4eec8-1241-4177-a864-e594e8d1fb38\updates\<hash>`, its profile count and update lock | Removed |
| `%APPDATA%\Mozilla\Firefox\Pending Pings` and the folders around it | Removed, if they weren't there before |
| `%LOCALAPPDATA%\Mozilla` and `AppData\LocalLow\Mozilla` (caches, the sandbox's temporary files) | Removed, if they weren't there before |
| **Make default** in Firefox's settings: `FirefoxHTML-<hash>`, `FirefoxURL-<hash>` and `FirefoxPDF-<hash>` file types, the `Firefox-<hash>` browser registration, and "Open with" entries | Removed |

A portable Firefox can't stay the default browser on a computer it may not be on, which is why that registration lasts only while it runs. From the PortableApps.com Platform, use the Platform's own file type associations.

## Coming from PortableApps.com's Firefox Portable

The profile is kept in `Data\profile` in both, so it carries over:

1. Copy this package's files over your existing `FirefoxPortable` folder, and compile the launcher.
2. Your `App\Firefox64`, `App\Firefox` and `Data` stay as they are; the next update replaces the Firefox folders with Mozilla's own.

PortableApps.com's `distribution.ini`, which adds a bookmark on the first run and reports Firefox's distribution as `portableapps`, isn't carried over by that update. Folders this package doesn't use can be deleted: `App\Bin`, `App\DefaultData`, `Data\plugins`, and in `Other\Source` the files of PortableApps.com's launcher (`FirefoxPortableU.nsi`, `Include`, `Languages`, `Plugins`).

## If something goes wrong

If Firefox Portable didn't close properly (a crash, a power cut, a USB drive pulled out), the next launch tells you and undoes what the last session changed. Start it again afterward.

When reporting a problem, please include an export of the `HKEY_CURRENT_USER\Software\pac-man\Journal` registry key and the contents of `%LOCALAPPDATA%\pac-man\Journal`.

## Building from source

The launcher is built with the [PortableApps Compiler][PACMAN]. Its configuration lives in `App\AppInfo`:

| File | Contents |
| --- | --- |
| `App\AppInfo\appinfo.ini` | Package details, version and file types. The launcher keeps the version current. |
| `App\AppInfo\Launcher\FirefoxPortable.ini` | The executables, the profile switch, the processes to wait for and the crash report folder |
| `App\AppInfo\Launcher\custom.nsh` | Install, updates, the policy, path updates, the journal of Windows leftovers and the version |
| `App\AppInfo\Launcher\Plugins\FoxHash.dll` | The install hash plugin, built from `Other\Source\FoxHash` |

`FoxHash` is CityHash64 (Google, MIT license), the version Firefox uses, over the install folder's path in UTF-16. It gives `308046B0AF4A39CB` for `C:\Program Files\Mozilla Firefox`, the hash a standard Firefox install uses. After each session the launcher compares it with the one Firefox recorded, and cleans up after that one too if they ever differ.

## Credits

* Firefox is developed by [Mozilla](https://www.mozilla.org/) and its contributors.
* CityHash by Geoff Pike and Jyrki Alakuijala, Google.
* [PortableApps.com Platform](https://portableapps.com/download) by [PortableApps.com](https://portableapps.com/).
* [PortableApps Compiler][PACMAN] developed by daemon.devin.
