$adUser = Get-ADUser -Identity $env:USERNAME -Properties HomeDirectory
$NetworkLocationPath = $adUser.HomeDirectory

if (-not $NetworkLocationPath) { exit }

$DisplayName = "Mon Dossier Personnel"
$ShellApp = New-Object -ComObject Shell.Application
$NetworkFolder = $ShellApp.Namespace(0x13).Self.Path
$NewLocation = Join-Path -Path $NetworkFolder -ChildPath $DisplayName

if (Test-Path "$NewLocation\target.lnk") { exit }

New-Item -Path $NewLocation -ItemType Directory -Force | Out-Null

$DesktopIniContent = @"
[.ShellClassInfo]
CLSID2={0AFACED1-E828-11D1-9187-B532F1E9575D}
Flags=2
"@

$DesktopIniPath = Join-Path -Path $NewLocation -ChildPath "Desktop.ini"
$DesktopIniContent | Out-File -FilePath $DesktopIniPath -Encoding Unicode

$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut("$NewLocation\target.lnk")
$Shortcut.TargetPath = $NetworkLocationPath
$Shortcut.Save()

Set-ItemProperty -Path $DesktopIniPath -Name Attributes -Value ([System.IO.FileAttributes]::System -bor [System.IO.FileAttributes]::Hidden)
Set-ItemProperty -Path $NewLocation -Name Attributes -Value ([System.IO.FileAttributes]::ReadOnly)
