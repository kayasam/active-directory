# #############################################################################
#
#   SCRIPT DE DÉPLOIEMENT COMPLET — AD + DFS + GPO
#
#   Exécuter sur le serveur PRINCIPAL en tant qu'administrateur.
#   Ce script est idempotent : il peut être relancé sans risque.
#
# #############################################################################

# =============================================================================
#  VARIABLES À MODIFIER SELON VOTRE ENVIRONNEMENT
# =============================================================================

$domainFQDN         = "ad.fournil.lab"                # Nom FQDN du domaine
$baseDN             = "DC=ad,DC=fournil,DC=lab"        # Distinguished Name du domaine
$domainNetBIOS      = "FOURNIL"                        # Nom NetBIOS du domaine

$serverPrincipal    = "DC01"                           # Nom du serveur principal (celui-ci)
$serverSecondaire   = "DC02"                            # Nom du serveur secondaire (réplica)

$entrepriseOU       = "fournil"                        # Nom de l'entreprise (dossiers C:\fournil, groupes)
$ouRacine           = "Fournil"                        # Nom de l'OU racine de l'entreprise
$ouUtilisateurs     = "Utilisateurs"                   # OU pour les comptes utilisateurs
$ouGroupes          = "Groupes"                        # OU pour les groupes de sécurité
$ouOrdinateurs      = "Ordinateurs"                    # OU pour les comptes machines

$rootFolder         = "C:\"                            # Racine des dossiers NTFS
$homesFolder        = "C:\homes"                       # Dossier des homes utilisateurs
$dfsRootsFolder     = "C:\DFSRoots"                    # Dossier des racines DFS

$csvPath            = ".\orga-fournil.csv"             # CSV structure organisationnelle
$userCsvPath        = ".\utilisateurs-fournil.csv"     # CSV des utilisateurs

$gpoName            = "GPO_Emplacement_Home"           # Nom de la GPO
$gpoScriptName      = "Set-NetworkLocation.ps1"        # Script de connexion GPO
$homeDrive          = "H:"                             # Lettre du lecteur réseau home
$homeDisplayName    = "Mon Dossier Personnel"          # Nom affiché dans l'explorateur

$groupeAdmins       = "$domainNetBIOS\Admins du domaine"
$groupeUtilDomaine  = "$domainNetBIOS\Utilisateurs du domaine"

# =============================================================================
#  FIN DES VARIABLES — NE PAS MODIFIER EN DESSOUS SAUF SI NÉCESSAIRE
# =============================================================================

Import-Module ActiveDirectory
Import-Module GroupPolicy -SkipEditionCheck -WarningAction SilentlyContinue

$csvContent = Import-Csv -Path $csvPath -Delimiter ','
$userCsvContent = Import-Csv -Path $userCsvPath -Delimiter ','
$entites = $csvContent | Select-Object -ExpandProperty Entite -Unique

# Cache et compteurs
$script:cache = @{ OU = @{}; Group = @{}; Member = @{}; Folder = @{} }
$script:c = @{
    OUNew=0; OUOk=0; GrpNew=0; GrpOk=0; MbrNew=0; MbrOk=0
    UsrNew=0; UsrOk=0; FldNew=0; FldOk=0; PermNew=0; PermOk=0
    ShrNew=0; ShrOk=0; DfsRNew=0; DfsROk=0; DfsFNew=0; DfsFOk=0
    DfsTNew=0; DfsTOk=0; RplNew=0; RplOk=0; ConNew=0; ConOk=0
    HomeNew=0; HomeOk=0; Err=0
}

$startTime = Get-Date

Write-Host ""
Write-Host "  ____  _____ ____  _     _____   __" -ForegroundColor Cyan
Write-Host " |  _ \| ____|  _ \| |   / _ \ \ / /" -ForegroundColor Cyan
Write-Host " | | | |  _| | |_) | |  | | | \ V / " -ForegroundColor Cyan
Write-Host " | |_| | |___|  __/| |__| |_| || |  " -ForegroundColor Cyan
Write-Host " |____/|_____|_|   |_____\___/ |_|  " -ForegroundColor Cyan
Write-Host ""
Write-Host "  Domaine    : $domainFQDN" -ForegroundColor White
Write-Host "  Serveurs   : $serverPrincipal (principal) / $serverSecondaire (replica)" -ForegroundColor White
Write-Host "  Entreprise : $entrepriseOU" -ForegroundColor White
Write-Host "  CSV orga   : $csvPath ($($csvContent.Count) lignes)" -ForegroundColor White
Write-Host "  CSV users  : $userCsvPath ($($userCsvContent.Count) utilisateurs)" -ForegroundColor White
Write-Host ""

# =============================================================================
#  FONCTIONS
# =============================================================================

function New-OUIfNotExists {
    param ([string]$Name, [string]$Parent)
    $path = "OU=$Name,$Parent"
    if ($script:cache.OU.ContainsKey($path)) { return $path }
    try {
        if (-not (Get-ADOrganizationalUnit -LDAPFilter "(distinguishedName=$path)" -ErrorAction SilentlyContinue)) {
            New-ADOrganizationalUnit -Name $Name -Path $Parent -ErrorAction Stop
            Write-Host "  [+] OU '$Name'" -ForegroundColor Green
            $script:c.OUNew++
        } else { Write-Host "  [=] OU '$Name' existe" -ForegroundColor Yellow; $script:c.OUOk++ }
    } catch { Write-Host "  [!] OU '$Name' : $_" -ForegroundColor Red; $script:c.Err++ }
    $script:cache.OU[$path] = $true
    return $path
}

