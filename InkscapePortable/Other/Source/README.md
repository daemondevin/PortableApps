# Inkscape Portable

A portable launcher for [Inkscape](https://inkscape.org/), the vector graphics editor, built with the [PortableApps Compiler][PACMAN] (pac-man). It keeps Inkscape's profile, GTK's user files and font cache in the package, adds portable fonts and Ghostscript, and follows the PortableApps.com Platform's language. Every change it makes to Windows is recorded first and undone when Inkscape closes, or on the next launch if something went wrong.

Inkscape is free software under the GNU GPL, by the Inkscape Project.

 [PACMAN]: https://github.com/daemondevin/pac-man

## System Requirements

* 64-bit Windows 10 or later. Inkscape has no 32-bit build any more.
* [PortableApps.com Platform](https://portableapps.com/download) (optional).

## Adding Inkscape

1. Download the Windows **7z archive** of Inkscape from [inkscape.org/release](https://inkscape.org/release/).
2. Unpack it, and copy the contents of its `inkscape` folder (`bin`, `etc`, `lib`, `share`...) into this package's `App\Inkscape`.
3. Start `InkscapePortable.exe`.

Until Inkscape is there, the launcher says what to do, offers to open the `App` folder, and stops. To update Inkscape, replace `App\Inkscape` with the new version's files the same way. After each session the launcher writes the version of `inkscape.exe` to `appinfo.ini`, so the PortableApps.com Platform shows it.

Inkscape's license lets you pass it on, so a copy of this package with `App\Inkscape` filled in can be shared (with the GPL's terms for its source, which inkscape.org provides).

## Configuration

`InkscapePortable.ini`, next to the launcher, holds the user settings. If it gets damaged, or you want to go back to the defaults, copy `Other\Source\InkscapePortable.ini` over it.

```INI
[InkscapePortable]
AdditionalParameters=
Language=
```

| Key | Default | What it does |
| --- | --- | --- |
| `Language` | empty | Inkscape's interface language, as its `share\locale` folder names it: `de`, `fr`, `pt_BR`, `zh_CN`... Set, it's used on every launch. Empty follows the PortableApps.com Platform's language when that changes (see below). |
| `AdditionalParameters` | empty | Extra command line switches passed to Inkscape. |

### Language

Started from the PortableApps.com Platform, Inkscape's language is set to the Platform's when the Platform's language is different from last time. A language you pick in Inkscape's preferences stays until the Platform's language changes again. Started on its own, Inkscape keeps the language set in its preferences.

## Data

Nothing has to be moved in and out for Inkscape: the launcher points it and GTK at folders in `Data` with environment variables.

| Folder | Contents | How |
| --- | --- | --- |
| `Data\Inkscape` | Inkscape's profile: preferences, keyboard shortcuts, extensions and palettes you add, templates, symbols, fonts collections | `INKSCAPE_PROFILE_DIR` |
| `Data\GLib\data` | GTK's recent files list | `XDG_DATA_HOME` |
| `Data\GLib\config` | GTK's settings, and your own fontconfig settings (`fontconfig\fonts.conf`) | `XDG_CONFIG_HOME` |
| `Data\GLib\cache` | The font cache and other caches | `XDG_CACHE_HOME`, and the fontconfig file below |
| `Data\Fonts` | Fonts you want Inkscape to have wherever it runs | the fontconfig file below |

For each launch the launcher writes `Data\GLib\fonts.conf` and points fontconfig at it (`FONTCONFIG_FILE`). It loads Inkscape's own font configuration, adds the fonts in `Data\Fonts` and in the PortableApps.com Platform's `PortableApps.com\Data\Fonts`, and keeps the font cache in `Data\GLib\cache` rather than `%LOCALAPPDATA%\fontconfig`. Don't edit that file; it's rewritten every time.

When the package is started from another folder or drive letter, the paths in `preferences.xml` (recent folders, symbol sets, templates) and in the recent files list are updated, first those into the package, then, if the drive letter changed, the others on the same drive.

## Ghostscript

Inkscape needs Ghostscript to import PostScript (`.ps`) and EPS files. The launcher uses the first one it finds:

1. [Ghostscript Portable](https://portableapps.com/apps/utilities/ghostscript_portable) in the PortableApps.com Platform's `CommonFiles\Ghostscript`.
2. A Ghostscript you put in this package's `App\Ghostscript` (with its `bin` and `lib` folders).
3. An installed Ghostscript.

Its `bin` and `lib` folders go on the `PATH` for Inkscape, and `GSC` names its console program, which Ghostscript's `ps2pdf` runs.

## Python

Inkscape's extensions run on the Python that comes with Inkscape. If an installed Python has set `PYTHONHOME` or `PYTHONPATH`, they'd make that Python's library get in the way, so the launcher clears both for Inkscape.

## What's journaled and undone

| Could be written | When Inkscape closes |
| --- | --- |
| `%APPDATA%\inkscape`, `%LOCALAPPDATA%\fontconfig`, `%LOCALAPPDATA%\gtk-3.0`, `%LOCALAPPDATA%\recently-used.xbel` (if anything still used the defaults) | Removed, if they weren't there before |
| `HKCU\Software\GPL Ghostscript` | Removed, or put back as it was |

## Coming from PortableApps.com's Inkscape Portable

That package kept the profile in `Data\settings` (with its launcher's settings), the recent files list in `Data` and the font cache in `Data\fontconfig`, and moved them into place for each session. The first launch of this one moves them once:

* the profile from `Data\settings` to `Data\Inkscape` (the launcher's own `InkscapePortableSettings.ini` stays),
* `Data\recently-used.xbel` to `Data\GLib\data`, with the paths to files that were in `Data\settings` updated,
* the font cache to `Data\GLib\cache\fontconfig`.

`Data\01-portableapps.conf` isn't needed any more and is removed. Copy this package's files over your existing `InkscapePortable` folder and compile the launcher; `App\Inkscape` stays as it is.

## If something goes wrong

If Inkscape Portable didn't close properly (a crash, a power cut, a USB drive pulled out), the next launch tells you and undoes what the last session changed. Start it again afterward.

When reporting a problem, please include an export of the `HKEY_CURRENT_USER\Software\pac-man\Journal` registry key and the contents of `%LOCALAPPDATA%\pac-man\Journal`.

## Building from source

The launcher is built with the [PortableApps Compiler][PACMAN], and needs the MissingApp and XML segments. Its configuration lives in `App\AppInfo`:

| File | Contents |
| --- | --- |
| `App\AppInfo\appinfo.ini` | Package details, version and file types. The launcher keeps the version current. |
| `App\AppInfo\Launcher\InkscapePortable.ini` | The executable, the missing program check and the environment variables |
| `App\AppInfo\Launcher\custom.nsh` | The older layout, fonts, Ghostscript, Python, language, path updates, the journal and the version |

## Credits

* Inkscape is developed by the [Inkscape Project](https://inkscape.org/).
* [Ghostscript](https://www.ghostscript.com/) by Artifex Software.
* [PortableApps.com Platform](https://portableapps.com/download) by [PortableApps.com](https://portableapps.com/).
* [PortableApps Compiler][PACMAN] developed by daemon.devin.
