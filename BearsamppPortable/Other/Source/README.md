# Bearsampp Portable

A portable launcher for [Bearsampp](https://bearsampp.com/), the portable WAMP-style development stack (Apache, MySQL, MariaDB, PostgreSQL, PHP, Node.js, Mailpit, Memcached and more), built with the [PortableApps Compiler][PACMAN] (PAC-MAN). Every change it makes to Windows is recorded first and undone when Bearsampp closes, or on the next launch if something went wrong. It also keeps Bearsampp itself up to date from its GitHub releases.

 [PACMAN]: https://github.com/daemondevin/pac-man

## System Requirements

* Windows 10 or later, 64-bit. Bearsampp has no 32-bit version.
* Administrator rights. Bearsampp installs Windows services and sets machine-wide environment variables, and refuses to start without them.
* An NTFS drive (a USB drive formatted NTFS is fine; FAT32, exFAT and network shares aren't). Bearsampp creates `current` links inside its own folders for the module versions in use.
* [PortableApps.com Platform](https://portableapps.com/download) (optional).

## Configuration

`BearsamppPortable.ini`, next to the launcher, holds the user settings. If it gets damaged, or you want to go back to the defaults, copy `Other\Source\BearsamppPortable.ini` over it.

```INI
[BearsamppPortable]
UpdateCheck=true
UpdateEdition=lite
KeepRootCA=false
```

| Key | Default | What it does |
| --- | --- | --- |
| `UpdateCheck` | `true` | Check GitHub for a newer Bearsampp each time it starts, and offer to update. |
| `UpdateEdition` | `lite` | The release download an update is taken from: `lite`, `basic` or `full`. See [Updates](#updates). |
| `KeepRootCA` | `false` | Leave Bearsampp's development root certificate trusted on this computer after it closes. See [Certificates](#certificates). |

## What Bearsampp changes, and how it's undone

Bearsampp is a server stack, so unlike most portable apps it has to change the computer while it runs. Before it starts, the launcher records the state of everything below; when Bearsampp closes, it puts each one back.

| Bearsampp changes | Put back when it closes |
| --- | --- |
| Services `bearsamppapache`, `bearsamppmysql`, `bearsamppmariadb`, `bearsampppostgresql`, `bearsamppmailpit`, `bearsamppmemcached`, `bearsamppxlight` | Stopped and deleted, if they weren't there before launch. Services that already existed are left alone. |
| Machine environment variables `BEARSAMPP_PATH` and `BEARSAMPP_BINS` | Restored to their previous value and type, or deleted if they weren't set. |
| `%BEARSAMPP_BINS%` added to the machine `Path` | Only that entry is removed. Everything else in `Path`, including changes other programs made during the session, is kept in order. |
| "Launch on startup" shortcut in your Startup folder | Deleted, if it wasn't there before launch. |
| Bearsampp's root certificate added to your trusted certificates | Removed, unless `KeepRootCA=true` or it was already trusted before launch. |

After the environment is restored, running programs are told it changed, so new command prompts see the original `Path`.

Bearsampp normally deletes its services itself when you choose **Exit**. The launcher's cleanup is what covers a crash, a forced shutdown, or Bearsampp being killed.

### Not undone

* **Windows Firewall rules.** If you let Apache or MySQL through the firewall when Windows asks, those rules are created by Windows, not Bearsampp, and stay. Remove them from *Windows Defender Firewall* if you don't want them.
* **Firefox settings.** When Bearsampp installs its certificate it may also turn on `security.enterprise_roots.enabled` in Firefox profiles so Firefox trusts it. That setting is harmless and is left as it is.

## Certificates

Bearsampp uses [mkcert](https://github.com/FiloSottile/mkcert) to make `https://localhost` and your virtual hosts trusted in the browser. It creates a development root certificate, `App\Bearsampp\ssl\rootCA.pem`, and adds it to your trusted root certificates.

With `KeepRootCA=false`, the certificate is only trusted while Bearsampp Portable runs:

* When Bearsampp closes, the certificate is removed. Windows shows a confirmation dialog for this; choose **Yes**.
* If it was trusted at the end of a session, the launcher re-trusts it at the start of the next one. Windows asks to confirm that too.
* If the certificate was already trusted before Bearsampp Portable started (from an installed Bearsampp, for example), it's left alone.

Set `KeepRootCA=true` to skip both dialogs and leave it trusted on this computer.

> [!IMPORTANT]
> The certificate's private key, `App\Bearsampp\ssl\rootCA-key.pem`, travels with the package. Anyone who copies it can make certificates your browser trusts on any computer where the root certificate is trusted. Don't share the package with it in place, and prefer `KeepRootCA=false` on computers that aren't yours.

Removing the certificate and cleaning up `Path` use Windows PowerShell, which is part of Windows 10 and 11. If it's missing, the launcher leaves the certificate as Bearsampp set it and doesn't journal the `Path` entry.

## Updates

When `UpdateCheck=true`, each launch looks up the latest release on [Bearsampp's GitHub](https://github.com/Bearsampp/Bearsampp/releases). If it's newer than the version in the package, you're asked whether to update, with the download size.

An update replaces **Bearsampp itself**: its `core` folder and `bearsampp.exe`, `bearsampp.ini`, `bar.dat`, `sprites.dat`, `favicon.ico` and `LICENSE`. Everything else is kept:

* your sites (`www`), virtual hosts, aliases and certificates (`ssl`)
* your databases, module versions and tools (`bin`, `apps`, `tools`)
* logs and `bearsampp.conf`

New module versions (a newer PHP or MySQL, say) are installed from inside Bearsampp, with **QuickPick**, not by the updater.

### The download

All three editions contain the same Bearsampp and differ only in how many module versions they bundle, so `lite` is usually the right choice:

| Edition | Download |
| --- | --- |
| `lite` | about 870 MB |
| `basic` | about 1 GB |
| `full` | about 1.7 GB |

Before downloading, the launcher checks there's enough free space on the package's drive for the download plus room to unpack it. The download is checked against the release's SHA-256 checksum before anything is replaced, and Bearsampp's own 7-Zip unpacks it. Only the files listed above are extracted.

Updating needs `curl.exe` and `certutil.exe`, which come with Windows 10 and 11.

### If an update fails

The old files are renamed, not deleted, until the new ones are in place, and each step is recorded in the journal. If the download or checksum fails, nothing is changed. If something goes wrong while files are being replaced, the old version is put back straight away. If the launcher is killed or the computer loses power mid-update, the next launch finds the leftover files and puts the previous version back before starting.

## If something goes wrong

If Bearsampp Portable didn't close properly (a crash, a power cut, a USB drive pulled out), the next launch tells you and undoes everything the last session changed: the services, environment variables, `Path` entry, startup shortcut and certificate. Start it again afterwards. Your sites and databases are kept.

When reporting a problem, please include an export of the `HKEY_CURRENT_USER\Software\pac-man\Journal` registry key and the contents of `%LOCALAPPDATA%\pac-man\Journal`.

## Building from source

The launcher is built with the [PortableApps Compiler][PACMAN]. Its configuration lives in `App\AppInfo`:

| File | Contents |
| --- | --- |
| `App\AppInfo\appinfo.ini` | Package details and version. The updater keeps the version current. |
| `App\AppInfo\installer.ini` | Folders and files a package upgrade must keep |
| `App\AppInfo\Launcher\BearsamppPortable.ini` | The launcher configuration |
| `App\AppInfo\Launcher\custom.nsh` | Journaling Bearsampp's system changes, and the updater |
| `App\AppInfo\Launcher\BearsamppPathClean.ps1` | Removes only Bearsampp's entry from the machine `Path` |
| `App\AppInfo\Launcher\BearsamppRootCA.ps1` | Checks and removes the root certificate |

The two PowerShell scripts are built into the launcher and copied to the journal store when needed, so cleanup still works if the package's drive is gone.

## Credits

* Bearsampp is developed by [the Bearsampp team](https://github.com/Bearsampp/Bearsampp), released under the GPL 3.0.
* [mkcert](https://github.com/FiloSottile/mkcert) by Filippo Valsorda.
* [PortableApps.com Platform](https://portableapps.com/download) by [PortableApps.com](https://portableapps.com/).
* [PortableApps Compiler][PACMAN] developed by daemon.devin.
