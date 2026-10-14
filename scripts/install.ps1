param([switch]$NoStart)
$ErrorActionPreference = 'Stop'
$installDir = Join-Path $env:LOCALAPPDATA 'HearSwift\app'
$exe = Join-Path $installDir 'HearSwift.exe'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$taskName = 'HearSwift-' + $identity.User.Value
if (!(Test-Path (Join-Path $PSScriptRoot 'HearSwift.exe'))) { throw 'Run install.ps1 from the extracted release ZIP.' }
# The installation belongs to this Windows user and never requires administrator rights.
$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing -and @($existing.Actions | Where-Object { $_.Execute -eq $exe }).Count -eq 0) { throw 'The startup task belongs to another installation. No changes made.' }
$files = @('HearSwift.exe','install.ps1','uninstall.ps1','README.md','README.tr.md','LICENSE','CHANGELOG.md','CONTRIBUTING.md','TESTING.md','VALIDATION.md','RELEASE_NOTES.md','Start.cmd','Settings.cmd','Uninstall.cmd','Setup.cmd')
foreach ($file in $files) { if (!(Test-Path -LiteralPath (Join-Path $PSScriptRoot $file))) { throw "Incomplete package: $file is missing. Extract the entire release ZIP." } }
$legacyTasks = @()
foreach ($legacyName in @('AirPodsQuickMode', ('AirPodsQuickMode-' + $identity.User.Value))) {
    $legacy = Get-ScheduledTask -TaskName $legacyName -ErrorAction SilentlyContinue
    if (!$legacy) { continue }
    try {
        $legacyUser = $legacy.Principal.UserId
        $legacySid = if ($legacyUser -like 'S-1-*') { $legacyUser } else { ([Security.Principal.NTAccount]::new($legacyUser)).Translate([Security.Principal.SecurityIdentifier]).Value }
        if ($legacySid -eq $identity.User.Value -and @($legacy.Actions | Where-Object { [IO.Path]::GetFileName($_.Execute) -eq 'AirPodsQuickMode.exe' }).Count -gt 0) { $legacyTasks += $legacy }
    } catch { continue }
}
$legacyPaths = @($legacyTasks | ForEach-Object { $_.Actions } | ForEach-Object Execute)
$sessionId = (Get-Process -Id $PID).SessionId
$running = @(Get-Process -Name HearSwift,AirPodsQuickMode -ErrorAction SilentlyContinue | Where-Object { $_.SessionId -eq $sessionId })
foreach ($process in $running) {
    if ($process.Path -ne $exe -and $process.Path -notin $legacyPaths) { throw 'Close the running portable copy from its tray menu before installing.' }
}
foreach ($legacy in $legacyTasks) { Disable-ScheduledTask -TaskName $legacy.TaskName | Out-Null; Stop-ScheduledTask -TaskName $legacy.TaskName }
if ($existing) {
    Disable-ScheduledTask -TaskName $taskName | Out-Null
    Stop-ScheduledTask -TaskName $taskName
}
Get-Process -Name HearSwift,AirPodsQuickMode -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.SessionId -eq $sessionId -and ($_.Path -eq $exe -or $_.Path -in $legacyPaths)) {
        Stop-Process -Id $_.Id -Force
        if (!$_.WaitForExit(5000)) { throw 'The existing app did not exit. Close it before updating.' }
    }
}
New-Item -ItemType Directory -Force $installDir | Out-Null
try {
    foreach ($file in $files) {
        $sourceFile = Join-Path $PSScriptRoot $file
        $targetFile = Join-Path $installDir $file
        if ([IO.Path]::GetFullPath($sourceFile) -ne [IO.Path]::GetFullPath($targetFile)) {
            # Task/process termination can return before Windows releases the executable image.
            for ($copyAttempt=0; $copyAttempt -lt 15; $copyAttempt++) {
                try { Copy-Item -LiteralPath $sourceFile -Destination $targetFile -Force -ErrorAction Stop; break }
                catch [IO.IOException] { if ($copyAttempt -eq 14) { throw }; Start-Sleep -Milliseconds 300 }
            }
        }
    }
    $user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $action = New-ScheduledTaskAction -Execute $exe -WorkingDirectory $installDir
    $logon = New-ScheduledTaskTrigger -AtLogOn -User $user
    $watch = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1)
    $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
    $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger @($logon,$watch) -Settings $settings -Principal $principal -Description 'HearSwift: starts at sign-in and restarts within one minute if closed. Quick mode starts OFF.' -Force | Out-Null
    $shell = New-Object -ComObject WScript.Shell
    $menuDir = Join-Path ([Environment]::GetFolderPath('Programs')) 'HearSwift'
    New-Item -ItemType Directory -Force $menuDir | Out-Null
    foreach ($item in @(@('HearSwift',''),@('HearSwift Settings','--settings'))) {
        $link = $shell.CreateShortcut((Join-Path $menuDir ($item[0]+'.lnk')))
        $link.TargetPath=$exe; $link.Arguments=$item[1]; $link.WorkingDirectory=$installDir; $link.Save()
    }
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\HearSwift'
    New-Item -Path $key -Force | Out-Null
    $uninstallScript = Join-Path $installDir 'uninstall.ps1'
    $uninstallCommand = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' + $uninstallScript + '"'
    $props = @{DisplayName='HearSwift'; DisplayVersion=(Get-Item $exe).VersionInfo.FileVersion; Publisher='HearSwift contributors'; InstallLocation=$installDir; DisplayIcon=$exe; UninstallString=$uninstallCommand; NoModify=1; NoRepair=1}
    foreach ($name in $props.Keys) { Set-ItemProperty -Path $key -Name $name -Value $props[$name] }
    if (!$NoStart) {
        Start-ScheduledTask -TaskName $taskName
        $started = $false
        for ($attempt=0; $attempt -lt 10; $attempt++) {
            Start-Sleep -Milliseconds 500
            $started = @(Get-Process -Name HearSwift -ErrorAction SilentlyContinue | Where-Object { $_.SessionId -eq $sessionId -and $_.Path -eq $exe }).Count -gt 0
            if ($started) { break }
        }
        if (!$started) { throw 'The installed app did not start. Check Task Scheduler and microphone/app permissions. Installation files were preserved for diagnosis.' }
    }
    foreach ($legacy in $legacyTasks) { Unregister-ScheduledTask -TaskName $legacy.TaskName -Confirm:$false }
    # Remove only the former product's menu/registration; retain its files/settings for rollback.
    $oldMenu = Join-Path ([Environment]::GetFolderPath('Programs')) 'AirPods Quick Mode'
    foreach ($oldLink in @('AirPods Quick Mode.lnk','AirPods Quick Mode Settings.lnk')) {
        $oldLinkPath = Join-Path $oldMenu $oldLink
        if (Test-Path -LiteralPath $oldLinkPath) { Remove-Item -LiteralPath $oldLinkPath }
    }
    if ((Test-Path $oldMenu) -and @(Get-ChildItem -LiteralPath $oldMenu -Force).Count -eq 0) { Remove-Item -LiteralPath $oldMenu }
    $oldRegistration = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\AirPodsQuickMode'
    if (Test-Path -LiteralPath $oldRegistration) { Remove-Item -LiteralPath $oldRegistration }
    Write-Host "Installed: $installDir"
    Write-Host 'Starts at sign-in; restarts within one minute. Ctrl+Alt+F9 toggles; F10 reads status; F11 turns mode off.'
} catch {
    if ($existing) { Register-ScheduledTask -TaskName $taskName -InputObject $existing -Force | Out-Null; Enable-ScheduledTask -TaskName $taskName | Out-Null }
    foreach ($legacy in $legacyTasks) {
        Register-ScheduledTask -TaskName $legacy.TaskName -InputObject $legacy -Force | Out-Null
        Enable-ScheduledTask -TaskName $legacy.TaskName | Out-Null
        Start-ScheduledTask -TaskName $legacy.TaskName
    }
    throw
}