function New-GroupIfNotExists {
    param ([string]$Name, [string]$Scope, [string]$Path, [string]$Desc)
    if ($script:cache.Group.ContainsKey($Name)) { return }
    try {
        if (-not (Get-ADGroup -Filter { Name -eq $Name } -SearchBase $Path -ErrorAction SilentlyContinue)) {
            New-ADGroup -Name $Name -GroupCategory Security -GroupScope $Scope -Path $Path -Description $Desc -ErrorAction Stop
            Write-Host "  [+] Groupe '$Name'" -ForegroundColor Green
            $script:c.GrpNew++
        } else { Write-Host "  [=] Groupe '$Name' existe" -ForegroundColor Yellow; $script:c.GrpOk++ }
    } catch { Write-Host "  [!] Groupe '$Name' : $_" -ForegroundColor Red; $script:c.Err++ }
    $script:cache.Group[$Name] = $true
}

function Add-MemberSafe {
    param ([string]$Member, [string]$Group)
    $key = "$Member->$Group"
    if ($script:cache.Member.ContainsKey($key)) { return }
    try {
        $members = Get-ADGroupMember -Identity $Group -ErrorAction Stop | Select-Object -ExpandProperty SamAccountName
        if ($members -contains $Member) { Write-Host "  [=] '$Member' deja dans '$Group'" -ForegroundColor Yellow; $script:c.MbrOk++ }
        else {
            Add-ADGroupMember -Identity $Group -Members $Member -ErrorAction Stop
            Write-Host "  [+] '$Member' → '$Group'" -ForegroundColor Green
            $script:c.MbrNew++
        }
    } catch { Write-Host "  [!] '$Member' → '$Group' : $_" -ForegroundColor Red; $script:c.Err++ }
    $script:cache.Member[$key] = $true
}

function Set-NTFSPermissions {
    param ([string]$Path, [string]$DL_Read, [string]$DL_Modify)
    if ($script:cache.Folder.ContainsKey($Path)) { return }
    try {
        $created = $false
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
            Write-Host "  [+] Dossier '$Path'" -ForegroundColor Green
            $created = $true; $script:c.FldNew++
        } else { Write-Host "  [=] Dossier '$Path' existe" -ForegroundColor Yellow; $script:c.FldOk++ }

        $acl = Get-Acl -Path $Path
        if (-not $created) {
            $ids = $acl.Access | ForEach-Object { $_.IdentityReference.Value }
            if (($ids -contains "$domainNetBIOS\$DL_Read") -and ($ids -contains "$domainNetBIOS\$DL_Modify") -and $acl.AreAccessRulesProtected) {
                Write-Host "  [=] Permissions OK '$Path'" -ForegroundColor Yellow; $script:c.PermOk++; $script:cache.Folder[$Path] = $true; return
            }
        }
        $acl.SetAccessRuleProtection($true, $false)
        foreach ($a in $acl.Access) { $acl.RemoveAccessRule($a) | Out-Null }
        foreach ($rule in @(
            @("BUILTIN\Administrateurs", "FullControl"),
            @("NT AUTHORITY\SYSTEM",     "FullControl"),
            @($DL_Read,                  "ReadAndExecute"),
            @($DL_Modify,                "Modify")
        )) {
            $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
                $rule[0], $rule[1], "ContainerInherit,ObjectInherit", "None", "Allow")))
        }
        Set-Acl -Path $Path -AclObject $acl
        Write-Host "  [+] Permissions '$Path'" -ForegroundColor Green
        $script:c.PermNew++
    } catch { Write-Host "  [!] Permissions '$Path' : $_" -ForegroundColor Red; $script:c.Err++ }
    $script:cache.Folder[$Path] = $true
}

function New-UserIfNotExists {
    param ([string]$Sam, [string]$First, [string]$Last, [string]$Display, [string]$UPN, [SecureString]$Pass, [string]$Desc, [string]$Path)
    try {
        if (-not (Get-ADUser -Filter { SamAccountName -eq $Sam } -ErrorAction SilentlyContinue)) {
            New-ADUser -Name $Display -GivenName $First -Surname $Last -SamAccountName $Sam -UserPrincipalName $UPN -Path $Path -AccountPassword $Pass -ChangePasswordAtLogon $true -Enabled $true -Description $Desc -ErrorAction Stop
            Write-Host "  [+] Utilisateur '$Display' ($Sam)" -ForegroundColor Green
            $script:c.UsrNew++
        } else { Write-Host "  [=] Utilisateur '$Sam' existe" -ForegroundColor Yellow; $script:c.UsrOk++ }
    } catch { Write-Host "  [!] Utilisateur '$Sam' : $_" -ForegroundColor Red; $script:c.Err++ }
}

function New-ShareSafe {
    param ([string]$Name, [string]$Path, [string]$FullAccess = "Tout le monde", [string]$ReadAccess, [string]$Computer)
    $tag = if ($Computer) { "[$Computer] " } else { "" }
    try {
        $exists = if ($Computer) {
            Invoke-Command -ComputerName $Computer -ScriptBlock { param($n) Get-SmbShare -Name $n -ErrorAction SilentlyContinue } -ArgumentList $Name
        } else { Get-SmbShare -Name $Name -ErrorAction SilentlyContinue }
        if ($exists) { Write-Host "  [=] ${tag}Partage '$Name' existe" -ForegroundColor Yellow; $script:c.ShrOk++; return }
        if ($Computer) {
            Invoke-Command -ComputerName $Computer -ScriptBlock { param($n,$p,$f) New-SmbShare -Name $n -Path $p -FullAccess $f } -ArgumentList $Name,$Path,$FullAccess | Out-Null
        } elseif ($ReadAccess) { New-SmbShare -Name $Name -Path $Path -FullAccess $FullAccess -ReadAccess $ReadAccess | Out-Null }
        else { New-SmbShare -Name $Name -Path $Path -FullAccess $FullAccess | Out-Null }
        Write-Host "  [+] ${tag}Partage '$Name'" -ForegroundColor Green; $script:c.ShrNew++
    } catch { Write-Host "  [!] ${tag}Partage '$Name' : $_" -ForegroundColor Red; $script:c.Err++ }
}

