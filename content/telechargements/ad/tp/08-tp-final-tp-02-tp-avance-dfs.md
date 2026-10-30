# TP Avancé — Scripter le déploiement DFS depuis un CSV

> Durée estimée : 3h
> Prérequis : TP Avancé AD terminé, DC01 + DC02 opérationnels
> Fichiers fournis : `orga-fournil.csv`, `utilisateurs-fournil.csv`
> Niveau : Avancé — écriture de script, Invoke-Command, DFS

---

## Contexte

L'arborescence AD du Fournil est en place (votre script du TP Avancé AD l'a créée). Maintenant vous devez **écrire un script PowerShell** qui automatise tout le déploiement DFS :
- Installation des rôles
- Création des dossiers et partages sur les 2 serveurs
- Configuration des espaces de noms DFS
- Mise en place de la réplication
- Création des dossiers personnels (homes)

Le script doit lire les CSV pour construire dynamiquement les partages, namespaces et groupes de réplication.

---

## Exercice 1 — Variables et configuration

### Consigne

En haut de votre script, définissez les variables :
- Les chemins des 2 CSV
- Le nom de domaine (`ad.fournil.lab`)
- Les noms des 2 serveurs (`DC01`, `DC02`)
- Le dossier racine des fichiers (`C:\fournil`)
- Le dossier des homes (`C:\homes`)
- Le dossier des racines DFS (`C:\DFSRoots`)
- La liste des entités (`Laboratoire`, `Vente`)

Importez les 2 CSV.

### Questions

- Pourquoi stocker les noms de serveurs dans des variables ?
- Pourquoi la liste des entités est-elle séparée du CSV ?

> [!tip]- Besoin d'aide ? Cliquez ici
> ```powershell
> $domainName = "ad.fournil.lab"
> $serverPrincipal = "DC01"
> $serverSecondaire = "DC02"
> $rootFolder = "C:\fournil"
> $homesFolder = "C:\homes"
> $dfsRootsFolder = "C:\DFSRoots"
> $entites = @("Laboratoire", "Vente")
> ```

---

## Exercice 2 — Installer les rôles DFS

### Consigne

Écrivez la partie du script qui :
1. Vérifie si les rôles **DFS Namespace** et **DFS Replication** sont installés sur DC01
2. Les installe uniquement s'ils manquent
3. Vérifie et installe **DFS Replication** sur DC02 via `Invoke-Command`

### Questions

- Quelle cmdlet vérifie si un rôle Windows est installé ?
- Pourquoi DC01 a besoin de `FS-DFS-Namespace` ET `FS-DFS-Replication` mais DC02 seulement de `FS-DFS-Replication` ?
- Comment exécuter une commande sur un serveur distant avec `Invoke-Command` ?

### Vérification

```powershell
Get-WindowsFeature FS-DFS-Namespace, FS-DFS-Replication | Select-Object Name, InstallState
Invoke-Command -ComputerName DC02 { Get-WindowsFeature FS-DFS-Replication | Select-Object Name, InstallState }
```

> [!tip]- Indice sur Invoke-Command
> ```powershell
> $missingRemote = Invoke-Command -ComputerName $serverSecondaire -ScriptBlock {
>     (Get-WindowsFeature FS-DFS-Replication).InstallState -ne "Installed"
> }
> if ($missingRemote) {
>     Invoke-Command -ComputerName $serverSecondaire -ScriptBlock {
>         Install-WindowsFeature FS-DFS-Replication -IncludeManagementTools
>     }
> }
> ```

---

## Exercice 3 — Créer les dossiers et partages depuis le CSV

### Consigne

Écrivez 2 fonctions utilitaires :
- `New-FolderIfNotExists` — crée un dossier s'il n'existe pas (local ou distant via `-ComputerName`)
- `New-ShareIfNotExists` — crée un partage SMB s'il n'existe pas (local ou distant)

Puis parcourez le CSV pour :
1. Créer toute l'arborescence de dossiers sur **DC02** (miroir de DC01)
2. Créer un partage caché par pôle (`fabrication$`, `boutique$`, etc.) sur **DC01 et DC02**

### Questions

- Comment construire le chemin du dossier à partir des colonnes du CSV ? (`Entreprise\Entite\Poles\Service`)
- Comment créer un dossier sur un serveur distant ? (`Invoke-Command` ou partage `C$` ?)
- Comment vérifier qu'un partage SMB existe sur un serveur distant ?
- Pourquoi utiliser des partages cachés (`$`) ?
- Comment éviter les doublons de partages quand plusieurs lignes CSV ont le même Pôle ?

### Vérification

