Import-Module ActiveDirectory

# =============================================================================
# Configuration
# =============================================================================
$csvPath = ".\orga-fournil.csv"
$userCsvPath = ".\utilisateurs-fournil.csv"
$domainName = "ad.fournil.lab"
$serverPrincipal = "DC01"
$serverSecondaire = "DC02"
$rootFolder = "C:\fournil"
$homesFolder = "C:\homes"
$dfsRootsFolder = "C:\DFSRoots"
$entites = @("Laboratoire", "Vente")

$csvContent = Import-Csv -Path $csvPath -Delimiter ','
$userCsvContent = Import-Csv -Path $userCsvPath -Delimiter ','

# Compteurs
$script:counts = @{ ShareCreated = 0; ShareExists = 0; DfsRootCreated = 0; DfsRootExists = 0; DfsFolderCreated = 0; DfsFolderExists = 0; DfsTargetCreated = 0; DfsTargetExists = 0; ReplGroupCreated = 0; ReplGroupExists = 0; ReplConnCreated = 0; ReplConnExists = 0; HomeConfigured = 0; HomeExists = 0; FolderCreated = 0; FolderExists = 0; Errors = 0 }

# =============================================================================
# Fonctions utilitaires
# =============================================================================

function New-ShareIfNotExists {
    param (
        [string]$shareName,
        [string]$path,
        [string]$fullAccess = "Tout le monde",
        [string]$readAccess,
        [string]$computerName
    )
    $displayTarget = if ($computerName) { "[$computerName] " } else { "" }
    try {
        if ($computerName) {
            $existing = Invoke-Command -ComputerName $computerName -ScriptBlock {
                param($n) Get-SmbShare -Name $n -ErrorAction SilentlyContinue
            } -ArgumentList $shareName
        } else {
            $existing = Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue
        }
        if ($existing) {
            Write-Host "  [=] ${displayTarget}Partage '$shareName' existe déjà" -ForegroundColor Yellow
            $script:counts.ShareExists++
            return
        }
        if ($computerName) {
            Invoke-Command -ComputerName $computerName -ScriptBlock {
                param($n, $p, $fa) New-SmbShare -Name $n -Path $p -FullAccess $fa
            } -ArgumentList $shareName, $path, $fullAccess | Out-Null
        } elseif ($readAccess) {
            New-SmbShare -Name $shareName -Path $path -FullAccess $fullAccess -ReadAccess $readAccess | Out-Null
        } else {
            New-SmbShare -Name $shareName -Path $path -FullAccess $fullAccess | Out-Null
        }
        Write-Host "  [+] ${displayTarget}Partage '$shareName' créé → $path" -ForegroundColor Green
        $script:counts.ShareCreated++
    } catch {
        Write-Host "  [!] ${displayTarget}Erreur partage '$shareName' : $_" -ForegroundColor Red
        $script:counts.Errors++
    }
}

function New-FolderIfNotExists {
    param (
        [string]$path,
        [string]$computerName
    )
    try {
        if ($computerName) {
            $exists = Invoke-Command -ComputerName $computerName -ScriptBlock {
                param($p) Test-Path $p
            } -ArgumentList $path
            if (-not $exists) {
                Invoke-Command -ComputerName $computerName -ScriptBlock {
                    param($p) New-Item -Path $p -ItemType Directory -Force | Out-Null
                } -ArgumentList $path
                Write-Host "  [+] [$computerName] Dossier '$path' créé" -ForegroundColor Green
                $script:counts.FolderCreated++
            } else {
                $script:counts.FolderExists++
            }
        } else {
            if (-not (Test-Path $path)) {
                New-Item -Path $path -ItemType Directory -Force | Out-Null
                Write-Host "  [+] Dossier '$path' créé" -ForegroundColor Green
                $script:counts.FolderCreated++
            } else {
                $script:counts.FolderExists++
            }
        }
    } catch {
        Write-Host "  [!] Erreur dossier '$path' : $_" -ForegroundColor Red
        $script:counts.Errors++
    }
}