function New-FolderRemote {
    param ([string]$Path, [string]$Computer)
    try {
        if ($Computer) {
            $exists = Invoke-Command -ComputerName $Computer -ScriptBlock { param($p) Test-Path $p } -ArgumentList $Path
            if (-not $exists) {
                Invoke-Command -ComputerName $Computer -ScriptBlock { param($p) New-Item -Path $p -ItemType Directory -Force | Out-Null } -ArgumentList $Path
                Write-Host "  [+] [$Computer] Dossier '$Path'" -ForegroundColor Green; $script:c.FldNew++
            } else { $script:c.FldOk++ }
        } else {
            if (-not (Test-Path $Path)) { New-Item -Path $Path -ItemType Directory -Force | Out-Null; Write-Host "  [+] Dossier '$Path'" -ForegroundColor Green; $script:c.FldNew++ }
            else { $script:c.FldOk++ }
        }
    } catch { Write-Host "  [!] Dossier '$Path' : $_" -ForegroundColor Red; $script:c.Err++ }
}

function New-DfsRootSafe {
    param ([string]$DfsPath, [string]$Target)
    try {
        Get-DfsnRoot -Path $DfsPath -ErrorAction Stop | Out-Null
        Write-Host "  [=] Racine DFS '$DfsPath' existe" -ForegroundColor Yellow; $script:c.DfsROk++
    } catch {
        try {
            New-DfsnRoot -Path $DfsPath -TargetPath $Target -Type DomainV2 -EnableAccessBasedEnumeration $true -ErrorAction Stop | Out-Null
            Write-Host "  [+] Racine DFS '$DfsPath'" -ForegroundColor Green; $script:c.DfsRNew++
        } catch { Write-Host "  [!] Racine DFS '$DfsPath' : $_" -ForegroundColor Red; $script:c.Err++ }
    }
}

function New-DfsFolderSafe {
    param ([string]$DfsPath, [string]$Target1, [string]$Target2, [string]$Desc)
    try { Get-DfsnFolder -Path $DfsPath -ErrorAction Stop | Out-Null; Write-Host "  [=] DFS '$DfsPath' existe" -ForegroundColor Yellow; $script:c.DfsFOk++ }
    catch {
        try { New-DfsnFolder -Path $DfsPath -TargetPath $Target1 -Description $Desc -ErrorAction Stop | Out-Null
            Write-Host "  [+] DFS '$DfsPath'" -ForegroundColor Green; $script:c.DfsFNew++
        } catch { Write-Host "  [!] DFS '$DfsPath' : $_" -ForegroundColor Red; $script:c.Err++; return }
    }
    try { Get-DfsnFolderTarget -Path $DfsPath -TargetPath $Target2 -ErrorAction Stop | Out-Null; Write-Host "  [=] Cible '$Target2' existe" -ForegroundColor Yellow; $script:c.DfsTOk++ }
    catch {
        try { New-DfsnFolderTarget -Path $DfsPath -TargetPath $Target2 -ErrorAction Stop | Out-Null
            Write-Host "  [+] Cible '$Target2'" -ForegroundColor Green; $script:c.DfsTNew++
        } catch { Write-Host "  [!] Cible '$Target2' : $_" -ForegroundColor Red; $script:c.Err++ }
    }
}

function New-ReplicationSafe {
    param ([string]$GroupName, [string]$FolderName, [string]$ContentPath, [string]$DfsnPath)
    $exists = Get-DfsReplicationGroup -GroupName $GroupName -ErrorAction SilentlyContinue
    if ($exists) { Write-Host "  [=] Replication '$GroupName' existe" -ForegroundColor Yellow; $script:c.RplOk++ } else {
        try {
            New-DfsReplicationGroup -GroupName $GroupName -ErrorAction Stop |
                New-DfsReplicatedFolder -FolderName $FolderName -ErrorAction Stop |
                Add-DfsrMember -ComputerName $serverPrincipal,$serverSecondaire -ErrorAction Stop | Out-Null
            Write-Host "  [+] Réplication '$GroupName'" -ForegroundColor Green; $script:c.RplNew++
        } catch { Write-Host "  [!] Réplication '$GroupName' : $_" -ForegroundColor Red; $script:c.Err++; return }
    }
    $conn = Get-DfsrConnection -GroupName $GroupName -SourceComputerName $serverPrincipal -DestinationComputerName $serverSecondaire -ErrorAction SilentlyContinue
    if ($conn) { Write-Host "  [=] Connexion '$GroupName' existe" -ForegroundColor Yellow; $script:c.ConOk++ } else {
        try { Add-DfsrConnection -GroupName $GroupName -SourceComputerName $serverPrincipal -DestinationComputerName $serverSecondaire -ErrorAction Stop | Out-Null
            Write-Host "  [+] Connexion $serverPrincipal ↔ $serverSecondaire" -ForegroundColor Green; $script:c.ConNew++
        } catch { Write-Host "  [!] Connexion '$GroupName' : $_" -ForegroundColor Red; $script:c.Err++ }
    }
    try {
        Set-DfsrMembership -GroupName $GroupName -FolderName $FolderName -ContentPath $ContentPath -ComputerName $serverPrincipal -PrimaryMember $true -Force -ErrorAction Stop | Out-Null
        Set-DfsrMembership -GroupName $GroupName -FolderName $FolderName -ContentPath $ContentPath -ComputerName $serverSecondaire -Force -ErrorAction Stop | Out-Null
        Set-DfsReplicatedFolder -GroupName $GroupName -FolderName $FolderName -DfsnPath $DfsnPath -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
    } catch { Write-Host "  [!] Config '$GroupName' : $_" -ForegroundColor Red; $script:c.Err++ }
}

