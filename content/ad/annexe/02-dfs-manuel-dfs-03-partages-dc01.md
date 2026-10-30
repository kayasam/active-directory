---
title: "Phase 3 — Creation des partages par pole sur DC01"
---

> Retour vers l'index : [Index DFS Manuel](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-00-index)
> Phase precedente : [DFS-02-Dossiers-Partages-DC02](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-02-dossiers-partages-dc02) | Phase suivante : [DFS-04-Espaces-Noms-DFS](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-04-espaces-noms-dfs)

## Objectif

Créer les mêmes partages SMB masqués sur DC01. Les dossiers existent déjà sur DC01 (créés par le script AD précédent) ; il ne reste qu'à les partager.

## Commandes détaillées

### 3.1 -- Création des partages sur DC01

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
