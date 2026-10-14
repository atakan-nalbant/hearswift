param([Parameter(Mandatory=$true)][string]$ReportPath,[switch]$AllowMissingDevice)
$ErrorActionPreference='Stop'
$exe = Join-Path $env:LOCALAPPDATA 'HearSwift\app\HearSwift.exe'
$log = Join-Path $env:LOCALAPPDATA 'HearSwift\data\status.log'
$taskName = 'HearSwift-' + [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
try {
    $keys = New-Object -ComObject WScript.Shell
    $keys.SendKeys('^%{F11}'); Start-Sleep -Milliseconds 600
    $probe=Start-Process -FilePath $exe -ArgumentList '--devices' -WindowStyle Hidden -Wait -PassThru
    if ($probe.ExitCode -ne 0) { throw 'Device enumeration failed.' }
    $hasAirPods = @(Get-Content (Join-Path $env:LOCALAPPDATA 'HearSwift\data\devices.txt') | Where-Object { $_ -match 'AirPods' }).Count -gt 0
    if (!$hasAirPods -and !$AllowMissingDevice) { throw 'Connect AirPods or pass -AllowMissingDevice to test the disconnected error path.' }
    if ($hasAirPods) {
        $probe=Start-Process -FilePath $exe -ArgumentList '--test' -WindowStyle Hidden -Wait -PassThru
        if ($probe.ExitCode -ne 0) { throw 'Microphone open/receive/release test failed.' }
    }
    $before = @(Get-Content $log).Count
    $keys.SendKeys('^%{F9}'); Start-Sleep -Seconds 3
    $keys.SendKeys('^%{F11}'); Start-Sleep -Milliseconds 400
    $keys.SendKeys('^%{F9}'); Start-Sleep -Seconds 3
    $keys.SendKeys('^%{F10}'); Start-Sleep -Milliseconds 500
    $keys.SendKeys('^%{F11}'); Start-Sleep -Milliseconds 500
    $tail = @(Get-Content $log | Select-Object -Skip $before)
    if ($hasAirPods) {
        if (@($tail | Where-Object { $_ -match 'ON: headset capture active' }).Count -ne 2) { throw 'Toggle/off/toggle sequence did not produce two active captures.' }
        if (@($tail | Where-Object { $_ -match 'STATUS ON' }).Count -ne 1) { throw 'Status shortcut failed.' }
    } else {
        if (@($tail | Where-Object { $_ -match 'Microphone not found' }).Count -ne 2) { throw 'Expected two actionable missing-device errors.' }
        if (@($tail | Where-Object { $_ -match 'STATUS OFF' }).Count -ne 1) { throw 'Status must remain OFF without AirPods.' }
    }
    $processes = @(Get-Process HearSwift -ErrorAction SilentlyContinue | Where-Object { $_.SessionId -eq (Get-Process -Id $PID).SessionId })
    if ($processes.Count -ne 1 -or $processes[0].Path -ne $exe) { throw 'Expected exactly one installed app process.' }
    if ((Get-ScheduledTask -TaskName $taskName).State -ne 'Running') { throw 'Scheduled application is not running.' }
    $result=if($hasAirPods) { 'PASS: microphone data received and released; F9/F11/F9/status/off; one installed process; scheduled launch verified.' } else { 'PASS: disconnected-device errors; F11 listener stays active; status OFF; one installed process; scheduled launch. Hardware capture skipped: AirPods disconnected.' }
    @($result) + $tail | Set-Content -LiteralPath $ReportPath -Encoding UTF8
} catch { $_ | Out-String | Set-Content -LiteralPath $ReportPath -Encoding UTF8; exit 1 }
