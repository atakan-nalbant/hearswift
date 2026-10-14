param([switch]$NoStart)
$ErrorActionPreference = 'Stop'
$installDir = Join-Path $env:LOCALAPPDATA 'AirPodsQuickMode\app'
$exe = Join-Path $installDir 'AirPodsQuickMode.exe'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$taskName = 'AirPodsQuickMode-' + $identity.User.Value
if (!(Test-Path (Join-Path $PSScriptRoot 'AirPodsQuickMode.exe'))) { throw 'Run install.ps1 from the extracted release ZIP.' }
# The installation belongs to this Windows user and never requires administrator rights.
$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing -and @($existing.Actions | Where-Object { $_.Execute -eq $exe }).Count -eq 0) { throw 'The startup task belongs to another installation. No changes made.' }
$legacy = Get-ScheduledTask -TaskName 'AirPodsQuickMode' -ErrorAction SilentlyContinue
if ($legacy) {
    try {
        $legacyUser = $legacy.Principal.UserId
        $legacySid = if ($legacyUser -like 'S-1-*') { $legacyUser } else { ([Security.Principal.NTAccount]::new($legacyUser)).Translate([Security.Principal.SecurityIdentifier]).Value }
        if ($legacySid -ne $identity.User.Value) { $legacy = $null }
    } catch { $legacy = $null }
}
if ($legacy -and @($legacy.Actions | Where-Object { [IO.Path]::GetFileName($_.Execute) -eq 'AirPodsQuickMode.exe' }).Count -eq 0) { $legacy = $null }
$legacyPaths = @(); if ($legacy) { $legacyPaths = @($legacy.Actions | ForEach-Object Execute) }
$sessionId = (Get-Process -Id $PID).SessionId
$running = @(Get-Process -Name AirPodsQuickMode -ErrorAction SilentlyContinue | Where-Object { $_.SessionId -eq $sessionId })
foreach ($process in $running) {
    if ($process.Path -ne $exe -and $process.Path -notin $legacyPaths) { throw 'Close the running portable copy from its tray menu before installing.' }
}
if ($legacy) { Disable-ScheduledTask -TaskName 'AirPodsQuickMode' | Out-Null; Stop-ScheduledTask -TaskName 'AirPodsQuickMode' }
if ($existing) {
    Disable-ScheduledTask -TaskName $taskName | Out-Null
    Stop-ScheduledTask -TaskName $taskName
}
Get-Process -Name AirPodsQuickMode -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.SessionId -eq $sessionId -and ($_.Path -eq $exe -or $_.Path -in $legacyPaths)) { Stop-Process -Id $_.Id -Force }
}
New-Item -ItemType Directory -Force $installDir | Out-Null
$files = @('AirPodsQuickMode.exe','install.ps1','uninstall.ps1','README.md','README.tr.md','LICENSE','CHANGELOG.md','Start.cmd','Settings.cmd','Uninstall.cmd','Setup.cmd')
try {
    foreach ($file in $files) {
        $sourceFile = Join-Path $PSScriptRoot $file
        $targetFile = Join-Path $installDir $file
        if ([IO.Path]::GetFullPath($sourceFile) -ne [IO.Path]::GetFullPath($targetFile)) { Copy-Item -LiteralPath $sourceFile -Destination $targetFile -Force }
    }
    $user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $action = New-ScheduledTaskAction -Execute $exe -WorkingDirectory $installDir
    $logon = New-ScheduledTaskTrigger -AtLogOn -User $user
    $watch = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1)
    $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
    $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger @($logon,$watch) -Settings $settings -Principal $principal -Description 'AirPods Quick Mode: starts at sign-in and restarts within one minute if closed. Quick mode starts OFF.' -Force | Out-Null
    $shell = New-Object -ComObject WScript.Shell
    $menuDir = Join-Path ([Environment]::GetFolderPath('Programs')) 'AirPods Quick Mode'
    New-Item -ItemType Directory -Force $menuDir | Out-Null
    foreach ($item in @(@('AirPods Quick Mode',''),@('AirPods Quick Mode Settings','--settings'))) {
        $link = $shell.CreateShortcut((Join-Path $menuDir ($item[0]+'.lnk')))
        $link.TargetPath=$exe; $link.Arguments=$item[1]; $link.WorkingDirectory=$installDir; $link.Save()
    }
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\AirPodsQuickMode'
    New-Item -Path $key -Force | Out-Null
    $uninstallScript = Join-Path $installDir 'uninstall.ps1'
    $uninstallCommand = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' + $uninstallScript + '"'
    $props = @{DisplayName='AirPods Quick Mode'; DisplayVersion=(Get-Item $exe).VersionInfo.FileVersion; Publisher='AirPods Quick Mode contributors'; InstallLocation=$installDir; DisplayIcon=$exe; UninstallString=$uninstallCommand; NoModify=1; NoRepair=1}
    foreach ($name in $props.Keys) { Set-ItemProperty -Path $key -Name $name -Value $props[$name] }
    if (!$NoStart) {
        Start-ScheduledTask -TaskName $taskName
        $started = $false
        for ($attempt=0; $attempt -lt 10; $attempt++) {
            Start-Sleep -Milliseconds 500
            $started = @(Get-Process -Name AirPodsQuickMode -ErrorAction SilentlyContinue | Where-Object { $_.SessionId -eq $sessionId -and $_.Path -eq $exe }).Count -gt 0
            if ($started) { break }
        }
        if (!$started) { throw 'The installed app did not start. Check Task Scheduler and microphone/app permissions. Installation files were preserved for diagnosis.' }
    }
    if ($legacy) { Unregister-ScheduledTask -TaskName 'AirPodsQuickMode' -Confirm:$false }
    Write-Host "Installed: $installDir"
    Write-Host 'Starts at sign-in; restarts within one minute. Ctrl+Alt+F9 toggles; F10 reads status; F11 turns mode off.'
} catch {
    if ($existing) { Register-ScheduledTask -TaskName $taskName -InputObject $existing -Force | Out-Null; Enable-ScheduledTask -TaskName $taskName | Out-Null }
    if ($legacy) { Enable-ScheduledTask -TaskName 'AirPodsQuickMode' | Out-Null; Start-ScheduledTask -TaskName 'AirPodsQuickMode' }
    throw
}