```powershell
Get-SmbShare | Where-Object { $_.Name -like "*$" -and $_.Name -notlike "[A-Z]$" }
Invoke-Command -ComputerName DC02 { Get-SmbShare | Where-Object { $_.Name -like "*$" -and $_.Name -notlike "[A-Z]$" } }
```

> [!tip]- Indice sur la création distante
> Pour créer sur un serveur distant, passez les paramètres au ScriptBlock :
> ```powershell
> function New-FolderIfNotExists {
>     param ([string]$path, [string]$computerName)
>     if ($computerName) {
>         $exists = Invoke-Command -ComputerName $computerName -ScriptBlock {
>             param($p) Test-Path $p
>         } -ArgumentList $path
>         if (-not $exists) {
>             Invoke-Command -ComputerName $computerName -ScriptBlock {
>                 param($p) New-Item -Path $p -ItemType Directory -Force
>             } -ArgumentList $path
>         }
>     }
> }
> ```

> [!tip]- Indice sur les pôles uniques
> Utilisez `Sort-Object -Unique` pour ne traiter chaque pôle qu'une fois :
> ```powershell
> foreach ($line in $csvContent | Sort-Object Poles -Unique) {
>     if (-not $line.Poles -or $line.Poles -eq "") { continue }
>     $shareName = "$($line.Poles)$"
>     # Créer le partage...
> }
> ```

---

## Exercice 4 — Espaces de noms DFS

> Etudiez l'architecture DFS avant de commencer :

![Schema-DFS-Architecture](https://cours.kaya.ovh/active-directory/assets/supports/c46280291d5668e55094.svg)

### Consigne

Écrivez la partie du script qui crée les espaces de noms DFS :

1. Pour chaque entité (`Laboratoire`, `Vente`) :
   - Créez le dossier racine `C:\DFSRoots\<Entite>`
   - Créez le partage `<Entite>` pointant vers ce dossier
   - Créez la racine DFS `\\ad.fournil.lab\<Entite>` de type `DomainV2`

2. Pour chaque pôle du CSV :
   - Créez le dossier DFS `\\ad.fournil.lab\<Entite>\<Pole>`
   - Ajoutez 2 cibles : `\\DC01\<Pole>$` et `\\DC02\<Pole>$`

### Questions

- Quelle est la différence entre `New-DfsnRoot` et `New-DfsnFolder` ?
- Que signifie `-Type DomainV2` ?
- Que fait `-EnableAccessBasedEnumeration $true` ?
- Quelle cmdlet ajoute une 2ème cible à un dossier DFS existant ?

### Vérification

```powershell
Get-DfsnRoot -Path "\\ad.fournil.lab\*"
Get-DfsnFolder -Path "\\ad.fournil.lab\Laboratoire\*"
Get-DfsnFolderTarget -Path "\\ad.fournil.lab\Laboratoire\fabrication"
```

> [!tip]- Indice sur la gestion d'erreurs DFS
> Les cmdlets DFS n'ont pas de `-Filter` pratique. Utilisez try/catch pour vérifier l'existence :
> ```powershell
> try {
>     Get-DfsnRoot -Path $dfsRootPath -ErrorAction Stop
>     Write-Host "  [=] Racine existe déjà"
> } catch {
>     New-DfsnRoot -Path $dfsRootPath -TargetPath "\\$serverPrincipal\$entite" `
>         -Type DomainV2 -EnableAccessBasedEnumeration $true
> }
> ```

---

## Exercice 5 — Réplication DFSr

### Consigne

Pour chaque pôle du CSV, écrivez le code qui :
1. Crée un groupe de réplication `<Entite>-<Pole>-Replication`
2. Ajoute DC01 et DC02 comme membres
3. Crée une connexion bidirectionnelle entre les 2 serveurs
4. Configure DC01 comme **membre principal** (`-PrimaryMember $true`)
5. Lie la réplication à l'espace de noms DFS

### Questions

- Quelle est la différence entre `New-DfsReplicationGroup` et `New-DfsReplicatedFolder` ?
- Pourquoi un serveur est "principal" ? Que se passe-t-il au premier sync ?
- Que fait `Set-DfsReplicatedFolder -DfsnPath` ?
- La réplication est-elle unidirectionnelle ou bidirectionnelle ?

### Test

```powershell
# Créer un fichier test sur DC01
New-Item "C:\fournil\Laboratoire\fabrication\test-replication.txt" -Value "bonjour"

