# Importer le module ActiveDirectory
Import-Module ActiveDirectory

# Chemin du fichier CSV
$csvPath = ".\orga-fournil.csv"
# Distinguished Name de base
$baseDN = "DC=ad,DC=fournil,DC=lab"
# Dossier racine
$rootFolder = "C:\"
# Nom de l'OU racine entreprise
$entrepriseOU = "Fournil"

# OUs de type d'objet (séparation bonnes pratiques)
$ouUtilisateurs = "Utilisateurs"
$ouGroupes = "Groupes"
$ouOrdinateurs = "Ordinateurs"

# Lire le contenu du CSV
$csvContent = Import-Csv -Path $csvPath -Delimiter ','

# Cache pour éviter les requêtes AD redondantes
$script:processedOUs = @{}
$script:processedGroups = @{}
$script:processedMembers = @{}
$script:processedFolders = @{}
$script:domainPrefix = (Get-ADDomain).NetBIOSName

# Compteurs
$script:counts = @{ OUCreated = 0; OUExists = 0; GroupCreated = 0; GroupExists = 0; MemberAdded = 0; MemberExists = 0; UserCreated = 0; UserExists = 0; FolderCreated = 0; FolderExists = 0; PermApplied = 0; PermSkipped = 0; Errors = 0 }

function New-OUIfNotExists {
    param (
        [string]$ouName,
        [string]$parentPath
    )
    $ouPath = "OU=$ouName,$parentPath"
    if ($script:processedOUs.ContainsKey($ouPath)) { return $ouPath }
    try {
        $existingOU = Get-ADOrganizationalUnit -LDAPFilter "(distinguishedName=$($ouPath))" -ErrorAction SilentlyContinue
        if (-not $existingOU) {
            New-ADOrganizationalUnit -Name $ouName -Path $parentPath -ErrorAction Stop
            Write-Host "  [+] OU '$ouName' créée sous '$parentPath'" -ForegroundColor Green
            $script:counts.OUCreated++
        } else {
            Write-Host "  [=] OU '$ouName' existe déjà" -ForegroundColor Yellow
            $script:counts.OUExists++
        }
    } catch {
        Write-Host "  [!] Erreur OU '$ouName' : $_" -ForegroundColor Red
        $script:counts.Errors++
    }
    $script:processedOUs[$ouPath] = $true
    return $ouPath
}

function New-GroupIfNotExists {
    param (
        [string]$groupName,
        [string]$groupScope,
        [string]$path,
        [string]$description
    )
    if ($script:processedGroups.ContainsKey($groupName)) { return }
    try {
        $existingGroup = Get-ADGroup -Filter { Name -eq $groupName } -SearchBase $path -ErrorAction SilentlyContinue
        if (-not $existingGroup) {
            New-ADGroup -Name $groupName -GroupCategory Security -GroupScope $groupScope -Path $path -Description $description -ErrorAction Stop
            Write-Host "  [+] Groupe '$groupName' créé" -ForegroundColor Green
            $script:counts.GroupCreated++
        } else {
            Write-Host "  [=] Groupe '$groupName' existe déjà" -ForegroundColor Yellow
            $script:counts.GroupExists++
        }
    } catch {
        Write-Host "  [!] Erreur groupe '$groupName' : $_" -ForegroundColor Red
        $script:counts.Errors++
    }
    $script:processedGroups[$groupName] = $true
}

function Add-MemberToGroupSafe {
    param (
        [string]$memberName,
        [string]$groupName
    )
    $key = "$memberName->$groupName"
    if ($script:processedMembers.ContainsKey($key)) { return }
    try {
        $members = Get-ADGroupMember -Identity $groupName -ErrorAction Stop | Select-Object -ExpandProperty SamAccountName
        if ($members -contains $memberName) {
            Write-Host "  [=] '$memberName' déjà membre de '$groupName'" -ForegroundColor Yellow
            $script:counts.MemberExists++
        } else {
            Add-ADGroupMember -Identity $groupName -Members $memberName -ErrorAction Stop
            Write-Host "  [+] '$memberName' ajouté au groupe '$groupName'" -ForegroundColor Green
            $script:counts.MemberAdded++
        }
    } catch {
        Write-Host "  [!] Erreur ajout '$memberName' dans '$groupName' : $_" -ForegroundColor Red
        $script:counts.Errors++
    }
    $script:processedMembers[$key] = $true
}

