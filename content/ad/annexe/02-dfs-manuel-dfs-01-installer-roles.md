---
title: "Phase 1 — Installation des roles DFS"
---

> Retour vers l'index : [Index DFS Manuel](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-00-index)
> Phase suivante : [DFS-02-Dossiers-Partages-DC02](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-02-dossiers-partages-dc02)

## Objectif

Installer les fonctionnalités Windows nécessaires au fonctionnement de DFS sur les deux serveurs. DC01 reçoit à la fois le rôle **Espaces de noms DFS** (DFSn) et le rôle **Réplication DFS** (DFSr), tandis que DC02 ne reçoit que le rôle **Réplication DFS** (DFSr).

## Pourquoi cette répartition ?

- **DC01** héberge les espaces de noms (la « vitrine » DFS que voient les utilisateurs) et participe à la réplication : il a donc besoin des deux rôles.
- **DC02** est uniquement un partenaire de réplication : il reçoit les copies des fichiers mais ne publie pas d'espace de noms. Le rôle DFSn n'est donc pas nécessaire sur DC02.

## Commandes détaillées

### 1.1 -- Installation sur DC01 (exécution locale)

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

### 1.2 -- Installation sur DC02 (exécution distante)

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

## Vérification

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