# Attendre 30 secondes puis vérifier sur DC02
Invoke-Command -ComputerName DC02 { Get-Content "C:\fournil\Laboratoire\fabrication\test-replication.txt" }
```

> [!tip]- Indice sur le chaînage des cmdlets DFS
> Les cmdlets DFSr se chaînent via le pipeline :
> ```powershell
> New-DfsReplicationGroup -GroupName $replGroupName |
>     New-DfsReplicatedFolder -FolderName $folderName |
>     Add-DfsrMember -ComputerName $serverPrincipal, $serverSecondaire
> 
> Add-DfsrConnection -GroupName $replGroupName `
>     -SourceComputerName $serverPrincipal `
>     -DestinationComputerName $serverSecondaire
> 
> Set-DfsrMembership -GroupName $replGroupName -FolderName $folderName `
>     -ContentPath $contentPath -ComputerName $serverPrincipal `
>     -PrimaryMember $true -Force
> ```

---

## Exercice 6 — Dossiers personnels (Homes)

### Consigne

Écrivez la partie du script qui gère les homes :

1. **Dossiers et permissions** :
   - Créez `C:\homes` et `C:\homes\<Entite>` sur DC01
   - Racine `C:\homes` : SYSTEM + Admins du domaine uniquement
   - Sous-dossiers : + `CREATEUR PROPRIETAIRE` en modification + `Utilisateurs du domaine` en création de dossier

2. **Partages** :
   - Créez un partage caché `homes-<Entite>$` par entité sur DC01 et DC02

3. **DFS** :
   - Créez la racine DFS `\\ad.fournil.lab\HOMES`
   - Pour chaque entité, créez un dossier DFS avec 2 cibles (DC01 + DC02)

4. **Réplication** :
   - Créez un groupe de réplication `HOMES-<Entite>-Replication` par entité

5. **HomeDirectory** :
   - Parcourez `utilisateurs-fournil.csv`
   - Pour chaque utilisateur, configurez `HomeDirectory` vers `\\ad.fournil.lab\HOMES\<Entite>\<Login>` avec le lecteur `H:`

### Questions

- Qu'est-ce que `CREATEUR PROPRIETAIRE` ? Pourquoi l'utiliser pour les homes ?
- Pourquoi `InheritOnly` pour `CREATEUR PROPRIETAIRE` ?
- Comment copier les dossiers homes vers DC02 avec leurs permissions ? (`Robocopy /COPYALL`)
- Que fait `Set-ADUser -HomeDirectory ... -HomeDrive "H:"` ?

### Vérification

```powershell
Get-ADUser -Identity "mlebrun" -Properties HomeDirectory, HomeDrive |
    Select-Object Name, HomeDirectory, HomeDrive

Get-DfsnFolder -Path "\\ad.fournil.lab\HOMES\*"
```

> [!tip]- Indice sur les permissions homes
> Les homes ont des permissions spéciales : `CREATEUR PROPRIETAIRE` avec `InheritOnly` permet à chaque utilisateur de devenir propriétaire de son sous-dossier :
> ```powershell
> $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
>     "CREATEUR PROPRIETAIRE", "Modify",
>     "ContainerInherit,ObjectInherit", "InheritOnly", "Allow")))
> $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
>     "FOURNIL\Utilisateurs du domaine", "CreateDirectories,ReadAndExecute",
>     "None", "None", "Allow")))
> ```

> [!tip]- Indice sur le HomeDirectory
> ```powershell
> foreach ($user in $userCsvContent) {
>     $homePath = "\\$domainName\HOMES\$($user.Entite)\$($user.Login)"
>     Set-ADUser -Identity $user.Login -HomeDirectory $homePath -HomeDrive "H:"
> }
> ```

---

## Exercice 7 — Vérification globale

### Consigne

Ajoutez un résumé en fin de script avec des compteurs, puis testez depuis un **poste client** connecté avec `mlebrun` :

| Test | Résultat attendu | OK ? |
|------|-------------------|------|
| `\\ad.fournil.lab\Laboratoire\fabrication` | Accès en modification | ☐ |
| `\\ad.fournil.lab\Vente\ressources` | Accès refusé | ☐ |
| Lecteur `H:` visible | Pointe vers le home | ☐ |
| Créer un fichier dans `H:` | Fonctionne | ☐ |
| Créer un fichier sur DC01, vérifier sur DC02 | Répliqué | ☐ |

### Critère de réussite

Votre script doit être **idempotent** : une 2ème exécution ne recrée rien.

---

## Bonus — Adaptabilité

Si on changeait les CSV et les variables pour un cabinet d'architectes avec 3 serveurs au lieu de 2, quelles modifications faudrait-il apporter ?

- Les fonctions doivent-elles changer ?
- Quelles variables ajouter/modifier ?
- Comment gérer un 3ème serveur de réplication ?

> La correction de ce TP : [Explication-Script-DFS](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-script-explication-script-dfs)
