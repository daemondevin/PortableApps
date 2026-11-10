# BitLord Portable

A portable launcher for [BitLord](https://www.bitlord.com/), a BitTorrent client with a built-in browser and player, built with the [PortableApps Compiler][PACMAN] (pac-man). It keeps BitLord's settings, torrents and browser data in the package, gives it firewall rules only while it runs, and undoes everything else it changes on the computer when it closes, or on the next launch if something went wrong.

 [PACMAN]: https://github.com/daemondevin/pac-man

## License

BitLord is freeware by House of Life, for personal, non-commercial use. Its license (`App\AppInfo\eula.txt`) doesn't allow passing it on, so the package doesn't include it: you add your own copy (see below). For the same reason the package isn't marked as shareable; share it without `App\BitLord`.

## System Requirements

* 64-bit Windows 10 or later. Every BitLord file is 64-bit.
* The Visual C++ 2015-2022 runtime (x64). The launcher checks for it, and offers to install it from `App\Prerequisites` when the computer doesn't have it. It stays installed afterward.
* Administrator rights, for the firewall rules (see below).
* [PortableApps.com Platform](https://portableapps.com/download) (optional).

## Adding BitLord

Put BitLord's program files in `App\BitLord`, so that `App\BitLord\BitLord.exe` is there. Until it is, the launcher says what to do, offers to open the `App` folder, and stops.

The files come from an installed BitLord:

1. Download BitLord from [bitlord.com](https://www.bitlord.com/download/) and install it.
   > [!WARNING]
   > BitLord's installer offers other software (browsers, antivirus and so on). Decline each offer on its page before clicking on.
2. Copy the contents of BitLord's program folder (in `Program Files`, where its Start menu shortcut points) into `App\BitLord`.
3. Uninstall BitLord from the computer if you don't need it there.

After each session the launcher writes the version of `BitLord.exe` to `appinfo.ini`, so the PortableApps.com Platform shows it.

## Updates

BitLord's own update check is kept off: it downloads BitLord's installer, with its offers. To update, install the new version as above and copy its program folder over `App\BitLord` while BitLord Portable is closed. Your settings and torrents are in `Data`, so they aren't touched.

## Configuration

`BitLordPortable.ini`, next to the launcher, holds the user settings. If it gets damaged, copy `Other\Source\BitLordPortable.ini` over it.

```INI
[BitLordPortable]
AdditionalParameters=
```

| Key | Default | What it does |
| --- | --- | --- |
| `AdditionalParameters` | empty | Extra command line arguments passed to BitLord. |

## Data

| In `Data` | On the computer while BitLord runs | Contents |
| --- | --- | --- |
| `settings\BitLord.reg` | `HKCU\Software\bitlord.com\BitLord` | BitLord's settings: download folders, connection and interface options |
| `BitLord` | `%APPDATA%\BitLord` | Torrents and their progress, DHT state, playlists, RSS feeds, the ad block list |
| `BrowserCache` | `%LOCALAPPDATA%\BitLord` | The built-in browser's profile (cookies, history) |

The built-in browser's caches (`BrowserCache\BrowserCache` and the GPU cache) are deleted before its folder moves back to `Data`. It rebuilds them as needed, so they don't have to travel on the drive.

### Download folders

The first time, BitLord's download folders (downloads, `.torrent` files, the auto-add folder and the "move completed" folder) are set to `Downloads` in the PortableApps.com Documents folder, next to your PortableApps folder, for example `X:\Documents\Downloads`. A folder you choose in BitLord's preferences afterward is kept.

When the package is started from another folder or drive letter, the paths in BitLord's settings are updated, first those into the package, then, if the drive letter changed, the others on the same drive. The folder each torrent was saved to is kept in BitLord's own torrent state, which the launcher can't update; if a torrent can't find its files after the drive letter changed, point it at its new folder or recheck it in BitLord.

### Forced settings

These settings are set every launch, whatever BitLord's preferences say:

| Setting | Value | Why |
| --- | --- | --- |
| Check for new releases | Off | BitLord's update check downloads its installer, with its offers. |
| Run at startup | Off | A portable app can't start with Windows from a drive that may not be there. |
| Check file associations | Off | BitLord would ask to take over `.torrent` files and magnet links on every computer. |

## Firewall

So other peers can connect to BitLord, the launcher adds two Windows Firewall rules for `App\BitLord\BitLord.exe` (incoming TCP and UDP, on private networks) while BitLord runs, and removes them when it closes. The rules are named `BitLord TCP [pac-man:BitLordPortable]` and `BitLord UDP [pac-man:BitLordPortable]`; rules the launcher didn't make are never touched.

Changing the firewall needs administrator rights, so the launcher asks for them (`RunAsAdmin=force`) and stops if they're refused. BitLord itself always runs as you, not elevated.

To run without administrator rights, set `RunAsAdmin=prompt` in `App\AppInfo\Launcher\BitLordPortable.ini` and rebuild the launcher. You're then asked each time, and when you decline, BitLord starts without the rules (with one warning) and only reaches peers through outgoing connections. Windows may also offer its own firewall prompt for BitLord, which leaves a rule behind.

## What's journaled and undone

| Could be written | When BitLord closes |
| --- | --- |
| `HKCU\Software\bitlord.com\BitLord` | Saved to `Data\settings\BitLord.reg` and removed; one an installed BitLord had is put back |
| `HKCU\Software\Classes\.torrent`, `BitLord`, `Magnet`, `torrentstream` (file associations) | Put back as they were |
| `HKCU\...\CurrentVersion\Run\BitLord` (run at startup) | Put back as it was |
| `%APPDATA%\BitLord`, `%LOCALAPPDATA%\BitLord` | Moved back to `Data`; an installed BitLord's folders are put back |
| The two firewall rules | Removed |

## If something goes wrong

If BitLord Portable didn't close properly (a crash, a power cut, a USB drive pulled out), the next launch tells you, removes the firewall rules and puts everything back. Start it again afterward.

When reporting a problem, please include an export of the `HKEY_CURRENT_USER\Software\pac-man\Journal` registry key and the contents of `%LOCALAPPDATA%\pac-man\Journal`.

## Building from source

The launcher is built with the [PortableApps Compiler][PACMAN], with the Firewall, Runtime, MissingApp, Registry and ExecAsUser segments. Its configuration lives in `App\AppInfo`:

| File | Contents |
| --- | --- |
| `App\AppInfo\appinfo.ini` | Package details, version and the `.torrent` file type. The launcher keeps the version current. |
| `App\AppInfo\Launcher\BitLordPortable.ini` | The executable, elevation, the missing program check, the Visual C++ runtime, registry keys, forced settings and path updates, the folders moved in and out, and the firewall rules |
| `App\AppInfo\Launcher\custom.nsh` | The default download folders, and the version |

## Credits

* BitLord is developed by [House of Life](https://www.bitlord.com/).
* [PortableApps.com Platform](https://portableapps.com/download) by [PortableApps.com](https://portableapps.com/).
* [PortableApps Compiler][PACMAN] developed by daemon.devin.
