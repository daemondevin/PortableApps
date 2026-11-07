# Axialis IconWorkshop Portable

A portable launcher for [Axialis IconWorkshop](https://www.axialis.com/iconworkshop/), the icon editor for Windows, macOS, web and mobile icons, cursors and toolbars, built with the [PortableApps Compiler][PACMAN] (pac-man). It keeps IconWorkshop's settings, your registration, templates, color swatches and the Librarian in the package, and follows the PortableApps.com Platform's language. Every change it makes to Windows is recorded first and undone when IconWorkshop closes, or on the next launch if something went wrong.

 [PACMAN]: https://github.com/daemondevin/pac-man

## License

IconWorkshop is commercial software by Axialis Software. This package doesn't include it, and doesn't register it: you add your own copy and register it with your own product key. Axialis' license is per user and doesn't allow passing the software on, so the package isn't marked as shareable.

## System Requirements

* Windows 7 or later, 64-bit.
* [PortableApps.com Platform](https://portableapps.com/download) (optional).

## Adding IconWorkshop

1. Download IconWorkshop from [axialis.com](https://www.axialis.com/iconworkshop/) and install it on a computer.
2. Copy the contents of its program folder (where `IconWorkshop.exe` is, with the `Res*.dll` language files) into this package's `App\IconWorkshop`. You can uninstall it afterward.
3. Start `IconWorkshopPortable.exe`, and register IconWorkshop with your product key.

Until `App\IconWorkshop\IconWorkshop.exe` is there, the launcher says what to do, offers to open the `App` folder, and stops.

To update IconWorkshop, install the new version and copy its program folder over `App\IconWorkshop` the same way. After each session the launcher writes the version of `IconWorkshop.exe` to `appinfo.ini`, so the PortableApps.com Platform shows it.

The installer's integrations (Explorer thumbnails for icon files, the Visual Studio add-in) are registered for the whole computer, so the package doesn't have them.

## Configuration

`IconWorkshopPortable.ini`, next to the launcher, holds the user settings. If it gets damaged, or you want to go back to the defaults, copy `Other\Source\IconWorkshopPortable.ini` over it.

```INI
[IconWorkshopPortable]
AdditionalParameters=
```

| Key | Default | What it does |
| --- | --- | --- |
| `AdditionalParameters` | empty | Extra command line arguments passed to IconWorkshop, such as a file to open. |

### Language

Started from the PortableApps.com Platform, IconWorkshop's language is set to the Platform's when the Platform's language is different from last time, if IconWorkshop has it (English, French, Italian, Spanish, German, Dutch, Portuguese, Simplified Chinese, Greek, Japanese or Korean). A language you pick in IconWorkshop stays until the Platform's language changes again.

## Data

| Where | Contents | How |
| --- | --- | --- |
| `Data\settings\IconWorkshop.reg` | IconWorkshop's settings and your registration (`HKCU\Software\Axialis\IconWorkshop`) | Put in the registry for the session and saved back afterward |
| `Data\settings\AxialisCustomerInfo.reg`, `AxialisFolders.reg`, `AxialisInternetAccess.reg` | Axialis' shared keys (`Customer Info`, `folders`, `Internet Access`), when IconWorkshop writes them | The same |
| `Data\IconWorkshop` | Templates, color swatches and color tables | Moved to `%APPDATA%\Axialis\IconWorkshop` for the session |
| `Data\Axialis` | Work files and preview files | Moved to `%LOCALAPPDATA%\Axialis` for the session |
| `Data\Axialis Librarian` | The Librarian's icons and objects | Set as the Librarian's location for every launch |

When the package is started from another folder or drive letter, the paths in the saved settings (recent folders, for one) are updated, first those into the package, then, if the drive letter changed, the others on the same drive.

## What's journaled and undone

| Could be written | When IconWorkshop closes |
| --- | --- |
| `HKCU\Software\Axialis\IconWorkshop`, `Customer Info`, `folders`, `Internet Access` | Saved to `Data\settings`, then put back as they were: an installed IconWorkshop's settings and registration come back |
| `HKCU\Software\Axialis`, `%APPDATA%\Axialis` | Removed when left empty |

## If something goes wrong

If IconWorkshop Portable didn't close properly (a crash, a power cut, a USB drive pulled out), the next launch tells you and undoes what the last session changed. Start it again afterward. Settings changed in that session aren't saved.

When reporting a problem, please include an export of the `HKEY_CURRENT_USER\Software\pac-man\Journal` registry key and the contents of `%LOCALAPPDATA%\pac-man\Journal`, but not your `Data\settings` files, which hold your registration.

## Building from source

The launcher is built with the [PortableApps Compiler][PACMAN], and needs the MissingApp segment. Its configuration lives in `App\AppInfo`:

| File | Contents |
| --- | --- |
| `App\AppInfo\appinfo.ini` | Package details, version and file types. The launcher keeps the version current. |
| `App\AppInfo\Launcher\IconWorkshopPortable.ini` | The executable, the missing program check and the data folders |
| `App\AppInfo\Launcher\custom.nsh` | The registry settings, the Librarian, the language, the older layout, path updates and the version |

## Credits

* IconWorkshop is developed by [Axialis Software](https://www.axialis.com/).
* [PortableApps.com Platform](https://portableapps.com/download) by [PortableApps.com](https://portableapps.com/).
* [PortableApps Compiler][PACMAN] developed by daemon.devin.
