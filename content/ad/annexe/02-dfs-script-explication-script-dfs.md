---
title: "Procédure de déploiement DFS -- Fournil"
---

## Présentation générale

Ce document décrit en détail la procédure de déploiement du système de fichiers distribués (DFS) pour l'infrastructure Active Directory de l'entreprise **Fournil**, une boulangerie dont le domaine est `ad.fournil.lab`.

L'infrastructure repose sur deux serveurs :

| Serveur | Rôle | Description |
|---------|------|-------------|
| **DC01** | Contrôleur de domaine principal | Héberge les espaces de noms DFS (DFSn) et la réplication (DFSr). Contient les dossiers partagés et les dossiers personnels (homes). Membre primaire de tous les groupes de réplication. |
| **DC02** | Contrôleur de domaine secondaire | Héberge la réplication DFS (DFSr) uniquement. Reçoit les réplicas des dossiers partagés et des homes. |

Le script `02-Deployer-DFS-fournil.ps1` automatise l'ensemble du déploiement en **7 phases** séquentielles. Ce document explique chaque phase, chaque commande et chaque paramètre afin qu'un administrateur puisse soit exécuter le script directement, soit reproduire la procédure manuellement étape par étape.

### Fichiers CSV requis

Le script s'appuie sur deux fichiers CSV :

