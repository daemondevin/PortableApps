# Ore Portable

A portable launcher for Ore, a Bejeweled style match three game, built with the [PortableApps Compiler][PACMAN] (PAC-MAN). It keeps your high scores and the game's settings in the package, and leaves nothing behind on the computer.

 [PACMAN]: https://github.com/daemondevin/pac-man

## System Requirements

* Windows 10 or later.
* The Microsoft Edge WebView2 Runtime, which Ore draws its board with. Windows 11 and up-to-date Windows 10 have it already. See [WebView2](#webview2) for a computer that doesn't.
* [PortableApps.com Platform](https://portableapps.com/download) (optional).

## Data

Ore is a Tauri app with the identifier `dev.ore.gems`. It keeps its files in two folders on the computer, and the launcher moves both into `Data` for each session and back afterward:

| In `Data` | On the computer while it runs | Contents |
| --- | --- | --- |
| `AppData` | `%APPDATA%\dev.ore.gems` | The game's own files: `highscores.json`, the high score log |
| `LocalAppData` | `%LOCALAPPDATA%\dev.ore.gems` | WebView2's profile (`EBWebView`): the page's storage and preferences |

WebView2's caches (`Cache`, `Code Cache`, `GPUCache`, the shader caches and `Crashpad`) are deleted before the profile moves back. WebView2 rebuilds them on the next start, so they never need to be carried on the drive.

If the computer has an installed Ore with its own folders, those are set aside while the portable one runs and put back afterward.

To start with a fresh high score log, clear the high scores in the game, or delete `Data\AppData\highscores.json` while the game is closed.

## WebView2

The launcher checks for the WebView2 Runtime before the game starts. If the computer doesn't have it, the launcher offers to open Microsoft's download page and stops; nothing is changed.

To run on a computer without the runtime, and without installing anything, add the **Fixed Version** runtime to the package:

1. Download the Fixed Version runtime for your Windows (x64 for most computers) from [Microsoft](https://developer.microsoft.com/microsoft-edge/webview2/).
2. Extract the cab file. It holds a folder named like `Microsoft.WebView2.FixedVersionRuntime.<version>.x64`.
3. Copy that folder's contents into this package's `App\WebView2`, so `App\WebView2\msedgewebview2.exe` is there.

When that folder is there, the launcher always uses it (`WEBVIEW2_BROWSER_EXECUTABLE_FOLDER`), even on a computer that has an installed runtime. The Fixed Version runtime doesn't update itself; replace the folder to update it.

## Configuration

`OrePortable.ini`, next to the launcher, holds the user settings. If it gets damaged, copy `Other\Source\OrePortable.ini` over it.

```INI
[OrePortable]
AdditionalParameters=
```

| Key | Default | What it does |
| --- | --- | --- |
| `AdditionalParameters` | empty | Extra command line arguments passed to the game. |

## Updating the game

Replace `App\ore\ore.exe` with the new build. Your high scores and settings are in `Data`, so they aren't touched. After each session the launcher writes the version of `ore.exe` to `appinfo.ini`, so the PortableApps.com Platform shows it.

## If something goes wrong

If Ore Portable didn't close properly (a crash, a power cut, a USB drive pulled out), the next launch moves the folders back into `Data` first. Start it again afterward.

## Building from source

The launcher is built with the [PortableApps Compiler][PACMAN]. Its configuration lives in `App\AppInfo`:

| File | Contents |
| --- | --- |
| `App\AppInfo\appinfo.ini` | Package details and version. The launcher keeps the version current. |
| `App\AppInfo\Launcher\OrePortable.ini` | The executable, the folders moved into `Data`, and the caches left out |
| `App\AppInfo\Launcher\custom.nsh` | The WebView2 check and Fixed Version runtime, waiting for WebView2 to close, and the version |

## Credits

* Ore and this package by daemon.devin.
* Built with [Tauri](https://tauri.app/) and Microsoft Edge WebView2.
* [PortableApps.com Platform](https://portableapps.com/download) by [PortableApps.com](https://portableapps.com/).
* [PortableApps Compiler][PACMAN] developed by daemon.devin.
