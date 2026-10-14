# Contributing to HearSwift

HearSwift started as an accessibility workaround for delayed screen reader feedback over Bluetooth. The most useful contributions help establish which combinations of headset, Windows build, Bluetooth adapter and screen reader benefit from it.

## Report an issue or a device result

Open a GitHub issue and include:

- HearSwift version and whether it was installed or run portably.
- Windows edition/version/build, headset model, and Bluetooth adapter/driver if known.
- Screen reader and version, plus the output device it uses.
- Exact steps, expected behavior, and actual behavior.
- Whether delay happens after every keypress or only when audio starts after silence.
- A comparison with quick mode off and on, and whether you hear the call-quality change.

Describe response changes as subjective unless you measured them. Do not generalize one device's result to all Bluetooth headsets. Diagnostic logs are in `%LOCALAPPDATA%\HearSwift\data`; review device names and other personal details before attaching them. Do not attach microphone recordings.

## Develop

Create a branch and keep changes focused. On Windows, build with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build.ps1
```

No external SDK or NuGet download is needed with .NET Framework 4.8 installed. The build includes a hardware-independent settings self-test. Follow [TESTING.md](TESTING.md) for changes involving audio, shortcuts, installation or startup. Keep user-facing English and Turkish text consistent, preserve keyboard access and screen reader labels, and document hardware-dependent behavior rather than assuming it passed in CI.

The maintainer-only `scripts/test-installed.ps1 -ReportPath <file>` drives the default global shortcuts and opens the microphone. Run it in your interactive user session only when you are ready for those changes. `-AllowMissingDevice` tests the disconnected-headset path if no AirPods microphone is present. It does not currently automate manually selected non-AirPods devices.

## Prepare a release

1. Update CHANGELOG.md, RELEASE_NOTES.md, and the build's default version.
2. Run the build and relevant manual checks; record known limitations in VALIDATION.md.
3. Tag the reviewed commit as `vMAJOR.MINOR.PATCH` and push that tag.
4. Wait for the draft-release workflow, verify its ZIP/checksum, and review the notes before publishing.

The workflow packages only that version's files. Draft releases are marked prerelease until the project establishes wider compatibility.
