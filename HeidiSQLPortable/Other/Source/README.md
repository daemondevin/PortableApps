# HeidiSQL Portable

A portable launcher for [HeidiSQL](https://www.heidisql.com/), the client for MariaDB, MySQL, Microsoft SQL Server, PostgreSQL, SQLite and Interbase/Firebird, built with the [PortableApps Compiler][PACMAN] (PAC-MAN). It runs HeidiSQL in its own portable mode, with your sessions, settings, snippets and query tab backups kept in the package, keeps HeidiSQL up to date from GitHub, and leaves nothing behind on the computer.

 [PACMAN]: https://github.com/daemondevin/pac-man

## License

HeidiSQL is free software by Ansgar Becker, under the GNU General Public License version 2 (see `App\HeidiSQL\gpl.txt` and `App\HeidiSQL\license.txt`). The package includes HeidiSQL 12.22 (64-bit) from the official portable zip, and can be shared freely.

## System Requirements

* 64-bit Windows (HeidiSQL's portable build is 64-bit only).
* [PortableApps.com Platform](https://portableapps.com/download) (optional).

## Data

HeidiSQL's portable mode keeps everything in files next to `heidisql.exe`, never in the registry or `%APPDATA%`. The launcher keeps those files in `Data`:

| In `Data` | Contents | How |
| --- | --- | --- |
| `settings\portable_settings.txt` | Sessions (hosts, users, passwords, SSH tunnels), preferences, window layout, query history | Named with `--psettings`, so HeidiSQL uses it where it is |
| `settings\tabs.ini` | The query tabs open when HeidiSQL closed (with "Restore tabs" on) | Moved next to `heidisql.exe` for the session |
| `Backups` | The contents of those tabs, including unsaved queries | Moved for the session |
| `Snippets` | Your SQL snippets | Moved for the session |
| `Logs` | SQL logs written with a session's "Log to file" option | Moved for the session |
| `Sessionlogs` | Session logs, when you turn them on in Preferences > Logging | Moved for the session |
| `Highlighters` | Custom editor color schemes | Moved for the session |

> [!WARNING]
> `portable_settings.txt` holds the passwords of sessions that save them. HeidiSQL only obscures them; it doesn't encrypt them. Treat the package like the passwords it holds, and turn on "Prompt for credentials" for sessions whose passwords shouldn't travel.

When the package is started from another folder or drive letter, the paths in `portable_settings.txt` and `tabs.ini` (SQLite files, private keys, log folders, a custom snippets folder) are updated. Paths into the package are updated first, then other paths on the same drive.

### Settings from another HeidiSQL

* **A portable HeidiSQL:** copy its `portable_settings.txt` (and `tabs.ini`, `Snippets`, `Backups` if you want them) into this package's `App\HeidiSQL`, next to `heidisql.exe`. The next launch moves them into `Data`. This only happens while `Data` has none of its own; to replace existing settings, delete `Data\settings\portable_settings.txt` first.
* **An installed HeidiSQL:** in it, use File > Export settings file, then in HeidiSQL Portable use File > Import settings file (or "Import settings file" in the session manager).

## While HeidiSQL runs

Portable HeidiSQL reads its settings file into a registry key of its own, `HKCU\Software\HeidiSQL Portable <process ID>`. It writes the settings back to the file and deletes that key when it closes.

If HeidiSQL crashes, the key stays behind, and changes since the start of that session are lost (HeidiSQL only saves on exit). After each session the launcher deletes any such key whose process is no longer running. Keys of a HeidiSQL that's still running are left alone.

HeidiSQL writes nothing else to the computer. It doesn't register file types.

## Updates

The launcher keeps HeidiSQL up to date from its [GitHub releases](https://github.com/HeidiSQL/HeidiSQL/releases):

1. Before HeidiSQL starts, at most every `UpdateInterval` days, it asks GitHub for the latest release. Previews and nightly builds aren't offered.
2. If that release is newer than the HeidiSQL in the package, it asks whether to update now (`UpdateCheck=ask`), or just does it (`UpdateCheck=auto`). Say no and HeidiSQL starts as it is; you're asked again at the next check.
3. It downloads the release's 64-bit portable zip (about 30 MB) and checks it against the SHA-256 checksum GitHub records for it. A download that doesn't match is never used.
4. It unpacks the zip with Windows' own `tar.exe` (Windows 10 1803 and later) or 7-Zip (installed, or 7-Zip Portable next to this package).
5. It checks that `heidisql.exe` carries a valid signature by **Ansgar Becker**, HeidiSQL's author, that Windows trusts, and that it's the version on offer.
6. It swaps the new HeidiSQL into `App\HeidiSQL`. The old folder is kept until the new one is in place, and the swap is journaled: if the launcher is stopped halfway, the next launch puts the old HeidiSQL back. Translations you added (`App\HeidiSQL\locale`) are carried over.

If anything fails, it says why and starts the HeidiSQL you have. Your settings and files are in `Data` the whole time, so an update never touches them.

A package without `App\HeidiSQL\heidisql.exe` offers to download HeidiSQL the same way on its first launch, so the package can also be passed on without HeidiSQL in it.

HeidiSQL's own update check (Help > Check for updates) still works. A nightly build it installs replaces `heidisql.exe` in place, and the launcher only offers a release that's newer than that build.

After each session the launcher writes the version of `heidisql.exe` to `appinfo.ini`, so the PortableApps.com Platform shows it.

## Configuration

`HeidiSQLPortable.ini`, next to the launcher, holds the user settings. If it gets damaged, copy `Other\Source\HeidiSQLPortable.ini` over it.

```INI
[HeidiSQLPortable]
AdditionalParameters=
UpdateCheck=ask
UpdateInterval=7
```

| Key | Default | What it does |
| --- | --- | --- |
| `UpdateCheck` | `ask` | `ask` asks before updating, `auto` updates without asking, `off` never checks. |
| `UpdateInterval` | `7` | Days between update checks. `0` checks on every launch. |
| `AdditionalParameters` | empty | Extra command line arguments passed to HeidiSQL, such as `-d=<session>` to open a session, or a `.sql` file to open. |
| `ReleaseURL` | GitHub's | Not in the file by default. Where to ask for the latest release, for a mirror that answers like GitHub's API. Download links from it are trusted as given; without it, only `https://github.com/` downloads are used. |

## If something goes wrong

If HeidiSQL Portable didn't close properly (a crash, a power cut, a USB drive pulled out), the next launch tells you, moves the folders back into `Data` and removes HeidiSQL's leftover registry key. Start it again afterward.

## Building from source

The launcher is built with the [PortableApps Compiler][PACMAN]. Its configuration lives in `App\AppInfo`:

| File | Contents |
| --- | --- |
| `App\AppInfo\appinfo.ini` | Package details and version. The launcher keeps the version current. Needs `[Dependencies] FileWriteReplace=true` for the path updates. |
| `App\AppInfo\Launcher\HeidiSQLPortable.ini` | The executable and `--psettings`, the folders and `tabs.ini` moved in and out, and the path updates |
| `App\AppInfo\Launcher\custom.nsh` | Install and updates from GitHub, creating the settings file, adopting settings from a plain portable HeidiSQL, removing leftover registry keys, and the version |

## Credits

* HeidiSQL is developed by [Ansgar Becker](https://www.heidisql.com/) and contributors.
* [PortableApps.com Platform](https://portableapps.com/download) by [PortableApps.com](https://portableapps.com/).
* [PortableApps Compiler][PACMAN] developed by daemon.devin.
