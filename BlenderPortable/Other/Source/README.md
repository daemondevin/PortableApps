# Blender Portable

A portable launcher for [Blender](https://www.blender.org/), the 3D creation suite, built with the [PortableApps Compiler][PACMAN] (PAC-MAN). It keeps Blender's preferences, startup file, add-ons, extensions and caches in the package, starts Blender without a console window, installs Blender from blender.org on the first launch and keeps it up to date itself. Every change it makes to Windows is recorded first and undone when Blender closes, or on the next launch if something went wrong.

Blender is free software under the GNU GPL, by the Blender Foundation. The package downloads Blender's own, unmodified portable zips.

 [PACMAN]: https://github.com/daemondevin/pac-man

## System Requirements

* 64-bit Windows 10 or later. Blender has no 32-bit build.
* An internet connection for the first launch and for updates, unless you add Blender yourself.
* About 2.5 GB free on the drive for an install or update.
* A graphics card and driver Blender supports (see [blender.org/download/requirements](https://www.blender.org/download/requirements/)).
* [PortableApps.com Platform](https://portableapps.com/download) (optional).

## First launch

The package doesn't include Blender. The first launch offers to download it:

1. It reads blender.org's release list (`download.blender.org/release`) and takes the newest version's folder, such as `Blender5.2`.
2. It downloads that folder's newest portable zip for your Windows (`blender-<version>-windows-x64.zip`, or `-arm64`).
3. It checks the zip against the SHA-256 blender.org publishes next to it (`blender-<version>.sha256`), and checks that `blender.exe` carries a valid signature by the **Blender Foundation** that Windows trusts. A download that fails a check is never used.
4. It unpacks the zip into `App\Blender` with Windows' own `tar.exe`, or with 7-Zip if `tar.exe` isn't there.

Then Blender starts. If you say no, or something fails, nothing is left behind and the launcher stops.

### Adding Blender yourself

You can also add Blender without the launcher downloading it, for a computer that's offline, say:

1. Download Blender for Windows as the **portable (.zip)** from [blender.org/download](https://www.blender.org/download/).
2. Unpack it into this package's `App` folder (or `App\Blender`).
3. Start `BlenderPortable.exe`.

The zip unpacks to a folder named like `blender-5.2.0-windows-x64`; the launcher moves it to `App\Blender` the first time, so you don't have to rename anything.

After each session the launcher writes the version of `blender.exe` to `appinfo.ini`, so the PortableApps.com Platform shows it.

Blender's license lets you pass it on, so a copy of this package with `App\Blender` filled in can be shared (with the GPL's terms for its source, which blender.org provides).

## Updates

The launcher keeps Blender up to date, the same way as the first install:

* Before Blender starts, at most once every `UpdateInterval` days, it looks for a newer Blender on blender.org: the newest release, or with `UpdateTrack=series` only the newest of the series you have (5.2.1 for 5.2.0, never 5.3). The series setting suits a long-term support (LTS) version.
* If there's a newer one, it asks whether to update now (`UpdateCheck=ask`), or just does it (`UpdateCheck=auto`). Say no and Blender starts as it is; you're asked again at the next check.
* The new Blender is downloaded, checked and unpacked as above, then swapped in. The old folder is kept until the new one is in place, and the swap is journaled: if the launcher is stopped halfway, the next launch puts the old Blender back.
* If anything fails, it says why and starts the Blender you have.

Your preferences, add-ons and extensions are in `Data`, so an update keeps them. A new series (5.2 to 5.3) uses them as they are; Blender's "Load previous version settings" isn't needed. Blender itself doesn't update on its own, so there's nothing in it to turn off.

## Configuration

`BlenderPortable.ini`, next to the launcher, holds the user settings. If it gets damaged, or you want to go back to the defaults, copy `Other\Source\BlenderPortable.ini` over it.

```INI
[BlenderPortable]
AdditionalParameters=
UpdateCheck=ask
UpdateInterval=7
UpdateTrack=latest
```

| Key | Default | What it does |
| --- | --- | --- |
| `UpdateCheck` | `ask` | `ask` asks before updating, `auto` updates without asking, `off` never checks. |
| `UpdateInterval` | `7` | Days between update checks. `0` checks on every launch. |
| `UpdateTrack` | `latest` | `latest` updates to the newest Blender; `series` stays on the series in use (5.2.x) and only takes its fixes. |
| `AdditionalParameters` | empty | Extra command line switches passed to Blender, such as `--factory-startup` or `--debug-gpu`. |
| `ReleaseURL` | blender.org's | Not in the file by default. The release list to download from, for a mirror of `download.blender.org/release`. |

The interface language, theme and everything else are set in Blender (Edit > Preferences) and kept in `userpref.blend`.

## Data

Blender is pointed at folders in `Data\Blender` with its `BLENDER_USER_*` variables. They're created before each launch: Blender ignores a variable that names a folder that doesn't exist and quietly uses `%APPDATA%` instead.

| Folder | Contents |
| --- | --- |
| `Data\Blender\config` | Preferences (`userpref.blend`), the startup file (`startup.blend`), bookmarks and recent files |
| `Data\Blender\scripts` | Add-ons, presets and startup scripts you install |
| `Data\Blender\extensions` | Extensions from the Extensions platform and their repositories |
| `Data\Blender\datafiles` | Your own fonts, color management and other data files |
| `Data\Blender\local` | Caches (asset library indexes, GPU shader caches), moved to `%LOCALAPPDATA%\Blender Foundation\Blender` for each session, since Blender has no variable for them |

When the package is started from another folder or drive letter, the paths in the bookmarks and recent files lists are updated, first those into the package, then, if the drive letter changed, the others on the same drive.

> [!NOTE]
> Paths saved inside `.blend` files (images, linked libraries, the render output) and inside `userpref.blend` (asset libraries, the temporary folder) aren't updated. Make them relative (File > External Data > Make Paths Relative) so a project keeps working wherever the package goes.

### Render output

Blender's default render output is `/tmp\`, which on Windows is `C:\tmp`. If a session creates `C:\tmp`, the launcher removes it again only while it's empty, so renders saved there are never deleted. To keep renders with your project, set the output in Output Properties to a relative path such as `//render\`.

## What's journaled and undone

| Could be written | When Blender closes |
| --- | --- |
| **Preferences > System > Register**: the `.blend` file type (`HKCU\Software\Classes\.blend`, `blender.<version>`, `blendfile`), Open with entries, and the thumbnail handler `BlendThumb.dll` (`HKCU\Software\Classes\CLSID\{D45F043D-...}`) | Removed, or put back as it was (an installed Blender's registration comes back) |
| `%APPDATA%\Blender Foundation`, if anything still used the defaults | Removed, if it wasn't there before |
| `%USERPROFILE%\.thumbnails`, the file browser's thumbnails | Removed, if it wasn't there before |
| `C:\tmp`, the default render output | Removed while it's empty, if it wasn't there before |

A portable Blender can't stay registered for `.blend` files from a drive that may not be there, which is why that lasts only while it runs.

## Coming from PortableApps.com's Blender Portable

That package kept Blender in `App\Blender64`, the user folders as `Data\user_config`, `user_scripts`, `user_extensions` and `user_datafiles`, and the caches in `Data\LocalAppDataBlender`. The first launch of this one moves them once:

* `App\Blender64` to `App\Blender`,
* `Data\user_*` to `Data\Blender\config`, `scripts`, `extensions` and `datafiles`,
* `Data\LocalAppDataBlender` to `Data\Blender\local`.

A `portable` folder in `App\Blender` (Blender's own portable mode, from 4.2 on) is moved into `Data\Blender` the same way. Copy this package's files over your existing `BlenderPortable` folder and compile the launcher; `App\Blender64` and `Data` stay as they are until the first launch.

## If something goes wrong

If Blender Portable didn't close properly (a crash, a power cut, a USB drive pulled out), the next launch tells you and undoes what the last session changed. Start it again afterward.

When reporting a problem, please include an export of the `HKEY_CURRENT_USER\Software\pac-man\Journal` registry key and the contents of `%LOCALAPPDATA%\pac-man\Journal`.

## Building from source

The launcher is built with the [PortableApps Compiler][PACMAN]. Its configuration lives in `App\AppInfo`:

| File | Contents |
| --- | --- |
| `App\AppInfo\appinfo.ini` | Package details, version and file types. The launcher keeps the version current. |
| `App\AppInfo\Launcher\BlenderPortable.ini` | The executable, the user folder variables and the cache folder |
| `App\AppInfo\Launcher\custom.nsh` | Install, updates, adding Blender yourself, the older layout, the user folders, path updates, the journal of Windows leftovers and the version |

## Credits

* Blender is developed by the [Blender Foundation](https://www.blender.org/) and its community.
* [PortableApps.com Platform](https://portableapps.com/download) by [PortableApps.com](https://portableapps.com/).
* [PortableApps Compiler][PACMAN] developed by daemon.devin.
