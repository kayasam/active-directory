---
title: "Phase 2 — Creation des dossiers et partages sur DC02"
---

> Retour vers l'index : [Index DFS Manuel](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-00-index)
> Phase precedente : [DFS-01-Installer-Roles](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-01-installer-roles) | Phase suivante : [DFS-03-Partages-DC01](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-03-partages-dc01)

## Objectif

Créer l'arborescence de dossiers `C:\fournil\...` sur DC02 à partir du fichier CSV `orga-fournil.csv`, puis créer des partages SMB masqués pour chaque pôle.

## Pourquoi sur DC02 d'abord ?

Le script AD précédent (`01-Deployer-AD-fournil.ps1`) a déjà créé l'arborescence sur DC01. Il faut donc reproduire cette structure sur DC02 pour que la réplication DFS puisse fonctionner. Les dossiers doivent exister des deux côtés avant de configurer la réplication.

## Commandes détaillées

### 2.1 -- Lecture du fichier CSV

```powershell
$csvContent = Import-Csv -Path ".\orga-fournil.csv" -Delimiter ";"
```

| Paramètre | Valeur | Description |
|-----------|--------|-------------|
| `-Path` | `".\orga-fournil.csv"` | Chemin vers le fichier CSV contenant l'organigramme. |
| `-Delimiter` | `";"` | Caractère séparateur des colonnes dans le fichier CSV. En France, on utilise souvent le point-virgule car la virgule sert de séparateur décimal. |

`Import-Csv` lit le fichier et retourne un tableau d'objets PowerShell, chaque ligne du CSV devenant un objet dont les propriétés correspondent aux en-têtes de colonnes (`Entreprise`, `Entite`, `Poles`, `Service`).

### 2.2 -- Création de l'arborescence sur DC02

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

### 2.3 -- Création des partages SMB masqués sur DC02

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

## Exemples de partages créés sur DC02

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