# =============================================================================
#  PHASE 1/11 — Rôles DFS
# =============================================================================
Write-Host "`n== PHASE 1/11 : Roles DFS ==" -ForegroundColor Blue
Write-Host "  Installation de DFSn+DFSr sur $serverPrincipal et DFSr sur $serverSecondaire" -ForegroundColor DarkGray

$missing = Get-WindowsFeature FS-DFS-Namespace, FS-DFS-Replication | Where-Object { $_.InstallState -ne "Installed" }
if ($missing) { Install-WindowsFeature FS-DFS-Namespace, FS-DFS-Replication -IncludeManagementTools | Out-Null
    Write-Host "  [+] DFSn+DFSr installés sur $serverPrincipal" -ForegroundColor Green
} else { Write-Host "  [=] DFSn+DFSr OK sur $serverPrincipal" -ForegroundColor Yellow }

$r = Invoke-Command -ComputerName $serverSecondaire -ScriptBlock { (Get-WindowsFeature FS-DFS-Replication).InstallState -ne "Installed" }
if ($r) { Invoke-Command -ComputerName $serverSecondaire -ScriptBlock { Install-WindowsFeature FS-DFS-Replication -IncludeManagementTools } | Out-Null
    Write-Host "  [+] DFSr installé sur $serverSecondaire" -ForegroundColor Green
} else { Write-Host "  [=] DFSr OK sur $serverSecondaire" -ForegroundColor Yellow }

# =============================================================================
#  PHASE 2/11 — Structure AD (OUs)
# =============================================================================
Write-Host "`n== PHASE 2/11 : Structure AD (OUs) ==" -ForegroundColor Blue
Write-Host "  Creation de l'OU racine '$ouRacine' + Utilisateurs/Groupes/Ordinateurs + arborescence" -ForegroundColor DarkGray

$entreprisePath = New-OUIfNotExists -Name $ouRacine -Parent $baseDN
$pathUsers   = New-OUIfNotExists -Name $ouUtilisateurs -Parent $entreprisePath
$pathGroups  = New-OUIfNotExists -Name $ouGroupes      -Parent $entreprisePath
$pathComputers = New-OUIfNotExists -Name $ouOrdinateurs -Parent $entreprisePath

foreach ($line in $csvContent) {
    $org = @()
    if ($line.Entite  -and $line.Entite  -ne "") { $org += $line.Entite }
    if ($line.Poles   -and $line.Poles   -ne "") { $org += $line.Poles }
    if ($line.Service -and $line.Service -ne "") { $org += $line.Service }

    $cu = $pathUsers;  foreach ($p in $org) { $cu = New-OUIfNotExists -Name $p -Parent $cu }
    $cg = $pathGroups; $groupOUPaths = @(); foreach ($p in $org) { $cg = New-OUIfNotExists -Name $p -Parent $cg; $groupOUPaths += $cg }
    $cc = $pathComputers; foreach ($p in $org) { $cc = New-OUIfNotExists -Name $p -Parent $cc }
}

# =============================================================================
#  PHASE 3/11 — Groupes de sécurité (G_ et DL_)
# =============================================================================
Write-Host "`n== PHASE 3/11 : Groupes de securite ==" -ForegroundColor Blue
Write-Host "  Creation des groupes G_ (globaux) et DL_ (domaine local) pour chaque niveau" -ForegroundColor DarkGray

foreach ($line in $csvContent) {
    $org = @()
    if ($line.Entite  -and $line.Entite  -ne "") { $org += $line.Entite }
    if ($line.Poles   -and $line.Poles   -ne "") { $org += $line.Poles }
    if ($line.Service -and $line.Service -ne "") { $org += $line.Service }

    $cg = $pathGroups; $groupOUPaths = @()
    foreach ($p in $org) { $cg = "OU=$p,$cg"; $groupOUPaths += $cg }

    $eName = "G_" + $line.Entreprise
    New-GroupIfNotExists -Name $eName -Scope "Global" -Path $pathGroups -Desc "Global $eName"
    New-GroupIfNotExists -Name "DL_$($line.Entreprise)_L" -Scope "DomainLocal" -Path $pathGroups -Desc "Lecture $($line.Entreprise)"
    New-GroupIfNotExists -Name "DL_$($line.Entreprise)_M" -Scope "DomainLocal" -Path $pathGroups -Desc "Modification $($line.Entreprise)"

    $prev = $null
    for ($i = 0; $i -lt $org.Count; $i++) {
        $parts = $org[0..$i]
        $gName = "G_" + ($parts -join "_")
        $gPath = $groupOUPaths[$i]
        New-GroupIfNotExists -Name $gName -Scope "Global" -Path $gPath -Desc "Global $gName"
        New-GroupIfNotExists -Name ("DL_" + ($parts -join "_") + "_L") -Scope "DomainLocal" -Path $gPath -Desc "Lecture $gName"
        New-GroupIfNotExists -Name ("DL_" + ($parts -join "_") + "_M") -Scope "DomainLocal" -Path $gPath -Desc "Modification $gName"
        if ($prev) { Add-MemberSafe -Member $gName -Group $prev }
        $prev = $gName
    }
    if ($org.Count -gt 0) { Add-MemberSafe -Member ("G_" + $org[0]) -Group $eName }
}

