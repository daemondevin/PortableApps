IconVectors Portable v1.10 Released

<!--more-->

A portable launcher for [Axialis IconVectors](https://www.axialis.com/iconvectors/), the SVG icon editor, built with the [PortableApps Compiler][PACMAN] (pac-man). It keeps IconVectors' settings, your registration, palettes, icon packs and autosaved drawings in the package. Every change it makes to Windows is recorded first and undone when IconVectors closes, or on the next launch if something went wrong.

 [PACMAN]: https://github.com/daemondevin/pac-man

## License

IconVectors is commercial software by Axialis Software. This package doesn't include it, and doesn't register it: you add your own copy and register it with your own product key. Axialis' license is per user and doesn't allow passing the software on, so the package isn't marked as shareable.

## System Requirements

* 64-bit Windows 10 or later.
* [PortableApps.com Platform](https://portableapps.com/download) (optional).

## Adding IconVectors

1. Download IconVectors from [axialis.com](https://www.axialis.com/iconvectors/) and install it on a computer.
2. Copy the contents of its program folder (where `IconVectors.exe` is, with its language folders `de`, `fr`...) into this package's `App\IconVectors`. You can uninstall it afterward.
3. Start `IconVectorsPortable.exe`, and register IconVectors with your own product key.

Until `App\IconVectors\IconVectors.exe` is there, the launcher says what to do, offers to open the `App` folder, and stops.

To update IconVectors, install the new version and copy its program folder over `App\IconVectors` the same way. IconVectors' own update check is turned off in the package: it would install the update into Program Files. After each session the launcher writes the version of `IconVectors.exe` to `appinfo.ini`, so the PortableApps.com Platform shows it.

## Configuration

`IconVectorsPortable.ini`, next to the launcher, holds the user settings. If it gets damaged, or you want to go back to the defaults, copy `Other\Source\IconVectorsPortable.ini` over it.

```INI
[IconVectorsPortable]
AdditionalParameters=
```

| Key | Default | What it does |
| --- | --- | --- |
| `AdditionalParameters` | empty | Extra command line arguments passed to IconVectors, such as a file to open. |

## Data

| Where | Contents | How |
| --- | --- | --- |
| `Data\settings\IconVectors.reg` | IconVectors' settings and your registration (`HKCU\Software\Axialis\IconVectors`) | Put in the registry for the session and saved back afterward |
| `Data\IconVectors` | Color palettes, icon packs (`.axp`) and autosaved drawings | Moved to `%APPDATA%\Axialis\IconVectors` for the session |

When the package is started from another folder or drive letter, the paths in the saved settings (recent folders, for one) are updated, first those into the package, then, if the drive letter changed, the others on the same drive.

## What's journaled and undone

| Could be written | When IconVectors closes |
| --- | --- |
| `HKCU\Software\Axialis\IconVectors` | Saved to `Data\settings`, then put back as it was: an installed IconVectors' settings and registration come back |
| `HKCU\Software\Axialis`, `%APPDATA%\Axialis` | Removed when left empty |
| `%LOCALAPPDATA%\Axialis\IconVectors` | Removed, if it wasn't there before |


## If something goes wrong

If IconVectors Portable didn't close properly (a crash, a power cut, a USB drive pulled out), the next launch tells you and undoes what the last session changed. Start it again afterward. Settings changed in that session aren't saved.

When reporting a problem, please include an export of the `HKEY_CURRENT_USER\Software\pac-man\Journal` registry key and the contents of `%LOCALAPPDATA%\pac-man\Journal`, but not your `Data\settings\IconVectors.reg`, which holds your product key.

## Building from source

The launcher is built with the [PortableApps Compiler][PACMAN], and needs the MissingApp segment. Its configuration lives in `App\AppInfo`:

| File | Contents |
| --- | --- |
| `App\AppInfo\appinfo.ini` | Package details and version. The launcher keeps the version current. |
| `App\AppInfo\Launcher\IconVectorsPortable.ini` | The executable, the missing program check and the data folder |
| `App\AppInfo\Launcher\custom.nsh` | The registry settings, the update check, the older layout, path updates and the version |

## Credits

* IconVectors is developed by [Axialis Software](https://www.axialis.com/).
* [PortableApps.com Platform](https://portableapps.com/download) by [PortableApps.com](https://portableapps.com/).
* [PortableApps Compiler][PACMAN] developed by daemon.devin.
