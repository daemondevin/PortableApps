# Opera Portable

A portable launcher for [Opera](https://www.opera.com/), built with the [PortableApps Compiler][PACMAN] (pac-man). It keeps your Opera user data in the package, installs Opera from Opera's server on the first launch and keeps it up to date itself. Every change it makes to Windows is recorded first and undone when Opera closes, or on the next launch if something went wrong.

Opera is a trademark of Opera Norway AS. This package isn't made or endorsed by Opera; it runs Opera's own, unmodified builds. Opera's license doesn't allow passing Opera on, which is why the package downloads it from Opera instead of including it, and using Opera means agreeing to [Opera's terms](https://legal.opera.com/terms).

 [PACMAN]: https://github.com/daemondevin/pac-man

## System Requirements

* Windows 10 or later.
* An internet connection for the first launch and for updates.
* [PortableApps.com Platform](https://portableapps.com/download) (optional).

## First launch

The package doesn't include Opera. The first launch offers to download it:

1. It reads Opera's release folder (`get.geo.opera.com/pub/opera/desktop`) and takes the newest version in it.
2. It downloads that version's installer: the 64-bit one on 64-bit Windows, the 32-bit one otherwise.
3. It checks the installer for a valid signature by **Opera Norway AS** that Windows trusts, and, when Opera publishes one next to the installer, against its SHA-256 checksum. A download that fails a check is never used.
4. It runs the installer in Opera's copy-only mode (`--copyonly=1`), into the package, with shortcuts, the default browser question and starting Opera afterward all turned off. Anything the installer registers anyway (an uninstall entry, a startup entry for Opera's assistant) is removed straight after.

Then Opera starts. If you say no, or something fails, nothing is left behind and the launcher stops.

## Updates

Opera's own updater (`App\Opera\autoupdate\opera_autoupdate.exe`) is set aside, renamed to `opera_autoupdate.exe.disabled`: it would update the package behind the launcher's back. The launcher does the updating instead, the same way as the first install:

* Before Opera starts, at most once every `UpdateInterval` days, it looks for a newer version in Opera's release folder.
* If there's one, it asks whether to update now (`UpdateCheck=ask`), or just does it (`UpdateCheck=auto`). Say no and Opera starts as it is; you're asked again after the interval.
* The new Opera is downloaded, checked and installed into a separate folder, then swapped in. The old folder is kept until the new one is in place, and the swap is journaled: if the launcher is stopped halfway, the next launch puts the old Opera back.
* If anything fails, it says why and starts the Opera you have.

## Configuration

`OperaPortable.ini`, next to the launcher, holds the user settings. If it gets damaged, or you want to go back to the defaults, copy `Other\Source\OperaPortable.ini` over it.

```INI
[OperaPortable]
AdditionalParameters=
UpdateCheck=ask
UpdateInterval=1
Language=
```

| Key | Default | What it does |
| --- | --- | --- |
| `UpdateCheck` | `ask` | `ask` asks before updating, `auto` updates without asking, `off` never checks. |
| `UpdateInterval` | `1` | Days between update checks. `0` checks on every launch. |
| `Language` | empty | Opera's interface language, as its `localization` folder names it: `de`, `fr`, `pt-BR`, `zh-CN`... Empty follows the PortableApps.com Platform's language when started from the Platform, and Opera's own setting otherwise. |
| `AdditionalParameters` | empty | Extra command line switches passed to Opera. |
| `ArchiveURL` | Opera's | Not in the file by default. A mirror of Opera's release folder. |

## Data

Opera starts with `--user-data-dir="Data\profile"` and `--no-default-browser-check`. Everything Opera keeps is in `Data\profile`: bookmarks, history, extensions and settings.

When the package is started from another folder or drive letter, the paths in the profile's `Preferences` (the download folder, for one) and the install folder Opera records in `App\Opera\installation_status.json` are updated.

> [!NOTE]
> Opera encrypts saved passwords and cookies with a key that Windows protects for your Windows account on that computer. On another computer they can't be read, and you'll need to sign in to websites again; Opera's own sync is the way to take passwords along.

## What Opera leaves in Windows, and how it's undone

| Opera writes | When Opera closes |
| --- | --- |
| `HKCU\Software\Opera Software` | Removed, or put back exactly as it was if you also have an installed Opera |
| `%APPDATA%\Opera Software` and `%LOCALAPPDATA%\Opera Software` | Removed, if they weren't there before |
| **Make default** in Opera's settings: its file types, browser registration and registered application entry | Removed. The launcher notes which Opera registrations exist before Opera starts and removes only the new ones; an installed Opera's stay. |

## Coming from PortableApps.com's Opera Portable

1. Copy this package's files over your existing `OperaPortable` folder, and compile the launcher.
2. A profile in `Data\profile\data` (where that package kept it) is moved up to `Data\profile` on the first launch.
3. `App\Opera` is used as it is until the next update replaces it.

Folders this package doesn't use can be deleted: `App\DefaultData`, and in `Other\Source` the files of PortableApps.com's launcher.

## If something goes wrong

If Opera Portable didn't close properly (a crash, a power cut, a USB drive pulled out), the next launch tells you and undoes what the last session changed. Start it again afterward.

When reporting a problem, please include an export of the `HKEY_CURRENT_USER\Software\pac-man\Journal` registry key and the contents of `%LOCALAPPDATA%\pac-man\Journal`.

## Building from source

The launcher is built with the [PortableApps Compiler][PACMAN]. Its configuration lives in `App\AppInfo`:

| File | Contents |
| --- | --- |
| `App\AppInfo\appinfo.ini` | Package details, version and file types. The launcher keeps the version current. |
| `App\AppInfo\Launcher\OperaPortable.ini` | The executable, the user data switch and the processes to wait for |
| `App\AppInfo\Launcher\custom.nsh` | Install, updates, language, path updates, the journal of Windows leftovers and the version |

## Credits

* Opera is developed by [Opera Norway AS](https://www.opera.com/).
* [PortableApps.com Platform](https://portableapps.com/download) by [PortableApps.com](https://portableapps.com/).
* [PortableApps Compiler][PACMAN] developed by daemon.devin.
