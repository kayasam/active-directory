---
title: "Phase 4 — Creation des espaces de noms DFS"
---

> Retour vers l'index : [Index DFS Manuel](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-00-index)
> Phase precedente : [DFS-03-Partages-DC01](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-03-partages-dc01) | Phase suivante : [DFS-05-Replication-DFSr](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-05-replication-dfsr)

![Schema-DFS-Architecture](https://cours.kaya.ovh/active-directory/assets/supports/c46280291d5668e55094.svg)

## Objectif

Configurer les espaces de noms DFS (DFSn) qui fournissent une arborescence unifiée aux utilisateurs. Au lieu d'accéder à `\\DC01\fabrication$` ou `\\DC02\fabrication$`, les utilisateurs accèdent à `\\ad.fournil.lab\Laboratoire\fabrication` -- un chemin unique, indépendant du serveur physique.

## Concepts clés

- **Racine DFS (DFS Root)** : point d'entrée de l'espace de noms, associé à un partage sur un serveur. Exemple : `\\ad.fournil.lab\Laboratoire`.
- **Dossier DFS (DFS Folder)** : sous-dossier virtuel dans l'espace de noms, renvoyant vers un ou plusieurs partages physiques. Exemple : `\\ad.fournil.lab\Laboratoire\fabrication`.
- **Cible de dossier DFS (DFS Folder Target)** : chemin UNC réel vers lequel pointe un dossier DFS. Un dossier peut avoir plusieurs cibles (une par serveur) pour la redondance.
- **ABE (Access-Based Enumeration)** : fonctionnalité qui masque les dossiers auxquels l'utilisateur n'a pas accès. Ainsi, chaque utilisateur ne voit que les dossiers qui le concernent.

## Commandes détaillées

### 4.1 -- Création des dossiers racines sur DC01

```powershell
New-Item -ItemType Directory -Path "C:\DFSRoots\Laboratoire" -Force
New-Item -ItemType Directory -Path "C:\DFSRoots\Vente" -Force
```

Ces dossiers locaux servent de support physique aux racines DFS. Ils sont placés dans `C:\DFSRoots\` par convention (emplacement recommandé par Microsoft).

### 4.2 -- Création des partages pour les racines DFS

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

### 4.3 -- Création des racines d'espaces de noms DFS

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

### 4.4 -- Création des dossiers DFS pour chaque pôle

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

### 4.5 -- Liste complète des dossiers DFS créés

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