# =============================================================================
# PHASE 1 : Installation des rôles DFS
# =============================================================================
Write-Host "`n=============================================" -ForegroundColor Blue
Write-Host "PHASE 1 : Installation des rôles DFS" -ForegroundColor Blue
Write-Host "=============================================`n" -ForegroundColor Blue

$featuresLocal = Get-WindowsFeature FS-DFS-Namespace, FS-DFS-Replication
$missingLocal = $featuresLocal | Where-Object { $_.InstallState -ne "Installed" }
if ($missingLocal) {
    Install-WindowsFeature FS-DFS-Namespace, FS-DFS-Replication -IncludeManagementTools | Out-Null
    Write-Host "  [+] Rôles DFSn + DFSr installés sur $serverPrincipal" -ForegroundColor Green
} else {
    Write-Host "  [=] Rôles DFSn + DFSr déjà installés sur $serverPrincipal" -ForegroundColor Yellow
}

$missingRemote = Invoke-Command -ComputerName $serverSecondaire -ScriptBlock {
    (Get-WindowsFeature FS-DFS-Replication).InstallState -ne "Installed"
}
if ($missingRemote) {
    Invoke-Command -ComputerName $serverSecondaire -ScriptBlock {
        Install-WindowsFeature FS-DFS-Replication -IncludeManagementTools
    } | Out-Null
    Write-Host "  [+] Rôle DFSr installé sur $serverSecondaire" -ForegroundColor Green
} else {
    Write-Host "  [=] Rôle DFSr déjà installé sur $serverSecondaire" -ForegroundColor Yellow
}

# =============================================================================
# PHASE 2 : Dossiers et partages sur DC02
# =============================================================================
Write-Host "`n=============================================" -ForegroundColor Blue
Write-Host "PHASE 2 : Dossiers et partages sur $serverSecondaire" -ForegroundColor Blue
Write-Host "=============================================`n" -ForegroundColor Blue

foreach ($line in $csvContent) {
    $parts = @()
    if ($line.Entreprise -and $line.Entreprise -ne "") { $parts += $line.Entreprise }
    if ($line.Entite -and $line.Entite -ne "")       { $parts += $line.Entite }
    if ($line.Poles -and $line.Poles -ne "")           { $parts += $line.Poles }
    if ($line.Service -and $line.Service -ne "")       { $parts += $line.Service }

    $folderPath = "C:\" + ($parts -join "\")
    New-FolderIfNotExists -path $folderPath -computerName $serverSecondaire
}

foreach ($line in $csvContent | Sort-Object Poles -Unique) {
    if (-not $line.Poles -or $line.Poles -eq "") { continue }
    $basePath = "C:\fournil\$($line.Entite)\$($line.Poles)"
    $shareName = "$($line.Poles)$"
    New-ShareIfNotExists -shareName $shareName -path $basePath -fullAccess "Tout le monde" -computerName $serverSecondaire
}

# =============================================================================
# PHASE 3 : Partages par pôle sur DC01
# =============================================================================
Write-Host "`n=============================================" -ForegroundColor Blue
Write-Host "PHASE 3 : Partages par pôle sur $serverPrincipal" -ForegroundColor Blue
Write-Host "=============================================`n" -ForegroundColor Blue

foreach ($line in $csvContent | Sort-Object Poles -Unique) {
    if (-not $line.Poles -or $line.Poles -eq "") { continue }
    $basePath = "C:\fournil\$($line.Entite)\$($line.Poles)"
    $shareName = "$($line.Poles)$"
    New-ShareIfNotExists -shareName $shareName -path $basePath -fullAccess "Tout le monde"
}

# =============================================================================
# PHASE 4 : Espaces de noms DFS
# =============================================================================
Write-Host "`n=============================================" -ForegroundColor Blue
Write-Host "PHASE 4 : Espaces de noms DFS" -ForegroundColor Blue
Write-Host "=============================================`n" -ForegroundColor Blue

