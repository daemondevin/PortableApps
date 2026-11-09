# ISOrack Portable

A portable launcher for ISOrack, the multiboot USB drive builder, built with the [PortableApps Compiler][PACMAN] (PAC-MAN). It runs ISOrack with its boot files and QEMU from the package, keeps its settings in the package, and leaves nothing behind on the computer.

 [PACMAN]: https://github.com/daemondevin/pac-man

## System Requirements

* 64-bit Windows 10 or later.
* Administrator rights. ISOrack partitions and writes drives with diskpart and raw disk access, so it asks for them every time it starts.
* The Microsoft Edge WebView2 Runtime, which ISOrack draws its interface with. Windows 11 and up-to-date Windows 10 have it already. See [WebView2](#webview2) for a computer that doesn't.
* [PortableApps.com Platform](https://portableapps.com/download) (optional).

## Data

It keeps its files in two folders on the computer, and the launcher moves both into `Data` for each session and back afterward:

| In `Data` | On the computer while it runs | Contents |
| --- | --- | --- |
| `ISOrack` | `%APPDATA%\ISOrack` | Your own catalog entries (`catalog.toml`), when you add any |
| `LocalAppData` | `%LOCALAPPDATA%\dev.isorack.app` | WebView2's profile (`EBWebView`): the download folder you chose and the theme |

WebView2's caches are deleted before the profile moves back. WebView2 rebuilds them on the next start, so they never need to be carried on the drive.

If the computer has an installed ISOrack with its own folders, those are set aside while the portable one runs and put back afterward.

The first time, ISOrack offers `Downloads\ISOrack` in your Windows user folder for downloaded ISOs. ISO images are large, so choose another folder there if the drive with the package is small. The folder you choose is remembered in `Data`. Choosing one on the same drive as the package keeps everything together.

The UEFI variables of a test boot go to the launcher's own temporary folder, which is removed when ISOrack closes.

## Test boots

ISOrack's test boot starts QEMU in a window of its own. If you close ISOrack first, the launcher waits for QEMU to close too before moving the folders back to `Data`.

## WebView2

The launcher checks for the WebView2 Runtime before ISOrack starts. If the computer doesn't have it, the launcher offers to open Microsoft's download page and stops; nothing is changed.

To run on a computer without the runtime, and without installing anything, add the **Fixed Version** runtime to the package:

1. Download the Fixed Version runtime for x64 from [Microsoft](https://developer.microsoft.com/microsoft-edge/webview2/).
2. Extract the cab file. It holds a folder named like `Microsoft.WebView2.FixedVersionRuntime.<version>.x64`.
3. Copy that folder's contents into this package's `App\WebView2`, so `App\WebView2\msedgewebview2.exe` is there.

When that folder is there, the launcher always uses it (`WEBVIEW2_BROWSER_EXECUTABLE_FOLDER`), even on a computer that has an installed runtime. The Fixed Version runtime doesn't update itself; replace the folder to update it.

## Updating ISOrack

Copy a new build's program files over `App\ISOrack` while ISOrack Portable is closed. Your settings are in `Data`, so they aren't touched. After each session the launcher writes the version of `isorack-app.exe` to `appinfo.ini`, so the PortableApps.com Platform shows it.

## Configuration

`ISOrackPortable.ini`, next to the launcher, holds the user settings. If it gets damaged, copy `Other\Source\ISOrackPortable.ini` over it.

```INI
[ISOrackPortable]
AdditionalParameters=
```

| Key | Default | What it does |
| --- | --- | --- |
| `AdditionalParameters` | empty | Extra command line arguments passed to ISOrack. |

## If something goes wrong

If ISOrack Portable didn't close properly (a crash, a power cut, a USB drive pulled out), the next launch moves the folders back into `Data` first. Start it again afterward.

## License

ISOrack is MIT licensed. The files next to it keep their own licenses, and passing the package on means passing on their source obligations too:

* `grub\BOOTX64.EFI` and `grub\mmx64.efi`: shim and MokManager, unmodified from Ubuntu's `shim-signed` package, BSD-2-Clause.
* `grub\grubx64.efi`, `core.img`, `boot.img`: GRUB 2.12 from Ubuntu's `grub2` packages, GPLv3 (versions in `grub\VERSION`).
* `grub\wimboot`: iPXE wimboot, GPLv2+ (version in `grub\wimboot.version`).
* `tools`: memdisk and HDT from SYSLINUX, Memtest86+, and iPXE, GPLv2, from Ubuntu packages (versions in `tools\VERSION`).
* `qemu`: QEMU for Windows from [qemu.weilnetz.de](https://qemu.weilnetz.de/), GPLv2 (`qemu\COPYING`, `qemu\COPYING.LIB`, version in `qemu\VERSION`).

The matching sources are the Ubuntu source packages and upstream releases named in those `VERSION` files.

## Building from source

The launcher is built with the [PortableApps Compiler][PACMAN]. Its configuration lives in `App\AppInfo`:

| File | Contents |
| --- | --- |
| `App\AppInfo\appinfo.ini` | Package details and version. The launcher keeps the version current. |
| `App\AppInfo\Launcher\ISOrackPortable.ini` | The executable and elevation, QEMU, the folders moved into `Data`, and the caches left out |
| `App\AppInfo\Launcher\custom.nsh` | The WebView2 check and Fixed Version runtime, waiting for WebView2 to close, and the version |

## Credits

* ISOrack by daemon.devin.
* Built with [Tauri](https://tauri.app/) and Microsoft Edge WebView2.
* [PortableApps.com Platform](https://portableapps.com/download) by [PortableApps.com](https://portableapps.com/).
* [PortableApps Compiler][PACMAN] developed by daemon.devin.