- **`orga-fournil.csv`** : décrit l'organigramme de l'entreprise avec les colonnes `Entreprise`, `Entite`, `Poles`, `Service`.
- **`utilisateurs-fournil.csv`** : liste les utilisateurs avec leurs informations (dont le login et l'entité de rattachement).

### Structure organisationnelle

L'entreprise Fournil est divisée en deux entités, chacune regroupant plusieurs pôles :

| Entité | Pôles |
|--------|-------|
| **Laboratoire** | fabrication, approvisionnement, conditionnement, qualite-hygiene, maintenance, direction-laboratoire, communs-laboratoire |
| **Vente** | boutique, commercial, livraisons, ressources, direction-vente, communs-vente |

---

## Phase 1 : Installation des rôles DFS

### Objectif

Installer les fonctionnalités Windows nécessaires au fonctionnement de DFS sur les deux serveurs. DC01 reçoit à la fois le rôle **Espaces de noms DFS** (DFSn) et le rôle **Réplication DFS** (DFSr), tandis que DC02 ne reçoit que le rôle **Réplication DFS** (DFSr).

### Pourquoi cette répartition ?

- **DC01** héberge les espaces de noms (la « vitrine » DFS que voient les utilisateurs) et participe à la réplication : il a donc besoin des deux rôles.
- **DC02** est uniquement un partenaire de réplication : il reçoit les copies des fichiers mais ne publie pas d'espace de noms. Le rôle DFSn n'est donc pas nécessaire sur DC02.

### Commandes détaillées

#### 1.1 -- Installation sur DC01 (exécution locale)

```powershell
Install-WindowsFeature FS-DFS-Namespace, FS-DFS-Replication -IncludeManagementTools
```

**Explication des paramètres :**

| Paramètre | Valeur | Description |
|-----------|--------|-------------|
| `FS-DFS-Namespace` | -- | Nom interne de la fonctionnalité « Espaces de noms DFS ». Permet de créer et gérer des espaces de noms (arborescences virtuelles de dossiers partagés). |
| `FS-DFS-Replication` | -- | Nom interne de la fonctionnalité « Réplication DFS ». Permet de synchroniser automatiquement des dossiers entre plusieurs serveurs via le moteur de réplication RDC (Remote Differential Compression). |
| `-IncludeManagementTools` | -- | Installe également les outils d'administration associés : la console graphique « Gestion du système de fichiers distribués DFS » (`dfsmgmt.msc`) et les cmdlets PowerShell du module `DFSN` et `DFSR`. Sans ce paramètre, seuls les services seraient installés, sans interface de gestion. |

La cmdlet `Install-WindowsFeature` est fournie par le module `ServerManager`. Elle installe un ou plusieurs rôles ou fonctionnalités sur le serveur Windows. On peut passer plusieurs noms de fonctionnalités séparés par des virgules.

#### 1.2 -- Installation sur DC02 (exécution distante)

```powershell
Invoke-Command -ComputerName DC02 -ScriptBlock {
    Install-WindowsFeature FS-DFS-Replication -IncludeManagementTools
}
```

**Explication des paramètres :**

| Paramètre | Valeur | Description |
|-----------|--------|-------------|
| `-ComputerName` | `DC02` | Nom NetBIOS ou FQDN du serveur distant sur lequel exécuter la commande. Ici, on cible le contrôleur de domaine secondaire DC02. |
| `-ScriptBlock` | `{ ... }` | Bloc de script PowerShell qui sera exécuté à distance via WinRM (Windows Remote Management). Tout le code entre les accolades s'exécute dans le contexte du serveur distant. |

On n'installe ici que `FS-DFS-Replication` (pas `FS-DFS-Namespace`) car DC02 ne publie pas d'espace de noms.

> **Note :** `Invoke-Command` nécessite que le service WinRM soit activé sur DC02 et que le compte exécutant la commande ait les droits administratifs sur le serveur distant. Dans un domaine Active Directory, les comptes du groupe « Admins du domaine » disposent de ces droits par défaut.

### Vérification

Après installation, on peut vérifier les fonctionnalités installées :

```powershell
# Sur DC01
Get-WindowsFeature FS-DFS-Namespace, FS-DFS-Replication

# Sur DC02
Invoke-Command -ComputerName DC02 -ScriptBlock {
    Get-WindowsFeature FS-DFS-Replication
}
```

La colonne `Install State` doit indiquer `Installed` pour chaque fonctionnalité.

---

## Phase 2 : Création des dossiers et partages sur DC02

### Objectif

Créer l'arborescence de dossiers `C:\fournil\...` sur DC02 à partir du fichier CSV `orga-fournil.csv`, puis créer des partages SMB masqués pour chaque pôle.

### Pourquoi sur DC02 d'abord ?

Le script AD précédent (`01-Deployer-AD-fournil.ps1`) a déjà créé l'arborescence sur DC01. Il faut donc reproduire cette structure sur DC02 pour que la réplication DFS puisse fonctionner. Les dossiers doivent exister des deux côtés avant de configurer la réplication.

### Commandes détaillées

#### 2.1 -- Lecture du fichier CSV

```powershell
$csvContent = Import-Csv -Path ".\orga-fournil.csv" -Delimiter ";"
```

| Paramètre | Valeur | Description |
|-----------|--------|-------------|
| `-Path` | `".\orga-fournil.csv"` | Chemin vers le fichier CSV contenant l'organigramme. |
| `-Delimiter` | `";"` | Caractère séparateur des colonnes dans le fichier CSV. En France, on utilise souvent le point-virgule car la virgule sert de séparateur décimal. |

`Import-Csv` lit le fichier et retourne un tableau d'objets PowerShell, chaque ligne du CSV devenant un objet dont les propriétés correspondent aux en-têtes de colonnes (`Entreprise`, `Entite`, `Poles`, `Service`).

#### 2.2 -- Création de l'arborescence sur DC02

```powershell
Invoke-Command -ComputerName DC02 -ScriptBlock {
    param($csv)
    foreach ($ligne in $csv) {
        $entite = $ligne.Entite
        $pole   = $ligne.Poles
        $chemin = "C:\fournil\$entite\$pole"
        if (-not (Test-Path $chemin)) {
            New-Item -ItemType Directory -Path $chemin -Force
        }
    }
} -ArgumentList (,$csvContent)
```

**Explication approfondie de `-ArgumentList (,$csvContent)` :**

C'est l'un des aspects les plus subtils de cette commande. Décortiquons :

- `-ArgumentList` : paramètre de `Invoke-Command` qui permet de passer des données locales au bloc de script distant. Les variables locales (comme `$csvContent`) n'existent pas dans le contexte distant ; il faut explicitement les transmettre.
- `(,$csvContent)` : la syntaxe avec la virgule unaire `,` est cruciale. Sans elle, PowerShell « déballerait » (unwrap) le tableau et passerait chaque élément du CSV comme un argument séparé au lieu de passer le tableau entier comme un seul argument.
  - `(,$csvContent)` crée un tableau contenant un seul élément : le tableau `$csvContent`. Ainsi, quand PowerShell déballe le premier niveau, il obtient `$csvContent` intact comme un seul argument.
  - Sans la virgule : `-ArgumentList $csvContent` passerait la première ligne du CSV à `$csv`, la deuxième ligne à un second paramètre inexistant, etc.
- `param($csv)` : dans le `ScriptBlock`, le mot-clé `param()` déclare les paramètres qui reçoivent les valeurs de `-ArgumentList`. Le premier paramètre `$csv` reçoit le premier argument, c'est-à-dire le tableau CSV complet.

**Autres commandes utilisées :**

| Cmdlet | Description |
|--------|-------------|
| `Test-Path $chemin` | Vérifie si le chemin (dossier ou fichier) existe déjà. Retourne `$true` ou `$false`. |
| `New-Item -ItemType Directory -Path $chemin -Force` | Crée un nouveau dossier. Le paramètre `-Force` crée automatiquement les dossiers parents intermédiaires s'ils n'existent pas (équivalent de `mkdir -p` sous Linux). |

#### 2.3 -- Création des partages SMB masqués sur DC02

```powershell
Invoke-Command -ComputerName DC02 -ScriptBlock {
    param($csv)
    $poles = $csv | Select-Object -Property Entite, Poles -Unique
    foreach ($item in $poles) {
        $entite = $item.Entite
        $pole   = $item.Poles
        $nomPartage = "$pole$"
        $chemin     = "C:\fournil\$entite\$pole"
        if (-not (Get-SmbShare -Name $nomPartage -ErrorAction SilentlyContinue)) {
            New-SmbShare -Name $nomPartage -Path $chemin -FullAccess "Tout le monde"
        }
    }
} -ArgumentList (,$csvContent)
```

**Explication des partages masqués :**

Un partage dont le nom se termine par `$` est un **partage masqué** (hidden share) sous Windows. Il n'apparaît pas lorsqu'on parcourt le réseau (`\\DC02\`) mais reste accessible si on connaît son nom exact (`\\DC02\fabrication$`). C'est une pratique courante pour les partages DFS : les utilisateurs accèdent aux fichiers via le chemin DFS (par exemple `\\ad.fournil.lab\Laboratoire\fabrication`) et n'ont pas besoin de voir les partages sous-jacents.

**Cmdlets utilisées :**

| Cmdlet | Description |
|--------|-------------|
| `Select-Object -Property Entite, Poles -Unique` | Extrait les combinaisons uniques d'entité/pôle du CSV. Élimine les doublons car plusieurs services peuvent appartenir au même pôle. |
| `Get-SmbShare -Name $nomPartage -ErrorAction SilentlyContinue` | Vérifie si le partage existe déjà. `-ErrorAction SilentlyContinue` empêche l'affichage d'une erreur si le partage n'existe pas (la cmdlet retourne alors `$null`). |
| `New-SmbShare -Name $nomPartage -Path $chemin -FullAccess "Tout le monde"` | Crée un nouveau partage SMB. `-FullAccess "Tout le monde"` accorde le contrôle total au niveau du partage à tous les utilisateurs. Les permissions effectives seront ensuite restreintes par les ACL NTFS sur les dossiers. |

> **Bonne pratique :** Les permissions au niveau du partage (`-FullAccess "Tout le monde"`) sont volontairement larges. Le contrôle d'accès fin se fait au niveau des permissions NTFS et de l'ABE (Access-Based Enumeration) configurée sur les espaces de noms DFS.

### Exemples de partages créés sur DC02

| Partage | Chemin local |
|---------|-------------|
| `fabrication$` | `C:\fournil\Laboratoire\fabrication` |
| `approvisionnement$` | `C:\fournil\Laboratoire\approvisionnement` |
| `conditionnement$` | `C:\fournil\Laboratoire\conditionnement` |
| `qualite-hygiene$` | `C:\fournil\Laboratoire\qualite-hygiene` |
| `maintenance$` | `C:\fournil\Laboratoire\maintenance` |
| `direction-laboratoire$` | `C:\fournil\Laboratoire\direction-laboratoire` |
| `communs-laboratoire$` | `C:\fournil\Laboratoire\communs-laboratoire` |
| `boutique$` | `C:\fournil\Vente\boutique` |
| `commercial$` | `C:\fournil\Vente\commercial` |
| `livraisons$` | `C:\fournil\Vente\livraisons` |
| `ressources$` | `C:\fournil\Vente\ressources` |
| `direction-vente$` | `C:\fournil\Vente\direction-vente` |
| `communs-vente$` | `C:\fournil\Vente\communs-vente` |

---

## Phase 3 : Création des partages par pôle sur DC01

### Objectif

Créer les mêmes partages SMB masqués sur DC01. Les dossiers existent déjà sur DC01 (créés par le script AD précédent) ; il ne reste qu'à les partager.

### Commandes détaillées

#### 3.1 -- Création des partages sur DC01

```powershell
$poles = $csvContent | Select-Object -Property Entite, Poles -Unique
foreach ($item in $poles) {
    $entite = $item.Entite
    $pole   = $item.Poles
    $nomPartage = "$pole$"
    $chemin     = "C:\fournil\$entite\$pole"
    if (-not (Get-SmbShare -Name $nomPartage -ErrorAction SilentlyContinue)) {
        New-SmbShare -Name "$pole$" -Path "C:\fournil\$entite\$pole" -FullAccess "Tout le monde"
    }
}
```

**Explication :**

La logique est identique à celle de la Phase 2, mais exécutée localement sur DC01 (pas besoin de `Invoke-Command`). Pour chaque combinaison unique entité/pôle :

1. On construit le nom du partage masqué : le nom du pôle suivi de `$`.
2. On construit le chemin local : `C:\fournil\<Entite>\<Pole>`.
3. On vérifie que le partage n'existe pas déjà.
4. On crée le partage avec `New-SmbShare`.

**Détail des paramètres de `New-SmbShare` :**

| Paramètre | Valeur | Description |
|-----------|--------|-------------|
| `-Name` | `"$pole$"` | Nom du partage réseau. Le `$` final en fait un partage masqué. Attention : en PowerShell, `"$pole$"` dans une chaîne entre guillemets doubles interpole la variable `$pole`, et le `$` final (non suivi d'un nom de variable) est traité comme un caractère littéral. |
| `-Path` | `"C:\fournil\$entite\$pole"` | Chemin local du dossier à partager. Les variables `$entite` et `$pole` sont interpolées. |
| `-FullAccess` | `"Tout le monde"` | Groupe intégré Windows (équivalent français de « Everyone »). Accorde le contrôle total au niveau du partage. |

> **Remarque sur la localisation :** Le groupe `Tout le monde` est le nom français du groupe intégré `Everyone`. Sur un Windows installé en français, il faut utiliser ce nom localisé. Sur un Windows en anglais, il faudrait utiliser `Everyone`.

---

## Phase 4 : Création des espaces de noms DFS

### Objectif

Configurer les espaces de noms DFS (DFSn) qui fournissent une arborescence unifiée aux utilisateurs. Au lieu d'accéder à `\\DC01\fabrication$` ou `\\DC02\fabrication$`, les utilisateurs accèdent à `\\ad.fournil.lab\Laboratoire\fabrication` -- un chemin unique, indépendant du serveur physique.

### Concepts clés

- **Racine DFS (DFS Root)** : point d'entrée de l'espace de noms, associé à un partage sur un serveur. Exemple : `\\ad.fournil.lab\Laboratoire`.
- **Dossier DFS (DFS Folder)** : sous-dossier virtuel dans l'espace de noms, renvoyant vers un ou plusieurs partages physiques. Exemple : `\\ad.fournil.lab\Laboratoire\fabrication`.
- **Cible de dossier DFS (DFS Folder Target)** : chemin UNC réel vers lequel pointe un dossier DFS. Un dossier peut avoir plusieurs cibles (une par serveur) pour la redondance.
- **ABE (Access-Based Enumeration)** : fonctionnalité qui masque les dossiers auxquels l'utilisateur n'a pas accès. Ainsi, chaque utilisateur ne voit que les dossiers qui le concernent.

### Commandes détaillées

#### 4.1 -- Création des dossiers racines sur DC01

```powershell
New-Item -ItemType Directory -Path "C:\DFSRoots\Laboratoire" -Force
New-Item -ItemType Directory -Path "C:\DFSRoots\Vente" -Force
```

Ces dossiers locaux servent de support physique aux racines DFS. Ils sont placés dans `C:\DFSRoots\` par convention (emplacement recommandé par Microsoft).

#### 4.2 -- Création des partages pour les racines DFS

```powershell
New-SmbShare -Name "Laboratoire" -Path "C:\DFSRoots\Laboratoire" `
    -FullAccess "Administrateurs" -ReadAccess "Tout le monde"

New-SmbShare -Name "Vente" -Path "C:\DFSRoots\Vente" `
    -FullAccess "Administrateurs" -ReadAccess "Tout le monde"
```

**Explication des paramètres :**

| Paramètre | Valeur | Description |
|-----------|--------|-------------|
| `-Name` | `"Laboratoire"` ou `"Vente"` | Nom du partage réseau (sans `$` : ces partages doivent être visibles car ils hébergent les racines DFS). |
| `-Path` | `"C:\DFSRoots\..."` | Chemin local du dossier racine. |
| `-FullAccess` | `"Administrateurs"` | Seuls les administrateurs ont le contrôle total sur le partage racine. |
| `-ReadAccess` | `"Tout le monde"` | Tous les utilisateurs peuvent lire le contenu (voir la liste des dossiers DFS). L'ABE se chargera de filtrer ce que chacun voit réellement. |

> **Différence avec les partages de pôles :** Les partages racines ne sont pas masqués (pas de `$`) et ont des permissions plus restrictives au niveau du partage (`ReadAccess` au lieu de `FullAccess` pour `Tout le monde`).

#### 4.3 -- Création des racines d'espaces de noms DFS

```powershell
New-DfsnRoot -Path "\\ad.fournil.lab\Laboratoire" `
    -TargetPath "\\DC01\Laboratoire" `
    -Type DomainV2 `
    -EnableAccessBasedEnumeration $true

New-DfsnRoot -Path "\\ad.fournil.lab\Vente" `
    -TargetPath "\\DC01\Vente" `
    -Type DomainV2 `
    -EnableAccessBasedEnumeration $true
```

**Explication approfondie des paramètres :**

| Paramètre | Valeur | Description |
|-----------|--------|-------------|
| `-Path` | `"\\ad.fournil.lab\Laboratoire"` | Chemin UNC de l'espace de noms DFS tel qu'il sera vu par les utilisateurs. Le premier segment (`ad.fournil.lab`) est le nom de domaine, le second (`Laboratoire`) est le nom de la racine. |
| `-TargetPath` | `"\\DC01\Laboratoire"` | Chemin UNC du partage physique qui héberge cette racine. C'est le partage créé à l'étape 4.2. |
| `-Type` | `DomainV2` | Type d'espace de noms. Les valeurs possibles sont : |
| | | - `Standalone` : espace de noms autonome, hébergé sur un seul serveur, sans intégration AD. Limité et non tolérant aux pannes. |
| | | - `DomainV1` : espace de noms basé sur le domaine, mode Windows 2000. Compatible avec les anciens systèmes mais limité (pas d'ABE, pas de scalabilité). |
| | | - **`DomainV2`** : espace de noms basé sur le domaine, mode Windows Server 2008+. C'est le mode recommandé. Il offre : la prise en charge de l'ABE, une meilleure scalabilité (jusqu'à 50 000 dossiers par racine), et le stockage de la configuration dans la partition de domaine AD. |
| `-EnableAccessBasedEnumeration` | `$true` | Active l'énumération basée sur l'accès. Quand un utilisateur parcourt `\\ad.fournil.lab\Laboratoire`, il ne verra que les sous-dossiers (pôles) pour lesquels il dispose d'au moins une permission de lecture. Cela évite de montrer des dossiers inaccessibles et simplifie la navigation. |

#### 4.4 -- Création des dossiers DFS pour chaque pôle

Pour chaque combinaison entité/pôle, on crée un dossier DFS et on ajoute les cibles :

```powershell
# Exemple pour le pôle "fabrication" de l'entité "Laboratoire"
New-DfsnFolder -Path "\\ad.fournil.lab\Laboratoire\fabrication" `
    -TargetPath "\\DC01\fabrication$"

New-DfsnFolderTarget -Path "\\ad.fournil.lab\Laboratoire\fabrication" `
    -TargetPath "\\DC02\fabrication$"
```

Cette opération est répétée pour chaque pôle. Voici ce que font ces cmdlets :

**`New-DfsnFolder`** : crée un dossier virtuel dans l'espace de noms DFS.

| Paramètre | Valeur | Description |
|-----------|--------|-------------|
| `-Path` | `"\\ad.fournil.lab\Laboratoire\fabrication"` | Chemin complet du dossier dans l'espace de noms. Le premier segment est le domaine, le deuxième la racine, le troisième le dossier. |
| `-TargetPath` | `"\\DC01\fabrication$"` | Premier chemin cible (partage physique). Quand un utilisateur accède au dossier DFS, il est redirigé vers ce partage. C'est la cible principale (DC01). |

**`New-DfsnFolderTarget`** : ajoute une cible supplémentaire à un dossier DFS existant.

| Paramètre | Valeur | Description |
|-----------|--------|-------------|
| `-Path` | `"\\ad.fournil.lab\Laboratoire\fabrication"` | Chemin du dossier DFS existant auquel ajouter la cible. |
| `-TargetPath` | `"\\DC02\fabrication$"` | Deuxième chemin cible (partage physique sur DC02). Le client DFS choisira automatiquement la cible la plus appropriée (généralement le serveur le plus proche ou le moins chargé). |

Avec deux cibles, si DC01 est indisponible, les utilisateurs sont automatiquement redirigés vers DC02 (tolérance aux pannes).

#### 4.5 -- Liste complète des dossiers DFS créés

**Entité Laboratoire :**

```powershell
# fabrication
New-DfsnFolder -Path "\\ad.fournil.lab\Laboratoire\fabrication" -TargetPath "\\DC01\fabrication$"
New-DfsnFolderTarget -Path "\\ad.fournil.lab\Laboratoire\fabrication" -TargetPath "\\DC02\fabrication$"

# approvisionnement
New-DfsnFolder -Path "\\ad.fournil.lab\Laboratoire\approvisionnement" -TargetPath "\\DC01\approvisionnement$"
New-DfsnFolderTarget -Path "\\ad.fournil.lab\Laboratoire\approvisionnement" -TargetPath "\\DC02\approvisionnement$"

# conditionnement
New-DfsnFolder -Path "\\ad.fournil.lab\Laboratoire\conditionnement" -TargetPath "\\DC01\conditionnement$"
New-DfsnFolderTarget -Path "\\ad.fournil.lab\Laboratoire\conditionnement" -TargetPath "\\DC02\conditionnement$"

# qualite-hygiene
New-DfsnFolder -Path "\\ad.fournil.lab\Laboratoire\qualite-hygiene" -TargetPath "\\DC01\qualite-hygiene$"
New-DfsnFolderTarget -Path "\\ad.fournil.lab\Laboratoire\qualite-hygiene" -TargetPath "\\DC02\qualite-hygiene$"

# maintenance
New-DfsnFolder -Path "\\ad.fournil.lab\Laboratoire\maintenance" -TargetPath "\\DC01\maintenance$"
New-DfsnFolderTarget -Path "\\ad.fournil.lab\Laboratoire\maintenance" -TargetPath "\\DC02\maintenance$"

# direction-laboratoire
New-DfsnFolder -Path "\\ad.fournil.lab\Laboratoire\direction-laboratoire" -TargetPath "\\DC01\direction-laboratoire$"
New-DfsnFolderTarget -Path "\\ad.fournil.lab\Laboratoire\direction-laboratoire" -TargetPath "\\DC02\direction-laboratoire$"

# communs-laboratoire
New-DfsnFolder -Path "\\ad.fournil.lab\Laboratoire\communs-laboratoire" -TargetPath "\\DC01\communs-laboratoire$"
New-DfsnFolderTarget -Path "\\ad.fournil.lab\Laboratoire\communs-laboratoire" -TargetPath "\\DC02\communs-laboratoire$"
```

**Entité Vente :**

```powershell
# boutique
New-DfsnFolder -Path "\\ad.fournil.lab\Vente\boutique" -TargetPath "\\DC01\boutique$"
New-DfsnFolderTarget -Path "\\ad.fournil.lab\Vente\boutique" -TargetPath "\\DC02\boutique$"

# commercial
New-DfsnFolder -Path "\\ad.fournil.lab\Vente\commercial" -TargetPath "\\DC01\commercial$"
New-DfsnFolderTarget -Path "\\ad.fournil.lab\Vente\commercial" -TargetPath "\\DC02\commercial$"

# livraisons
New-DfsnFolder -Path "\\ad.fournil.lab\Vente\livraisons" -TargetPath "\\DC01\livraisons$"
New-DfsnFolderTarget -Path "\\ad.fournil.lab\Vente\livraisons" -TargetPath "\\DC02\livraisons$"

# ressources
New-DfsnFolder -Path "\\ad.fournil.lab\Vente\ressources" -TargetPath "\\DC01\ressources$"
New-DfsnFolderTarget -Path "\\ad.fournil.lab\Vente\ressources" -TargetPath "\\DC02\ressources$"

# direction-vente
New-DfsnFolder -Path "\\ad.fournil.lab\Vente\direction-vente" -TargetPath "\\DC01\direction-vente$"
New-DfsnFolderTarget -Path "\\ad.fournil.lab\Vente\direction-vente" -TargetPath "\\DC02\direction-vente$"

# communs-vente
New-DfsnFolder -Path "\\ad.fournil.lab\Vente\communs-vente" -TargetPath "\\DC01\communs-vente$"
New-DfsnFolderTarget -Path "\\ad.fournil.lab\Vente\communs-vente" -TargetPath "\\DC02\communs-vente$"
```

---

## Phase 5 : Configuration de la réplication DFS (DFSr)

### Objectif

Mettre en place la réplication automatique des fichiers entre DC01 et DC02 pour chaque pôle. La réplication DFS utilise le protocole RDC (Remote Differential Compression) pour ne transmettre que les différences entre fichiers, économisant ainsi la bande passante.

### Concepts clés

- **Groupe de réplication (Replication Group)** : conteneur logique qui définit un ensemble de serveurs et de dossiers à répliquer ensemble.
- **Dossier répliqué (Replicated Folder)** : dossier physique inclus dans un groupe de réplication.
- **Membre (Member)** : serveur participant à un groupe de réplication.
- **Connexion (Connection)** : lien de réplication entre deux membres.
- **Membre primaire (Primary Member)** : lors de la réplication initiale, le membre primaire est la source de référence. En cas de conflit, ses fichiers priment.

### Commandes détaillées pour un pôle

La procédure est identique pour chaque pôle. Prenons l'exemple du pôle `fabrication` de l'entité `Laboratoire` :

#### 5.1 -- Création du groupe de réplication

```powershell
New-DfsReplicationGroup -GroupName "Laboratoire-fabrication-Replication"
```

| Paramètre | Valeur | Description |
|-----------|--------|-------------|
| `-GroupName` | `"Laboratoire-fabrication-Replication"` | Nom du groupe de réplication. La convention de nommage utilisée est `<Entite>-<Pole>-Replication` pour identifier facilement chaque groupe. |

Cette cmdlet crée un objet groupe de réplication vide dans Active Directory. Il faut ensuite lui ajouter des dossiers, des membres et des connexions.

#### 5.2 -- Ajout du dossier répliqué

```powershell
New-DfsReplicatedFolder -GroupName "Laboratoire-fabrication-Replication" `
    -FolderName "fabrication"
```

| Paramètre | Valeur | Description |
|-----------|--------|-------------|
| `-GroupName` | `"Laboratoire-fabrication-Replication"` | Nom du groupe de réplication auquel ajouter le dossier. |
| `-FolderName` | `"fabrication"` | Nom logique du dossier répliqué. Ce nom est utilisé dans la configuration ; le chemin physique réel est défini séparément via `Set-DfsrMembership`. |

#### 5.3 -- Ajout des membres (serveurs)

```powershell
Add-DfsrMember -GroupName "Laboratoire-fabrication-Replication" `
    -ComputerName DC01,DC02
```

| Paramètre | Valeur | Description |
|-----------|--------|-------------|
| `-GroupName` | `"Laboratoire-fabrication-Replication"` | Groupe de réplication auquel ajouter les membres. |
| `-ComputerName` | `DC01,DC02` | Liste des serveurs à ajouter comme membres. On peut passer plusieurs noms séparés par des virgules. Les deux serveurs rejoignent le groupe en une seule commande. |

#### 5.4 -- Création de la connexion de réplication

```powershell
Add-DfsrConnection -GroupName "Laboratoire-fabrication-Replication" `
    -SourceComputerName DC01 `
    -DestinationComputerName DC02
```

| Paramètre | Valeur | Description |
|-----------|--------|-------------|
| `-GroupName` | `"Laboratoire-fabrication-Replication"` | Groupe de réplication concerné. |
| `-SourceComputerName` | `DC01` | Serveur source de la connexion de réplication. |
| `-DestinationComputerName` | `DC02` | Serveur destination de la connexion de réplication. |

> **Note :** Bien que la connexion soit définie avec une source et une destination, la réplication DFS est **bidirectionnelle** par défaut. Les modifications effectuées sur DC02 sont également répliquées vers DC01. La notion de source/destination définit surtout la topologie initiale et la direction de la réplication de première synchronisation.

#### 5.5 -- Configuration de l'appartenance (membership) pour DC01

```powershell
Set-DfsrMembership -GroupName "Laboratoire-fabrication-Replication" `
    -FolderName "fabrication" `
    -ComputerName DC01 `
    -ContentPath "C:\fournil\Laboratoire\fabrication" `
    -PrimaryMember $true `
    -Force
```

| Paramètre | Valeur | Description |
|-----------|--------|-------------|
| `-GroupName` | `"Laboratoire-fabrication-Replication"` | Groupe de réplication. |
| `-FolderName` | `"fabrication"` | Nom logique du dossier répliqué (défini à l'étape 5.2). |
| `-ComputerName` | `DC01` | Serveur membre à configurer. |
| `-ContentPath` | `"C:\fournil\Laboratoire\fabrication"` | Chemin physique local du dossier sur ce serveur. C'est ici que le moteur DFSr lira et écrira les fichiers répliqués. |
| `-PrimaryMember` | `$true` | **Paramètre crucial.** Désigne DC01 comme le membre primaire. Lors de la réplication initiale, si des fichiers existent des deux côtés avec des différences, les fichiers de DC01 font autorité. Les fichiers en conflit sur DC02 sont déplacés dans le dossier `ConflictAndDeleted`. |
| `-Force` | -- | Supprime les demandes de confirmation interactives. Nécessaire pour une exécution non interactive (dans un script). |

#### 5.6 -- Configuration de l'appartenance pour DC02

```powershell
Set-DfsrMembership -GroupName "Laboratoire-fabrication-Replication" `
    -FolderName "fabrication" `
    -ComputerName DC02 `
    -ContentPath "C:\fournil\Laboratoire\fabrication" `
    -Force
```

Même commande que pour DC01, mais sans `-PrimaryMember $true`. Par défaut, le membre n'est pas primaire (`$false`). DC02 recevra les fichiers de DC01 lors de la synchronisation initiale.

#### 5.7 -- Liaison avec l'espace de noms DFS

```powershell
Set-DfsReplicatedFolder -GroupName "Laboratoire-fabrication-Replication" `
    -FolderName "fabrication" `
    -DfsnPath "\\ad.fournil.lab\Laboratoire\fabrication"
```

| Paramètre | Valeur | Description |
|-----------|--------|-------------|
| `-DfsnPath` | `"\\ad.fournil.lab\Laboratoire\fabrication"` | Associe le dossier répliqué à son chemin dans l'espace de noms DFS. Cette liaison permet aux outils d'administration de corréler la réplication et l'espace de noms, et facilite le diagnostic. |

### Récapitulatif : groupes de réplication créés

Cette séquence de 7 commandes (5.1 à 5.7) est répétée pour chaque pôle. Voici la liste complète des groupes de réplication :

| Groupe de réplication | Entité | Pôle |
|-----------------------|--------|------|
| `Laboratoire-fabrication-Replication` | Laboratoire | fabrication |
| `Laboratoire-approvisionnement-Replication` | Laboratoire | approvisionnement |
| `Laboratoire-conditionnement-Replication` | Laboratoire | conditionnement |
| `Laboratoire-qualite-hygiene-Replication` | Laboratoire | qualite-hygiene |
| `Laboratoire-maintenance-Replication` | Laboratoire | maintenance |
| `Laboratoire-direction-laboratoire-Replication` | Laboratoire | direction-laboratoire |
| `Laboratoire-communs-laboratoire-Replication` | Laboratoire | communs-laboratoire |
| `Vente-boutique-Replication` | Vente | boutique |
| `Vente-commercial-Replication` | Vente | commercial |
| `Vente-livraisons-Replication` | Vente | livraisons |
| `Vente-ressources-Replication` | Vente | ressources |
| `Vente-direction-vente-Replication` | Vente | direction-vente |
| `Vente-communs-vente-Replication` | Vente | communs-vente |

---

## Phase 6 : Configuration des dossiers personnels (Homes)

### Objectif

Créer les dossiers personnels des utilisateurs (homes) avec les permissions NTFS appropriées, les répliquer sur DC02, les partager, les intégrer dans un espace de noms DFS dédié, et configurer la réplication.

### Commandes détaillées

#### 6.1 -- Création des dossiers homes sur DC01

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

#### 6.2 -- Configuration des permissions NTFS sur le dossier racine `C:\homes`

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

#### 6.3 -- Configuration des permissions NTFS par entité

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

#### 6.4 -- Copie des homes vers DC02 avec Robocopy

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

#### 6.5 -- Création des partages homes sur DC01 et DC02

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

#### 6.6 -- Création de l'espace de noms DFS pour les homes

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

#### 6.7 -- Configuration de la réplication DFSr pour les homes

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

---

## Phase 7 : Configuration du HomeDirectory des utilisateurs

### Objectif

Associer à chaque utilisateur Active Directory un dossier personnel (home directory) et un lecteur réseau mappé automatiquement à l'ouverture de session.

### Commandes détaillées

#### 7.1 -- Lecture du fichier utilisateurs

```powershell
$utilisateurs = Import-Csv -Path ".\utilisateurs-fournil.csv" -Delimiter ";"
```

Le fichier contient les informations de chaque utilisateur, dont le login (`SamAccountName`) et l'entité de rattachement.

#### 7.2 -- Configuration du HomeDirectory pour chaque utilisateur

```powershell
foreach ($user in $utilisateurs) {
    $login  = $user.Login       # ou le nom de la colonne correspondante
    $entite = $user.Entite

    # Vérifier si le HomeDirectory est déjà configuré
    $adUser = Get-ADUser -Identity $login -Properties HomeDirectory, HomeDrive
    if (-not $adUser.HomeDirectory) {
        Set-ADUser -Identity $login `
            -HomeDirectory "\\ad.fournil.lab\HOMES\$entite\$login" `
            -HomeDrive "H:"
    }
}
```

**Explication des paramètres de `Set-ADUser` :**

| Paramètre | Valeur | Description |
|-----------|--------|-------------|
| `-Identity` | `$login` | Identifie l'utilisateur AD à modifier. Accepte un `SamAccountName`, un `DistinguishedName`, un `SID` ou un `GUID`. Ici, on utilise le login (SamAccountName). |
| `-HomeDirectory` | `"\\ad.fournil.lab\HOMES\$entite\$login"` | Chemin UNC du dossier personnel de l'utilisateur. Le chemin passe par l'espace de noms DFS : `\\ad.fournil.lab\HOMES\<Entite>\<Login>`. Par exemple, pour l'utilisateur `jdupont` de l'entité `Laboratoire` : `\\ad.fournil.lab\HOMES\Laboratoire\jdupont`. |
| `-HomeDrive` | `"H:"` | Lettre de lecteur qui sera automatiquement mappée au `HomeDirectory` lors de l'ouverture de session Windows de l'utilisateur. `H:` est une convention courante (H pour Home). |

**Explication de la vérification préalable :**

```powershell
$adUser = Get-ADUser -Identity $login -Properties HomeDirectory, HomeDrive
if (-not $adUser.HomeDirectory) { ... }
```

- `Get-ADUser -Properties HomeDirectory, HomeDrive` : par défaut, `Get-ADUser` ne retourne qu'un sous-ensemble de propriétés. Il faut explicitement demander `HomeDirectory` et `HomeDrive` avec le paramètre `-Properties`.
- `if (-not $adUser.HomeDirectory)` : vérifie que le `HomeDirectory` n'est pas déjà configuré. Si la propriété est `$null` ou vide, `-not` retourne `$true` et la configuration est appliquée. Cela rend le script idempotent : on peut le relancer sans risquer d'écraser une configuration existante.

### Comportement côté utilisateur

Lors de l'ouverture de session :

1. Windows lit les attributs `HomeDirectory` et `HomeDrive` de l'utilisateur dans Active Directory.
2. Windows mappe automatiquement le lecteur `H:` vers `\\ad.fournil.lab\HOMES\<Entite>\<Login>`.
3. Si le dossier n'existe pas encore, Windows le crée automatiquement (grâce à la permission `CreateDirectories` accordée aux « Utilisateurs du domaine » à l'étape 6.3).
4. L'utilisateur devient le « créateur propriétaire » de son dossier et obtient les droits de modification (grâce à la permission CREATEUR PROPRIETAIRE configurée à l'étape 6.3).
5. L'utilisateur peut stocker ses fichiers personnels dans `H:\`, qui sera répliqué entre DC01 et DC02.

---

## Tableau récapitulatif des chemins DFS

### Espaces de noms des pôles

| Chemin DFS (vu par les utilisateurs) | Cible DC01 | Cible DC02 |
|---------------------------------------|------------|-----------|
| `\\ad.fournil.lab\Laboratoire\fabrication` | `\\DC01\fabrication$` | `\\DC02\fabrication$` |
| `\\ad.fournil.lab\Laboratoire\approvisionnement` | `\\DC01\approvisionnement$` | `\\DC02\approvisionnement$` |
| `\\ad.fournil.lab\Laboratoire\conditionnement` | `\\DC01\conditionnement$` | `\\DC02\conditionnement$` |
| `\\ad.fournil.lab\Laboratoire\qualite-hygiene` | `\\DC01\qualite-hygiene$` | `\\DC02\qualite-hygiene$` |
| `\\ad.fournil.lab\Laboratoire\maintenance` | `\\DC01\maintenance$` | `\\DC02\maintenance$` |
| `\\ad.fournil.lab\Laboratoire\direction-laboratoire` | `\\DC01\direction-laboratoire$` | `\\DC02\direction-laboratoire$` |
| `\\ad.fournil.lab\Laboratoire\communs-laboratoire` | `\\DC01\communs-laboratoire$` | `\\DC02\communs-laboratoire$` |
| `\\ad.fournil.lab\Vente\boutique` | `\\DC01\boutique$` | `\\DC02\boutique$` |
| `\\ad.fournil.lab\Vente\commercial` | `\\DC01\commercial$` | `\\DC02\commercial$` |
| `\\ad.fournil.lab\Vente\livraisons` | `\\DC01\livraisons$` | `\\DC02\livraisons$` |
| `\\ad.fournil.lab\Vente\ressources` | `\\DC01\ressources$` | `\\DC02\ressources$` |
| `\\ad.fournil.lab\Vente\direction-vente` | `\\DC01\direction-vente$` | `\\DC02\direction-vente$` |
| `\\ad.fournil.lab\Vente\communs-vente` | `\\DC01\communs-vente$` | `\\DC02\communs-vente$` |

### Espaces de noms des homes

| Chemin DFS (vu par les utilisateurs) | Cible DC01 | Cible DC02 |
|---------------------------------------|------------|-----------|
| `\\ad.fournil.lab\HOMES\Laboratoire` | `\\DC01\homes-Laboratoire$` | `\\DC02\homes-Laboratoire$` |
| `\\ad.fournil.lab\HOMES\Vente` | `\\DC01\homes-Vente$` | `\\DC02\homes-Vente$` |

### Groupes de réplication DFSr

| Groupe de réplication | Dossier répliqué | Chemin DC01 | Chemin DC02 | Membre primaire |
|-----------------------|------------------|-------------|------------|-----------------|
| `Laboratoire-fabrication-Replication` | fabrication | `C:\fournil\Laboratoire\fabrication` | `C:\fournil\Laboratoire\fabrication` | DC01 |
| `Laboratoire-approvisionnement-Replication` | approvisionnement | `C:\fournil\Laboratoire\approvisionnement` | `C:\fournil\Laboratoire\approvisionnement` | DC01 |
| `Laboratoire-conditionnement-Replication` | conditionnement | `C:\fournil\Laboratoire\conditionnement` | `C:\fournil\Laboratoire\conditionnement` | DC01 |
| `Laboratoire-qualite-hygiene-Replication` | qualite-hygiene | `C:\fournil\Laboratoire\qualite-hygiene` | `C:\fournil\Laboratoire\qualite-hygiene` | DC01 |
| `Laboratoire-maintenance-Replication` | maintenance | `C:\fournil\Laboratoire\maintenance` | `C:\fournil\Laboratoire\maintenance` | DC01 |
| `Laboratoire-direction-laboratoire-Replication` | direction-laboratoire | `C:\fournil\Laboratoire\direction-laboratoire` | `C:\fournil\Laboratoire\direction-laboratoire` | DC01 |
| `Laboratoire-communs-laboratoire-Replication` | communs-laboratoire | `C:\fournil\Laboratoire\communs-laboratoire` | `C:\fournil\Laboratoire\communs-laboratoire` | DC01 |
| `Vente-boutique-Replication` | boutique | `C:\fournil\Vente\boutique` | `C:\fournil\Vente\boutique` | DC01 |
| `Vente-commercial-Replication` | commercial | `C:\fournil\Vente\commercial` | `C:\fournil\Vente\commercial` | DC01 |
| `Vente-livraisons-Replication` | livraisons | `C:\fournil\Vente\livraisons` | `C:\fournil\Vente\livraisons` | DC01 |
| `Vente-ressources-Replication` | ressources | `C:\fournil\Vente\ressources` | `C:\fournil\Vente\ressources` | DC01 |
| `Vente-direction-vente-Replication` | direction-vente | `C:\fournil\Vente\direction-vente` | `C:\fournil\Vente\direction-vente` | DC01 |
| `Vente-communs-vente-Replication` | communs-vente | `C:\fournil\Vente\communs-vente` | `C:\fournil\Vente\communs-vente` | DC01 |
| `HOMES-Laboratoire-Replication` | homes-Laboratoire | `C:\homes\Laboratoire` | `C:\homes\Laboratoire` | DC01 |
| `HOMES-Vente-Replication` | homes-Vente | `C:\homes\Vente` | `C:\homes\Vente` | DC01 |

---

## Commandes de vérification post-déploiement

Après avoir exécuté le script (ou suivi cette procédure manuellement), voici les commandes pour valider le bon fonctionnement :

### Vérifier les espaces de noms DFS

```powershell
# Lister les racines DFS
Get-DfsnRoot -Path "\\ad.fournil.lab\*"

# Lister les dossiers DFS d'un espace de noms
Get-DfsnFolder -Path "\\ad.fournil.lab\Laboratoire\*"
Get-DfsnFolder -Path "\\ad.fournil.lab\Vente\*"
Get-DfsnFolder -Path "\\ad.fournil.lab\HOMES\*"

# Vérifier les cibles d'un dossier DFS
Get-DfsnFolderTarget -Path "\\ad.fournil.lab\Laboratoire\fabrication"
```

### Vérifier la réplication DFS

```powershell
# Lister les groupes de réplication
Get-DfsReplicationGroup

# Vérifier l'état d'un groupe de réplication
Get-DfsrState -GroupName "Laboratoire-fabrication-Replication"

# Générer un rapport de diagnostic de réplication
Write-DfsrHealthReport -GroupName "Laboratoire-fabrication-Replication" `
    -ReferenceComputerName DC01 -Path "C:\DFSRapports"
```

### Vérifier les partages SMB

```powershell
# Sur DC01
Get-SmbShare | Where-Object { $_.Name -like "*$*" -and $_.Name -ne "IPC$" -and $_.Name -ne "C$" }

# Sur DC02
Invoke-Command -ComputerName DC02 -ScriptBlock {
    Get-SmbShare | Where-Object { $_.Name -like "*$*" -and $_.Name -ne "IPC$" -and $_.Name -ne "C$" }
}
```

### Vérifier les HomeDirectory des utilisateurs

```powershell
Get-ADUser -Filter * -Properties HomeDirectory, HomeDrive |
    Where-Object { $_.HomeDirectory } |
    Select-Object SamAccountName, HomeDirectory, HomeDrive |
    Format-Table -AutoSize
```

---

## Dépannage courant

| Problème | Cause probable | Solution |
|----------|---------------|----------|
| `New-DfsnRoot` échoue avec « accès refusé » | Le compte n'a pas les droits d'administration de l'espace de noms | Vérifier l'appartenance au groupe « Admins du domaine » |
| La réplication ne démarre pas | Le service DFSR n'est pas démarré | `Get-Service DFSR -ComputerName DC01,DC02` puis `Start-Service DFSR` |
| Les dossiers DFS ne sont pas visibles | L'ABE masque les dossiers sans permission | Vérifier les ACL NTFS sur les dossiers physiques |
| `Invoke-Command` échoue | WinRM non activé ou pare-feu bloquant | `Enable-PSRemoting -Force` sur DC02, vérifier le port 5985/TCP |
| Le lecteur `H:` ne se mappe pas à l'ouverture de session | Le `HomeDirectory` n'est pas configuré dans AD | Vérifier avec `Get-ADUser -Properties HomeDirectory` |
| Conflit de fichiers après réplication initiale | Des fichiers différents existaient des deux côtés | Vérifier le dossier `ConflictAndDeleted` sur le membre non primaire |
