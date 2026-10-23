# Emsisoft Emergency Kit Portable

A portable launcher for [Emsisoft Emergency Kit](https://www.emsisoft.com/en/emergency-kit/), Emsisoft's second-opinion malware scanner and cleaner, built with the [PortableApps Compiler][PACMAN] (pac-man). Every change it makes to Windows is recorded first and undone when Emergency Kit closes, or on the next launch if something went wrong.

The package contains only the launcher. Emergency Kit itself comes from Emsisoft, and its license applies: it's free for private, non-commercial use, and businesses need Emsisoft's commercial license.

 [PACMAN]: https://github.com/daemondevin/pac-man

## System Requirements

* Windows 10 or later, 64-bit. Emergency Kit has no 32-bit version.
* Administrator rights. Emergency Kit needs them to scan memory, other users' files and the registry.
* A local drive (a USB drive is fine; a network share isn't).
* [PortableApps.com Platform](https://portableapps.com/download) (optional).

## Two scanners

| Start | What runs |
| --- | --- |
| `EmergencyKitPortable.exe` | The Emergency Kit scanner, with its full window |
| `CLScannerPortable.exe` | A menu for the Emsisoft Commandline Scanner (`a2cmd.exe`), in a command prompt |

The menu offers a quick scan, a malware scan, or a scan of a folder or drive you choose, with options for potentially unwanted programs, archives and NTFS alternate data streams. Detected objects can be quarantined, deleted or only reported. It can also list, restore and delete quarantined objects, and update the signatures. Each scan's log is saved in `Data\Logs`.

`CLScannerPortable.exe` starts `EmergencyKitPortable.exe /CLScanner`, so both go through the same launcher, with the same clean-up.

## Configuration

`EmergencyKitPortable.ini`, next to the launcher, holds the user settings. If it gets damaged, or you want to go back to the defaults, copy `Other\Source\EmergencyKitPortable.ini` over it.

```INI
[EmergencyKitPortable]
AdditionalParameters=
Language=
```

| Key | Default | What it does |
| --- | --- | --- |
| `Language` | empty | The language Emergency Kit uses, for example `de-de`. See [Language](#language). |
| `AdditionalParameters` | empty | Extra command line switches passed to Emergency Kit. |

## Language

Started from the PortableApps.com Platform, Emergency Kit uses the Platform's language, if it has a translation for it; otherwise English. Started on its own, it keeps the language you chose in Emergency Kit. `Language=` in `EmergencyKitPortable.ini` overrides both.

Emergency Kit has Czech, Dutch, English, Farsi, Finnish, French, German, Hungarian, Italian, Japanese, Korean, Polish, Portuguese (Brazil), Russian, Simplified and Traditional Chinese, Slovenian, Spanish and Turkish.

## Data

Emergency Kit keeps everything in its own folder, `App\EEK`. Your settings, logs, reports and quarantine are kept in `Data` and moved into place while it runs:

| Emergency Kit uses | Kept in |
| --- | --- |
| `App\EEK\a2settings.ini` and its other settings files | `Data\settings` |
| `App\EEK\Logs` | `Data\Logs` |
| `App\EEK\Reports` | `Data\Reports` |
| `App\EEK\Quarantine` | `Data\Quarantine` |

> [!NOTE]
> The quarantine holds the malware Emergency Kit found, stored so it can't run. Copying `Data` copies it too.

## Updates

Emergency Kit updates its signatures and its own program files itself, in `App\EEK\bin64`: use **Update** in its window, or in the command line menu. Nothing else is needed.

After each session the launcher reads the version of `a2emergencykit.exe` and writes it to `appinfo.ini`, so the PortableApps.com Platform shows the version Emergency Kit has updated itself to.

### Moving from an older package

Older versions of this package kept the signatures and translations in `App\DefaultData` or `Data`, and moved them into Emergency Kit's folder for each session. Emergency Kit updates both itself, so they now stay in `App\EEK\bin64`. The first launch moves them there once.

## What Emergency Kit changes, and how it's undone

Before Emergency Kit starts, the launcher records the state of each of these. When it closes, everything that wasn't there before is removed.

| Emergency Kit adds | Removed when it closes |
| --- | --- |
| The Emsisoft Protection Platform driver (service `epp`), which it loads to scan memory and look for rootkits | Stopped and deleted, along with `System32\drivers\epp.sys` if that was put there |
| Service `a2service`, which the command line scanner's `/s` switch installs | Stopped and deleted |
| `HKLM\SOFTWARE\Emsisoft` | Deleted |
| `%ProgramData%\Emsisoft` | Deleted |

Emergency Kit normally removes its driver itself when it closes. The launcher's clean-up is what covers a crash, a forced shutdown, or Emergency Kit being killed.

### With Emsisoft Anti-Malware installed

Anything that already existed before launch is left alone: an installed Emsisoft Anti-Malware's driver, services, registry key and `%ProgramData%\Emsisoft` folder are never touched. Emergency Kit itself won't start while Emsisoft Anti-Malware is running.

## If something goes wrong

If Emergency Kit Portable didn't close properly (a crash, a power cut, a USB drive pulled out), the next launch tells you and undoes everything the last session changed. Start it again afterwards. Your settings, logs and quarantine are put back in `Data`.

When reporting a problem, please include an export of the `HKEY_CURRENT_USER\Software\pac-man\Journal` registry key and the contents of `%LOCALAPPDATA%\pac-man\Journal`.

## Building from source

The launcher is built with the [PortableApps Compiler][PACMAN]. Its configuration lives in `App\AppInfo`:

| File | Contents |
| --- | --- |
| `App\AppInfo\appinfo.ini` | Package details and version. The launcher keeps the version current. |
| `App\AppInfo\Launcher\EmergencyKitPortable.ini` | The launcher configuration: the data moves and the language |
| `App\AppInfo\Launcher\custom.nsh` | Journaling Emergency Kit's system changes, the second scanner, and the version |
| `App\CLScanner.cmd` | The command line scanner's menu |
| `Other\Source\CLScannerPortable.nsi` | The second launcher. Compile it with NSIS from `Other\Source`; it writes `CLScannerPortable.exe` to the package root. |

## Credits

* Emsisoft Emergency Kit is developed by [Emsisoft](https://www.emsisoft.com/).
* [PortableApps.com Platform](https://portableapps.com/download) by [PortableApps.com](https://portableapps.com/).
* [PortableApps Compiler][PACMAN] developed by daemon.devin.
