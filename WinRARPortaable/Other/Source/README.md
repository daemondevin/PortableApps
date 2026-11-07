# WinRAR Portable

A portable launcher for [WinRAR](https://www.win-rar.com/), the RAR and ZIP archiver, built with the [PortableApps Compiler][PACMAN] (PAC-MAN). It keeps WinRAR's settings, your registration key and themes in the package, using WinRAR's own `WinRAR.ini` support, by default WinRAR doesn't write to the registry at all, and the launcher can download WinRAR and keep it up to date. Every change it makes to Windows is recorded first and undone when WinRAR closes, or on the next launch if something went wrong.

 [PACMAN]: https://github.com/daemondevin/pac-man

## License

WinRAR is shareware by win.rar GmbH: free to try for 40 days, then a license is needed. Its license doesn't allow including WinRAR in another package, so this one doesn't: the launcher downloads the official installer from rarlab.com for you (or you add your own copy), and you bring your own license (your `rarreg.key`). For the same reason the package isn't marked as shareable; share it without `App\WinRAR` and your key.

## System Requirements

* Windows 7 or later, with the WinRAR build for it (64-bit or 32-bit).
* [PortableApps.com Platform](https://portableapps.com/download) (optional).

## First launch

The package doesn't include WinRAR. The first launch offers to download it:

1. It reads rarlab.com's download page for the newest WinRAR: the 64-bit build, or the 32-bit one on 32-bit Windows, in English or the language `InstallerLanguage` names.
2. It downloads that installer (`winrar-x64-<version>.exe`).
3. It checks that the installer carries a valid signature by **win.rar GmbH** that Windows trusts. rarlab.com publishes no checksums, so the signature is the check. A download that fails is never used.
4. It unpacks the installer into `App\WinRAR` without running it: the installer is a self-extracting archive. The first time this needs 7-Zip, on the computer or as 7-Zip Portable next to this package; after that, WinRAR's own `UnRAR.exe` does it.
5. It checks that `WinRAR.exe` from it is signed by win.rar GmbH too, and is the version on offer.

Then WinRAR starts. If you say no, or something fails, nothing is left behind and the launcher stops.

### Adding WinRAR yourself

You can also add WinRAR without the launcher downloading it:

* **From the installer:** download WinRAR from [win-rar.com](https://www.win-rar.com/download.html) and open it with 7-Zip (or WinRAR), then extract its contents into this package's `App\WinRAR`, without running it.
* **From an installed WinRAR:** copy the contents of `C:\Program Files\WinRAR` into `App\WinRAR`.

After each session the launcher writes the version of `WinRAR.exe` to `appinfo.ini`, so the PortableApps.com Platform shows it.

### Your registration key

Put your `rarreg.key` in `Data\WinRAR`. The launcher moves it next to `WinRAR.exe` for each session and back afterward; it never reads or changes it. A key in `%APPDATA%\WinRAR` on the computer isn't used (see `Global\AppData` below).

### Your settings from an installed WinRAR

In the installed WinRAR, use Options > Import and export > Create WinRAR.ini file, and copy the `WinRAR.ini` it makes into `Data\WinRAR`. Its themes, if you added any, are in `%APPDATA%\WinRAR\Themes`; copy that folder to `Data\WinRAR\Themes`.

## Updates

The launcher keeps WinRAR up to date, the same way as the first install:

* Before WinRAR starts, at most once every `UpdateInterval` days, it reads rarlab.com's download page. It stays with the build you have: a 32-bit WinRAR is updated with the 32-bit installer. Betas aren't offered.
* If there's a newer WinRAR, it asks whether to update now (`UpdateCheck=ask`), or just does it (`UpdateCheck=auto`). Say no and WinRAR starts as it is; you're asked again at the next check.
* The new WinRAR is downloaded, checked and unpacked as above, then swapped in. Your settings, key and themes are in `Data` at that point, so they aren't touched. The old folder is kept until the new one is in place, and the swap is journaled: if the launcher is stopped halfway, the next launch puts the old WinRAR back.
* If anything fails, it says why and starts the WinRAR you have.

A WinRAR license covers new versions, so your `rarreg.key` keeps working after an update.

## Configuration

`WinRARPortable.ini`, next to the launcher, holds the user settings. If it gets damaged, or you want to go back to the defaults, copy `Other\Source\WinRARPortable.ini` over it.

```INI
[WinRARPortable]
AdditionalParameters=
Integration=false
UpdateCheck=ask
UpdateInterval=7
InstallerLanguage=
```

| Key | Default | What it does |
| --- | --- | --- |
| `Integration` | `false` | `false` keeps WinRAR out of the registry entirely (`Global\Integration=0`): the Integration settings can't change file associations or the Explorer context menu. `true` lets them (see below). |
| `UpdateCheck` | `ask` | `ask` asks before updating, `auto` updates without asking, `off` never checks. |
| `UpdateInterval` | `7` | Days between update checks. `0` checks on every launch. |
| `InstallerLanguage` | empty | Empty downloads the English WinRAR. For another language, the code rarlab.com adds to the installer's name: `d` (German), `fr` (French), `es` (Spanish), `ru` (Russian), `sc` (Simplified Chinese), `br` (Brazilian Portuguese), and so on; `winrar-x64-713d.exe` is the German 7.13. |
| `AdditionalParameters` | empty | Extra command line switches passed to WinRAR. |
| `ReleaseURL`, `DownloadURL` | rarlab.com's | Not in the file by default. The page listing WinRAR's installers and the folder they're downloaded from, for a mirror. |

## Data

| In `Data\WinRAR` | Contents |
| --- | --- |
| `WinRAR.ini` | WinRAR's settings, written by WinRAR when it closes (UTF-16 text) |
| `rarreg.key` | Your registration key, which you put there |
| `Themes` | Interface themes you install |
| `settings.reg`, `rar.log` | Settings you export, and WinRAR's error log, when there are any |

How it's done:

* WinRAR keeps its settings in `WinRAR.ini` instead of the registry when there's one next to `WinRAR.exe`, and with `Global\AppData=0` in it, it keeps the registration key, themes and log next to `WinRAR.exe` too, instead of `%APPDATA%\WinRAR`.
* The launcher moves those files from `Data\WinRAR` next to `WinRAR.exe` for each session and back afterward. Ones left there by a session that didn't close properly are taken back first.
* Before each launch it puts `Global\AppData=0` and `Global\Integration` (from `Integration` above) at the top of `WinRAR.ini`, creating the file if there isn't one. The rest of the file is kept as it was.

## Integration

With `Integration=true`, WinRAR's Options > Settings > Integration can associate archive types with WinRAR and add its context menus to Explorer. A portable WinRAR can't stay integrated with a drive that may not be there, so that lasts only while WinRAR runs:

| Could be written | When WinRAR closes |
| --- | --- |
| WinRAR's file types (`WinRAR`, `WinRAR.ZIP`, `WinRAR.REV`) and extensions set to open with them | Removed, or put back as they were; an extension that didn't open with WinRAR before loses that again |
| The shell extension (`CLSID\{B41DB860-...}`, 32- and 64-bit) and its context menu and drag-and-drop entries | Removed, or put back as they were |
| `App Paths\WinRAR.exe`, `RegisteredApplications`, the shell extension's approval | Removed, or put back as they were |

WinRAR writes these for the current user, or for all users when it runs as administrator; the launcher looks after the all-users ones only when it runs as administrator too.

On Windows 11, WinRAR's entry in the new top-level context menu comes from a small app package it registers with Windows (`RarExtInstaller.exe`). That isn't registry data, and the launcher doesn't remove it; remove "WinRAR" from Settings > Apps if it stays. Windows 10 and later also treat file associations as suggestions, so WinRAR may only appear under "Open with".

## What's journaled and undone

| Could be written | When WinRAR closes |
| --- | --- |
| `HKCU\Software\WinRAR`, `HKCU\Software\WinRAR SFX` (an installed WinRAR's settings, and self-extracting archives' remembered folders) | Put back as they were |
| `%APPDATA%\WinRAR` | Removed, if it wasn't there before |
| With `Integration=true`, the entries above | Removed, or put back as they were |

## If something goes wrong

If WinRAR Portable didn't close properly (a crash, a power cut, a USB drive pulled out), the next launch tells you and undoes what the last session changed. Start it again afterward.

When reporting a problem, please include an export of the `HKEY_CURRENT_USER\Software\pac-man\Journal` registry key and the contents of `%LOCALAPPDATA%\pac-man\Journal`, but never your `rarreg.key`.

## Building from source

The launcher is built with the [PortableApps Compiler][PACMAN]. Its configuration lives in `App\AppInfo`:

| File | Contents |
| --- | --- |
| `App\AppInfo\appinfo.ini` | Package details, version and file types. The launcher keeps the version current. |
| `App\AppInfo\Launcher\WinRARPortable.ini` | The executable |
| `App\AppInfo\Launcher\custom.nsh` | Install, updates, moving WinRAR's files in and out, the global settings in `WinRAR.ini`, the journal of integration and other leftovers, and the version |

## Credits

* WinRAR is developed by Alexander Roshal and published by [win.rar GmbH](https://www.win-rar.com/).
* [PortableApps.com Platform](https://portableapps.com/download) by [PortableApps.com](https://portableapps.com/).
* [PortableApps Compiler][PACMAN] developed by daemon.devin.
