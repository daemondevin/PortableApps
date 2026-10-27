# AUMBI Portable

A portable launcher for AUMBI (Absolute USB MultiBoot Installer) by Darwin Toledo, built with the [PortableApps Compiler][PACMAN] (pac-man). AUMBI makes USB drives that boot many Linux, Windows and rescue ISO files from one menu. It's based on YUMI and released under the GNU GPL version 2.

 [PACMAN]: https://github.com/daemondevin/pac-man

## System Requirements

* Windows 7 or later.
* Administrator rights: AUMBI partitions and formats drives, so it's built to always run as an administrator, and the launcher asks for those rights (UAC) each time.
* [PortableApps.com Platform](https://portableapps.com/download) (optional).

## Adding AUMBI

1. Download AUMBI from its author's page: [niwrad.gumroad.com/l/aumbi](https://niwrad.gumroad.com/l/aumbi). It comes as one file, such as `AUMBI-2020.2.exe`.
2. Put that file in this package's `App\AUMBI` folder (or in the package folder itself).
3. Start `AUMBIPortable.exe`.

The launcher renames it to `App\AUMBI\AUMBI.exe` and records its version in `appinfo.ini`, so the PortableApps.com Platform shows it. To update, put the newer `AUMBI-<version>.exe` in the same place; it replaces the one in use. An older one is left where it is and not used.

Until AUMBI is there, the launcher says what to do, offers to open the `App` folder, and stops.

> [!NOTE]
> AUMBI is free software under the GPL, so you can include it in a copy of this package you pass on, as long as you follow the GPL: include, or offer, AUMBI's source along with it. AUMBI's own license and readme (`AUMBI-Copying.txt`, `AUMBI-Readme.txt`) are inside `AUMBI.exe`.

## Data

There's nothing to keep: AUMBI unpacks its tools (Syslinux, Grub4DOS, 7-Zip, wimlib and others) into a temporary folder each time it runs, removes it when it closes, and keeps no settings of its own. What it makes, it writes to the USB drive you choose.

> [!WARNING]
> Formatting or wiping a drive in AUMBI erases it. Check the drive letter and disk before you start.

## Configuration

`AUMBIPortable.ini`, next to the launcher, holds the user settings. If it gets damaged, or you want to go back to the defaults, copy `Other\Source\AUMBIPortable.ini` over it.

```INI
[AUMBIPortable]
AdditionalParameters=
```

| Key | Default | What it does |
| --- | --- | --- |
| `AdditionalParameters` | empty | Extra command line switches passed to AUMBI. |

## Building from source

The launcher is built with the [PortableApps Compiler][PACMAN], and needs the MissingApp segment. Its configuration lives in `App\AppInfo`:

| File | Contents |
| --- | --- |
| `App\AppInfo\appinfo.ini` | Package details and version. The launcher keeps the version current. |
| `App\AppInfo\Launcher\AUMBIPortable.ini` | The executable, administrator rights and the missing program check |
| `App\AppInfo\Launcher\custom.nsh` | Taking a newly added `AUMBI-<version>.exe` into place, and its version |

## Credits

* AUMBI is developed by Darwin Toledo, based on [YUMI](https://www.pendrivelinux.com/yumi-multiboot-usb-creator/) by Pendrivelinux.
* [PortableApps.com Platform](https://portableapps.com/download) by [PortableApps.com](https://portableapps.com/).
* [PortableApps Compiler][PACMAN] developed by daemon.devin.
