# AIMP Portable

A portable launcher for [AIMP](https://www.aimp.ru/), the music player with its own audio library, audio converter and tag editor, built with the [PortableApps Compiler][PACMAN] (pac-man). Every change it makes to Windows is recorded first and undone when AIMP closes, or on the next launch if something went wrong.

AIMP isn't included: its license only allows AIMP's original installer to be passed on. You add AIMP yourself, once (see [Adding AIMP](#adding-aimp)).

 [PACMAN]: https://github.com/daemondevin/pac-man

## System Requirements

* Windows 7 or later.
* [PortableApps.com Platform](https://portableapps.com/download) (optional).

## Adding AIMP

1. Download AIMP from [aimp.ru](https://www.aimp.ru/?do=download).
2. Run its installer and choose the portable install, into this package's `App\AIMP` folder. Or copy the program folder of an AIMP that's already installed to `App\AIMP`.
3. Start `AIMPPortable.exe`.

Until AIMP is there, the launcher says which folder to copy and where, offers to open the `App` folder, and stops. It checks for `AIMP.exe`, `AIMP.Runtime.dll` and `AIMP.Shared.dll`, so a copy of only `AIMP.exe` is caught too.

An `AIMP.ini` that comes with the copied program is taken over the first time; from then on the one in `Data` is used, set to keep AIMP's profile in the package.

## Configuration

`AIMPPortable.ini`, next to the launcher, holds the user settings. If it gets damaged, or you want to go back to the defaults, copy `Other\Source\AIMPPortable.ini` over it.

```INI
[AIMPPortable]
AdditionalParameters=
SystemIntegration=false
```

| Key | Default | What it does |
| --- | --- | --- |
| `SystemIntegration` | `false` | Let AIMP register itself with Windows. See [System integration](#system-integration). |
| `AdditionalParameters` | empty | Extra command line switches passed to AIMP. |

## Data

AIMP keeps everything in its profile. With `UserMode=0` in the `AIMP.ini` next to `AIMP.exe`, that profile is the `Profile` folder beside it rather than `%APPDATA%\AIMP`. Both live in `Data` and are moved into place while AIMP runs:

| AIMP uses | Kept in |
| --- | --- |
| `App\AIMP\AIMP.ini` | `Data\AIMP.ini` |
| `App\AIMP\Profile` (settings, playlists, audio library, skins you add) | `Data\Profile` |
| Recordings | `Data\Recorded` |

When the package moves (another drive letter, another folder), the paths stored in AIMP's settings, tag editor and converter settings are updated to match.

> [!NOTE]
> AIMP's audio library (`Data\Profile\AudioLibrary\Local.adb`) stores the full path of every file in it, in a format the launcher doesn't change. If your music is on the same drive as the package and that drive gets a different letter, rescan the library folders in AIMP.

## System integration

In its settings AIMP can register itself with Windows: as the player for file types, in Explorer's right-click menu, as an AutoPlay handler, and in Default Programs. It does that through `Elevator.exe`, which asks for administrator rights and changes Windows for every user.

The launcher runs with your normal rights, so it couldn't undo those changes. That's why, with `SystemIntegration=false` (the default), `Elevator.exe` is set aside while AIMP runs and those options do nothing. It's renamed to `Elevator.exe.disabled` for the session and put back when AIMP closes; if AIMP updated itself meanwhile, the new `Elevator.exe` is kept.

With `SystemIntegration=true`, AIMP can make those changes, and they stay until you turn the options off in AIMP again.

## What AIMP changes, and how it's undone

| AIMP changes | Put back when it closes |
| --- | --- |
| "Run AIMP at Windows startup": the `AIMP` value in `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` | Removed, or put back exactly as it was (an installed AIMP's entry, for example) |
| `Elevator.exe` set aside (see above) | Put back |

A portable AIMP can't start with Windows from a drive that may not be there, which is why the startup entry is removed.

## Updates

AIMP can update itself in place; its update checker is in its settings. After each session the launcher writes the version of `AIMP.exe` to `appinfo.ini`, so the PortableApps.com Platform shows the version AIMP has updated itself to.

## Moving from PortableApps.com's AIMP Portable

This package keeps `AIMP.ini` and the profile in `Data` the same way PortableApps.com's AIMP Portable does, so your settings carry over:

1. Copy this package's files over your existing `AIMPPortable` folder, and compile the launcher.
2. Your `App\AIMP` and `Data` stay as they are.

Installing this package with the PortableApps.com Installer over PortableApps.com's one keeps `Data` too. `App\bin\sqlite3.exe` from the older package is no longer used (it updated an audio library format AIMP 5 doesn't use), and can be deleted.

## If something goes wrong

If AIMP Portable didn't close properly (a crash, a power cut, a USB drive pulled out), the next launch tells you and undoes what the last session changed. Start it again afterward.

When reporting a problem, please include an export of the `HKEY_CURRENT_USER\Software\pac-man\Journal` registry key and the contents of `%LOCALAPPDATA%\pac-man\Journal`.

## Building from source

The launcher is built with the [PortableApps Compiler][PACMAN], and needs the MissingApp segment. Its configuration lives in `App\AppInfo`:

| File | Contents |
| --- | --- |
| `App\AppInfo\appinfo.ini` | Package details, version and file types. The launcher keeps the version current. |
| `App\AppInfo\Launcher\AIMPPortable.ini` | The launcher configuration: the missing program check, data moves, language and path updates |
| `App\AppInfo\Launcher\custom.nsh` | Portable mode, system integration, the startup entry and the version |

## Credits

* AIMP is developed by [Artem Izmaylov and the AIMP DevTeam](https://www.aimp.ru/).
* The data layout, language mapping and path updates follow PortableApps.com's AIMP Portable.
* [PortableApps.com Platform](https://portableapps.com/download) by [PortableApps.com](https://portableapps.com/).
* [PortableApps Compiler][PACMAN] developed by daemon.devin.
