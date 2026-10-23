# Adobe Illustrator CS3 Portable

A portable launcher for Adobe Illustrator CS3, built with the [PortableApps Compiler][PACMAN] (pac-man). Every change it makes to Windows is recorded first and undone when Illustrator closes, or on the next launch if something went wrong.

The package doesn't include or handle Illustrator's licensing: use it with a copy of Illustrator CS3 you're licensed to run.

 [PACMAN]: https://github.com/daemondevin/pac-man

## System Requirements

* Windows, 32-bit or 64-bit. Illustrator CS3 is a 32-bit application.
* Administrator rights for the launcher. Illustrator itself runs with your normal rights (see [Drag and drop](#drag-and-drop)).
* `Data` on a local drive (a USB drive is fine; a network share isn't). See [Data](#data).
* [PortableApps.com Platform](https://portableapps.com/download) (optional).

## Drag and drop

Windows doesn't let Explorer, or any other program running with normal rights, drag files into a program that runs as administrator. So a launcher that runs Illustrator elevated also breaks drag and drop.

The launcher still needs administrator rights, for the shared files in Common Files and Program Data and the language setting in the machine-wide registry. But once it has set those up, it starts Illustrator the way Explorer would: with the rights of the signed-in user, using Explorer's own credentials. Drag and drop from Explorer, the desktop and other programs then works as it does with an installed Illustrator.

* A second launch while Illustrator runs (opening a file from the PortableApps.com Platform, for example) isn't elevated at all, so there's no UAC prompt. It hands its files to the running Illustrator.
* If the launcher was elevated with a different account's password (a standard user typing an administrator's password), Illustrator has to run as that administrator, and drag and drop from your own Explorer can't work. Signing in with an account that is an administrator avoids that.

## Configuration

`IllustratorPortable.ini`, next to the launcher, holds the user settings. If it gets damaged, or you want to go back to the defaults, copy `Other\Source\IllustratorPortable.ini` over it.

```INI
[IllustratorPortable]
AdditionalParameters=
DisableSplashScreen=false
RunLocally=false
ProductLanguage=en_us
```

| Key | Default | What it does |
| --- | --- | --- |
| `ProductLanguage` | `en_us` | The language Adobe's shared code is told Illustrator runs in, written the way Adobe writes it (`en_us`, `de_de`, `fr_fr` and so on). It has to be a language the Illustrator in the package has. |
| `AdditionalParameters` | empty | Extra command line switches passed to Illustrator. |
| `DisableSplashScreen` | `false` | Don't show the launcher's splash screen. |
| `RunLocally` | `false` | Copy Illustrator to the `TEMP` folder and run it from there, for read-only media. Changes made in that session aren't saved back. |

Launching the package again while Illustrator runs passes the files to the running Illustrator.

## Data

While Illustrator runs, these are linked into `Data` with NTFS junctions, so nothing is copied back and forth:

| Illustrator uses | Kept in |
| --- | --- |
| `%APPDATA%\Adobe\Adobe Illustrator CS3 Settings` | `Data\Adobe Illustrator CS3 Settings` |
| `%ProgramData%\Adobe\Adobe PDF` | `Data\Adobe PDF` |
| `Common Files\Adobe\Plug-Ins\CS3` | `Data\CommonFiles\Plug-Ins\CS3` |
| `Common Files\Adobe\TypeSupport` | `Data\CommonFiles\TypeSupport` |
| `Common Files\Adobe\XMP\Custom File Info Panels` | `Data\CommonFiles\XMP\Custom File Info Panels` |
| `Common Files\Adobe\Help\en_US\Illustrator` | `Data\CommonFiles\Help\Illustrator` |

`Common Files` is the 32-bit one (`Program Files (x86)\Common Files` on 64-bit Windows), which is where Illustrator CS3 looks.

If an installed Adobe application already has one of these folders, it's moved aside for the session and put back when Illustrator Portable closes. Close installed Adobe applications before starting Illustrator Portable, so they don't run without their shared files in the meantime.

> [!IMPORTANT]
> Junctions can only point to a local drive. Running from a network share isn't supported.

## Registry

Illustrator CS3 writes these for itself when it can (the machine-wide ones only when it runs elevated, which the launcher now avoids):

* its file types (`.ps`, `.win`, `Adobe.Illustrator`, `Adobe.Illustrator.13`, `Adobe.Illustrator.EPS`, `Adobe.ColorSettings`)
* its scripting (COM) classes, their CLSIDs and its type library
* payload records under `HKCU\Software\Adobe\Payloads`

The launcher records every one of these keys before Illustrator starts. A key that didn't exist is deleted when Illustrator closes; one that did (from an installed Illustrator or another program, such as a `.ps` viewer) is put back exactly as it was. The list is `[IllustratorRegistry]` in `App\AppInfo\Launcher\IllustratorPortable.ini`.

The product language (`HKLM\SOFTWARE\Adobe\DefaultLanguage`) is set the same way, for the session only.

## If something goes wrong

If Illustrator Portable didn't close properly (a crash, a power cut, a USB drive pulled out), the next launch tells you and undoes everything the last session changed before it starts again. You don't need to do anything else.

When reporting a problem, please include an export of the `HKEY_CURRENT_USER\Software\pac-man\Journal` registry key and the contents of `%LOCALAPPDATA%\pac-man\Journal`.

## Building from source

The launcher is built with the [PortableApps Compiler][PACMAN]. Its configuration lives in `App\AppInfo`:

| File | Contents |
| --- | --- |
| `App\AppInfo\appinfo.ini` | Package details and version |
| `App\AppInfo\Launcher\IllustratorPortable.ini` | The launcher configuration: the data links and the registry keys to journal |
| `App\AppInfo\Launcher\custom.nsh` | Starting Illustrator without elevation, journaling the registry keys and setting the product language |

## Credits

* Adobe Illustrator is developed by Adobe Systems, Inc.
* [PortableApps.com Platform](https://portableapps.com/download) by [PortableApps.com](https://portableapps.com/).
* [PortableApps Compiler][PACMAN] developed by daemon.devin.
