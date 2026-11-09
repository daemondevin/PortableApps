# LYNX SHARE Portable

A portable launcher for [LYNX SHARE](https://github.com/Ka1-S/LYNX-SHARE), the lightweight digital audio workstation with the FL Studio workflow, built with the [PortableApps Compiler][PACMAN] (PAC-MAN). It keeps everything LYNX SHARE writes in the package, keeps LYNX SHARE up to date from its GitHub releases, and leaves nothing behind on the computer.

 [PACMAN]: https://github.com/daemondevin/pac-man

## License

LYNX SHARE is free software by Ka1-S, under the GNU Affero General Public License version 3 (see `App\LYNX\LICENSE`, and `App\LYNX\THIRD_PARTY.md` for the libraries it uses). Its source code is at [github.com/Ka1-S/LYNX-SHARE](https://github.com/Ka1-S/LYNX-SHARE). The package includes LYNX SHARE 0.1.21-alpha, unmodified, from the official Windows zip (its SHA-256 matches the release's `SHA256SUMS.txt`), and can be shared freely.

LYNX SHARE is alpha software: it opens, plays and exports whole projects, but its author doesn't yet recommend it as a daily-driver DAW.

## System Requirements

* 64-bit Windows 10 or later.
* [PortableApps.com Platform](https://portableapps.com/download) (optional).

## Data

LYNX SHARE can keep all of its files in one folder of your choice, named by its `LYNX_PROFILE_DIR` setting. The launcher sets it to `Data\Profile`, so nothing goes to `%APPDATA%\LYNX` or `Documents\LYNX` on the computer:

| In `Data\Profile` | Contents |
| --- | --- |
| `LYNX` | Settings (language, theme, preferences), the plugin list and scan files, update settings, autosaves and recovered projects, crash and freeze reports |
| `LYNX\Plugins` | LYNX SHARE's own plugin folder. Plugins you put here travel with the package |
| `LYNX\Presets` | Your presets |
| `Documents\LYNX` | Templates, mixer states and the other files LYNX SHARE keeps in Documents |
| `cache` | Waveform and other rebuildable caches |

Projects (`.lynx`) and exports go wherever you save them. A `Projects` folder next to `App` and `Data` keeps them with the package.

Plugins in the computer's standard folders (`Common Files\VST3`, `Common Files\CLAP` and so on) are found and used, but they stay on that computer. When the package is started from another drive letter, paths LYNX SHARE stored (recent projects, plugins in `LYNX\Plugins`) point at the old letter; rescan plugins in LYNX SHARE's settings if they're missing.

LYNX SHARE also creates an empty `%APPDATA%\LYNX` folder when it starts, even with its profile elsewhere. The launcher removes it again afterward, unless it was there before.

### Project files

While LYNX SHARE runs, it registers `.lynx` project files for the current user (`HKCU\Software\Classes\.lynx` and `LYNX.Project`), so they open in it. When it closes, those keys are removed, or put back as they were if the computer had them. Through the PortableApps.com Platform, `.lynx` files can be associated with LYNX SHARE Portable instead.

### LYNX ASIO

`App\LYNX` contains LYNX ASIO (`lynx-asio.dll`) and two batch files that register it, so other programs can list LYNX SHARE as an ASIO driver. LYNX SHARE itself doesn't need it, and the launcher doesn't register it. Registering it from the package writes the package's path into the computer's ASIO driver list (it needs administrator rights) and leaves it there; if you do, run `Unregister LYNX ASIO.bat` before you take the package away.

## Updates

The launcher keeps LYNX SHARE up to date from its [GitHub releases](https://github.com/Ka1-S/LYNX-SHARE/releases):

1. Before LYNX SHARE starts, at most every `UpdateInterval` days, it asks GitHub for the list of LYNX SHARE releases. Every release so far is a pre-release, so the newest release is taken, pre-release or not.
2. If that release is newer than the LYNX SHARE in the package, it asks whether to update now (`UpdateCheck=ask`), or just does it (`UpdateCheck=auto`). Say no and LYNX SHARE starts as it is; you're asked again at the next check.
3. It downloads the release's `SHA256SUMS.txt`, then its Windows zip (about 17 MB), and checks the zip against the SHA-256 listed there, and against the one GitHub records for the zip when there is one. A download that doesn't match, or a release without a checksum for it, is never used. LYNX SHARE isn't code-signed yet, so the checksums are the check.
4. It unpacks the zip with Windows' own `tar.exe` (Windows 10 1803 and later) or 7-Zip (installed, or 7-Zip Portable next to this package), and checks that `LYNX.exe` is the version on offer.
5. It swaps the new LYNX SHARE into `App\LYNX`. The old folder is kept until the new one is in place, and the swap is journaled: if the launcher is stopped halfway, the next launch puts the old LYNX SHARE back.

If anything fails, it says why and starts the LYNX SHARE you have. Everything LYNX SHARE writes is in `Data` the whole time, so an update never touches it.

A package without `App\LYNX\LYNX.exe` offers to download LYNX SHARE the same way on its first launch.

While the launcher does the updating, LYNX SHARE's own automatic update check (Settings › General › Updates) is turned off, because its Update button only saves the zip for a portable build. *Help › Check for updates…* still shows what's new. With `UpdateCheck=off`, the launcher leaves LYNX SHARE's own setting alone.

After each update the launcher writes the version to `appinfo.ini` (`0.1.21-alpha`), so the PortableApps.com Platform shows it. A build you copy into `App\LYNX` yourself is picked up after the session.

## Configuration

`LYNXSHAREPortable.ini`, next to the launcher, holds the user settings. If it gets damaged, copy `Other\Source\LYNXSHAREPortable.ini` over it.

```INI
[LYNXSHAREPortable]
AdditionalParameters=
UpdateCheck=ask
UpdateInterval=1
```

| Key | Default | What it does |
| --- | --- | --- |
| `UpdateCheck` | `ask` | `ask` asks before updating, `auto` updates without asking, `off` never checks (LYNX SHARE's own check then works as usual). |
| `UpdateInterval` | `1` | Days between update checks. `0` checks on every launch. New releases come often during the alpha. |
| `AdditionalParameters` | empty | Extra command line arguments passed to LYNX SHARE, such as a project to open. |
| `ReleaseURL` | GitHub's | Not in the file by default. Where to ask for the release list, for a mirror that answers like GitHub's API. Download links from it are trusted as given; without it, only `https://github.com/` downloads are used. |

## If something goes wrong

If LYNX SHARE Portable didn't close properly (a crash, a power cut, a USB drive pulled out), the next launch puts back the `.lynx` registration and removes the leftover folder first. LYNX SHARE itself offers to recover your project from its autosave, and to send a crash report (only if you agree).

When reporting a problem with the launcher, please include an export of the `HKEY_CURRENT_USER\Software\pac-man\Journal` registry key and the contents of `%LOCALAPPDATA%\pac-man\Journal`. Problems with LYNX SHARE itself go to its [issue tracker](https://github.com/Ka1-S/LYNX-SHARE/issues).

## Building from source

The launcher is built with the [PortableApps Compiler][PACMAN], with the Registry segment. Its configuration lives in `App\AppInfo`:

| File | Contents |
| --- | --- |
| `App\AppInfo\appinfo.ini` | Package details, version and the `.lynx` file type. The launcher keeps the version current. |
| `App\AppInfo\Launcher\LYNXSHAREPortable.ini` | The executable, `LYNX_PROFILE_DIR` and the `.lynx` registration |
| `App\AppInfo\Launcher\custom.nsh` | Install and updates from GitHub, turning LYNX SHARE's own update check off, the `%APPDATA%\LYNX` leftover, and the version |

## Credits

* LYNX SHARE is developed by [Ka1-S](https://github.com/Ka1-S).
* [PortableApps.com Platform](https://portableapps.com/download) by [PortableApps.com](https://portableapps.com/).
* [PortableApps Compiler][PACMAN] developed by daemon.devin.