foreach ($entite in $entites) {
    Write-Host "--- Namespace : $entite" -ForegroundColor Cyan

    # Dossier racine DFS
    New-FolderIfNotExists -path "$dfsRootsFolder\$entite"

    # Partage racine
    New-ShareIfNotExists -shareName $entite -path "$dfsRootsFolder\$entite" -fullAccess "Administrateurs" -readAccess "Tout le monde"

    # Racine DFS
    $dfsRootPath = "\\$domainName\$entite"
    try {
        $existingRoot = Get-DfsnRoot -Path $dfsRootPath -ErrorAction Stop
        Write-Host "  [=] Racine DFS '$dfsRootPath' existe déjà" -ForegroundColor Yellow
        $script:counts.DfsRootExists++
    } catch {
        try {
            New-DfsnRoot -Path $dfsRootPath -TargetPath "\\$serverPrincipal\$entite" -Type DomainV2 -EnableAccessBasedEnumeration $true -ErrorAction Stop | Out-Null
            Write-Host "  [+] Racine DFS '$dfsRootPath' créée" -ForegroundColor Green
            $script:counts.DfsRootCreated++
        } catch {
            Write-Host "  [!] Erreur racine DFS '$dfsRootPath' : $_" -ForegroundColor Red
            $script:counts.Errors++
        }
    }
}

# Dossiers DFS et cibles (DC01 + DC02)
Write-Host ""
foreach ($line in $csvContent | Sort-Object Poles -Unique) {
    if (-not $line.Poles -or $line.Poles -eq "") { continue }

    $folderPath = "\\$domainName\$($line.Entite)\$($line.Poles)"
    $target1 = "\\$serverPrincipal\$($line.Poles)$"
    $target2 = "\\$serverSecondaire\$($line.Poles)$"

    Write-Host "--- DFS Folder : $($line.Entite)\$($line.Poles)" -ForegroundColor Cyan

    # Dossier DFS + cible principale
    try {
        $existingFolder = Get-DfsnFolder -Path $folderPath -ErrorAction Stop
        Write-Host "  [=] Dossier DFS '$folderPath' existe déjà" -ForegroundColor Yellow
        $script:counts.DfsFolderExists++
    } catch {
        try {
            New-DfsnFolder -Path $folderPath -TargetPath $target1 -Description "Dossier DFS pour $($line.Poles)" -ErrorAction Stop | Out-Null
            Write-Host "  [+] Dossier DFS '$folderPath' créé → $target1" -ForegroundColor Green
            $script:counts.DfsFolderCreated++
        } catch {
            Write-Host "  [!] Erreur dossier DFS '$folderPath' : $_" -ForegroundColor Red
            $script:counts.Errors++
            continue
        }
    }

    # Cible secondaire
    try {
        $existingTarget = Get-DfsnFolderTarget -Path $folderPath -TargetPath $target2 -ErrorAction Stop
        Write-Host "  [=] Cible '$target2' existe déjà" -ForegroundColor Yellow
        $script:counts.DfsTargetExists++
    } catch {
        try {
            New-DfsnFolderTarget -Path $folderPath -TargetPath $target2 -ErrorAction Stop | Out-Null
            Write-Host "  [+] Cible '$target2' ajoutée" -ForegroundColor Green
            $script:counts.DfsTargetCreated++
        } catch {
            Write-Host "  [!] Erreur cible '$target2' : $_" -ForegroundColor Red
            $script:counts.Errors++
        }
    }
}

# =============================================================================
# PHASE 5 : Réplication DFSr
# =============================================================================
Write-Host "`n=============================================" -ForegroundColor Blue
Write-Host "PHASE 5 : Réplication DFSr" -ForegroundColor Blue
Write-Host "=============================================`n" -ForegroundColor Blue

