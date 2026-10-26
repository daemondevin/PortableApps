# Portable Apps by daemon.devin

Portable versions of Windows programs, built with [PAC-MAN][pacman] (PortableApps Compiler & Management). Run them from a USB drive, an external disk or any folder, without installing anything. Your settings travel with the app, and the computer is left the way it was.

> [!IMPORTANT]
> These packages aren't made or endorsed by PortableApps.com, or by the developers of the programs they launch. PAC-MAN is built on the PortableApps.com Launcher and produces packages in the PortableApps.com Format, so they work with the [PortableApps.com Platform][platform], but it's a separate project.

## Two kinds of package

| Kind | What's in it | What you do |
| --- | --- | --- |
| **Complete** | The launcher and the program | Extract it and run it |
| **Launcher only** | The launcher, without the program | Add the program folder from your own licensed copy, once |

**Launcher-only packages** are for commercial software, and for free programs whose license doesn't allow copies to be passed on. They contain no program files, serial numbers, license keys, cracks or patches, and they never work around a program's licensing or activation. You need your own copy and license, exactly as you would to install the program.

The first time you start one, the launcher tells you which folder to copy from an installed copy of the program, and where to put it in `App`, and offers to open the folder for you.

## The packages

What's here so far.

| Package | Kind | Notes |
| --- | --- | --- |
| AIMP Portable | Launcher only | AIMP's license only allows AIMP's original installer to be passed on. |
| Adobe Illustrator Portable | Launcher only | |
| Adobe Photoshop Portable | Launcher only | |
| Bearsampp Portable | Launcher only | Download Bearsampp from Bearsampp's GitHub releases |
| Emsisoft Emergency Kit Portable | Launcher only | Free for private use; get it from Emsisoft. It updates itself. |
| FL Studio Portable | Launcher only | |
| Google Chrome Portable | Launcher only | |
| Komodo Edit Portable | Complete | |
| Komodo IDE Portable | Complete | |
| Mozilla Firefox Portable | Launcher only | |
| Opera Portable | Launcher only | |
| O&O Defrag Portable | Launcher only | |
| O&O RegEditor Portable | Launcher only | |
| RipX DAW Portable | Launcher only | |
| WeBuilder Portable | Launcher only | |

Every package has a `README.md` that says exactly what it changes on the computer, what's kept in `Data`, and what its settings do.

There's also some PortableApps that have there own project pages:

- [GitHub Desktop](https://github.com/daemondevin/GitHubDesktopPortable)
- [7-Zip Portable](https://github.com/daemondevin/7-ZipPortable)
- [Discord Portable](https://github.com/daemondevin/DiscordPortable)
- [VS Code Portable](https://github.com/daemondevin/VSCodePortable)

## Installing

1. Download the package from [Releases](../../releases).
2. Extract it to a folder of your choice. To use the PortableApps.com Platform, put it in the Platform's `PortableApps` folder.
3. **Launcher only:** start it once, and copy the program folder where it tells you to.
4. Start `<AppName>Portable.exe`.

To update a package, extract the new release over the old one. Your `Data` folder and your `<AppName>Portable.ini` settings are kept.

## Every change can be undone

Many modern programs don't stay inside their own folder. They register services, drivers, file associations, fonts, firewall rules or scheduled tasks, or write to parts of the registry that are shared by the whole computer. PAC-MAN launchers handle that safely:

- **Before** a launcher changes anything on the computer, it writes down how to undo it, in a journal.
- **When the program closes,** the journal is used to put everything back.
- **If it closes badly,** after a crash, a power cut or a USB drive pulled out too soon, the next launch finds the journal and finishes the job.
- **Anything that was already there** before the launch, such as an installed copy of the same program, is left alone.

Some programs need administrator rights for this. Each package's README says when, and why.

## My promise: no cracked software
 
Every release I publish is made from software obtained legitimately. That means:
 
- **No cracks, keygens, patched binaries or license bypasses.** Ever.
- **No repackaged pirated installers.** If an app needs a license, you bring your own, or it ships as the vendor's own free or trial edition.
- **The app itself is not modified** to remove protections, ads, checks or telemetry unless the vendor allows it, and if I do change something, the release notes say so.
- **What I add is the launcher.** The PAC-MAN launcher, its settings and its cleanup are my work, and you can read what they do.
If you ever find a release of mine that breaks this promise, tell me and I will pull it.
 
## Signed releases and the warning you may see
 
I sign my launchers with a code signing certificate, using the signing tools built into PAC-MAN. The signature proves two things: the file came from me, and it has not been changed since I signed it. If someone tampers with a release or passes off their own build as mine, the signature breaks.
 
My certificate is not one that Windows trusts out of the box, so the first time you run one of my launchers, Windows may warn you about an unknown publisher. That warning is Windows saying it does not know me yet. It is not saying the file is bad.
 
## Stop the warnings
 
If you trust my releases and want the warnings to go away, add my certificate to your certificate manager.
 
1. **Download the certificate:** [daemon.devin certificate](https://envs.net/~daemondevin/portableapps/uploads/daemon.devin.p7b)
2. **Check it is mine** before you trust it. Open the file, go to the **Details** tab and compare the **Thumbprint** with this one: `070f1dc3f30dd5da9beae822cf2de256b8ad434b`. If they differ, do not install it.
3. Press **Win + R**, type `certmgr.msc` and press Enter. (This installs it for your account only. Use `certlm.msc` to install it for every user on the PC, which needs administrator rights.)
4. Open **Trusted Root Certification Authorities**, right-click **Certificates**, choose **All Tasks → Import**, and pick the file I gave you.
5. Repeat the import into **Trusted Publishers**.
6. Run one of my launchers. The unknown publisher warning should be gone.
A few honest notes:
 
- **Only do this if you trust me.** A certificate in your trusted store tells Windows to believe whatever is signed with it. That is the whole idea, and it is also why you should check the thumbprint and not take a certificate from anyone else's page.
- **You can undo it any time.** Open the same store, find my certificate, and delete it.
- **It will not hide everything.** Windows SmartScreen judges downloads by reputation as well as signature, so a brand new download can still get a prompt even from a trusted publisher. Choose **More info → Run anyway** once for that file.
- **Your antivirus may still flag a launcher** now and then, because launchers write to the registry and start services, which is also what malware does. If you want to be sure, check the signature before you run anything: right-click the file, choose **Properties → Digital Signatures**, and check the signer is me.
Thanks for using my releases.

## Reporting a problem

Open an [issue](../../issues) here for a problem with one of these packages. Please include:

- the package name and version, and your Windows version
- what happened, and what you expected
- after a crash, an export of `HKEY_CURRENT_USER\Software\pac-man\Journal` and the contents of `%LOCALAPPDATA%\pac-man\Journal`

> [!WARNING]
> Remove license keys, serial numbers, account tokens and personal paths from anything you attach.

Problems with a program itself, rather than with running it portably, belong with its developer. Questions about PAC-MAN go to its [Discussions][discussions].

## Building from source

Each package folder holds the launcher's source:

| File | Contents |
| --- | --- |
| `App\AppInfo\appinfo.ini` | Package details and version |
| `App\AppInfo\Launcher\<AppName>Portable.ini` | The launcher configuration |
| `App\AppInfo\Launcher\custom.nsh` | Code specific to this program, when it needs any |
| `Other\Source\README.md` | What the launcher does, and how it's undone |

To build a launcher, open the [PortableApps Compiler][pacman] and point it at the package folder. Program files aren't kept in this repository; they're in the release downloads of complete packages.

## License

The launchers and their configuration (everything in this repository) are released under the [GNU General Public License v2.0 or later](LICENSE), like PAC-MAN and the PortableApps.com Launcher they're built on.

The programs themselves are not covered by that license. Each is the property of its developer and keeps its own license, which applies whether the program came in a complete package or you added it yourself.

## Credits

- [PAC-MAN][pacman] by daemon.devin
- [PortableApps.com Launcher and Platform][platform] by PortableApps.com
- Each program by its own developer

[pacman]: https://github.com/daemondevin/pac-man
[discussions]: https://github.com/daemondevin/pac-man/discussions
[platform]: https://portableapps.com/
