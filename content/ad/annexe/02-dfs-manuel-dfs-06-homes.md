---
title: "Phase 6 — Configuration des dossiers personnels Homes"
---

> Retour vers l'index : [Index DFS Manuel](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-00-index)
> Phase precedente : [DFS-05-Replication-DFSr](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-05-replication-dfsr) | Phase suivante : [DFS-07-HomeDirectory](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-07-homedirectory)

## Objectif

Créer les dossiers personnels des utilisateurs (homes) avec les permissions NTFS appropriées, les répliquer sur DC02, les partager, les intégrer dans un espace de noms DFS dédié, et configurer la réplication.

## Commandes détaillées

### 6.1 -- Création des dossiers homes sur DC01

```powershell
New-Item -ItemType Directory -Path "C:\homes\Laboratoire" -Force
New-Item -ItemType Directory -Path "C:\homes\Vente" -Force
```

L'arborescence créée :

```
C:\homes\
    Laboratoire\
    Vente\
```

### 6.2 -- Configuration des permissions NTFS sur le dossier racine `C:\homes`

```powershell
$acl = Get-Acl "C:\homes"

# Désactiver l'héritage et supprimer les permissions héritées
$acl.SetAccessRuleProtection($true, $false)

# SYSTEM : Contrôle total
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "SYSTEM", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
)
$acl.AddAccessRule($rule)

# Administrateurs : Contrôle total
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "Administrateurs", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
)
$acl.AddAccessRule($rule)

Set-Acl "C:\homes" $acl
```

**Explication des paramètres de `FileSystemAccessRule` :**

Le constructeur prend 5 arguments :

1. **Identité** (`"SYSTEM"` ou `"Administrateurs"`) : le compte ou groupe concerné.
2. **Droits** (`"FullControl"`) : le niveau de permission. Valeurs possibles : `FullControl`, `Modify`, `ReadAndExecute`, `Read`, `Write`, `CreateDirectories`, etc.
3. **Héritage** (`"ContainerInherit,ObjectInherit"`) : définit comment la permission se propage aux enfants.
   - `ContainerInherit` : la permission s'applique aux sous-dossiers.
   - `ObjectInherit` : la permission s'applique aux fichiers.
   - Les deux combinés : la permission s'applique à tout le contenu récursivement.
4. **Propagation** (`"None"`) : modifie le comportement de l'héritage.
   - `None` : la permission s'applique à cet objet ET aux enfants.
   - `InheritOnly` : la permission ne s'applique qu'aux enfants, pas à l'objet lui-même.
   - `NoPropagateInherit` : la permission s'applique aux enfants directs uniquement (pas aux petits-enfants).
5. **Type** (`"Allow"`) : `Allow` pour autoriser, `Deny` pour refuser.