foreach ($line in $csvContent | Sort-Object Poles -Unique) {
    if (-not $line.Poles -or $line.Poles -eq "") { continue }

    $replGroupName = "$($line.Entite)-$($line.Poles)-Replication"
    $folderName = $line.Poles
    $contentPath = "C:\fournil\$($line.Entite)\$($line.Poles)"
    $dfsnPath = "\\$domainName\$($line.Entite)\$($line.Poles)"

    Write-Host "--- Réplication : $replGroupName" -ForegroundColor Cyan

    # Groupe de réplication
    $existingGroup = Get-DfsReplicationGroup -GroupName $replGroupName -ErrorAction SilentlyContinue
    if ($existingGroup) {
        Write-Host "  [=] Groupe '$replGroupName' existe déjà" -ForegroundColor Yellow
        $script:counts.ReplGroupExists++
    } else {
        try {
            New-DfsReplicationGroup -GroupName $replGroupName -ErrorAction Stop |
                New-DfsReplicatedFolder -FolderName $folderName -ErrorAction Stop |
                Add-DfsrMember -ComputerName $serverPrincipal, $serverSecondaire -ErrorAction Stop | Out-Null
            Write-Host "  [+] Groupe '$replGroupName' créé" -ForegroundColor Green
            $script:counts.ReplGroupCreated++
        } catch {
            Write-Host "  [!] Erreur groupe réplication '$replGroupName' : $_" -ForegroundColor Red
            $script:counts.Errors++
            continue
        }
    }

    # Connexion
    $existingConn = Get-DfsrConnection -GroupName $replGroupName -SourceComputerName $serverPrincipal -DestinationComputerName $serverSecondaire -ErrorAction SilentlyContinue
    if ($existingConn) {
        Write-Host "  [=] Connexion $serverPrincipal ↔ $serverSecondaire existe déjà" -ForegroundColor Yellow
        $script:counts.ReplConnExists++
    } else {
        try {
            Add-DfsrConnection -GroupName $replGroupName -SourceComputerName $serverPrincipal -DestinationComputerName $serverSecondaire -ErrorAction Stop | Out-Null
            Write-Host "  [+] Connexion $serverPrincipal ↔ $serverSecondaire créée" -ForegroundColor Green
            $script:counts.ReplConnCreated++
        } catch {
            Write-Host "  [!] Erreur connexion '$replGroupName' : $_" -ForegroundColor Red
            $script:counts.Errors++
        }
    }

    # Membership DC01 (principal)
    try {
        Set-DfsrMembership -GroupName $replGroupName -FolderName $folderName -ContentPath $contentPath -ComputerName $serverPrincipal -PrimaryMember $true -Force -ErrorAction Stop | Out-Null
        Write-Host "  [+] $serverPrincipal configuré (principal)" -ForegroundColor Green
    } catch {
        Write-Host "  [!] Erreur membership $serverPrincipal : $_" -ForegroundColor Red
        $script:counts.Errors++
    }

    # Membership DC02 (secondaire)
    try {
        Set-DfsrMembership -GroupName $replGroupName -FolderName $folderName -ContentPath $contentPath -ComputerName $serverSecondaire -Force -ErrorAction Stop | Out-Null
        Write-Host "  [+] $serverSecondaire configuré (secondaire)" -ForegroundColor Green
    } catch {
        Write-Host "  [!] Erreur membership $serverSecondaire : $_" -ForegroundColor Red
        $script:counts.Errors++
    }

    # Liaison DFS
    try {
        Set-DfsReplicatedFolder -GroupName $replGroupName -FolderName $folderName -DfsnPath $dfsnPath -ErrorAction Stop | Out-Null
        Write-Host "  [+] Liaison DFS : $folderName → $dfsnPath" -ForegroundColor Green
    } catch {
        Write-Host "  [!] Erreur liaison DFS '$folderName' : $_" -ForegroundColor Red
        $script:counts.Errors++
    }
}

# =============================================================================
# PHASE 6 : Homes (dossiers, permissions, partages, DFS, réplication)
# =============================================================================
Write-Host "`n=============================================" -ForegroundColor Blue
Write-Host "PHASE 6 : Dossiers personnels (Homes)" -ForegroundColor Blue
Write-Host "=============================================`n" -ForegroundColor Blue

# 6.1 Créer les dossiers homes sur DC01
Write-Host "--- Dossiers et permissions homes sur $serverPrincipal" -ForegroundColor Cyan

