# RipX DAW Portable

A portable launcher for [RipX DAW](https://hitnmix.com/), Hit'n'Mix's stem separation and audio editing workstation, built with the [PortableApps Compiler][PACMAN] (pac-man). Every change it makes to Windows is recorded first and undone when RipX closes, or on the next launch if something went wrong.

The package doesn't include or handle RipX's licensing: use it with a copy of RipX DAW you're licensed to run.

 [PACMAN]: https://github.com/daemondevin/pac-man

## System Requirements

* Windows 10 or later, 64-bit. RipX DAW has no 32-bit version.
* Administrator rights for the launcher. RipX itself runs with your normal rights (see [Drag and drop](#drag-and-drop)).
* `Data` on a local drive (a USB drive is fine; a network share isn't). See [Data](#data).
* [PortableApps.com Platform](https://portableapps.com/download) (optional).

## Drag and drop

Windows doesn't let Explorer, or any other program running with normal rights, drag files into a program that runs as administrator. So a launcher that runs RipX elevated also breaks dragging audio files into it.

The launcher still needs administrator rights for the machine-wide registry key RipX reads (see [Registry](#registry)). But once it has set that up, it starts RipX the way Explorer would: with the rights of the signed-in user, using Explorer's own credentials. Dragging audio into RipX from Explorer, the desktop and other programs then works as it does with an installed RipX.

* A second launch while RipX runs (opening a rip from the PortableApps.com Platform, for example) isn't elevated at all, so there's no UAC prompt. It hands its files to the running RipX.
* If the launcher was elevated with a different account's password (a standard user typing an administrator's password), RipX has to run as that administrator, and dragging from your own Explorer can't work. Signing in with an account that is an administrator avoids that.

## Configuration

`RipXDAWPortable.ini`, next to the launcher, holds the user settings. If it gets damaged, or you want to go back to the defaults, copy `Other\Source\RipXDAWPortable.ini` over it.

```INI
[RipXDAWPortable]
AdditionalParameters=
DisableSplashScreen=false
Symlinks=true
```

| Key | Default | What it does |
| --- | --- | --- |
| `Symlinks` | `true` | Link RipX's folders into `Data` while it runs. With `false`, RipX uses the folders on the computer and nothing in them travels with the package. |
| `AdditionalParameters` | empty | Extra command line switches passed to RipX. |
| `DisableSplashScreen` | `false` | Don't show the launcher's splash screen. |

## Data

While RipX runs, these are linked into `Data` with NTFS junctions, so nothing is copied back and forth. That matters here: a single rip is often several hundred megabytes.

| RipX uses | Kept in |
| --- | --- |
| `Documents\RipX` (rips, stems, loops, sound palettes, RipLists, RipScripts) | `Data\RipX` |
| `%APPDATA%\Hit'n'Mix` (shared instrument data) | `Data\Hit'n'Mix` |

If an installed RipX already has one of these folders, it's moved aside for the session and put back when RipX DAW Portable closes.

RipX's preferences, `HKCU\Software\HitnMix\HitnMix\Kit`, are kept in `Data\settings\RipX.reg`. They're loaded when RipX starts and saved when it closes; an installed RipX's preferences are put back afterward.

Close an installed RipX before starting RipX DAW Portable; the launcher won't start while one is open.

> [!IMPORTANT]
> Junctions can only point to a local drive. Running from a network share isn't supported.

## Registry

RipX reads where its resources are, and the user details its installer leaves, from `HKLM\SOFTWARE\HitnMix`. Without them it treats itself as a broken installation. For the session, the launcher writes what RipX's installer would, pointing at the package:

* `HitnMix\ApplicationPath`: the package's `RipX.exe`
* `HitnMix\Kit\DataPath`: `ResourcePath` and `HitnMixSharedPath`, the package's `App\RipXDAW` folder
* `HitnMix\Kit\User info`: the installer's defaults for `Name`, `Company` and `ActivationCode`, only where they aren't set

The whole key is recorded first. If it wasn't there it's deleted when RipX closes; if an installed RipX had it, it's put back exactly as it was, including the installed RipX's own user details.

### Activation

The launcher doesn't touch RipX's activation. RipX keeps it for each Windows user in a registry key of its own, which stays on the computer, so RipX may ask you to activate it on each computer you use it on, as Hit'n'Mix intends.

## If something goes wrong

If RipX DAW Portable didn't close properly (a crash, a power cut, a USB drive pulled out), the next launch tells you and undoes everything the last session changed. Start it again afterward. Your rips and files in `Data` are kept; preferences changed in the session that crashed aren't saved.

When reporting a problem, please include an export of the `HKEY_CURRENT_USER\Software\pac-man\Journal` registry key and the contents of `%LOCALAPPDATA%\pac-man\Journal`.

## Building from source

The launcher is built with the [PortableApps Compiler][PACMAN]. Its configuration lives in `App\AppInfo`:

| File | Contents |
| --- | --- |
| `App\AppInfo\appinfo.ini` | Package details, version and file types |
| `App\AppInfo\Launcher\RipXDAWPortable.ini` | The launcher configuration: the data links |
| `App\AppInfo\Launcher\custom.nsh` | Starting RipX without elevation, the machine-wide key and the portable preferences |

## Credits

* RipX DAW is developed by [Hit'n'Mix Ltd](https://hitnmix.com/).
* [PortableApps.com Platform](https://portableapps.com/download) by [PortableApps.com](https://portableapps.com/).
* [PortableApps Compiler][PACMAN] developed by daemon.devin.
