Import-Module ActiveDirectory
Import-Module GroupPolicy

# =============================================================================
# Configuration
# =============================================================================
$gpoName = "GPO_Emplacement_Home"
$ouTarget = "OU=Fournil,DC=ad,DC=fournil,DC=lab"
$domainName = "ad.fournil.lab"
$scriptName = "Set-NetworkLocation.ps1"

# =============================================================================
# PHASE 1 : Créer le script de connexion
# =============================================================================
Write-Host "`n=============================================" -ForegroundColor Blue
Write-Host "PHASE 1 : Script de connexion" -ForegroundColor Blue
Write-Host "=============================================`n" -ForegroundColor Blue

$scriptContent = @'
# Windows PowerShell sur le client : interrogation LDAP, sans module RSAT AD.
$loginLdap = $env:USERNAME.Replace('\', '\5c').Replace('*', '\2a').Replace('(', '\28').Replace(')', '\29')
$searcher = New-Object System.DirectoryServices.DirectorySearcher
$searcher.Filter = "(&(objectCategory=person)(objectClass=user)(sAMAccountName=$loginLdap))"
[void]$searcher.PropertiesToLoad.Add('homeDirectory')
try {
    $result = $searcher.FindOne()
    if (-not $result -or $result.Properties['homedirectory'].Count -eq 0) { exit }
    $NetworkLocationPath = [string]$result.Properties['homedirectory'][0]
} finally {
    $searcher.Dispose()
}

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
'@

$localScriptPath = "C:\Deploy\$scriptName"
if (-not (Test-Path $localScriptPath)) {
    $scriptContent | Out-File -FilePath $localScriptPath -Encoding UTF8
    Write-Host "  [+] Script '$scriptName' créé dans C:\Deploy\" -ForegroundColor Green
} else {
    Write-Host "  [=] Script '$scriptName' existe déjà dans C:\Deploy\" -ForegroundColor Yellow
}

# =============================================================================
# PHASE 2 : Créer la GPO et la lier à l'OU
# =============================================================================
Write-Host "`n=============================================" -ForegroundColor Blue
Write-Host "PHASE 2 : Création et liaison de la GPO" -ForegroundColor Blue
Write-Host "=============================================`n" -ForegroundColor Blue

$existingGPO = Get-GPO -Name $gpoName -ErrorAction SilentlyContinue
if (-not $existingGPO) {
    $gpo = New-GPO -Name $gpoName -Comment "Script de connexion pour créer un emplacement réseau vers le dossier personnel"
    Write-Host "  [+] GPO '$gpoName' créée" -ForegroundColor Green
} else {
    $gpo = $existingGPO
    Write-Host "  [=] GPO '$gpoName' existe déjà" -ForegroundColor Yellow
}

# Lier la GPO à l'OU
$existingLink = Get-GPInheritance -Target $ouTarget | Select-Object -ExpandProperty GpoLinks | Where-Object { $_.DisplayName -eq $gpoName }
if (-not $existingLink) {
    New-GPLink -Name $gpoName -Target $ouTarget -LinkEnabled Yes | Out-Null
    Write-Host "  [+] GPO liée à '$ouTarget'" -ForegroundColor Green
} else {
    Write-Host "  [=] GPO déjà liée à '$ouTarget'" -ForegroundColor Yellow
}

# =============================================================================
# PHASE 3 : Copier le script dans le SYSVOL de la GPO
# =============================================================================
Write-Host "`n=============================================" -ForegroundColor Blue
Write-Host "PHASE 3 : Déploiement du script dans SYSVOL" -ForegroundColor Blue
Write-Host "=============================================`n" -ForegroundColor Blue

$gpoId = $gpo.Id.ToString("B").ToUpper()
$sysvolScriptPath = "\\$domainName\SYSVOL\$domainName\Policies\$gpoId\User\Scripts\Logon"

if (-not (Test-Path $sysvolScriptPath)) {
    New-Item -Path $sysvolScriptPath -ItemType Directory -Force | Out-Null
    Write-Host "  [+] Dossier SYSVOL Logon créé" -ForegroundColor Green
}

$destScript = Join-Path $sysvolScriptPath $scriptName
if (-not (Test-Path $destScript)) {
    Copy-Item -Path $localScriptPath -Destination $destScript -Force
    Write-Host "  [+] Script copié dans SYSVOL" -ForegroundColor Green
} else {
    Write-Host "  [=] Script déjà présent dans SYSVOL" -ForegroundColor Yellow
}

# =============================================================================
# PHASE 4 : Enregistrer le script comme script de connexion
# =============================================================================
Write-Host "`n=============================================" -ForegroundColor Blue
Write-Host "PHASE 4 : Enregistrement du script de connexion" -ForegroundColor Blue
Write-Host "=============================================`n" -ForegroundColor Blue

# Le fichier psscripts.ini référence les scripts PowerShell de connexion
$psScriptsIniPath = "\\$domainName\SYSVOL\$domainName\Policies\$gpoId\User\Scripts\psscripts.ini"

$iniContent = @"

[Logon]
0CmdLine=$scriptName
0Parameters=
"@

if (-not (Test-Path $psScriptsIniPath)) {
    $iniContent | Out-File -FilePath $psScriptsIniPath -Encoding Unicode
    Write-Host "  [+] psscripts.ini créé — script de connexion enregistré" -ForegroundColor Green
} else {
    $existingContent = Get-Content $psScriptsIniPath -Raw -ErrorAction SilentlyContinue
    if ($existingContent -match [regex]::Escape($scriptName)) {
        Write-Host "  [=] Script de connexion déjà enregistré dans psscripts.ini" -ForegroundColor Yellow
    } else {
        Add-Content -Path $psScriptsIniPath -Value "`n[Logon]`n0CmdLine=$scriptName`n0Parameters=" -Encoding Unicode
        Write-Host "  [+] Script de connexion ajouté à psscripts.ini" -ForegroundColor Green
    }
}

# =============================================================================
# RÉSUMÉ
# =============================================================================
Write-Host "`n=============================================" -ForegroundColor Blue
Write-Host "RÉSUMÉ" -ForegroundColor Blue
Write-Host "=============================================" -ForegroundColor Blue
Write-Host "  GPO           : $gpoName" -ForegroundColor White
Write-Host "  Liée à        : $ouTarget" -ForegroundColor White
Write-Host "  Script        : $scriptName" -ForegroundColor White
Write-Host "  SYSVOL        : $destScript" -ForegroundColor White
Write-Host ""
Write-Host "  A la connexion, chaque utilisateur verra :" -ForegroundColor Cyan
Write-Host "  'Mon Dossier Personnel' dans les emplacements réseau" -ForegroundColor Cyan
Write-Host "  pointant vers \\$domainName\HOMES\<Entite>\<Login>" -ForegroundColor Cyan
Write-Host "=============================================`n" -ForegroundColor Blue