New-FolderIfNotExists -path $homesFolder
foreach ($entite in $entites) {
    New-FolderIfNotExists -path "$homesFolder\$entite"
}

# Permissions racine homes
$acl = Get-Acl $homesFolder
if (-not $acl.AreAccessRulesProtected) {
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($access in $acl.Access) { $acl.RemoveAccessRule($access) | Out-Null }
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
        "NT AUTHORITY\SYSTEM", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")))
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
        "FOURNIL\Admins du domaine", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")))
    Set-Acl $homesFolder $acl
    Write-Host "  [+] Permissions racine homes appliquées" -ForegroundColor Green
} else {
    Write-Host "  [=] Permissions racine homes déjà configurées" -ForegroundColor Yellow
}

# Permissions par entité
foreach ($entite in $entites) {
    $path = "$homesFolder\$entite"
    $acl = Get-Acl $path
    if (-not $acl.AreAccessRulesProtected) {
        $acl.SetAccessRuleProtection($true, $false)
        foreach ($access in $acl.Access) { $acl.RemoveAccessRule($access) | Out-Null }
        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
            "NT AUTHORITY\SYSTEM", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")))
        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
            "FOURNIL\Admins du domaine", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")))
        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
            "CREATEUR PROPRIETAIRE", "Modify", "ContainerInherit,ObjectInherit", "InheritOnly", "Allow")))
        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
            "FOURNIL\Utilisateurs du domaine", "CreateDirectories,ReadAndExecute", "None", "None", "Allow")))
        Set-Acl $path $acl
        Write-Host "  [+] Permissions '$entite' appliquées" -ForegroundColor Green
    } else {
        Write-Host "  [=] Permissions '$entite' déjà configurées" -ForegroundColor Yellow
    }
}

# 6.2 Copier vers DC02
Write-Host "`n--- Copie homes vers $serverSecondaire" -ForegroundColor Cyan
$remoteHomesExist = Invoke-Command -ComputerName $serverSecondaire -ScriptBlock {
    param($p, $e) foreach ($ent in $e) { if (-not (Test-Path "$p\$ent")) { return $false } }; return $true
} -ArgumentList $homesFolder, $entites

if (-not $remoteHomesExist) {
    Write-Host "  [+] Robocopy homes → \\$serverSecondaire" -ForegroundColor Green
    Robocopy $homesFolder "\\$serverSecondaire\C$\homes" /E /COPYALL /DCOPY:DAT /NFL /NDL /NJH /NJS | Out-Null
} else {
    Write-Host "  [=] Homes déjà présents sur $serverSecondaire" -ForegroundColor Yellow
}

# 6.3 Partages homes
Write-Host "`n--- Partages homes" -ForegroundColor Cyan
foreach ($entite in $entites) {
    New-ShareIfNotExists -shareName "homes-$entite$" -path "$homesFolder\$entite" -fullAccess "Tout le monde"
    New-ShareIfNotExists -shareName "homes-$entite$" -path "$homesFolder\$entite" -fullAccess "Tout le monde" -computerName $serverSecondaire
}

# 6.4 DFS namespace HOMES
Write-Host "`n--- Namespace DFS HOMES" -ForegroundColor Cyan
New-FolderIfNotExists -path "$dfsRootsFolder\HOMES"
New-ShareIfNotExists -shareName "HOMES" -path "$dfsRootsFolder\HOMES" -fullAccess "FOURNIL\Admins du domaine"

$homesRootPath = "\\$domainName\HOMES"
try {
    Get-DfsnRoot -Path $homesRootPath -ErrorAction Stop | Out-Null
    Write-Host "  [=] Racine DFS HOMES existe déjà" -ForegroundColor Yellow
    $script:counts.DfsRootExists++
} catch {
    try {
        New-DfsnRoot -Path $homesRootPath -TargetPath "\\$serverPrincipal\HOMES" -Type DomainV2 -EnableAccessBasedEnumeration $true -ErrorAction Stop | Out-Null
        Write-Host "  [+] Racine DFS HOMES créée" -ForegroundColor Green
        $script:counts.DfsRootCreated++
    } catch {
        Write-Host "  [!] Erreur racine DFS HOMES : $_" -ForegroundColor Red
        $script:counts.Errors++
    }
}

