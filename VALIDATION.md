# Validation — 2026-10-15

Environment: Windows 11 Home Single Language 25H2, build 26200.9457, .NET Framework compiler. AirPods 3 was available during the initial capture test and disconnected during the final installed-package test.

Verified locally:

- Compilation/package generation under both PowerShell 7 and Windows PowerShell 5.1 (the latter matches the CI shell).
- Hardware-independent self-test: duplicate shortcuts rejected; Unicode settings serialization roundtrip; modifier/key formatting.
- Release archive contains exactly the 11 intended files; SHA-256 matches; no settings, diagnostic logs, Git metadata or machine-specific scheduled-task exports included.
- Public application capture implementation opened AirPods, received 41 nonempty buffers and released the microphone during the earlier direct hardware probe. This preceded final installation checks; it is not a substitute for a final connected-device test.
- Turkish settings dialog rendered and inspected: controls visible, distinct labels and keyboard access names; full screen-reader navigation is still a manual check.
- Installation in the actual interactive Windows user session: per-user app files, Start menu and Installed Apps entries, SID-specific scheduled task, successful scheduled application launch.
- Uninstall removed the executable, active process, scheduled task and Installed Apps registration. Reinstall succeeded and restored Turkish settings.
- Forced termination followed by automatic scheduled recovery in 55 seconds.
- Installed app while AirPods was disconnected: F9 reports missing microphone; F11 keeps listener active; immediate F9 works again; F10 reports OFF; exactly one app process remains. Fast mode stays off.

Execution environment note: automation-created LocalAppData files were initially visible only in the automation process context, so direct scheduled launch returned file-not-found. Installation was rerun through a temporary scheduled installer in the real interactive user context; scheduled launch and lifecycle tests then passed. The temporary test task was removed. No workaround or machine-specific path is embedded in the product.

Not yet verified:

- Final installed version with connected AirPods, including perceived latency comparison and physical unplug/reconnect during active capture.
- Sign out/sign in or reboot. Logon trigger configuration was inspected; no user session was interrupted.
- Other headset models, other Windows versions, ARM, restrictive enterprise policies, or a separate clean computer.
- GitHub-hosted CI/release execution, which requires the remote repository to be provided.
- Code signing, which is not configured.