function Set-NTFSPermissions {
    param (
        [string]$folderPath,
        [string]$dlGroupRead,
        [string]$dlGroupModify
    )
    if ($script:processedFolders.ContainsKey($folderPath)) { return }

    try {
        $folderCreated = $false
        if (-not (Test-Path -Path $folderPath)) {
            New-Item -Path $folderPath -ItemType Directory -Force | Out-Null
            Write-Host "  [+] Dossier '$folderPath' créé" -ForegroundColor Green
            $folderCreated = $true
            $script:counts.FolderCreated++
        } else {
            $script:counts.FolderExists++
        }

        $acl = Get-Acl -Path $folderPath

        if (-not $folderCreated) {
            $existingIdentities = $acl.Access | Select-Object -ExpandProperty IdentityReference | ForEach-Object { $_.Value }
            $hasRead = $existingIdentities -contains "$($script:domainPrefix)\$dlGroupRead"
            $hasModify = $existingIdentities -contains "$($script:domainPrefix)\$dlGroupModify"
            $isProtected = $acl.AreAccessRulesProtected
            if ($hasRead -and $hasModify -and $isProtected) {
                Write-Host "  [=] Permissions déjà OK sur '$folderPath'" -ForegroundColor Yellow
                $script:counts.PermSkipped++
                $script:processedFolders[$folderPath] = $true
                return
            }
        }

        $acl.SetAccessRuleProtection($true, $false)
        foreach ($access in $acl.Access) {
            $acl.RemoveAccessRule($access) | Out-Null
        }

        $administrators = "BUILTIN\Administrateurs"
        $system = "NT AUTHORITY\SYSTEM"

        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
            $administrators, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'
        )))
        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
            $system, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'
        )))
        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
            $dlGroupRead, 'ReadAndExecute', 'ContainerInherit,ObjectInherit', 'None', 'Allow'
        )))
        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
            $dlGroupModify, 'Modify', 'ContainerInherit,ObjectInherit', 'None', 'Allow'
        )))

        Set-Acl -Path $folderPath -AclObject $acl
        Write-Host "  [+] Permissions appliquées sur '$folderPath' ($dlGroupRead=L, $dlGroupModify=M)" -ForegroundColor Green
        $script:counts.PermApplied++
    } catch {
        Write-Host "  [!] Erreur permissions '$folderPath' : $_" -ForegroundColor Red
        $script:counts.Errors++
    }
    $script:processedFolders[$folderPath] = $true
}

