## HearSwift 0.1.0 — first experimental release

HearSwift grew out of a screen reader user's experience: Bluetooth audio was clear but each keypress felt delayed; entering a meeting reduced quality yet made navigation feel responsive. This release makes the headset call profile available through keyboard shortcuts, without joining a call.

Download and extract the Windows ZIP, then run Setup.cmd for installation or Start.cmd for portable use. See README.tr.md for Turkish instructions.

Default shortcuts: Ctrl+Alt+F9 toggle, Ctrl+Alt+F10 status, Ctrl+Alt+F11 off. F11 keeps the listener active. Settings.cmd opens microphone, shortcut, language and speech preferences.

The app opens the selected microphone to request the call profile. Audio is discarded in memory; no audio recording or transmission occurs. Quality may drop and battery use may increase. Latency improvement varies by device. Tested initially with AirPods 3 on Windows 11 25H2; broader compatibility remains unverified. Other Bluetooth Classic HFP headsets can be selected in Settings for testing; automatic selection currently searches for AirPods only.

Installation enables logon startup and automatic restart within one minute. Mode starts off. Builds are unsigned; a SHA-256 checksum is attached. This is an independent project, unaffiliated with Apple or Microsoft.

### Included

- Keyboard toggle, spoken status and off-only shortcut; the listener stays alive after F11.
- Turkish/English settings, manual microphone selection and configurable shortcuts.
- Per-user setup, uninstall, background startup and automatic recovery.
- Portable usage, MIT-licensed source, ZIP distribution and SHA-256 checksum.
- Migration from the original AirPods Quick Mode prototype.

### Known limits

No universal latency, compatibility or battery-life claim is made. Installed capture and shortcut tests passed with AirPods 3. Objective latency measurement, a fresh listening comparison, broader device testing, and a reboot/sign-in test remain on the manual checklist. This prerelease does not replace Bluetooth drivers or fix pairing/interference issues. See VALIDATION.md for the test record.
