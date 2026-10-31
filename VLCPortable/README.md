# VLC Media Player Portable

A portable launcher for [VLC media player](https://www.videolan.org/vlc/), built with the [PortableApps Compiler][PACMAN] (pac-man). It keeps VLC's preferences, interface layout, recent media, media library, album art, extensions and skins in the package, keeps the language you pick there too, installs VLC from VideoLAN on the first launch and keeps it up to date itself. Every change it makes to Windows is recorded first and undone when VLC closes, or on the next launch if something went wrong.

VLC is free software under the GNU GPL (version 2 or later), by VideoLAN. The package downloads VideoLAN's own, unmodified zips.

 [PACMAN]: https://github.com/daemondevin/pac-man

## System Requirements

* Windows 7 or later.
* An internet connection for the first launch and for updates, unless you add VLC yourself.
* [PortableApps.com Platform](https://portableapps.com/download) (optional).

## First launch

The package doesn't include VLC. The first launch offers to download it:

1. It reads VideoLAN's release list (`download.videolan.org/pub/videolan/vlc/last/`) for the newest VLC: the 64-bit build (`win64`), or the 32-bit one (`win32`) on 32-bit Windows.
2. It downloads that release's zip (`vlc-<version>-win64.zip`).
3. It checks the zip against the SHA-256 VideoLAN publishes next to it (`vlc-<version>-win64.zip.sha256`), and checks that `vlc.exe` carries a valid signature by **VideoLAN** that Windows trusts. A download that fails a check is never used.
4. It unpacks the zip into `App\vlc` with Windows' own `tar.exe`, or with 7-Zip if `tar.exe` isn't there, and builds VLC's plugin cache (`vlc-cache-gen.exe`), so VLC doesn't scan all its plugins at every start.

Then VLC starts. If you say no, or something fails, nothing is left behind and the launcher stops.

### Adding VLC yourself

You can also add VLC without the launcher downloading it, for a computer that's offline, say:

1. Download VLC for Windows as the **zip** (in "Other Systems", or from [download.videolan.org](https://download.videolan.org/pub/videolan/vlc/last/win64/)).
2. Unpack it, and copy the contents of its `vlc-<version>` folder into this package's `App\vlc`, so `vlc.exe` is `App\vlc\vlc.exe`.
3. Start `VLCPortable.exe`.

After each session the launcher writes the version of `vlc.exe` to `appinfo.ini`, so the PortableApps.com Platform shows it.

## Updates

The launcher keeps VLC up to date, the same way as the first install:

* Before VLC starts, at most once every `UpdateInterval` days, it reads VideoLAN's release list. It stays with the build you have: a 32-bit VLC is updated with the 32-bit zip.
* If there's a newer VLC, it asks whether to update now (`UpdateCheck=ask`), or just does it (`UpdateCheck=auto`). Say no and VLC starts as it is; you're asked again at the next check.
* The new VLC is downloaded, checked and unpacked as above, then swapped in. Skins and Lua extensions you added to `App\vlc` (`skins`, `lua\extensions`...) that the new VLC doesn't come with are moved into it. The old folder is kept until the new one is in place, and the swap is journaled: if the launcher is stopped halfway, the next launch puts the old VLC back.
* If anything fails, it says why and starts the VLC you have.

While the launcher checks, VLC's own update notice is turned off (`--no-qt-updates-notif`): it offers VLC's installer, which would install VLC into Program Files. With `UpdateCheck=off` it's left as you set it in VLC.

VideoLAN's download server sends each download to a mirror near you. If downloads fail where you are, set `ReleaseURL` to a mirror of `pub/videolan/vlc/` that has the `last` folder.

## Configuration

`VLCPortable.ini`, next to the launcher, holds the user settings. If it gets damaged, or you want to go back to the defaults, copy `Other\Source\VLCPortable.ini` over it.

```INI
[VLCPortable]
AdditionalParameters=
Language=
UpdateCheck=ask
UpdateInterval=7
```

| Key | Default | What it does |
| --- | --- | --- |
| `Language` | empty | VLC's interface language, as its `locale` folder names it: `de`, `fr`, `pt_BR`, `zh_CN`... Set, it's used on every launch. Empty keeps the language you pick in VLC, and follows the PortableApps.com Platform's language when that changes (see below). |
| `UpdateCheck` | `ask` | `ask` asks before updating, `auto` updates without asking, `off` never checks. |
| `UpdateInterval` | `7` | Days between update checks. `0` checks on every launch. |
| `AdditionalParameters` | empty | Extra command line switches passed to VLC, such as `--fullscreen` or `--no-video-title-show`. |
| `ReleaseURL` | VideoLAN's | Not in the file by default. Where VLC's releases are downloaded from, for a mirror (the folder with `last` and the version folders in it). |

### Language

VLC keeps the language you pick (Tools > Preferences > Interface > Language) in the registry, `HKEY_CURRENT_USER\Software\VideoLAN\VLC`. The launcher keeps it in the package instead: it puts it there for the session, takes back what you picked when VLC closes, and puts the key back as it was (an installed VLC's language included).

Started from the PortableApps.com Platform, the language is set to the Platform's when the Platform's language is different from last time. A language you pick in VLC stays until the Platform's language changes again.

## Data

VLC keeps everything of yours in a folder named `portable` next to `vlc.exe` when there's one. The launcher moves `Data\VLC` there for each session and back afterward; a `portable` folder left there by a session that didn't close properly is taken back first.

| Folder | Contents |
| --- | --- |
| `Data\VLC` | `vlcrc` (preferences), `vlc\vlc-qt-interface.ini` (window layout, recent media, recent folders), `ml.xspf` (media library), `art` (album art), and the `lua` extensions and skins you install from VLC |
| `Data\dvdcss` | Keys of DVDs libdvdcss has played (`DVDCSS_CACHE`), so they play at once next time |
| `Data\aacs` | libaacs' Blu-ray key database (`KEYDB.cfg`, which you supply) and cache, moved to `%APPDATA%\aacs` for each session |

When the package is started from another folder or drive letter, the paths in `vlcrc` (snapshot and record folders, for example), in the recent media list and in the media library are updated, first those into the package, then, if the drive letter changed, the others on the same drive.

### Blu-ray menus

Blu-ray menus (BD-J) run on Java, which VLC loads into itself. An installed Java is found as usual. Without one, a portable Java in the PortableApps.com Platform's `CommonFiles` is used: `CommonFiles\Java64` for a 64-bit VLC, `CommonFiles\Java` for a 32-bit one.

## What's journaled and undone

| Could be written | When VLC closes |
| --- | --- |
| `HKCU\Software\VideoLAN` (the language) | Put back as it was |
| `%APPDATA%\vlc`, where VLC writes crash reports | Removed, if it wasn't there before |
| `%APPDATA%\aacs` | Moved back to `Data\aacs`; one that was there before comes back |

On Windows 8 and later, VLC's Preferences > Interface > Set up associations opens Windows' own Default Apps settings, which the package doesn't change. The PortableApps.com Platform can open media with VLC Portable through its own file types (`[Associations]` in `appinfo.ini`).

## Coming from PortableApps.com's VLC Portable

That package kept `vlcrc` and `ml.xspf` in `Data\settings` (with its launcher's settings) and moved `vlc-qt-interface.ini` next to `vlc.exe` for each session. The first launch of this one moves them into `Data\VLC`. `Data\dvdcss` and `Data\aacs` stay where they are.

Copy this package's files over your existing `VLCPortable` folder and compile the launcher; `App\vlc` stays as it is. `App\DefaultData` and `help.html` from that package aren't used any more and can be deleted.

## If something goes wrong

If VLC Portable didn't close properly (a crash, a power cut, a USB drive pulled out), the next launch tells you and undoes what the last session changed. Start it again afterward.

When reporting a problem, please include an export of the `HKEY_CURRENT_USER\Software\pac-man\Journal` registry key and the contents of `%LOCALAPPDATA%\pac-man\Journal`.

## Building from source

The launcher is built with the [PortableApps Compiler][PACMAN]. Its configuration lives in `App\AppInfo`:

| File | Contents |
| --- | --- |
| `App\AppInfo\appinfo.ini` | Package details, version and file types. The launcher keeps the version current. |
| `App\AppInfo\Launcher\VLCPortable.ini` | The executable, the DVD key cache and the Blu-ray key folder |
| `App\AppInfo\Launcher\custom.nsh` | Install, updates, the settings folder, the older layout, the language, Java, path updates, the journal of Windows leftovers and the version |

## Credits

* VLC is developed by [VideoLAN](https://www.videolan.org/) and its contributors.
* [PortableApps.com Platform](https://portableapps.com/download) by [PortableApps.com](https://portableapps.com/).
* [PortableApps Compiler][PACMAN] developed by daemon.devin.
