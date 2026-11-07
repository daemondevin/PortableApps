# Android Studio Portable

A portable launcher for [Android Studio](https://developer.android.com/studio), the IDE for Android development, built with the [PortableApps Compiler][PACMAN] (PAC-MAN). It keeps the IDE's settings, caches and plugins, the Android SDK, your emulators (AVDs) and Gradle's caches in the package, and stops the background processes Android Studio leaves running so the drive can be removed. Every change it makes to Windows is recorded first and undone when Android Studio closes, or on the next launch if something went wrong.

Android Studio is made by Google, and you download it yourself under Google's terms (see below). This package's own files are by daemon.devin; its icon is original, not Android Studio's.

 [PACMAN]: https://github.com/daemondevin/pac-man

## System Requirements

* 64-bit Windows 10 or later, with what Android Studio needs ([requirements](https://developer.android.com/studio/install#windows)): 16 GB of memory is recommended, and the emulator needs hardware virtualization.
* An NTFS-formatted drive with plenty of room: Android Studio is about 3 GB unpacked, the SDK with one platform and one emulator image another 10 GB or so, and Gradle's caches grow with every project. A FAT32 or exFAT USB stick will be slow, and FAT32 can't hold emulator images over 4 GB.
* [PortableApps.com Platform](https://portableapps.com/download) (optional).

## Adding Android Studio

1. On [developer.android.com/studio](https://developer.android.com/studio#downloads), download the Windows **zip** (`android-studio-<version>-windows.zip`), not the installer. You agree to Google's terms there.
2. Unpack it into this package's `App` folder (or `App\AndroidStudio`). The zip holds a folder named `android-studio`; the launcher moves it to `App\AndroidStudio` the first time.
3. Start `AndroidStudioPortable.exe`.

Until Android Studio is there, the launcher says what to do, offers to open the `App` folder, and stops.

Android Studio isn't included because Google's terms for the Android SDK and its tools don't allow passing them on, and the download asks you to accept them. 

On the first launch, Android Studio's setup wizard offers to download the SDK. It proposes `Data\Sdk` (the launcher sets `ANDROID_HOME` there); keep that, so the SDK travels with the package.

## Updates

Android Studio updates itself: Help > Check for Updates downloads a patch and applies it to `App\AndroidStudio`, which works for a zip install like this one. The SDK Manager (Tools > SDK Manager) updates the SDK in `Data\Sdk`. Neither needs anything from the launcher.

After each session the launcher writes the version in `App\AndroidStudio\product-info.json` to `appinfo.ini`, so the PortableApps.com Platform shows it.

## Configuration

`AndroidStudioPortable.ini`, next to the launcher, holds the user settings. If it gets damaged, or you want to go back to the defaults, copy `Other\Source\AndroidStudioPortable.ini` over it.

```INI
[AndroidStudioPortable]
AdditionalParameters=
StopDaemons=true
```

| Key | Default | What it does |
| --- | --- | --- |
| `StopDaemons` | `true` | When Android Studio and the emulator have closed, stop the adb server and every process still running from the package (Gradle and Kotlin daemons, mostly). They'd otherwise keep the drive busy for hours. `false` leaves them running. |
| `AdditionalParameters` | empty | Extra command line arguments passed to Android Studio, such as a project folder to open. |

## Data

| Folder | Contents | How |
| --- | --- | --- |
| `Data\AndroidStudio\config` | The IDE's settings: SDK and JDK locations, keymaps, code style, recent projects | `idea.properties` |
| `Data\AndroidStudio\system` | Caches and indexes (safe to delete when Android Studio is closed; it rebuilds them) | `idea.properties` |
| `Data\AndroidStudio\plugins` | Plugins you install | `idea.properties` |
| `Data\AndroidStudio\log` | `idea.log` and other logs | `idea.properties` |
| `Data\Sdk` | The Android SDK: platforms, build tools, platform tools (adb), the emulator and its system images | `ANDROID_HOME` |
| `Data\.android` | The SDK tools' settings: the debug keystore, adb's keys, emulator settings | `ANDROID_USER_HOME`, `ANDROID_EMULATOR_HOME` |
| `Data\.android\avd` | Your emulators (AVDs) | `ANDROID_AVD_HOME` |
| `Data\.gradle` | Gradle's distributions, caches and daemons | `GRADLE_USER_HOME` |

How it's done:

* The launcher writes `Data\AndroidStudio\idea.properties` for every launch and names it with `STUDIO_PROPERTIES`. It sets the four folders above, with forward slashes. Lines you add to it (such as `idea.max.intellisense.filesize`) are kept.
* `ANDROID_SDK_ROOT`, the older name for `ANDROID_HOME`, is set to the same folder: Android Studio and the Android Gradle plugin stop with an error when the two disagree, and the computer may have its own.
* `ANDROID_SDK_HOME`, which older tools use to find `.android`, is cleared for Android Studio, so one set on the computer doesn't send the tools elsewhere.
* Android Studio runs on the Java that comes with it (`STUDIO_JDK` names `App\AndroidStudio\jbr`). Otherwise it would take a `JDK_HOME` or `JAVA_HOME` set on the computer first, which may be too old.

When the package is started from another folder or drive letter, the paths in the IDE's settings (`config\options\*.xml`: the SDK location, JDKs, recent projects, the default project folder) and in your AVDs' `.ini` files are updated, first those into the package, then, if the drive letter changed, the others on the same drive.

> [!TIP]
> Keep your projects in the package too (a `Projects` folder next to `App` and `Data`, say), and set it as the default project folder (Settings > Appearance & Behavior > System Settings). Each project's `local.properties` names the SDK (`sdk.dir`); if the package moves, Android Studio offers to fix it when it opens the project.

## What's journaled and undone

| Could be written | When Android Studio closes |
| --- | --- |
| `%APPDATA%\Google`, `%LOCALAPPDATA%\Google` (Android Studio's default settings and caches folders, consent choices), `%APPDATA%\JetBrains`, `%LOCALAPPDATA%\JetBrains` | Removed, if they weren't there before; otherwise just `Google\AndroidStudio<version>`, if that wasn't |
| `%USERPROFILE%\.android`, `.gradle`, `.skiko`, `%LOCALAPPDATA%\kotlin` (tools that don't read the variables above) | Removed, if they weren't there before |
| `HKCU\Software\JavaSoft\Prefs\jetbrains`, `google` and `com` (Java preferences the IDE keeps in the registry) | Removed, or put back as they were. When there was no `HKCU\Software\JavaSoft` before, all of it is removed. |

Android Studio may offer to exclude its folders from Microsoft Defender scanning. That needs administrator rights and changes Defender's settings for the whole computer; the launcher doesn't undo it, so it's best declined on a computer that isn't yours.

## If something goes wrong

If Android Studio Portable didn't close properly (a crash, a power cut, a USB drive pulled out), the next launch tells you and undoes what the last session changed. Start it again afterward.

When reporting a problem, please include an export of the `HKEY_CURRENT_USER\Software\pac-man\Journal` registry key and the contents of `%LOCALAPPDATA%\pac-man\Journal`, and `Data\AndroidStudio\log\idea.log`.

## Building from source

The launcher is built with the [PortableApps Compiler][PACMAN], and needs the MissingApp segment. Its configuration lives in `App\AppInfo`:

| File | Contents |
| --- | --- |
| `App\AppInfo\appinfo.ini` | Package details and version. The launcher keeps the version current. |
| `App\AppInfo\Launcher\AndroidStudioPortable.ini` | The executable, the processes to wait for, the missing program check and the environment variables |
| `App\AppInfo\Launcher\custom.nsh` | `idea.properties`, the IDE's Java, adding Android Studio, path updates, stopping background processes, the journal of Windows leftovers and the version |

## Credits

* Android Studio is developed by Google, based on IntelliJ IDEA by JetBrains.
* [PortableApps.com Platform](https://portableapps.com/download) by [PortableApps.com](https://portableapps.com/).
* [PortableApps Compiler][PACMAN] developed by daemon.devin.
