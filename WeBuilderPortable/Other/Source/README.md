# WeBuilder Portable

A portable launcher for [WeBuilder](https://www.webuilderapp.com/), the all-in-one code editor by Karlis Blumentals, built with the [PortableApps Compiler][PACMAN] (pac-man).

WeBuilder is commercial software. The package doesn't include or handle a licence: register WeBuilder with your own licence from inside WeBuilder.

 [PACMAN]: https://github.com/daemondevin/pac-man

## System Requirements

* Windows 10 or later.
* No administrator rights. WeBuilder runs with your normal rights, so dragging files into it from Explorer works.
* `Data` on a local drive (a USB drive is fine; a network share isn't).
* [PortableApps.com Platform](https://portableapps.com/download) (optional).

## Configuration

`WeBuilderPortable.ini`, next to the launcher, holds the user settings. If it gets damaged, or you want to go back to the defaults, copy `Other\Source\WeBuilderPortable.ini` over it.

```INI
[WeBuilderPortable]
AdditionalParameters=
DisableSplashScreen=false
Firefox=
Chrome=
Opera=
DiffTool=
```

| Key | Default | What it does |
| --- | --- | --- |
| `Firefox`, `Chrome`, `Opera` | empty | Browsers WeBuilder previews pages in, for example `%PAL:PortableAppsDir%\FirefoxPortable\FirefoxPortable.exe`. |
| `DiffTool` | empty | The file compare tool, with `%file1` and `%file2` where the two files go. |
| `AdditionalParameters` | empty | Extra command line switches passed to WeBuilder. |
| `DisableSplashScreen` | `false` | Don't show the launcher's splash screen. |

The tool settings are written to WeBuilder's settings each time it starts, with `%PAL:...%` variables expanded, so they follow the drive the package is on. Leave one empty to keep what's set in WeBuilder itself.

## Data

WeBuilder runs in portable mode when `App\WeBuilder\settings` exists, and keeps all its settings there. While it runs, that folder is an NTFS junction to `Data\config`, so nothing is copied back and forth; the junction is removed when WeBuilder closes, or on the next launch if something went wrong.

Earlier packages moved the settings folder in and out of `Data\config`. If one of them left `App\WeBuilder\settings` behind after a crash, the first launch moves it into `Data\config` and keeps the previous `Data\config` as `Data\config.old`.

> [!IMPORTANT]
> Junctions can only point to a local drive. Running from a network share isn't supported.

## Building from source

The launcher is built with the [PortableApps Compiler][PACMAN]. Its configuration lives in `App\AppInfo`:

| File | Contents |
| --- | --- |
| `App\AppInfo\AppInfo.ini` | Package details and version |
| `App\AppInfo\Launcher\WeBuilderPortable.ini` | The launcher configuration: the settings link and the section the tool settings go to |
| `App\AppInfo\Launcher\custom.nsh` | The tool settings and taking over earlier packages' settings |

## Credits

* WeBuilder is developed by [Karlis Blumentals](https://www.webuilderapp.com/).
* [PortableApps.com Platform](https://portableapps.com/download) by [PortableApps.com](https://portableapps.com/).
* [PortableApps Compiler][PACMAN] developed by daemon.devin.