foreach ($entite in $entites) {
    $dfsFolderPath = "\\$domainName\HOMES\$entite"
    $target1 = "\\$serverPrincipal\homes-$entite$"
    $target2 = "\\$serverSecondaire\homes-$entite$"

    try {
        Get-DfsnFolder -Path $dfsFolderPath -ErrorAction Stop | Out-Null
        Write-Host "  [=] Dossier DFS HOMES\$entite existe déjà" -ForegroundColor Yellow
        $script:counts.DfsFolderExists++
    } catch {
        try {
            New-DfsnFolder -Path $dfsFolderPath -TargetPath $target1 -Description "Homes $entite" -ErrorAction Stop | Out-Null
            Write-Host "  [+] Dossier DFS HOMES\$entite créé" -ForegroundColor Green
            $script:counts.DfsFolderCreated++
        } catch {
            Write-Host "  [!] Erreur dossier DFS HOMES\$entite : $_" -ForegroundColor Red
            $script:counts.Errors++
            continue
        }
    }

    try {
        Get-DfsnFolderTarget -Path $dfsFolderPath -TargetPath $target2 -ErrorAction Stop | Out-Null
        Write-Host "  [=] Cible HOMES $target2 existe déjà" -ForegroundColor Yellow
        $script:counts.DfsTargetExists++
    } catch {
        try {
            New-DfsnFolderTarget -Path $dfsFolderPath -TargetPath $target2 -ErrorAction Stop | Out-Null
            Write-Host "  [+] Cible HOMES $target2 ajoutée" -ForegroundColor Green
            $script:counts.DfsTargetCreated++
        } catch {
            Write-Host "  [!] Erreur cible HOMES '$target2' : $_" -ForegroundColor Red
            $script:counts.Errors++
        }
    }
}

# 6.5 Réplication homes
Write-Host "`n--- Réplication homes" -ForegroundColor Cyan

foreach ($entite in $entites) {
    $replGroupName = "HOMES-$entite-Replication"
    $folderName = "homes-$entite"
    $contentPath = "$homesFolder\$entite"
    $dfsnPath = "\\$domainName\HOMES\$entite"

    Write-Host "--- Réplication : $replGroupName" -ForegroundColor Cyan

    $existingGroup = Get-DfsReplicationGroup -GroupName $replGroupName -ErrorAction SilentlyContinue
    if ($existingGroup) {
        Write-Host "  [=] Groupe '$replGroupName' existe déjà" -ForegroundColor Yellow
        $script:counts.ReplGroupExists++
    } else {
        try {
            New-DfsReplicationGroup -GroupName $replGroupName -ErrorAction Stop |
                New-DfsReplicatedFolder -FolderName $folderName -ErrorAction Stop |
                Add-DfsrMember -ComputerName $serverPrincipal, $serverSecondaire -ErrorAction Stop | Out-Null
            Write-Host "  [+] Groupe '$replGroupName' créé" -ForegroundColor Green
            $script:counts.ReplGroupCreated++
        } catch {
            Write-Host "  [!] Erreur groupe '$replGroupName' : $_" -ForegroundColor Red
            $script:counts.Errors++
            continue
        }
    }

    $existingConn = Get-DfsrConnection -GroupName $replGroupName -SourceComputerName $serverPrincipal -DestinationComputerName $serverSecondaire -ErrorAction SilentlyContinue
    if ($existingConn) {
        Write-Host "  [=] Connexion existe déjà" -ForegroundColor Yellow
        $script:counts.ReplConnExists++
    } else {
        try {
            Add-DfsrConnection -GroupName $replGroupName -SourceComputerName $serverPrincipal -DestinationComputerName $serverSecondaire -ErrorAction Stop | Out-Null
            Write-Host "  [+] Connexion $serverPrincipal ↔ $serverSecondaire créée" -ForegroundColor Green
            $script:counts.ReplConnCreated++
        } catch {
            Write-Host "  [!] Erreur connexion '$replGroupName' : $_" -ForegroundColor Red
            $script:counts.Errors++
        }
    }

    try {
        Set-DfsrMembership -GroupName $replGroupName -FolderName $folderName -ContentPath $contentPath -ComputerName $serverPrincipal -PrimaryMember $true -Force -ErrorAction Stop | Out-Null
        Set-DfsrMembership -GroupName $replGroupName -FolderName $folderName -ContentPath $contentPath -ComputerName $serverSecondaire -Force -ErrorAction Stop | Out-Null
        Set-DfsReplicatedFolder -GroupName $replGroupName -FolderName $folderName -DfsnPath $dfsnPath -ErrorAction Stop | Out-Null
        Write-Host "  [+] Réplication homes $entite configurée" -ForegroundColor Green
    } catch {
        Write-Host "  [!] Erreur réplication homes '$entite' : $_" -ForegroundColor Red
        $script:counts.Errors++
    }
}