function New-UserIfNotExists {
    param (
        [string]$samAccountName,
        [string]$givenName,
        [string]$surname,
        [string]$displayName,
        [string]$upn,
        [SecureString]$password,
        [string]$description,
        [string]$path
    )
    try {
        $existingUser = Get-ADUser -Filter { SamAccountName -eq $samAccountName } -ErrorAction SilentlyContinue
        if (-not $existingUser) {
            New-ADUser `
                -Name $displayName `
                -GivenName $givenName `
                -Surname $surname `
                -SamAccountName $samAccountName `
                -UserPrincipalName $upn `
                -Path $path `
                -AccountPassword $password `
                -ChangePasswordAtLogon $true `
                -Enabled $true `
                -Description $description `
                -ErrorAction Stop
            Write-Host "  [+] Utilisateur '$displayName' ($samAccountName) créé" -ForegroundColor Green
            $script:counts.UserCreated++
        } else {
            Write-Host "  [=] Utilisateur '$samAccountName' existe déjà" -ForegroundColor Yellow
            $script:counts.UserExists++
        }
    } catch {
        Write-Host "  [!] Erreur utilisateur '$samAccountName' : $_" -ForegroundColor Red
        $script:counts.Errors++
    }
}

# =============================================================================
# PHASE 1 : Structure de base (OU racine + OUs de type)
# =============================================================================
Write-Host "`n=============================================" -ForegroundColor Blue
Write-Host "PHASE 1 : Structure de base" -ForegroundColor Blue
Write-Host "=============================================`n" -ForegroundColor Blue

# OU racine : Fournil
$entreprisePath = New-OUIfNotExists -ouName $entrepriseOU -parentPath $baseDN

# OUs de type d'objet sous Fournil
$utilisateursBasePath = New-OUIfNotExists -ouName $ouUtilisateurs -parentPath $entreprisePath
$groupesBasePath = New-OUIfNotExists -ouName $ouGroupes -parentPath $entreprisePath
$ordinateursBasePath = New-OUIfNotExists -ouName $ouOrdinateurs -parentPath $entreprisePath

# =============================================================================
# PHASE 2 : OUs organisationnelles, Groupes, Dossiers, Permissions
# =============================================================================
Write-Host "`n=============================================" -ForegroundColor Blue
Write-Host "PHASE 2 : OUs organisationnelles, Groupes, Dossiers" -ForegroundColor Blue
Write-Host "=============================================`n" -ForegroundColor Blue

foreach ($line in $csvContent) {
    Write-Host "--- $($line.Entreprise) > $($line.Entite) > $($line.Poles) > $($line.Service)" -ForegroundColor Cyan

    # Construire la hiérarchie organisationnelle (Entite > Poles > Service)
    $orgParts = @()
    if ($line.Entite -and $line.Entite -ne "") { $orgParts += $line.Entite }
    if ($line.Poles -and $line.Poles -ne "") { $orgParts += $line.Poles }
    if ($line.Service -and $line.Service -ne "") { $orgParts += $line.Service }

    # Créer la hiérarchie sous Utilisateurs
    $currentUserPath = $utilisateursBasePath
    foreach ($part in $orgParts) {
        $currentUserPath = New-OUIfNotExists -ouName $part -parentPath $currentUserPath
    }

    # Créer la hiérarchie sous Groupes
    $currentGroupPath = $groupesBasePath
    $groupOUPaths = @()
    foreach ($part in $orgParts) {
        $currentGroupPath = New-OUIfNotExists -ouName $part -parentPath $currentGroupPath
        $groupOUPaths += $currentGroupPath
    }

    # Créer la hiérarchie sous Ordinateurs
    $currentComputerPath = $ordinateursBasePath
    foreach ($part in $orgParts) {
        $currentComputerPath = New-OUIfNotExists -ouName $part -parentPath $currentComputerPath
    }

    # Groupes au niveau Entreprise (dans l'OU Groupes directement)
    $enterpriseGroupName = "G_" + $line.Entreprise
    New-GroupIfNotExists -groupName $enterpriseGroupName -groupScope "Global" -path $groupesBasePath -description "Groupe global pour $enterpriseGroupName"

    $dlGroupRead = "DL_" + $line.Entreprise + "_L"
    $dlGroupModify = "DL_" + $line.Entreprise + "_M"
    New-GroupIfNotExists -groupName $dlGroupRead -groupScope "DomainLocal" -path $groupesBasePath -description "Groupe de lecture pour $dlGroupRead"
    New-GroupIfNotExists -groupName $dlGroupModify -groupScope "DomainLocal" -path $groupesBasePath -description "Groupe de modification pour $dlGroupModify"

    $enterpriseFolderPath = Join-Path $rootFolder $line.Entreprise
    Set-NTFSPermissions -folderPath $enterpriseFolderPath -dlGroupRead $dlGroupRead -dlGroupModify $dlGroupModify

    # Groupes à chaque niveau organisationnel (dans les sous-OUs de Groupes)
    $previousGroupName = $null
    $folderPath = Join-Path $rootFolder $line.Entreprise

    for ($i = 0; $i -lt $orgParts.Count; $i++) {
        $currentGroupNameParts = $orgParts[0..$i]
        $groupName = "G_" + ($currentGroupNameParts -join "_")
        $groupLevelPath = $groupOUPaths[$i]

        New-GroupIfNotExists -groupName $groupName -groupScope "Global" -path $groupLevelPath -description "Groupe global pour $groupName"

        if ($previousGroupName) {
            Add-MemberToGroupSafe -memberName $groupName -groupName $previousGroupName
        }
        $previousGroupName = $groupName

        $dlGroupRead = "DL_" + ($currentGroupNameParts -join "_") + "_L"
        $dlGroupModify = "DL_" + ($currentGroupNameParts -join "_") + "_M"
        New-GroupIfNotExists -groupName $dlGroupRead -groupScope "DomainLocal" -path $groupLevelPath -description "Groupe de lecture pour $dlGroupRead"
        New-GroupIfNotExists -groupName $dlGroupModify -groupScope "DomainLocal" -path $groupLevelPath -description "Groupe de modification pour $dlGroupModify"

        $folderPath = Join-Path $folderPath $orgParts[$i]
        Set-NTFSPermissions -folderPath $folderPath -dlGroupRead $dlGroupRead -dlGroupModify $dlGroupModify
    }

    # Imbriquer Entité dans Entreprise
    if ($orgParts.Count -gt 0) {
        $entityGroupName = "G_" + $orgParts[0]
        Add-MemberToGroupSafe -memberName $entityGroupName -groupName $enterpriseGroupName
    }
}

# =============================================================================
# PHASE 3 : Imbrication G dans DL
# =============================================================================
Write-Host "`n=============================================" -ForegroundColor Blue
Write-Host "PHASE 3 : Imbrication des groupes G dans DL" -ForegroundColor Blue
Write-Host "=============================================`n" -ForegroundColor Blue

foreach ($line in $csvContent) {
    $orgParts = @()
    if ($line.Entite -and $line.Entite -ne "") { $orgParts += $line.Entite }
    if ($line.Poles -and $line.Poles -ne "") { $orgParts += $line.Poles }
    if ($line.Service -and $line.Service -ne "") { $orgParts += $line.Service }

    for ($i = 0; $i -lt $orgParts.Count; $i++) {
        $currentGroupNameParts = $orgParts[0..$i]
        $groupName = "G_" + ($currentGroupNameParts -join "_")
        $dlGroupRead = "DL_" + ($currentGroupNameParts -join "_") + "_L"
        $dlGroupModify = "DL_" + ($currentGroupNameParts -join "_") + "_M"

        if ($i -eq $orgParts.Count - 1) {
            Add-MemberToGroupSafe -memberName $groupName -groupName $dlGroupModify
        } else {
            Add-MemberToGroupSafe -memberName $groupName -groupName $dlGroupRead
        }
    }
}

# =============================================================================
# PHASE 4 : Utilisateurs
# =============================================================================
Write-Host "`n=============================================" -ForegroundColor Blue
Write-Host "PHASE 4 : Création des utilisateurs" -ForegroundColor Blue
Write-Host "=============================================`n" -ForegroundColor Blue

$userCsvPath = ".\utilisateurs-fournil.csv"
$userCsvContent = Import-Csv -Path $userCsvPath -Delimiter ','

foreach ($user in $userCsvContent) {
    Write-Host "--- $($user.Prenom) $($user.Nom) ($($user.Login))" -ForegroundColor Cyan

    # Chemin dans la branche Utilisateurs : OU=service,OU=pole,OU=entite,OU=Utilisateurs,OU=Fournil,DC=...
    $ouParts = @()
    if ($user.Service -and $user.Service -ne "") { $ouParts += "OU=$($user.Service)" }
    if ($user.Pole -and $user.Pole -ne "") { $ouParts += "OU=$($user.Pole)" }
    if ($user.Entite -and $user.Entite -ne "") { $ouParts += "OU=$($user.Entite)" }
    $ouParts += "OU=$ouUtilisateurs"
    $ouParts += "OU=$entrepriseOU"

    $userPath = ($ouParts -join ",") + ",$baseDN"

    $securePassword = ConvertTo-SecureString $user.MotDePasse -AsPlainText -Force

    New-UserIfNotExists `
        -samAccountName $user.Login `
        -givenName $user.Prenom `
        -surname $user.Nom `
        -displayName "$($user.Prenom) $($user.Nom)" `
        -upn $user.Email `
        -password $securePassword `
        -description $user.Fonction `
        -path $userPath

    $groupParts = @()
    if ($user.Entite -and $user.Entite -ne "") { $groupParts += $user.Entite }
    if ($user.Pole -and $user.Pole -ne "") { $groupParts += $user.Pole }
    if ($user.Service -and $user.Service -ne "") { $groupParts += $user.Service }

    $groupName = "G_" + ($groupParts -join "_")
    $login = $user.Login
    Add-MemberToGroupSafe -memberName $login -groupName $groupName
}

# =============================================================================
# RÉSUMÉ
# =============================================================================
Write-Host "`n=============================================" -ForegroundColor Blue
Write-Host "RÉSUMÉ" -ForegroundColor Blue
Write-Host "=============================================" -ForegroundColor Blue
Write-Host "  OUs         : $($script:counts.OUCreated) créées, $($script:counts.OUExists) existantes" -ForegroundColor White
Write-Host "  Groupes     : $($script:counts.GroupCreated) créés, $($script:counts.GroupExists) existants" -ForegroundColor White
Write-Host "  Membres     : $($script:counts.MemberAdded) ajoutés, $($script:counts.MemberExists) déjà en place" -ForegroundColor White
Write-Host "  Utilisateurs: $($script:counts.UserCreated) créés, $($script:counts.UserExists) existants" -ForegroundColor White
Write-Host "  Dossiers    : $($script:counts.FolderCreated) créés, $($script:counts.FolderExists) existants" -ForegroundColor White
Write-Host "  Permissions : $($script:counts.PermApplied) appliquées, $($script:counts.PermSkipped) déjà OK" -ForegroundColor White
if ($script:counts.Errors -gt 0) {
    Write-Host "  Erreurs     : $($script:counts.Errors)" -ForegroundColor Red
} else {
    Write-Host "  Erreurs     : 0" -ForegroundColor Green
}
Write-Host "=============================================`n" -ForegroundColor Blue
