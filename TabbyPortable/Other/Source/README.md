# Tabby Portable

A portable launcher for [Tabby](https://tabby.sh/), the terminal, SSH, serial and Telnet client, built with the [PortableApps Compiler][PACMAN] (pac-man). It keeps Tabby's settings, profiles and plugins in the package, installs Tabby from its GitHub releases on the first launch and keeps it up to date itself. Every change it makes to Windows is recorded first and undone when Tabby closes, or on the next launch if something went wrong.

Tabby is open source ([MIT license](https://github.com/Eugeny/tabby/blob/master/LICENSE)) by Eugene Pankov and contributors. The package downloads Tabby's own, unmodified portable builds.

 [PACMAN]: https://github.com/daemondevin/pac-man

## System Requirements

* 64-bit Windows 10 or later (x64 or ARM64). Tabby has no 32-bit build.
* An internet connection for the first launch and for updates.
* [PortableApps.com Platform](https://portableapps.com/download) (optional).

## First launch

The package doesn't include Tabby. The first launch offers to download it:

1. It asks GitHub for Tabby's latest release (`Eugeny/tabby`).
2. It downloads that release's portable zip for your Windows (`tabby-<version>-portable-x64.zip`, or `-arm64`).
3. It checks the zip against the SHA-256 GitHub records for it, when GitHub gives one, and checks that `Tabby.exe` carries a valid signature by **syslink GmbH** (Tabby's publisher) that Windows trusts. A download that fails a check is never used.
4. It unpacks the zip into `App\Tabby` with Windows' own `tar.exe`, or with 7-Zip if `tar.exe` isn't there.

Then Tabby starts. If you say no, or something fails, nothing is left behind and the launcher stops.

## Updates

The launcher keeps Tabby up to date, the same way as the first install:

* Before Tabby starts, at most once every `UpdateInterval` days, it asks GitHub for the latest release.
* If there's a newer one, it asks whether to update now (`UpdateCheck=ask`), or just does it (`UpdateCheck=auto`). Say no and Tabby starts as it is; you're asked again after the interval.
* The new Tabby is downloaded, checked and unpacked as above, then swapped in. The old folder is kept until the new one is in place, and the swap is journaled: if the launcher is stopped halfway, the next launch puts the old Tabby back.
* If anything fails, it says why and starts the Tabby you have.

While the launcher checks for updates, Tabby's own update notice is turned off: `enableAutomaticUpdates: false` is set in Tabby's `config.yaml`. With `UpdateCheck=off` it's left as you set it in Tabby.

## Configuration

`TabbyPortable.ini`, next to the launcher, holds the user settings. If it gets damaged, or you want to go back to the defaults, copy `Other\Source\TabbyPortable.ini` over it.

```INI
[TabbyPortable]
AdditionalParameters=
UpdateCheck=ask
UpdateInterval=1
```

| Key | Default | What it does |
| --- | --- | --- |
| `UpdateCheck` | `ask` | `ask` asks before updating, `auto` updates without asking, `off` never checks. |
| `UpdateInterval` | `1` | Days between update checks. `0` checks on every launch. |
| `AdditionalParameters` | empty | Extra command line switches passed to Tabby. |
| `ReleaseURL`, `DownloadURL` | GitHub's | Not in the file by default. Where the release information and the zips are downloaded from, for a mirror. |

## Data

Tabby starts with `--user-data-dir="Data\Tabby"`, so everything it keeps is there: `config.yaml` (settings, profiles, saved connections), installed plugins, and its window state and logs.

When the package is started from another folder or drive letter, the paths in `config.yaml` (private key files and working folders you keep in the package, for example) are updated, first those into the package, then, if the drive letter changed, the others on the same drive.

> [!NOTE]
> `config.yaml` can name private key files elsewhere on the computer, such as `C:\Users\<you>\.ssh\id_ed25519`. Those keys aren't in the package and won't be there on another computer; keep the keys you need in the package (in `Data\Tabby`, say), or use Tabby's vault.

## What Tabby leaves in Windows, and how it's undone

| Tabby writes | When Tabby closes |
| --- | --- |
| **Settings > Shell integration**: "Open Tabby here" and "Paste path into Tabby" in Explorer's context menus (`HKCU\Software\Classes\...\shell\Tabby`) | Removed, or put back as it was |
| Run at startup (`Tabby` in `HKCU\...\CurrentVersion\Run`) | Removed, or put back as it was |
| `%APPDATA%\tabby` and `%LOCALAPPDATA%\tabby-updater` | Removed, if they weren't there before |

A portable Tabby can't stay in Explorer's menus or start with Windows from a drive that may not be there, which is why those last only while it runs.

## Coming from Tabby's own portable zip

If you unpacked Tabby's portable zip straight into this package's folder, Tabby's `data` folder is this package's `Data` folder: Windows doesn't tell `data` from `Data`. The first launch moves Tabby's files from there into `Data\Tabby`, and updates the paths in `config.yaml` that pointed into the old `data` folder. Then it downloads the current Tabby into `App\Tabby`.

## If something goes wrong

If Tabby Portable didn't close properly (a crash, a power cut, a USB drive pulled out), the next launch tells you and undoes what the last session changed. Start it again afterward.

When reporting a problem, please include an export of the `HKEY_CURRENT_USER\Software\pac-man\Journal` registry key and the contents of `%LOCALAPPDATA%\pac-man\Journal`.

## Building from source

The launcher is built with the [PortableApps Compiler][PACMAN]. Its configuration lives in `App\AppInfo`:

| File | Contents |
| --- | --- |
| `App\AppInfo\appinfo.ini` | Package details and version. The launcher keeps the version current. |
| `App\AppInfo\Launcher\TabbyPortable.ini` | The executable, the user data switch and the processes to wait for |
| `App\AppInfo\Launcher\custom.nsh` | Install, updates, adopting Tabby's own data folder, path updates, the journal of Windows leftovers and the version |

## Credits

* Tabby is developed by [Eugene Pankov](https://github.com/Eugeny/tabby) and contributors.
* [PortableApps.com Platform](https://portableapps.com/download) by [PortableApps.com](https://portableapps.com/).
* [PortableApps Compiler][PACMAN] developed by daemon.devin.
