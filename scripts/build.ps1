param([string]$Version = '0.1.0')
$ErrorActionPreference = 'Stop'
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Version must use major.minor.patch.' }
$projectRoot = Split-Path $PSScriptRoot
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (!(Test-Path $compiler)) { $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
if (!(Test-Path $compiler)) { throw '.NET Framework compiler not found. Windows 10/11 with .NET Framework 4.8 is required.' }
$speechDll = Get-ChildItem (Join-Path $env:WINDIR 'Microsoft.NET\assembly\GAC_MSIL\System.Speech') -Filter System.Speech.dll -Recurse | Select-Object -First 1 -ExpandProperty FullName
if (!$speechDll) { throw 'System.Speech.dll not found.' }
$package = Join-Path $projectRoot "dist\HearSwift-$Version-windows"
New-Item -ItemType Directory -Force $package | Out-Null
$source = Get-Content (Join-Path $projectRoot 'src\HearSwift.cs') -Raw -Encoding UTF8
$source = $source.Replace('0.1.0.0', "$Version.0").Replace('version 0.1.0', "version $Version")
$buildSource = Join-Path $package 'build-source.cs'
[IO.File]::WriteAllText($buildSource, $source, [Text.UTF8Encoding]::new($true))
try {
    & $compiler /nologo /optimize+ /target:winexe /platform:anycpu "/out:$package\HearSwift.exe" /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.Runtime.Serialization.dll "/reference:$speechDll" $buildSource
    if ($LASTEXITCODE -ne 0) { throw 'Compilation failed.' }
} finally { Remove-Item -LiteralPath $buildSource -ErrorAction SilentlyContinue }
Copy-Item (Join-Path $projectRoot 'scripts\install.ps1'),(Join-Path $projectRoot 'scripts\uninstall.ps1') -Destination $package -Force
Copy-Item (Join-Path $projectRoot 'README.md'),(Join-Path $projectRoot 'README.tr.md'),(Join-Path $projectRoot 'LICENSE'),(Join-Path $projectRoot 'CHANGELOG.md') -Destination $package -Force
Copy-Item (Join-Path $projectRoot 'CONTRIBUTING.md'),(Join-Path $projectRoot 'TESTING.md'),(Join-Path $projectRoot 'VALIDATION.md'),(Join-Path $projectRoot 'RELEASE_NOTES.md') -Destination $package -Force
Copy-Item (Join-Path $projectRoot 'launchers\*') -Destination $package -Force
$test = Start-Process -FilePath (Join-Path $package 'HearSwift.exe') -ArgumentList '--self-test' -Wait -PassThru -WindowStyle Hidden
if ($test.ExitCode -ne 0) { throw 'Application self-test failed.' }
$zip = "$package.zip"
$releaseNames = @('HearSwift.exe','install.ps1','uninstall.ps1','README.md','README.tr.md','LICENSE','CHANGELOG.md','CONTRIBUTING.md','TESTING.md','VALIDATION.md','RELEASE_NOTES.md','Start.cmd','Settings.cmd','Uninstall.cmd','Setup.cmd')
$releaseFiles = @($releaseNames | ForEach-Object { Join-Path $package $_ })
Compress-Archive -LiteralPath $releaseFiles -DestinationPath $zip -Force
$hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText("$zip.sha256", "$hash  $([IO.Path]::GetFileName($zip))`n", [Text.UTF8Encoding]::new($false))
Write-Output "Package: $zip"
Write-Output "SHA256: $hash"