# =============================================================================
#  PHASE 4/11 — Imbrication G → DL
# =============================================================================
Write-Host "`n== PHASE 4/11 : Imbrication G -> DL ==" -ForegroundColor Blue
Write-Host "  Dernier niveau -> DL_M (modification), niveaux parents -> DL_L (lecture)" -ForegroundColor DarkGray

foreach ($line in $csvContent) {
    $org = @()
    if ($line.Entite  -and $line.Entite  -ne "") { $org += $line.Entite }
    if ($line.Poles   -and $line.Poles   -ne "") { $org += $line.Poles }
    if ($line.Service -and $line.Service -ne "") { $org += $line.Service }

    for ($i = 0; $i -lt $org.Count; $i++) {
        $parts = $org[0..$i]
        $gName = "G_" + ($parts -join "_")
        if ($i -eq $org.Count - 1) { Add-MemberSafe -Member $gName -Group ("DL_" + ($parts -join "_") + "_M") }
        else { Add-MemberSafe -Member $gName -Group ("DL_" + ($parts -join "_") + "_L") }
    }
}

# =============================================================================
#  PHASE 5/11 — Dossiers NTFS et permissions
# =============================================================================
Write-Host "`n== PHASE 5/11 : Dossiers NTFS et permissions ==" -ForegroundColor Blue
Write-Host "  Creation de C:\$entrepriseOU\... avec ACL : DL_L=Lecture, DL_M=Modification" -ForegroundColor DarkGray

foreach ($line in $csvContent) {
    $org = @()
    if ($line.Entite  -and $line.Entite  -ne "") { $org += $line.Entite }
    if ($line.Poles   -and $line.Poles   -ne "") { $org += $line.Poles }
    if ($line.Service -and $line.Service -ne "") { $org += $line.Service }

    $eFolderPath = Join-Path $rootFolder $line.Entreprise
    Set-NTFSPermissions -Path $eFolderPath -DL_Read "DL_$($line.Entreprise)_L" -DL_Modify "DL_$($line.Entreprise)_M"

    $fp = $eFolderPath
    for ($i = 0; $i -lt $org.Count; $i++) {
        $parts = $org[0..$i]
        $fp = Join-Path $fp $org[$i]
        Set-NTFSPermissions -Path $fp -DL_Read ("DL_" + ($parts -join "_") + "_L") -DL_Modify ("DL_" + ($parts -join "_") + "_M")
    }
}

# =============================================================================
#  PHASE 6/11 — Utilisateurs
# =============================================================================
Write-Host "`n== PHASE 6/11 : Utilisateurs ==" -ForegroundColor Blue
Write-Host "  Creation des $($userCsvContent.Count) comptes dans OU=Utilisateurs + ajout aux groupes G_" -ForegroundColor DarkGray

foreach ($user in $userCsvContent) {
    $ouParts = @()
    if ($user.Service -and $user.Service -ne "") { $ouParts += "OU=$($user.Service)" }
    if ($user.Pole    -and $user.Pole    -ne "") { $ouParts += "OU=$($user.Pole)" }
    if ($user.Entite  -and $user.Entite  -ne "") { $ouParts += "OU=$($user.Entite)" }
    $ouParts += "OU=$ouUtilisateurs"; $ouParts += "OU=$ouRacine"
    $userPath = ($ouParts -join ",") + ",$baseDN"

    $login = $user.Login
    $secPwd = ConvertTo-SecureString $user.MotDePasse -AsPlainText -Force

    New-UserIfNotExists -Sam $login -First $user.Prenom -Last $user.Nom -Display "$($user.Prenom) $($user.Nom)" -UPN $user.Email -Pass $secPwd -Desc $user.Fonction -Path $userPath

    $gParts = @()
    if ($user.Entite  -and $user.Entite  -ne "") { $gParts += $user.Entite }
    if ($user.Pole    -and $user.Pole    -ne "") { $gParts += $user.Pole }
    if ($user.Service -and $user.Service -ne "") { $gParts += $user.Service }
    Add-MemberSafe -Member $login -Group ("G_" + ($gParts -join "_"))
}

# =============================================================================
#  PHASE 7/11 — Dossiers et partages sur le serveur secondaire
# =============================================================================
Write-Host "`n== PHASE 7/11 : Dossiers et partages sur $serverSecondaire ==" -ForegroundColor Blue
Write-Host "  Replication de l'arborescence + partages caches par pole sur le serveur secondaire" -ForegroundColor DarkGray

