# Komodo Edit Portable

A portable launcher for [Komodo Edit][KO], ActiveState's free multi-language code editor, built with the [PortableApps Compiler][PACMAN] (pac-man). Everything Komodo changes on the PC is recorded first and undone when Komodo closes, or on the next launch if something went wrong.

ActiveState has stopped developing Komodo; version 12 is the last release, and its source is on [GitHub](https://github.com/Komodo/KomodoEdit).

 [KO]: https://www.activestate.com/products/komodo-edit/
 [PACMAN]: https://github.com/daemondevin/pac-man

## System Requirements

* Windows 7 or later.
* No administrator rights.
* [PortableApps.com Platform](https://portableapps.com/download) (optional).

## Configuration

`KomodoEditPortable.ini`, next to the launcher, holds the user settings. If it gets damaged, or you want to go back to the defaults, copy `Other\Source\KomodoEditPortable.ini` over it.

```INI
[KomodoEditPortable]
AdditionalParameters=
RunLocally=false
```

| Key | Default | What it does |
| --- | --- | --- |
| `AdditionalParameters` | empty | Extra command line switches passed to Komodo. |
| `RunLocally` | `false` | Copy Komodo to the `TEMP` folder and run it from there, for read-only media. Changes made in that session aren't saved back. |

Launching the package again while Komodo runs passes the files to the running Komodo.

## Data

Komodo keeps its settings, toolbox, projects list and Mozilla profile in one folder per version. The launcher points Komodo at `Data\ActiveState\KomodoEdit` with Komodo's own `KOMODO_USERDATADIR` setting, so the folder for version 12 is `Data\ActiveState\KomodoEdit\12.0`. Nothing is copied, linked or moved, and an installed Komodo Edit keeps its own settings.

New projects go to `Data\Workspace` unless you change the project folder in Komodo's preferences.

When the package moves (another drive letter or folder), the paths Komodo remembered inside the package are updated in its preferences and Mozilla's add-on list. Mozilla's startup cache is cleared after each session, since it holds those paths too; Komodo rebuilds it on the next start.

## What's cleaned up

Komodo and the Mozilla platform it's built on make a few folders outside its settings folder:

* `%APPDATA%\ActiveState\Komodo Edit` (crash reports)
* `%LOCALAPPDATA%\ActiveState\Komodo Edit` (the update folder)
* `%LOCALAPPDATA%\ActiveState\KomodoEdit`
* `%APPDATA%\Mozilla`

Any of these that didn't exist before Komodo started is removed when it closes, or on the next launch if Komodo didn't close properly. Folders that already existed (from an installed Komodo) are left alone. `%APPDATA%\Mozilla` is also where Firefox and Thunderbird keep their profiles, so it's only removed when Komodo made it and no Mozilla program has started using it since.

## If something goes wrong

If Komodo Edit Portable didn't close properly (a crash, a power cut, a USB drive pulled out), the next launch tells you and undoes everything the last session changed before it starts again.

When reporting a problem, please include an export of the `HKEY_CURRENT_USER\Software\pac-man\Journal` registry key and the contents of `%LOCALAPPDATA%\pac-man\Journal`.

## Building from source

The launcher is built with the [PortableApps Compiler][PACMAN]. Its configuration lives in `App\AppInfo`:

| File | Contents |
| --- | --- |
| `App\AppInfo\AppInfo.ini` | Package details, version and file types |
| `App\AppInfo\Launcher\KomodoEditPortable.ini` | The launcher configuration: the data folder, the folders to clean up and the path updates |
| `App\AppInfo\Launcher\custom.nsh` | Cleaning up the folders Komodo makes outside `Data` |

## Credits

* Komodo Edit is developed by ActiveState Software Inc.
* [PortableApps.com Platform](https://portableapps.com/download) by [PortableApps.com](https://portableapps.com/).
* [PortableApps Compiler][PACMAN] developed by daemon.devin.
