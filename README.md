# HearSwift

**A keyboard-controlled Bluetooth call mode for more responsive screen reader audio on Windows.**

[Download releases](https://github.com/atakan-nalbant/hearswift/releases) · [Türkçe](README.tr.md) · [Contributing](CONTRIBUTING.md) · [Test results](VALIDATION.md)

## Why HearSwift exists

HearSwift began with an accessibility problem: AirPods sounded clear on a Windows computer, but screen reader speech arrived late after **every keypress**. Navigating quickly meant repeatedly waiting for audio feedback.

Then a meeting started. Sound quality became a little worse, but the screen reader suddenly felt much more responsive. The useful part was the headset's call mode. Joining a meeting just to get that behavior should not be necessary.

HearSwift turns that observation into an explicit, keyboard-controlled mode. Press a shortcut when responsiveness matters; turn it off when you want normal listening quality again. It started with AirPods 3, but the underlying Windows Bluetooth behavior also applies to other headsets that support the Hands-Free Profile (HFP).

## What it does

Windows commonly uses two profiles for Bluetooth Classic audio:

| Profile | Typical use | Tradeoff |
| --- | --- | --- |
| A2DP | Higher-quality stereo listening | The feedback delay can be noticeable during interactive screen reader use. |
| HFP | Calls: microphone and playback together | Lower-fidelity, generally mono audio; it may feel more responsive on a given setup. |

Opening the headset microphone asks Windows to use its call profile. HearSwift keeps that microphone stream open while quick mode is on and discards the incoming samples in memory. It does **not** record, transmit or play back microphone audio. Turning the mode off releases the microphone.

This is an experimental workaround, not a new Bluetooth driver or a universal latency fix. HearSwift does not measure latency or verify the active Bluetooth profile. Improvement depends on your headset, Bluetooth adapter and drivers. It does not fix pairing failures, interference, or every source of audio delay. The technical basis is documented in [Microsoft's Bluetooth Classic Audio guide](https://learn.microsoft.com/en-us/windows-hardware/drivers/bluetooth/bluetooth-classic-audio).

## Quick start

1. Download the Windows ZIP from [Releases](https://github.com/atakan-nalbant/hearswift/releases) and extract **all** files.
2. Run **Setup.cmd** as your normal Windows user. Administrator rights are not required.
3. Connect your headset and set your screen reader's audio output to that headset.
4. Press **Ctrl+Alt+F9** to turn quick mode on. Compare the response while navigating with your keyboard.
5. Press **Ctrl+Alt+F11** to turn it off. HearSwift stays in the background and keeps listening for shortcuts.

For a headset other than AirPods, first open **Settings.cmd** and select its Bluetooth microphone. Automatic selection currently looks for exactly one microphone with `AirPods` in its name; other headsets require explicit selection.

For portable use, run **Start.cmd** instead of Setup.cmd. Portable mode does not add automatic startup.

### Default shortcuts

| Shortcut | Action |
| --- | --- |
| Ctrl+Alt+F9 | Toggle quick mode |
| Ctrl+Alt+F10 | Speak the current status |
| Ctrl+Alt+F11 | Turn quick mode off; keep the shortcut listener running |

Open **Settings.cmd**, the Start menu Settings entry, or Settings in the tray menu to change the microphone, shortcut keys, modifier combination, language, or spoken feedback. Controls have screen reader labels and support keyboard navigation. Full screen reader testing is still welcome.

Shortcuts must use distinct F1–F24 keys with Ctrl+Alt, Ctrl+Shift, Alt+Shift, or Ctrl+Alt+Shift. A combination already registered by another application is rejected. Saving settings turns quick mode off. Settings.cmd opens the running instance's settings instead of starting a second listener.

## Requirements and compatibility

- Windows 10 or Windows 11 with .NET Framework 4.8.
- A paired Bluetooth headset with an enabled, Windows-accessible microphone; the intended mechanism is Bluetooth Classic HFP.
- Windows microphone privacy settings must allow desktop applications to access the microphone.
- Task Scheduler must be available for the installed startup/restart feature. Organization policies may restrict it.

**Initial hardware testing:** AirPods 3 on Windows 11 25H2, build 26200.9457. This is not a compatibility certification for every AirPods model, Windows version, or Bluetooth headset. Other HFP headsets are candidates for testing through manual microphone selection. Bluetooth LE Audio can behave differently. Windows on ARM has not been tested; the executable is AnyCPU and local verification used x64 Windows.

## Tradeoffs and behavior

- **Quality:** call mode can reduce fidelity and switch playback to mono.
- **Battery:** keeping the microphone open can use more headset battery. No measured battery-life claim is made for HearSwift.
- **Microphone indicator:** Windows shows microphone use while quick mode is active.
- **Startup:** the application starts with quick mode **off**. It does not enable microphone use automatically.
- **Output routing:** HearSwift does not change your audio output device. Select the headset in Windows or your screen reader.
- **Other applications:** if a meeting or another application still holds the headset microphone open, turning HearSwift off may not restore the listening profile until that application releases it.
- **Disconnects:** when capture fails or audio stops arriving, quick mode turns off. Reconnect the headset and enable it again.
- **Device names:** Windows' legacy audio API can truncate microphone names. Identically named devices cannot be distinguished in this version.

## Installation, updates and removal

Setup installs to `%LOCALAPPDATA%\HearSwift\app`, creates Start menu entries and a Windows Installed Apps entry, and adds a per-user `HearSwift-<user SID>` scheduled task. The task starts HearSwift at sign-in and relaunches it within approximately one minute if it exits. It runs on battery and only while you are signed in. Choosing Exit in the tray menu therefore does not permanently stop an installed copy; use the off shortcut for normal daily use.

To update, extract the next release ZIP and run Setup.cmd again. Settings are retained. Exit manually started portable copies before installation. An older AirPods Quick Mode installation is migrated: its startup task is replaced and its settings are copied on first launch if HearSwift settings do not exist. The old files remain available for rollback.

To remove HearSwift, use Windows **Installed Apps** or run **Uninstall.cmd** from the installed folder. The application files, startup task, shortcuts and Installed Apps entry are removed. Settings and diagnostic logs remain. To delete those too, run the installed `uninstall.ps1 -RemoveSettings` before uninstalling. The uninstaller refuses to remove a task that points to another installation.

## Privacy

HearSwift has no network requests, telemetry, account requirement or cloud service. Microphone samples are kept only in short-lived native memory buffers and discarded. No microphone audio is written to disk, sent elsewhere, or played through your speakers.

Settings and diagnostic logs are stored in `%LOCALAPPDATA%\HearSwift\data`, including for portable use. Logs contain timestamps, device names and errors, not audio. Review them before sharing. The current log rotates at approximately 1 MB.

## Build and test

On Windows with .NET Framework 4.8, no NuGet packages or external SDK downloads are required:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build.ps1 -Version 0.1.0
```

This compiles the app, runs a hardware-independent settings self-test, and produces:

- `dist/HearSwift-0.1.0-windows.zip`
- `dist/HearSwift-0.1.0-windows.zip.sha256`

Builds are currently **unsigned**. Windows may display reputation warnings. You can compare the downloaded archive's SHA-256 with its adjacent checksum file:

```powershell
Get-FileHash .\HearSwift-0.1.0-windows.zip -Algorithm SHA256
```

Diagnostic arguments: `--self-test`, `--devices`, `--test`, and `--settings`. The first three return a nonzero exit code on failure and write diagnostic information to the log; --devices also writes devices.txt. **--test opens the selected microphone for several seconds**, so do not run it alongside an active capture session.

See [TESTING.md](TESTING.md) for the release checklist and [VALIDATION.md](VALIDATION.md) for what was actually tested. CI checks builds and packaging; it cannot establish physical Bluetooth behavior or perceived screen reader latency.

## Releases and contributions

Branch pushes and pull requests build Windows artifacts with GitHub Actions. A `vMAJOR.MINOR.PATCH` tag builds a matching archive and checksum and prepares a **draft prerelease** with release notes. The first release remains experimental. A draft can be tested before publishing; no code-signing certificate is configured.

Contributions are welcome, especially device compatibility reports, accessibility feedback and reproducible bugs. Please include your Windows build, headset model, screen reader/version, and whether the issue affects every keypress or only audio starting after silence. See [CONTRIBUTING.md](CONTRIBUTING.md).

[MIT licensed](LICENSE). HearSwift is an independent community project, unaffiliated with Apple or Microsoft.