foreach ($line in $csvContent) {
    $parts = @()
    if ($line.Entreprise -and $line.Entreprise -ne "") { $parts += $line.Entreprise }
    if ($line.Entite     -and $line.Entite     -ne "") { $parts += $line.Entite }
    if ($line.Poles      -and $line.Poles      -ne "") { $parts += $line.Poles }
    if ($line.Service    -and $line.Service    -ne "") { $parts += $line.Service }
    New-FolderRemote -Path ("C:\" + ($parts -join "\")) -Computer $serverSecondaire
}
foreach ($line in $csvContent | Sort-Object Poles -Unique) {
    if (-not $line.Poles -or $line.Poles -eq "") { continue }
    New-ShareSafe -Name "$($line.Poles)$" -Path "C:\$entrepriseOU\$($line.Entite)\$($line.Poles)" -Computer $serverSecondaire
}

# =============================================================================
#  PHASE 8/11 — Partages sur le serveur principal
# =============================================================================
Write-Host "`n== PHASE 8/11 : Partages sur $serverPrincipal ==" -ForegroundColor Blue
Write-Host "  Partages caches par pole (ex: fabrication$) sur le serveur principal" -ForegroundColor DarkGray

foreach ($line in $csvContent | Sort-Object Poles -Unique) {
    if (-not $line.Poles -or $line.Poles -eq "") { continue }
    New-ShareSafe -Name "$($line.Poles)$" -Path "C:\$entrepriseOU\$($line.Entite)\$($line.Poles)"
}

# =============================================================================
#  PHASE 9/11 — Espaces de noms DFS + Réplication
# =============================================================================
Write-Host "`n== PHASE 9/11 : DFS Namespaces + Replication ==" -ForegroundColor Blue
Write-Host "  \\$domainFQDN\<entite>\<pole> avec cibles $serverPrincipal+$serverSecondaire + DFSr" -ForegroundColor DarkGray

foreach ($e in $entites) {
    New-FolderRemote -Path "$dfsRootsFolder\$e"
    New-ShareSafe -Name $e -Path "$dfsRootsFolder\$e" -FullAccess "Administrateurs" -ReadAccess "Tout le monde"
    New-DfsRootSafe -DfsPath "\\$domainFQDN\$e" -Target "\\$serverPrincipal\$e"
}

foreach ($line in $csvContent | Sort-Object Poles -Unique) {
    if (-not $line.Poles -or $line.Poles -eq "") { continue }
    $pole = $line.Poles; $entite = $line.Entite

    New-DfsFolderSafe -DfsPath "\\$domainFQDN\$entite\$pole" -Target1 "\\$serverPrincipal\$pole$" -Target2 "\\$serverSecondaire\$pole$" -Desc "DFS $pole"
    New-ReplicationSafe -GroupName "$entite-$pole-Replication" -FolderName $pole -ContentPath "C:\$entrepriseOU\$entite\$pole" -DfsnPath "\\$domainFQDN\$entite\$pole"
}

# =============================================================================
#  PHASE 10/11 — Homes (dossiers, permissions, DFS, réplication, HomeDirectory)
# =============================================================================
Write-Host "`n== PHASE 10/11 : Homes ==" -ForegroundColor Blue
Write-Host "  Dossiers personnels \\$domainFQDN\HOMES\<entite>\<login> + DFS + replication + $homeDrive" -ForegroundColor DarkGray

New-FolderRemote -Path $homesFolder
foreach ($e in $entites) { New-FolderRemote -Path "$homesFolder\$e" }

$acl = Get-Acl $homesFolder
if (-not $acl.AreAccessRulesProtected) {
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($a in $acl.Access) { $acl.RemoveAccessRule($a) | Out-Null }
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule("NT AUTHORITY\SYSTEM","FullControl","ContainerInherit,ObjectInherit","None","Allow")))
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($groupeAdmins,"FullControl","ContainerInherit,ObjectInherit","None","Allow")))
    Set-Acl $homesFolder $acl
    Write-Host "  [+] Permissions racine homes" -ForegroundColor Green
} else { Write-Host "  [=] Permissions racine homes OK" -ForegroundColor Yellow }

foreach ($e in $entites) {
    $p = "$homesFolder\$e"; $acl = Get-Acl $p
    if (-not $acl.AreAccessRulesProtected) {
        $acl.SetAccessRuleProtection($true, $false)
        foreach ($a in $acl.Access) { $acl.RemoveAccessRule($a) | Out-Null }
        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule("NT AUTHORITY\SYSTEM","FullControl","ContainerInherit,ObjectInherit","None","Allow")))
        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($groupeAdmins,"FullControl","ContainerInherit,ObjectInherit","None","Allow")))
        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule("CREATEUR PROPRIETAIRE","Modify","ContainerInherit,ObjectInherit","InheritOnly","Allow")))
        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($groupeUtilDomaine,"CreateDirectories,ReadAndExecute","None","None","Allow")))
        Set-Acl $p $acl
        Write-Host "  [+] Permissions homes '$e'" -ForegroundColor Green
    } else { Write-Host "  [=] Permissions homes '$e' OK" -ForegroundColor Yellow }
}

$remoteOk = Invoke-Command -ComputerName $serverSecondaire -ScriptBlock {
    param($p,$ents) foreach ($e in $ents) { if (-not (Test-Path "$p\$e")) { return $false } }; return $true
} -ArgumentList $homesFolder,$entites
if (-not $remoteOk) {
    Robocopy $homesFolder "\\$serverSecondaire\C$\homes" /E /COPYALL /DCOPY:DAT /NFL /NDL /NJH /NJS | Out-Null
    Write-Host "  [+] Homes copiés vers $serverSecondaire" -ForegroundColor Green
} else { Write-Host "  [=] Homes déjà sur $serverSecondaire" -ForegroundColor Yellow }

foreach ($e in $entites) {
    New-ShareSafe -Name "homes-$e$" -Path "$homesFolder\$e"
    New-ShareSafe -Name "homes-$e$" -Path "$homesFolder\$e" -Computer $serverSecondaire
}

