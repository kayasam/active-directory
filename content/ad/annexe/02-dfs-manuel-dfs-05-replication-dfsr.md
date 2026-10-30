---
title: "Phase 5 — Configuration de la replication DFS"
---

> Retour vers l'index : [Index DFS Manuel](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-00-index)
> Phase precedente : [DFS-04-Espaces-Noms-DFS](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-04-espaces-noms-dfs) | Phase suivante : [DFS-06-Homes](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-06-homes)

## Objectif

Mettre en place la réplication automatique des fichiers entre DC01 et DC02 pour chaque pôle. La réplication DFS utilise le protocole RDC (Remote Differential Compression) pour ne transmettre que les différences entre fichiers, économisant ainsi la bande passante.

## Concepts clés

- **Groupe de réplication (Replication Group)** : conteneur logique qui définit un ensemble de serveurs et de dossiers à répliquer ensemble.
- **Dossier répliqué (Replicated Folder)** : dossier physique inclus dans un groupe de réplication.
- **Membre (Member)** : serveur participant à un groupe de réplication.
- **Connexion (Connection)** : lien de réplication entre deux membres.
- **Membre primaire (Primary Member)** : lors de la réplication initiale, le membre primaire est la source de référence. En cas de conflit, ses fichiers priment.

## Commandes détaillées pour un pôle

La procédure est identique pour chaque pôle. Prenons l'exemple du pôle `fabrication` de l'entité `Laboratoire` :

### 5.1 -- Création du groupe de réplication

```powershell
New-DfsReplicationGroup -GroupName "Laboratoire-fabrication-Replication"
```

| Paramètre | Valeur | Description |
|-----------|--------|-------------|
| `-GroupName` | `"Laboratoire-fabrication-Replication"` | Nom du groupe de réplication. La convention de nommage utilisée est `<Entite>-<Pole>-Replication` pour identifier facilement chaque groupe. |

Cette cmdlet crée un objet groupe de réplication vide dans Active Directory. Il faut ensuite lui ajouter des dossiers, des membres et des connexions.

### 5.2 -- Ajout du dossier répliqué

```powershell
New-DfsReplicatedFolder -GroupName "Laboratoire-fabrication-Replication" `
    -FolderName "fabrication"
```

| Paramètre | Valeur | Description |
|-----------|--------|-------------|
| `-GroupName` | `"Laboratoire-fabrication-Replication"` | Nom du groupe de réplication auquel ajouter le dossier. |
| `-FolderName` | `"fabrication"` | Nom logique du dossier répliqué. Ce nom est utilisé dans la configuration ; le chemin physique réel est défini séparément via `Set-DfsrMembership`. |

### 5.3 -- Ajout des membres (serveurs)

```powershell
Add-DfsrMember -GroupName "Laboratoire-fabrication-Replication" `
    -ComputerName DC01,DC02
```

| Paramètre | Valeur | Description |
|-----------|--------|-------------|
| `-GroupName` | `"Laboratoire-fabrication-Replication"` | Groupe de réplication auquel ajouter les membres. |
| `-ComputerName` | `DC01,DC02` | Liste des serveurs à ajouter comme membres. On peut passer plusieurs noms séparés par des virgules. Les deux serveurs rejoignent le groupe en une seule commande. |

### 5.4 -- Création de la connexion de réplication

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

### 5.5 -- Configuration de l'appartenance (membership) pour DC01

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

### 5.6 -- Configuration de l'appartenance pour DC02

```powershell
Set-DfsrMembership -GroupName "Laboratoire-fabrication-Replication" `
    -FolderName "fabrication" `
    -ComputerName DC02 `
    -ContentPath "C:\fournil\Laboratoire\fabrication" `
    -Force
```

Même commande que pour DC01, mais sans `-PrimaryMember $true`. Par défaut, le membre n'est pas primaire (`$false`). DC02 recevra les fichiers de DC01 lors de la synchronisation initiale.

### 5.7 -- Liaison avec l'espace de noms DFS

```powershell
Set-DfsReplicatedFolder -GroupName "Laboratoire-fabrication-Replication" `
    -FolderName "fabrication" `
    -DfsnPath "\\ad.fournil.lab\Laboratoire\fabrication"
```

| Paramètre | Valeur | Description |
|-----------|--------|-------------|
| `-DfsnPath` | `"\\ad.fournil.lab\Laboratoire\fabrication"` | Associe le dossier répliqué à son chemin dans l'espace de noms DFS. Cette liaison permet aux outils d'administration de corréler la réplication et l'espace de noms, et facilite le diagnostic. |

## Récapitulatif : groupes de réplication créés

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
