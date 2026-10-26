# O&O RegEditor Portable

A portable launcher for [O&O RegEditor](https://www.oo-software.com/en/ooregeditor), O&O Software's free registry editor: full-text search with a results list, favorites, an address bar that takes pasted key paths, and copying and moving of whole keys. It's built with the [PortableApps Compiler][PACMAN] (pac-man). Every change it makes to Windows is recorded first and undone when O&O RegEditor closes, or on the next launch if something went wrong.

O&O RegEditor isn't included: O&O's license only allows it to be passed on unmodified and on its own, and counts packaging it in an installer or wrapper as a modification. You add it yourself, once (see [Adding O&O RegEditor](#adding-oo-regeditor)).

 [PACMAN]: https://github.com/daemondevin/pac-man

## System Requirements

* Windows Vista or later, 32-bit or 64-bit (O&O RegEditor 12).
* Administrator rights. O&O RegEditor is built to always run as an administrator, so the launcher asks for them (UAC) every time.
* [PortableApps.com Platform](https://portableapps.com/download) (optional).

## Adding O&O RegEditor

1. Download O&O RegEditor from [oo-software.com](https://www.oo-software.com/en/ooregeditor).
2. Extract or copy its program files into this package's `App\OORegEditor` folder: `OORegEdt.exe`, `OORegEdt32.exe`, and the `en` and `de` folders.
3. Start `O&ORegEditorPortable.exe`.

Until the program is there, the launcher says which folder to copy and where, offers to open the `App` folder, and stops. On 64-bit Windows it starts `OORegEdt.exe`, the 64-bit edition, which sees the whole registry without WOW64 redirection; on 32-bit Windows it starts `OORegEdt32.exe`.

## Configuration

`O&ORegEditorPortable.ini`, next to the launcher, holds the user settings. If it gets damaged, or you want to go back to the defaults, copy `Other\Source\O&ORegEditorPortable.ini` over it.

```INI
[O&ORegEditorPortable]
AdditionalParameters=
Language=auto
```

| Key | Default | What it does |
| --- | --- | --- |
| `Language` | `auto` | `en` or `de` sets the language. `auto` follows the PortableApps.com Platform's language when started from the Platform (German for German, English for everything else), and otherwise leaves the choice to O&O RegEditor, which goes by the system locale. |
| `AdditionalParameters` | empty | Extra command line switches passed to O&O RegEditor. |

O&O RegEditor has no language setting of its own: it uses the language whose folder is there. To set one, the launcher renames the other folder (`de` becomes `de.off`) for the session and puts it back when O&O RegEditor closes.

## Data

O&O RegEditor keeps every setting in `OORegEdt.ini` next to the program, shared by both editions: the window and toolbar layout, favorites, the address bar history and the last key opened. It's kept in `Data\OORegEdt.ini` and moved into place while O&O RegEditor runs.

If O&O RegEditor was started without the launcher, its `OORegEdt.ini` is left in `App\OORegEditor`. The next launch takes it into `Data`, or, if `Data` already has one, keeps it as `Data\OORegEdt.found.ini`, so neither is lost.

## What O&O RegEditor changes, and how it's undone

| O&O RegEditor changes | Put back when it closes |
| --- | --- |
| **Always open .REG files with O&O RegEditor**: the default value of `.reg` in `HKLM\SOFTWARE\Classes` (or `HKCU\Software\Classes` if you have your own `.reg` entry there) | Put back exactly as it was, normally `regfile` |
| The `OOREGEDIT.Document` file type it registers for that, in the same places | Removed, or put back as it was |
| The `de` or `en` folder set aside for the language (see above) | Put back |

Explorer can't open a `.reg` file with a program on a drive that isn't there, which is why the association only lasts while O&O RegEditor runs. To open `.reg` files with it from the PortableApps.com Platform, use the Platform's own file type associations.

Everything you change *in the registry with O&O RegEditor* is, of course, not undone: that's what a registry editor is for. Export a key before changing it.

## Updates

O&O RegEditor doesn't update itself; **Check for updates** opens O&O's website. Replace the program files in `App\OORegEditor` with the new ones. After each session the launcher writes O&O RegEditor's product version (for example 12.0.2172) to `appinfo.ini`, so the PortableApps.com Platform shows the version that was added.

## Coming from another O&O RegEditor Portable

A package that kept `OORegEdt.ini` in `Data` and the program in `App\ooregeditor` carries over as it is: copy this package's files over the existing folder and compile the launcher. Folder names in Windows don't depend on case, so `App\ooregeditor` is `App\OORegEditor`.

## If something goes wrong

If O&O RegEditor Portable didn't close properly (a crash, a power cut, a USB drive pulled out), the next launch tells you and undoes what the last session changed. Start it again afterward.

When reporting a problem, please include an export of the `HKEY_CURRENT_USER\Software\pac-man\Journal` registry key and the contents of `%LOCALAPPDATA%\pac-man\Journal`.

## Building from source

The launcher is built with the [PortableApps Compiler][PACMAN], and needs the MissingApp segment. Its configuration lives in `App\AppInfo`:

| File | Contents |
| --- | --- |
| `App\AppInfo\appinfo.ini` | Package details, version and file types. The launcher keeps the version current. |
| `App\AppInfo\Launcher\O&ORegEditorPortable.ini` | The executables, administrator rights, the missing program check and the settings file |
| `App\AppInfo\Launcher\custom.nsh` | Settings adoption, the `.reg` association, language and the version |

## Credits

* O&O RegEditor is developed by [O&O Software GmbH](https://www.oo-software.com/). The package icons are O&O RegEditor's own, taken from `OORegEdt.exe`.
* [PortableApps.com Platform](https://portableapps.com/download) by [PortableApps.com](https://portableapps.com/).
* [PortableApps Compiler][PACMAN] developed by daemon.devin.
