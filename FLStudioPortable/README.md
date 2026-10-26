# FL Studio Portable

A portable launcher for [FL Studio](https://www.image-line.com/fl-studio/), the digital audio workstation by Image-Line, built with the [PortableApps Compiler][PACMAN] (pac-man). Every change it makes to Windows is recorded first and undone when FL Studio closes, or on the next launch if something went wrong.

The package doesn't include or handle FL Studio's licensing: use it with a copy of FL Studio you're licensed to run.

 [PACMAN]: https://github.com/daemondevin/pac-man

## System Requirements

* Windows 10 or later, 64-bit. FL Studio has no 32-bit version; on Windows 11 on ARM the x64 version runs emulated.
* No administrator rights. FL Studio runs with your normal rights, so dragging samples, presets and projects into it from Explorer works.
* `Data` on a local drive (a USB drive is fine; a network share isn't). See [Data](#data).
* [PortableApps.com Platform](https://portableapps.com/download) (optional).

## Configuration

`FLStudioPortable.ini`, next to the launcher, holds the user settings. If it gets damaged, or you want to go back to the defaults, copy `Other\Source\FLStudioPortable.ini` over it.

```INI
[FLStudioPortable]
AdditionalParameters=
DisableSplashScreen=false
RunLocally=false
Scaled=false
Symlinks=true
```

| Key | Default | What it does |
| --- | --- | --- |
| `Scaled` | `false` | Start `FL64 (scaled).exe` instead of `FL64.exe`. Windows scales that version up on high DPI screens, like the "FL Studio (scaled)" shortcut of an installed FL Studio. |
| `Symlinks` | `true` | Link FL Studio's folders into `Data` while it runs. With `false`, FL Studio uses the folders on the computer and nothing in them travels with the package. |
| `AdditionalParameters` | empty | Extra command line switches passed to FL Studio. |
| `DisableSplashScreen` | `false` | Don't show the launcher's splash screen. |
| `RunLocally` | `false` | Copy FL Studio to the `TEMP` folder and run it from there, for read-only media. Changes made in that session aren't saved back. |

Opening a project or sample from the PortableApps.com Platform while FL Studio runs hands it to the running FL Studio.

## Data

While FL Studio runs, these are linked into `Data` with NTFS junctions, so nothing is copied back and forth:

| FL Studio uses | Kept in |
| --- | --- |
| `Documents\Image-Line` (the user data folder: projects, presets, recordings, renders, hardware scripts, settings files) | `Data\Image-Line` |
| `%APPDATA%\Image-Line` | `Data\AppData\Image-Line` |
| `%ProgramData%\FL Cloud Plugins` | `Data\ProgramData\FL Cloud Plugins` |

If an installed FL Studio already has one of these folders, it's moved aside for the session and put back when FL Studio Portable closes. The one exception is `FL Cloud Plugins`: an installed FL Studio's copy of it belongs to the administrator, so the launcher can't always move it. Then it's left in place and FL Studio Portable uses it for that session.

FL Studio's registry settings, `HKCU\Software\Image-Line` (its preferences, and its registration once you've unlocked it), are kept in `Data\settings\Image-Line.reg`. They're loaded when FL Studio starts and saved when it closes, whatever FL Studio version wrote them. An installed FL Studio's settings are put back afterwards.

Close an installed FL Studio before starting FL Studio Portable; the launcher won't start while one is open.

> [!IMPORTANT]
> Junctions can only point to a local drive. Running from a network share isn't supported.

### Coming from an earlier FL Studio Portable

The first launch takes over what earlier packages kept, so nothing has to be moved by hand:

* `Data\settings\FLStudio.reg` and `ILReg.reg` are loaded once and saved as `Image-Line.reg`. The old files are left alone and can be deleted afterwards.
* `Data\AppData` and `Data\ProgramData` held the contents of `%APPDATA%\Image-Line` and `FL Cloud Plugins` directly. They're moved one folder down, to `Data\AppData\Image-Line` and `Data\ProgramData\FL Cloud Plugins`.

## Registry

Besides `HKCU\Software\Image-Line`, the launcher records these keys before FL Studio starts:

* `HKCU\Software\ASIO`
* the `.flp`, `.fsc`, `.fst` and `.flkey` file types in `HKCU\Software\Classes`

A key that didn't exist is deleted when FL Studio closes; one that did (from an installed FL Studio or another program) is put back exactly as it was. The list is `[FLStudioRegistry]` in `App\AppInfo\Launcher\FLStudioPortable.ini`.

## If something goes wrong

If FL Studio Portable didn't close properly (a crash, a power cut, a USB drive pulled out), the next launch tells you and undoes everything the last session changed. Start it again afterwards. Your projects and files in `Data` are kept; registry settings changed in the session that crashed aren't saved.

When reporting a problem, please include an export of the `HKEY_CURRENT_USER\Software\pac-man\Journal` registry key and the contents of `%LOCALAPPDATA%\pac-man\Journal`.

## Building from source

The launcher is built with the [PortableApps Compiler][PACMAN]. Its configuration lives in `App\AppInfo`:

| File | Contents |
| --- | --- |
| `App\AppInfo\appinfo.ini` | Package details, version and file types |
| `App\AppInfo\Launcher\FLStudioPortable.ini` | The launcher configuration: the data links and the extra registry keys to journal |
| `App\AppInfo\Launcher\custom.nsh` | The portable registry settings, the FL Cloud Plugins link, the scaled version and taking over earlier packages' data |

Don't put `Data\settings\Image-Line.reg`, or the `ILReg.reg` of earlier packages, in `App\DefaultData` of a package you share: once FL Studio is unlocked, it holds your registration.

## Credits

* FL Studio is developed by [Image-Line](https://www.image-line.com/).
* [PortableApps.com Platform](https://portableapps.com/download) by [PortableApps.com](https://portableapps.com/).
* [PortableApps Compiler][PACMAN] developed by daemon.devin.