# =============================================================================
# PHASE 7 : HomeDirectory des utilisateurs
# =============================================================================
Write-Host "`n=============================================" -ForegroundColor Blue
Write-Host "PHASE 7 : HomeDirectory des utilisateurs" -ForegroundColor Blue
Write-Host "=============================================`n" -ForegroundColor Blue

foreach ($user in $userCsvContent) {
    $login = $user.Login
    $homePath = "\\$domainName\HOMES\$($user.Entite)\$login"

    try {
        $adUser = Get-ADUser -Identity $login -Properties HomeDirectory -ErrorAction Stop
        if ($adUser.HomeDirectory -eq $homePath) {
            Write-Host "  [=] $login → HomeDirectory déjà configuré" -ForegroundColor Yellow
            $script:counts.HomeExists++
        } else {
            Set-ADUser -Identity $login -HomeDirectory $homePath -HomeDrive "H:" -ErrorAction Stop
            Write-Host "  [+] $login → $homePath (H:)" -ForegroundColor Green
            $script:counts.HomeConfigured++
        }
    } catch {
        Write-Host "  [!] Erreur HomeDirectory '$login' : $_" -ForegroundColor Red
        $script:counts.Errors++
    }
}

# =============================================================================
# RÉSUMÉ
# =============================================================================
Write-Host "`n=============================================" -ForegroundColor Blue
Write-Host "RÉSUMÉ" -ForegroundColor Blue
Write-Host "=============================================" -ForegroundColor Blue
Write-Host "  Dossiers        : $($script:counts.FolderCreated) créés, $($script:counts.FolderExists) existants" -ForegroundColor White
Write-Host "  Partages        : $($script:counts.ShareCreated) créés, $($script:counts.ShareExists) existants" -ForegroundColor White
Write-Host "  Racines DFS     : $($script:counts.DfsRootCreated) créées, $($script:counts.DfsRootExists) existantes" -ForegroundColor White
Write-Host "  Dossiers DFS    : $($script:counts.DfsFolderCreated) créés, $($script:counts.DfsFolderExists) existants" -ForegroundColor White
Write-Host "  Cibles DFS      : $($script:counts.DfsTargetCreated) créées, $($script:counts.DfsTargetExists) existantes" -ForegroundColor White
Write-Host "  Groupes DFSR    : $($script:counts.ReplGroupCreated) créés, $($script:counts.ReplGroupExists) existants" -ForegroundColor White
Write-Host "  Connexions DFSR : $($script:counts.ReplConnCreated) créées, $($script:counts.ReplConnExists) existantes" -ForegroundColor White
Write-Host "  HomeDirectory   : $($script:counts.HomeConfigured) configurés, $($script:counts.HomeExists) déjà OK" -ForegroundColor White
if ($script:counts.Errors -gt 0) {
    Write-Host "  Erreurs         : $($script:counts.Errors)" -ForegroundColor Red
} else {
    Write-Host "  Erreurs         : 0" -ForegroundColor Green
}
Write-Host "=============================================`n" -ForegroundColor Blue