New-FolderRemote -Path "$dfsRootsFolder\HOMES"
New-ShareSafe -Name "HOMES" -Path "$dfsRootsFolder\HOMES" -FullAccess $groupeAdmins
New-DfsRootSafe -DfsPath "\\$domainFQDN\HOMES" -Target "\\$serverPrincipal\HOMES"

foreach ($e in $entites) {
    New-DfsFolderSafe -DfsPath "\\$domainFQDN\HOMES\$e" -Target1 "\\$serverPrincipal\homes-$e$" -Target2 "\\$serverSecondaire\homes-$e$" -Desc "Homes $e"
    New-ReplicationSafe -GroupName "HOMES-$e-Replication" -FolderName "homes-$e" -ContentPath "$homesFolder\$e" -DfsnPath "\\$domainFQDN\HOMES\$e"
}

foreach ($user in $userCsvContent) {
    $login = $user.Login
    $homePath = "\\$domainFQDN\HOMES\$($user.Entite)\$login"
    try {
        $ad = Get-ADUser -Identity $login -Properties HomeDirectory -ErrorAction Stop
        if ($ad.HomeDirectory -eq $homePath) { $script:c.HomeOk++ }
        else { Set-ADUser -Identity $login -HomeDirectory $homePath -HomeDrive $homeDrive -ErrorAction Stop
            Write-Host "  [+] $login → $homePath ($homeDrive)" -ForegroundColor Green; $script:c.HomeNew++ }
    } catch { Write-Host "  [!] Home '$login' : $_" -ForegroundColor Red; $script:c.Err++ }
}

# =============================================================================
#  PHASE 11/11 — GPO Emplacement réseau
# =============================================================================
Write-Host "`n== PHASE 11/11 : GPO ==" -ForegroundColor Blue
Write-Host "  GPO '$gpoName' : emplacement reseau '$homeDisplayName' a la connexion" -ForegroundColor DarkGray

$ouTarget = "OU=$ouRacine,$baseDN"

$scriptContent = @"

`$adUser = Get-ADUser -Identity `$env:USERNAME -Properties HomeDirectory
`$NetworkLocationPath = `$adUser.HomeDirectory
if (-not `$NetworkLocationPath) { exit }
`$DisplayName = "$homeDisplayName"
`$ShellApp = New-Object -ComObject Shell.Application
`$NetworkFolder = `$ShellApp.Namespace(0x13).Self.Path
`$NewLocation = Join-Path -Path `$NetworkFolder -ChildPath `$DisplayName
if (Test-Path "`$NewLocation\target.lnk") { exit }
New-Item -Path `$NewLocation -ItemType Directory -Force | Out-Null
`$ini = "[.ShellClassInfo]`r`nCLSID2={0AFACED1-E828-11D1-9187-B532F1E9575D}`r`nFlags=2"
`$iniPath = Join-Path `$NewLocation "Desktop.ini"
`$ini | Out-File -FilePath `$iniPath -Encoding Unicode
`$ws = New-Object -ComObject WScript.Shell
`$sc = `$ws.CreateShortcut("`$NewLocation\target.lnk")
`$sc.TargetPath = `$NetworkLocationPath
`$sc.Save()
Set-ItemProperty -Path `$iniPath -Name Attributes -Value ([System.IO.FileAttributes]::System -bor [System.IO.FileAttributes]::Hidden)
Set-ItemProperty -Path `$NewLocation -Name Attributes -Value ([System.IO.FileAttributes]::ReadOnly)
"@

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$localScript = Join-Path $scriptDir $gpoScriptName
if (-not (Test-Path $localScript)) { $scriptContent | Out-File -FilePath $localScript -Encoding UTF8
    Write-Host "  [+] Script '$gpoScriptName' créé" -ForegroundColor Green
} else { Write-Host "  [=] Script '$gpoScriptName' existe" -ForegroundColor Yellow }

$gpo = Get-GPO -Name $gpoName -ErrorAction SilentlyContinue
if (-not $gpo) { $gpo = New-GPO -Name $gpoName -Comment "Emplacement réseau vers le dossier personnel"
    Write-Host "  [+] GPO '$gpoName' créée" -ForegroundColor Green
} else { Write-Host "  [=] GPO '$gpoName' existe" -ForegroundColor Yellow }

try {
    $linked = Get-GPInheritance -Target $ouTarget -ErrorAction Stop | Select-Object -ExpandProperty GpoLinks | Where-Object { $_.DisplayName -eq $gpoName }
} catch { $linked = $null }
if (-not $linked) {
    try { New-GPLink -Name $gpoName -Target $ouTarget -LinkEnabled Yes -ErrorAction Stop | Out-Null
        Write-Host "  [+] GPO liée à '$ouTarget'" -ForegroundColor Green
    } catch {
        if ($_ -match "already linked") { Write-Host "  [=] GPO déjà liée" -ForegroundColor Yellow }
        else { Write-Host "  [!] Liaison GPO : $_" -ForegroundColor Red; $script:c.Err++ }
    }
} else { Write-Host "  [=] GPO déjà liée" -ForegroundColor Yellow }

$gpoId = $gpo.Id.ToString("B").ToUpper()
$sysvolPath = "\\$domainFQDN\SYSVOL\$domainFQDN\Policies\$gpoId\User\Scripts\Logon"
if (-not (Test-Path $sysvolPath)) { New-Item -Path $sysvolPath -ItemType Directory -Force | Out-Null }
$dest = Join-Path $sysvolPath $gpoScriptName
if (-not (Test-Path $dest)) { Copy-Item -Path $localScript -Destination $dest -Force
    Write-Host "  [+] Script copié dans SYSVOL" -ForegroundColor Green
} else { Write-Host "  [=] Script déjà dans SYSVOL" -ForegroundColor Yellow }

$iniPath = "\\$domainFQDN\SYSVOL\$domainFQDN\Policies\$gpoId\User\Scripts\psscripts.ini"
if (-not (Test-Path $iniPath)) {
    "`n[Logon]`n0CmdLine=$gpoScriptName`n0Parameters=" | Out-File -FilePath $iniPath -Encoding Unicode
    Write-Host "  [+] psscripts.ini créé" -ForegroundColor Green
} else {
    $raw = Get-Content $iniPath -Raw -ErrorAction SilentlyContinue
    if ($raw -match [regex]::Escape($gpoScriptName)) { Write-Host "  [=] psscripts.ini OK" -ForegroundColor Yellow }
    else { Add-Content -Path $iniPath -Value "`n[Logon]`n0CmdLine=$gpoScriptName`n0Parameters=" -Encoding Unicode
        Write-Host "  [+] Script ajouté à psscripts.ini" -ForegroundColor Green }
}