**`SetAccessRuleProtection($true, $false)` :**
- Premier argument `$true` : active la protection (désactive l'héritage des permissions du parent).
- Second argument `$false` : ne conserve pas les permissions héritées existantes (les supprime). Si `$true`, les permissions héritées seraient converties en permissions explicites.

Le résultat : seuls SYSTEM et les Administrateurs ont accès au dossier `C:\homes`. Aucun utilisateur standard ne peut y accéder directement.

### 6.3 -- Configuration des permissions NTFS par entité

Pour chaque dossier d'entité (`C:\homes\Laboratoire` et `C:\homes\Vente`) :

```powershell
$acl = Get-Acl "C:\homes\Laboratoire"
$acl.SetAccessRuleProtection($true, $false)

# SYSTEM : Contrôle total
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "SYSTEM", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
)
$acl.AddAccessRule($rule)

# Administrateurs : Contrôle total
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "Administrateurs", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
)
$acl.AddAccessRule($rule)

# CREATEUR PROPRIETAIRE : Modification (hérité par les sous-dossiers uniquement)
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "CREATEUR PROPRIETAIRE", "Modify", "ContainerInherit,ObjectInherit", "InheritOnly", "Allow"
)
$acl.AddAccessRule($rule)

# Utilisateurs du domaine : Créer des dossiers (sur ce dossier uniquement)
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "Utilisateurs du domaine", "CreateDirectories", "None", "None", "Allow"
)
$acl.AddAccessRule($rule)

Set-Acl "C:\homes\Laboratoire" $acl
```

**Explication de la logique des permissions :**

| Identité | Droit | Héritage | Propagation | Effet |
|----------|-------|----------|-------------|-------|
| SYSTEM | FullControl | ContainerInherit, ObjectInherit | None | Accès total partout (nécessaire au système). |
| Administrateurs | FullControl | ContainerInherit, ObjectInherit | None | Les administrateurs gèrent tous les homes. |
| CREATEUR PROPRIETAIRE | Modify | ContainerInherit, ObjectInherit | InheritOnly | Quand un utilisateur crée son dossier home, il en devient le propriétaire et obtient automatiquement le droit de modification sur ce dossier et son contenu. `InheritOnly` signifie que cette règle ne s'applique pas au dossier d'entité lui-même, uniquement aux sous-dossiers créés dedans. |
| Utilisateurs du domaine | CreateDirectories | None | None | Permet aux utilisateurs du domaine de créer un sous-dossier (leur home) dans le dossier d'entité. `None` pour l'héritage signifie que cette permission ne s'applique qu'à ce dossier, pas aux sous-dossiers. Les utilisateurs peuvent créer leur dossier mais ne peuvent pas lister le contenu du dossier parent ni accéder aux homes des autres. |

> **Principe de fonctionnement :** Quand un utilisateur se connecte pour la première fois et que Windows crée son dossier home, l'utilisateur devient le « créateur propriétaire » de ce dossier. La règle CREATEUR PROPRIETAIRE lui accorde alors automatiquement les droits de modification. C'est un mécanisme élégant qui évite de devoir configurer les permissions individuellement pour chaque utilisateur.

### 6.4 -- Copie des homes vers DC02 avec Robocopy

```powershell
robocopy "C:\homes" "\\DC02\C$\homes" /MIR /COPYALL /R:1 /W:1
```

| Paramètre | Description |
|-----------|-------------|
| `"C:\homes"` | Dossier source (local sur DC01). |
| `"\\DC02\C$\homes"` | Dossier destination sur DC02, via le partage administratif `C$`. |
| `/MIR` | Mode miroir : copie tout et supprime dans la destination les fichiers qui n'existent plus dans la source. Crée une copie exacte. |
| `/COPYALL` | Copie tous les attributs des fichiers : données, attributs, horodatages, **permissions NTFS (DACL)**, propriétaire, **informations d'audit (SACL)**. C'est crucial pour que les permissions configurées à l'étape 6.3 soient identiques sur DC02. |
| `/R:1` | Nombre de tentatives en cas d'échec de copie d'un fichier : 1 (au lieu des 1 million par défaut). |
| `/W:1` | Temps d'attente entre les tentatives : 1 seconde (au lieu de 30 secondes par défaut). |

> **Pourquoi `/COPYALL` et pas `/COPY:DATSOU` ?** `/COPYALL` est un raccourci pour `/COPY:DATSOU` qui copie les 6 attributs : **D**onnées, **A**ttributs, **T**imestamps, **S**ecurity (DACL), **O**wner, a**U**diting (SACL). On utilise `/COPYALL` ici car les permissions NTFS doivent être identiques sur les deux serveurs pour que la réplication DFS fonctionne correctement.

### 6.5 -- Création des partages homes sur DC01 et DC02

```powershell
# Sur DC01
New-SmbShare -Name "homes-Laboratoire$" -Path "C:\homes\Laboratoire" -FullAccess "Tout le monde"
New-SmbShare -Name "homes-Vente$" -Path "C:\homes\Vente" -FullAccess "Tout le monde"

# Sur DC02
Invoke-Command -ComputerName DC02 -ScriptBlock {
    New-SmbShare -Name "homes-Laboratoire$" -Path "C:\homes\Laboratoire" -FullAccess "Tout le monde"
    New-SmbShare -Name "homes-Vente$" -Path "C:\homes\Vente" -FullAccess "Tout le monde"
}
```

Les partages sont masqués (`$`) et nommés `homes-<Entite>$`. L'accès total au niveau du partage est accordé à tout le monde ; ce sont les permissions NTFS qui contrôlent l'accès réel.

### 6.6 -- Création de l'espace de noms DFS pour les homes

```powershell
# Création du dossier racine et du partage
New-Item -ItemType Directory -Path "C:\DFSRoots\HOMES" -Force
New-SmbShare -Name "HOMES" -Path "C:\DFSRoots\HOMES" `
    -FullAccess "Administrateurs" -ReadAccess "Tout le monde"

# Création de la racine DFS
New-DfsnRoot -Path "\\ad.fournil.lab\HOMES" `
    -TargetPath "\\DC01\HOMES" `
    -Type DomainV2 `
    -EnableAccessBasedEnumeration $true

# Création des dossiers DFS pour chaque entité
New-DfsnFolder -Path "\\ad.fournil.lab\HOMES\Laboratoire" `
    -TargetPath "\\DC01\homes-Laboratoire$"
New-DfsnFolderTarget -Path "\\ad.fournil.lab\HOMES\Laboratoire" `
    -TargetPath "\\DC02\homes-Laboratoire$"

New-DfsnFolder -Path "\\ad.fournil.lab\HOMES\Vente" `
    -TargetPath "\\DC01\homes-Vente$"
New-DfsnFolderTarget -Path "\\ad.fournil.lab\HOMES\Vente" `
    -TargetPath "\\DC02\homes-Vente$"
```

L'espace de noms `\\ad.fournil.lab\HOMES` permet aux utilisateurs d'accéder à leurs dossiers personnels via un chemin uniforme, indépendamment du serveur physique.

### 6.7 -- Configuration de la réplication DFSr pour les homes

La procédure suit le même schéma que pour les pôles (Phase 5), avec deux groupes de réplication :

```powershell
# --- HOMES Laboratoire ---
New-DfsReplicationGroup -GroupName "HOMES-Laboratoire-Replication"
New-DfsReplicatedFolder -GroupName "HOMES-Laboratoire-Replication" -FolderName "homes-Laboratoire"
Add-DfsrMember -GroupName "HOMES-Laboratoire-Replication" -ComputerName DC01,DC02
Add-DfsrConnection -GroupName "HOMES-Laboratoire-Replication" `
    -SourceComputerName DC01 -DestinationComputerName DC02

Set-DfsrMembership -GroupName "HOMES-Laboratoire-Replication" `
    -FolderName "homes-Laboratoire" -ComputerName DC01 `
    -ContentPath "C:\homes\Laboratoire" -PrimaryMember $true -Force

Set-DfsrMembership -GroupName "HOMES-Laboratoire-Replication" `
    -FolderName "homes-Laboratoire" -ComputerName DC02 `
    -ContentPath "C:\homes\Laboratoire" -Force

Set-DfsReplicatedFolder -GroupName "HOMES-Laboratoire-Replication" `
    -FolderName "homes-Laboratoire" `
    -DfsnPath "\\ad.fournil.lab\HOMES\Laboratoire"

# --- HOMES Vente ---
New-DfsReplicationGroup -GroupName "HOMES-Vente-Replication"
New-DfsReplicatedFolder -GroupName "HOMES-Vente-Replication" -FolderName "homes-Vente"
Add-DfsrMember -GroupName "HOMES-Vente-Replication" -ComputerName DC01,DC02
Add-DfsrConnection -GroupName "HOMES-Vente-Replication" `
    -SourceComputerName DC01 -DestinationComputerName DC02

Set-DfsrMembership -GroupName "HOMES-Vente-Replication" `
    -FolderName "homes-Vente" -ComputerName DC01 `
    -ContentPath "C:\homes\Vente" -PrimaryMember $true -Force

Set-DfsrMembership -GroupName "HOMES-Vente-Replication" `
    -FolderName "homes-Vente" -ComputerName DC02 `
    -ContentPath "C:\homes\Vente" -Force

Set-DfsReplicatedFolder -GroupName "HOMES-Vente-Replication" `
    -FolderName "homes-Vente" `
    -DfsnPath "\\ad.fournil.lab\HOMES\Vente"
```
