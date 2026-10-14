param([switch]$RemoveSettings)
$ErrorActionPreference = 'Stop'
$expectedDir = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'HearSwift\app'))
$exe = Join-Path $expectedDir 'HearSwift.exe'
$taskName = 'HearSwift-' + [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($task) {
    $owned = @($task.Actions | Where-Object { $_.Execute -eq $exe }).Count -gt 0
    if (!$owned) { throw 'The scheduled task points to another installation. No changes made.' }
    Disable-ScheduledTask -TaskName $taskName | Out-Null
    Stop-ScheduledTask -TaskName $taskName
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}
Get-Process -Name HearSwift -ErrorAction SilentlyContinue | ForEach-Object { if ($_.Path -eq $exe) { Stop-Process -Id $_.Id -Force } }
# Remove only named application files, never recursively delete a computed directory.
$files = @('HearSwift.exe','install.ps1','uninstall.ps1','README.md','README.tr.md','LICENSE','CHANGELOG.md','CONTRIBUTING.md','TESTING.md','VALIDATION.md','RELEASE_NOTES.md','Start.cmd','Settings.cmd','Uninstall.cmd','Setup.cmd')
foreach ($file in $files) {
    $target = [IO.Path]::GetFullPath((Join-Path $expectedDir $file))
    if ([IO.Path]::GetDirectoryName($target) -ne $expectedDir) { throw 'Unsafe uninstall path.' }
    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Force }
}
if ((Test-Path $expectedDir) -and @(Get-ChildItem -LiteralPath $expectedDir -Force).Count -eq 0) { Remove-Item -LiteralPath $expectedDir }
$menuDir = Join-Path ([Environment]::GetFolderPath('Programs')) 'HearSwift'
foreach ($name in @('HearSwift.lnk','HearSwift Settings.lnk')) {
    $link = Join-Path $menuDir $name
    if (Test-Path -LiteralPath $link) { Remove-Item -LiteralPath $link }
}
if ((Test-Path $menuDir) -and @(Get-ChildItem -LiteralPath $menuDir -Force).Count -eq 0) { Remove-Item -LiteralPath $menuDir }
Remove-Item -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\HearSwift' -ErrorAction SilentlyContinue
if ($RemoveSettings) {
    $dataDir = Join-Path $env:LOCALAPPDATA 'HearSwift\data'
    foreach ($pattern in @('settings.json','settings.json.tmp','status.log','status.log.*.old','devices.txt')) {
        Get-ChildItem -LiteralPath $dataDir -Filter $pattern -File -ErrorAction SilentlyContinue | Remove-Item -Force
    }
}
Write-Host 'Uninstalled. Settings are preserved unless -RemoveSettings was supplied.'