# Enregistrer les extensions CSE sur l'objet GPO AD (sinon la GPMC ne voit pas le script)
$scriptCSE = "[{42B5FAAE-6536-11D2-AE5A-0000F87571E3}{40B6664F-4972-11D1-A7CA-0000F87571E3}]"
$gpoDN = "CN=$gpoId,CN=Policies,CN=System,$baseDN"
try {
    $gpoAD = Get-ADObject -Identity $gpoDN -Properties gPCUserExtensionNames -ErrorAction Stop
    $currentExt = $gpoAD.gPCUserExtensionNames
    if (-not $currentExt -or $currentExt -notmatch "42B5FAAE") {
        $newExt = if ($currentExt) { "$currentExt$scriptCSE" } else { $scriptCSE }
        Set-ADObject -Identity $gpoDN -Replace @{gPCUserExtensionNames = $newExt} -ErrorAction Stop
        $version = [int](Get-ADObject -Identity $gpoDN -Properties versionNumber).versionNumber
        Set-ADObject -Identity $gpoDN -Replace @{versionNumber = ($version + 65536)} -ErrorAction Stop
        $gptIniPath = "\\$domainFQDN\SYSVOL\$domainFQDN\Policies\$gpoId\GPT.INI"
        if (Test-Path $gptIniPath) {
            $gptContent = Get-Content $gptIniPath -Raw
            $newVersion = $version + 65536
            $gptContent = $gptContent -replace "Version=\d+", "Version=$newVersion"
            $gptContent | Out-File -FilePath $gptIniPath -Encoding ASCII
        }
        Write-Host "  [+] Extensions CSE enregistrées (script visible dans GPMC)" -ForegroundColor Green
    } else { Write-Host "  [=] Extensions CSE déjà configurées" -ForegroundColor Yellow }
} catch { Write-Host "  [!] Extensions CSE : $_" -ForegroundColor Red; $script:c.Err++ }

# =============================================================================
#  RÉSUMÉ FINAL
# =============================================================================
$duration = (Get-Date) - $startTime

Write-Host "`n=============================================" -ForegroundColor Blue
Write-Host "  DÉPLOIEMENT TERMINÉ — $([math]::Round($duration.TotalSeconds))s" -ForegroundColor Blue
Write-Host "=============================================" -ForegroundColor Blue
Write-Host "  OUs            : $($script:c.OUNew) créées, $($script:c.OUOk) existantes" -ForegroundColor White
Write-Host "  Groupes        : $($script:c.GrpNew) créés, $($script:c.GrpOk) existants" -ForegroundColor White
Write-Host "  Membres        : $($script:c.MbrNew) ajoutés, $($script:c.MbrOk) en place" -ForegroundColor White
Write-Host "  Utilisateurs   : $($script:c.UsrNew) créés, $($script:c.UsrOk) existants" -ForegroundColor White
Write-Host "  Dossiers       : $($script:c.FldNew) créés, $($script:c.FldOk) existants" -ForegroundColor White
Write-Host "  Permissions    : $($script:c.PermNew) appliquées, $($script:c.PermOk) OK" -ForegroundColor White
Write-Host "  Partages       : $($script:c.ShrNew) créés, $($script:c.ShrOk) existants" -ForegroundColor White
Write-Host "  Racines DFS    : $($script:c.DfsRNew) créées, $($script:c.DfsROk) existantes" -ForegroundColor White
Write-Host "  Dossiers DFS   : $($script:c.DfsFNew) créés, $($script:c.DfsFOk) existants" -ForegroundColor White
Write-Host "  Cibles DFS     : $($script:c.DfsTNew) créées, $($script:c.DfsTOk) existantes" -ForegroundColor White
Write-Host "  Réplication    : $($script:c.RplNew) groupes, $($script:c.ConNew) connexions" -ForegroundColor White
Write-Host "  HomeDirectory  : $($script:c.HomeNew) configurés, $($script:c.HomeOk) OK" -ForegroundColor White
if ($script:c.Err -gt 0) { Write-Host "  ERREURS        : $($script:c.Err)" -ForegroundColor Red }
else { Write-Host "  ERREURS        : 0" -ForegroundColor Green }
Write-Host "=============================================" -ForegroundColor Blue
