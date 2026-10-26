# Google Chrome Portable

A portable launcher for [Google Chrome](https://www.google.com/chrome/), built with the [PortableApps Compiler][PACMAN] (PAC-MAN). It keeps your Chrome user data in the package, installs Chrome from Google on the first launch and keeps it up to date itself. Every change it makes to Windows is recorded first and undone when Chrome closes, or on the next launch if something went wrong.

Google and Chrome are trademarks of Google LLC. This package isn't made or endorsed by Google; it runs Google's own, unmodified Chrome builds, and using Chrome means agreeing to the [Google Terms of Service](https://policies.google.com/terms) and the [Chrome Additional Terms](https://www.google.com/chrome/terms/).

 [PACMAN]: https://github.com/daemondevin/pac-man

## System Requirements

* Windows 10 or later.
* An internet connection for the first launch and for updates.
* 7-Zip, to unpack Chrome: [7-Zip Portable](https://portableapps.com/apps/utilities/7-zip_portable) in the same folder as this package (`PortableApps\7-ZipPortable`), `7z.exe` and `7z.dll` in this package's `App\7-Zip`, or an installed 7-Zip.
* [PortableApps.com Platform](https://portableapps.com/download) (optional).

## First launch

The package doesn't include Chrome. The first launch offers to download it:

1. It asks Google's update server (`tools.google.com`, the server Chrome's own updater asks) for the current Chrome on your channel: the 64-bit build on 64-bit Windows, the 32-bit one otherwise.
2. It downloads that installer from Google and checks it twice: against the SHA-256 the update server gave for it, and for a valid signature by **Google LLC** that Windows trusts. A download that fails either check is never used.
3. It takes the Chrome archive out of the installer and unpacks it with 7-Zip into `App\Chrome-bin`. The installer itself never runs, so nothing is installed or registered.

Then Chrome starts. If you say no, or something fails, nothing is left behind and the launcher stops.

## Updates

A portable Chrome has no updater of its own (Google's updater is a separate, installed program), so the launcher does it, the same way as the first install:

* Before Chrome starts, at most once every `UpdateInterval` days, it asks Google's update server for the current version.
* If there's a newer one, it asks whether to update now (`UpdateCheck=ask`), or just does it (`UpdateCheck=auto`). Say no and Chrome starts as it is; you're asked again after the interval.
* The new Chrome is downloaded, checked and unpacked as above, then swapped in. The old folder is kept until the new one is in place, and the swap is journaled: if the launcher is stopped halfway, the next launch puts the old Chrome back.
* Spell checking dictionaries (`Chrome-bin\Dictionaries`) and an `initial_preferences` file are carried over.
* If anything fails, it says why and starts the Chrome you have.

## Configuration

`GoogleChromePortable.ini`, next to the launcher, holds the user settings. If it gets damaged, or you want to go back to the defaults, copy `Other\Source\GoogleChromePortable.ini` over it.

```INI
[GoogleChromePortable]
AdditionalParameters=
UpdateCheck=ask
UpdateChannel=stable
UpdateInterval=1
Language=
```

| Key | Default | What it does |
| --- | --- | --- |
| `UpdateCheck` | `ask` | `ask` asks before updating, `auto` updates without asking, `off` never checks. |
| `UpdateChannel` | `stable` | `stable`, `beta` or `dev`. |
| `UpdateInterval` | `1` | Days between update checks. `0` checks on every launch. |
| `Language` | empty | Chrome's interface language, as its `Locales` folder names it: `de`, `fr`, `pt-BR`, `zh-CN`... Empty follows the PortableApps.com Platform's language when started from the Platform, and Chrome's own setting otherwise. |
| `AdditionalParameters` | empty | Extra command line switches passed to Chrome. |
| `UpdateServer` | Google's | Not in the file by default. Another update server that speaks the same protocol. |

## Data

Chrome starts with `--user-data-dir="Data\profile"` and `--no-default-browser-check`. Everything Chrome keeps is in `Data\profile`: your profiles, bookmarks, history, extensions and settings.

When the package is started from another folder or drive letter, the paths stored in each profile's `Preferences` (the download folder, for one) are updated, first those into the package, then, if the drive letter changed, the others on the same drive.

> [!NOTE]
> Chrome encrypts saved passwords and cookies with a key that Windows protects for your Windows account on that computer. On another computer they can't be read, and you'll need to sign in to websites again; signing in to Chrome with a Google account and syncing passwords is the way to take them along. Chrome also notices that some protected settings (such as the start page and search engine) were made on another computer, and may reset them.

## What Chrome leaves in Windows, and how it's undone

| Chrome writes | When Chrome closes |
| --- | --- |
| `HKCU\Software\Google\Chrome` | Removed, or put back exactly as it was if you also have an installed Chrome |
| `%LOCALAPPDATA%\Google\Chrome` and the folders around it | Removed, if they weren't there before |
| **Make default** in Chrome's settings: `ChromeHTML.<id>` and `ChromePDF.<id>` file types, the `Google Chrome.<id>` browser registration | Removed. Those names end in an ID Chrome makes up, so the launcher notes which ones exist before Chrome starts and removes only the new ones; an installed Chrome's registrations stay. |

A portable Chrome can't stay the default browser on a computer it may not be on, which is why that registration lasts only while it runs. From the PortableApps.com Platform, use the Platform's own file type associations.

## Coming from PortableApps.com's Google Chrome Portable

Both keep Chrome in `App\Chrome-bin` and your user data in `Data\profile`, so they carry over:

1. Copy this package's files over your existing `GoogleChromePortable` folder, and compile the launcher.
2. The next update replaces `App\Chrome-bin` with Google's current build for your Windows, the 64-bit one on 64-bit Windows even if you had the 32-bit one. Chrome uses the same user data either way.

Folders this package doesn't use can be deleted: `App\DefaultData`, and in `Other\Source` the files of PortableApps.com's launcher.

## If something goes wrong

If Google Chrome Portable didn't close properly (a crash, a power cut, a USB drive pulled out), the next launch tells you and undoes what the last session changed. Start it again afterward.

When reporting a problem, please include an export of the `HKEY_CURRENT_USER\Software\pac-man\Journal` registry key and the contents of `%LOCALAPPDATA%\pac-man\Journal`.

## Building from source

The launcher is built with the [PortableApps Compiler][PACMAN]. Its configuration lives in `App\AppInfo`:

| File | Contents |
| --- | --- |
| `App\AppInfo\appinfo.ini` | Package details, version and file types. The launcher keeps the version current. |
| `App\AppInfo\Launcher\GoogleChromePortable.ini` | The executable, the user data switch and the processes to wait for |
| `App\AppInfo\Launcher\custom.nsh` | Install, updates, language, path updates, the journal of Windows leftovers and the version |

## Credits

* Google Chrome is developed by [Google](https://www.google.com/chrome/).
* [7-Zip](https://www.7-zip.org/) by Igor Pavlov.
* [PortableApps.com Platform](https://portableapps.com/download) by [PortableApps.com](https://portableapps.com/).
* [PortableApps Compiler][PACMAN] developed by daemon.devin.
