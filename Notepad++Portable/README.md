# Notepad++ Portable

A portable launcher for [Notepad++](https://notepad-plus-plus.org/), the source code and text editor, built with the [PortableApps Compiler][PACMAN] (PAC-MAN). It keeps Notepad++'s settings, sessions, themes, user defined languages, macros, backups and plugin settings in the package, follows the PortableApps.com Platform's language, installs Notepad++ from its GitHub releases on the first launch and keeps it up to date itself. Every change it makes to Windows is recorded first and undone when Notepad++ closes, or on the next launch if something went wrong.

Notepad++ is free software under the GNU GPL, by Don Ho and contributors. The package downloads Notepad++'s own, unmodified portable zips.

 [PACMAN]: https://github.com/daemondevin/pac-man

## System Requirements

* A Windows version the Notepad++ you add supports, with the build for it: x64 or ARM64 on 64-bit Windows, x86 on 32-bit Windows.
* An internet connection for the first launch and for updates, unless you add Notepad++ yourself.
* [PortableApps.com Platform](https://portableapps.com/download) (optional).

## First launch

The package doesn't include Notepad++. The first launch offers to download it:

1. It asks GitHub for Notepad++'s latest release (`notepad-plus-plus/notepad-plus-plus`).
2. It downloads that release's portable zip for your Windows: `npp.<version>.portable.x64.zip`, `.arm64.zip`, or `npp.<version>.portable.zip` on 32-bit Windows.
3. It checks the zip against the SHA-256 the release notes list for it, and checks that `notepad++.exe` carries a valid signature by **Notepad++** that Windows trusts. A download that fails a check is never used.
4. It unpacks the zip into `App\Notepad++` with Windows' own `tar.exe`, or with 7-Zip if `tar.exe` isn't there.

Then Notepad++ starts. If you say no, or something fails, nothing is left behind and the launcher stops.

### Adding Notepad++ yourself

You can also add Notepad++ without the launcher downloading it, for a computer that's offline, say:

1. Download Notepad++ as the **portable zip** from [notepad-plus-plus.org/downloads](https://notepad-plus-plus.org/downloads/): `npp.<version>.portable.x64.zip` for most computers.
2. Unpack it into this package's `App\Notepad++` folder, so `notepad++.exe` is `App\Notepad++\notepad++.exe`.
3. Start `Notepad++Portable.exe`.

If the build in `App\Notepad++` can't run on the computer (x64 on 32-bit Windows, or ARM64 on x64), the launcher says so and stops. After each session it writes the version of `notepad++.exe` to `appinfo.ini`, so the PortableApps.com Platform shows it.

## Updates

The launcher keeps Notepad++ up to date, the same way as the first install:

* Before Notepad++ starts, at most once every `UpdateInterval` days, it asks GitHub for the latest release. It stays with the build you have: a 32-bit Notepad++ is updated with the 32-bit zip.
* If there's a newer one, it asks whether to update now (`UpdateCheck=ask`), or just does it (`UpdateCheck=auto`). Say no and Notepad++ starts as it is; you're asked again at the next check.
* The new Notepad++ is downloaded, checked and unpacked as above, then swapped in. The plugins you installed (folders in `App\Notepad++\plugins` that Notepad++ doesn't come with) are moved into the new one; the plugins Notepad++ comes with are the new versions. The old folder is kept until the new one is in place, and the swap is journaled: if the launcher is stopped halfway, the next launch puts the old Notepad++ back.
* If anything fails, it says why and starts the Notepad++ you have.

Changes you made inside `App\Notepad++` itself (its `autoCompletion` or `functionList` files, say) don't carry over; your settings in `Data\Config` do.

Notepad++'s own updater stays off (`disableNppAutoUpdate.xml`): it downloads the installer, which would install Notepad++ into Program Files.

## Configuration

`Notepad++Portable.ini`, next to the launcher, holds the user settings. If it gets damaged, or you want to go back to the defaults, copy `Other\Source\Notepad++Portable.ini` over it.

```INI
[Notepad++Portable]
AdditionalParameters=
Language=
UpdateCheck=ask
UpdateInterval=1
```

| Key | Default | What it does |
| --- | --- | --- |
| `Language` | empty | Notepad++'s interface language, as its `localization` folder names the file, without `.xml`: `german`, `french`, `chineseSimplified`... Set, it's used on every launch. Empty follows the PortableApps.com Platform's language when that changes (see below). |
| `UpdateCheck` | `ask` | `ask` asks before updating, `auto` updates without asking, `off` never checks. |
| `UpdateInterval` | `1` | Days between update checks. `0` checks on every launch. |
| `AdditionalParameters` | empty | Extra command line switches passed to Notepad++, such as `-multiInst` or `-nosession`. |
| `ReleaseURL`, `DownloadURL` | GitHub's | Not in the file by default. Where the release information and the zips are downloaded from, for a mirror. |

### Language

Started from the PortableApps.com Platform, Notepad++'s language is set to the Platform's when the Platform's language is different from last time. A language you pick in Notepad++ (Settings > Preferences > General) stays until the Platform's language changes again. Started on its own, Notepad++ keeps the language you picked.

## Data

| Folder | Contents |
| --- | --- |
| `Data\Config` | Everything Notepad++ keeps for you: `config.xml`, `session.xml`, `shortcuts.xml` (macros and run commands), `stylers.xml`, `langs.xml`, `contextMenu.xml`, `nativeLang.xml`, `themes`, `userDefineLangs`, `functionList`, and `backup` (unsaved files, for session snapshots) |
| `Data\Config\plugins\config` | Plugin settings |
| `Data\Fonts` | Fonts you want Notepad++ to have wherever it runs. They're loaded for the session and removed afterward. |

How it's done:

* Notepad++ is started with `-settingsDir="Data\Config"`, which takes its settings and session there.
* `doLocalConf.xml` next to `notepad++.exe` keeps it out of `%APPDATA%\Notepad++`.
* With `doLocalConf.xml`, Notepad++ looks for themes next to `notepad++.exe` only, whatever `-settingsDir` says. Its cloud setting (`App\Notepad++\cloud\choice`) names `Data\Config` and makes it look there too. The launcher writes it for every launch, so it follows the package. Settings > Preferences > Cloud & Link shows that folder; changing it there has no effect.
* Plugins keep their settings in `App\Notepad++\plugins\Config` whatever the settings folder is. The launcher moves them in from `Data\Config\plugins\config` for each session and back afterward. Plugins Admin's list (`nppPluginList.dll`) comes with Notepad++ and stays where it is.
* When Plugins Admin installs a plugin, it closes Notepad++ and starts it again without `-settingsDir`. That Notepad++ saves its session next to `notepad++.exe`; the launcher waits for it and takes the session into `Data\Config`.

When the package is started from another folder or drive letter, the paths in `session.xml`, `config.xml` (recent files and folders, the Folder as Workspace roots), `shortcuts.xml` and the Explorer plugin's settings are updated, first those into the package, then, if the drive letter changed, the others on the same drive.

## What's journaled and undone

| Could be written | When Notepad++ closes |
| --- | --- |
| Settings > Preferences > File Association: extensions set to open with Notepad++, and its `Notepad++_file` type | Each extension gets its earlier file type back. This needs administrator rights, so the launcher only does it for `HKEY_LOCAL_MACHINE` when it runs as administrator. |
| Explorer's Open with entry (`HKCU\Software\Classes\Applications\notepad++.exe`) | Removed, or put back as it was |
| `%APPDATA%\Notepad++`, `%LOCALAPPDATA%\Notepad++`, if anything still used the defaults | Removed, if they weren't there before |
| Fonts in `Data\Fonts` | Unloaded |

## Coming from PortableApps.com's Notepad++ Portable

That package had a 32-bit Notepad++ in `App\Notepad++` and a 64-bit one in `App\Notepad++64`. It kept the settings in `Data\Config` (as this one does), and moved `Data\themes`, `Data\toolbarIcons` and the plugin settings next to `notepad++.exe` for each session.

Copy this package's files over your existing `Notepad++Portable` folder and compile the launcher. On 64-bit Windows, the first launch:

* moves `App\Notepad++` (the 32-bit one) to `App\Notepad++32`, and `App\Notepad++64` to `App\Notepad++`, with its plugins. Paths that pointed into `App\Notepad++64`, the Explorer plugin's NppExec folder for one, are updated.
* moves `Data\themes` and `Data\toolbarIcons` into `Data\Config`.
* puts the `nppPluginList.dll` copy it kept in `Data\Config\plugins\config` back with Notepad++, when Notepad++ doesn't have its own.

These are left from that package and not used any more; delete them when you like:

* `App\Notepad++32`, `App\DefaultData`, `App\DarkNpp.dll`
* `Data\plugins` and `Data\settings-backup` (from Notepad++ 6 and 7)
* `Data\backup`, `Data\Temp`, `Data\updater`, `Data\My Documents`
* `help.html`

## If something goes wrong

If Notepad++ Portable didn't close properly (a crash, a power cut, a USB drive pulled out), the next launch tells you and undoes what the last session changed. Plugin settings and a session left next to `notepad++.exe` are taken back into `Data` first. Start it again afterward.

When reporting a problem, please include an export of the `HKEY_CURRENT_USER\Software\pac-man\Journal` registry key and the contents of `%LOCALAPPDATA%\pac-man\Journal`.

## Building from source

The launcher is built with the [PortableApps Compiler][PACMAN], and needs the Fonts segment. Its configuration lives in `App\AppInfo`:

| File | Contents |
| --- | --- |
| `App\AppInfo\appinfo.ini` | Package details, version and file types. The launcher keeps the version current. |
| `App\AppInfo\Launcher\Notepad++Portable.ini` | The executable, the settings folder switch and the fonts |
| `App\AppInfo\Launcher\custom.nsh` | Install, updates, the settings folder, plugin settings, the session, the older layout, the language, path updates, the journal of Windows leftovers and the version |

## Credits

* Notepad++ is developed by [Don Ho](https://notepad-plus-plus.org/) and contributors.
* [PortableApps.com Platform](https://portableapps.com/download) by [PortableApps.com](https://portableapps.com/).
* [PortableApps Compiler][PACMAN] developed by daemon.devin.
