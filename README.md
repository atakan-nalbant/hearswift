# AirPods Quick Mode

[Türkçe kullanım kılavuzu](README.tr.md)

A small Windows tray application for screen reader users who prefer the responsiveness of their Bluetooth headset's call profile. It opens the selected microphone and discards incoming audio in memory. Windows can then switch from A2DP to HFP, as it does during calls.

This is an experimental utility, not a guarantee of zero latency. Quality usually drops to mono call audio; battery use can increase. Tested with AirPods 3 on Windows 11 25H2. Other devices and Windows versions need community testing.

## Requirements

- Windows 10/11, .NET Framework 4.8, and a paired Bluetooth headset with an enabled microphone.
- Windows microphone privacy settings must allow desktop apps to access the microphone.
- Windows on ARM has not been tested. Build/package verification currently targets Windows x64; the executable is AnyCPU.

## Install

1. Download the Windows ZIP from this repository's Releases page and extract it completely.
2. Run `Setup.cmd` as your normal Windows user. Administrator privileges are not required.
3. Connect your AirPods and use the shortcuts below. Mode starts **off**.

The installer copies the app to `%LOCALAPPDATA%\AirPodsQuickMode\app`, adds Start menu entries and an Installed Apps entry, and creates an `AirPodsQuickMode-<user SID>` scheduled task unique to the current Windows user. The task starts the app at sign-in and relaunches it within a minute if it exits. It runs on battery, only while you are signed in. Task Scheduler must be available; organizational policies may block task registration.

For portable use, run `Start.cmd` instead. Portable mode adds no startup task; settings and diagnostic logs still live in `%LOCALAPPDATA%\AirPodsQuickMode\data`.

Unsigned builds may trigger Windows reputation warnings. These releases are not code-signed. Verify the downloaded ZIP with the adjacent SHA-256 file: `Get-FileHash .\AirPodsQuickMode-0.1.0-windows.zip -Algorithm SHA256`.

## Shortcuts

| Default shortcut | Action |
| --- | --- |
| Ctrl+Alt+F9 | Toggle quick mode |
| Ctrl+Alt+F10 | Speak current status |
| Ctrl+Alt+F11 | Turn mode off, keeping shortcuts active |

Open `Settings.cmd`, the Start menu Settings entry, or Settings from the tray icon. All controls are keyboard accessible and labeled for screen readers. Choose a microphone, distinct F1–F24 keys, modifier combination, Turkish/English UI, and spoken feedback. Saving settings turns mode off. Shortcuts in use by other programs are rejected; choose another combination. Settings changes are sent to an existing app instance rather than starting a second copy.

Automatic selection requires exactly one input device whose name contains `AirPods`. If it fails, choose the headset microphone explicitly. Selecting a laptop microphone will not switch the AirPods profile. Connect/reconnect the headset before opening Settings to refresh the device list. Windows' legacy audio API may truncate device names; identically named devices cannot be distinguished by this version.

The output device is not changed by this app. Configure your screen reader to play through your AirPods. If another app keeps the microphone open, turning quick mode off may leave the call profile active. On disconnect or capture failure, mode turns off; reconnect and toggle it on again. HFP is requested through microphone use; the application does not measure the actual Bluetooth profile or end-to-end latency.

## Privacy and battery

Microphone samples stay in short-lived native memory buffers and are discarded. No audio recording, audio playback, network requests, telemetry, or administrator access is used. Windows displays its microphone-use indicator while mode is active. Logs contain timestamps, device names and errors; review them before sharing. Logs are capped at approximately 1 MB. Keeping the microphone open can increase battery consumption. Startup does not enable quick mode automatically.

## Uninstall and update

Run `Uninstall.cmd` in the installed app folder, or uninstall **AirPods Quick Mode** through Windows Installed Apps. This removes the scheduled task, menu entries and app files. Settings/logs are preserved. To remove those too, run the installed `uninstall.ps1 -RemoveSettings` before uninstalling. The uninstaller refuses to remove a task pointing to a different installation.

To update, extract the new ZIP and run `Setup.cmd` again. Settings are retained. Exit any manually launched portable copy before installing. The installer updates the current user's task and migrates the original prototype's task when owned by the same user. Only one app copy runs per session.

## Build and test

No NuGet packages or external SDK downloads are needed on a Windows machine with .NET Framework 4.8:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build.ps1 -Version 0.1.0
```

Output: `dist/AirPodsQuickMode-0.1.0-windows.zip` and its `.sha256` file. The build runs a hardware-independent settings self-test. The scripts compile using the Windows .NET Framework C# compiler and System.Speech assembly. `--self-test`, `--devices`, and `--test` exit with a nonzero code on failure and write to the diagnostic log. `--test` actually opens the selected microphone for several seconds; do not run it alongside an active capture session.

Before a public release, perform [the manual checks](TESTING.md) on real devices. CI cannot validate Bluetooth audio or human-perceived latency.

## GitHub Releases

After adding your remote and pushing the repository, create a version tag such as `v0.1.0`. The release workflow compiles a matching version and creates a **draft** release with the ZIP, SHA-256 checksum and release notes. Review the assets and device tests, then publish the draft. Regular pushes and pull requests build packages as CI artifacts. Update `CHANGELOG.md`, `RELEASE_NOTES.md`, and the default version in `scripts/build.ps1` for subsequent releases. A signing certificate can be added later; signing is not currently configured.

Technical basis: [Microsoft Bluetooth Classic Audio](https://learn.microsoft.com/en-us/windows-hardware/drivers/bluetooth/bluetooth-classic-audio). This project is independent of Apple and Microsoft.

License: [MIT](LICENSE).
