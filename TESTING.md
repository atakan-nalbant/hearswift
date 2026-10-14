# Release verification

Record the Windows version, headset model, app version, and result. Automated checks cannot establish perceived latency or Bluetooth profile selection.

- Build and checksum generation; hardware-independent self-test must pass.
- Launch without AirPods: starts OFF, no microphone access until requested; toggle reports an actionable error and stays alive.
- Connect AirPods, toggle ON; compare screen reader response to OFF and verify the microphone indicator.
- F11 followed immediately by F9 must work without restarting the application.
- Read status and verify one process remains after repeatedly launching Start.cmd.
- Open Settings via Settings.cmd while running; tab through every control with a screen reader.
- Save a different microphone/key combination; old shortcuts are released, new ones work. Duplicate/reserved-in-use shortcuts must be rejected without losing prior settings.
- Verify Turkish and English feedback, speech disabled, and restored settings after restart.
- Disconnect/reconnect while ON; mode stops on capture failure; toggling after reconnection works.
- Run Setup.cmd as a standard user. Verify installed files, Start menu links, Installed Apps entry and the scheduled task.
- Exit the app; scheduled relaunch occurs within one minute. Sign out/in to verify logon startup; mode remains OFF.
- Install an update; retain settings and avoid duplicate active processes.
- Uninstall from Installed Apps. Verify the task, app files and shortcuts are removed; the process does not restart.
- Test additional Windows versions and headset models before expanding compatibility claims.

## Local verification, 2026-10-14

Prototype: Windows 11 25H2 build 26200.9457, AirPods 3. Microphone buffers received; open/release and shortcut sequences verified. No objective end-to-end latency measurement was performed. Public-package checks are recorded in VALIDATION.md.
