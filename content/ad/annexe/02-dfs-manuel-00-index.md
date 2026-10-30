---
title: "Procedure de deploiement DFS -- Fournil"
---

## Présentation générale

Ce document décrit en détail la procédure de déploiement du système de fichiers distribués (DFS) pour l'infrastructure Active Directory de l'entreprise **Fournil**, une boulangerie dont le domaine est `ad.fournil.lab`.

L'infrastructure repose sur deux serveurs :

| Serveur | Rôle | Description |
|---------|------|-------------|
| **DC01** | Contrôleur de domaine principal | Héberge les espaces de noms DFS (DFSn) et la réplication (DFSr). Contient les dossiers partagés et les dossiers personnels (homes). Membre primaire de tous les groupes de réplication. |
| **DC02** | Contrôleur de domaine secondaire | Héberge la réplication DFS (DFSr) uniquement. Reçoit les réplicas des dossiers partagés et des homes. |

Le script `02-DFS-Deploiement.ps1` automatise l'ensemble du déploiement en **7 phases** séquentielles. Ce document explique chaque phase, chaque commande et chaque paramètre afin qu'un administrateur puisse soit exécuter le script directement, soit reproduire la procédure manuellement étape par étape.

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

## Phases de deploiement

| Phase | Titre | Note |
|-------|-------|------|
| Phase 1 | Installation des rôles DFS | [DFS-01-Installer-Roles](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-01-installer-roles) |
| Phase 2 | Création des dossiers et partages sur DC02 | [DFS-02-Dossiers-Partages-DC02](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-02-dossiers-partages-dc02) |
| Phase 3 | Création des partages par pôle sur DC01 | [DFS-03-Partages-DC01](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-03-partages-dc01) |
| Phase 4 | Création des espaces de noms DFS | [DFS-04-Espaces-Noms-DFS](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-04-espaces-noms-dfs) |
| Phase 5 | Configuration de la réplication DFS (DFSr) | [DFS-05-Replication-DFSr](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-05-replication-dfsr) |
| Phase 6 | Configuration des dossiers personnels (Homes) | [DFS-06-Homes](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-06-homes) |
| Phase 7 | Configuration du HomeDirectory des utilisateurs | [DFS-07-HomeDirectory](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-07-homedirectory) |
| -- | Vérification et dépannage | [DFS-08-Verification-Depannage](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-08-verification-depannage) |

---

## Recapitulatif des commandes principales

| Commande | Description | Phase |
|----------|-------------|-------|
| `Install-WindowsFeature` | Installe les rôles DFS sur les serveurs | [Phase 1](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-01-installer-roles) |
| `Import-Csv` | Lecture des fichiers CSV d'organigramme et d'utilisateurs | [Phase 2](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-02-dossiers-partages-dc02) |
| `Invoke-Command` | Exécution distante de commandes sur DC02 via WinRM | [Phase 2](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-02-dossiers-partages-dc02) |
| `New-Item -ItemType Directory` | Création de l'arborescence de dossiers | [Phase 2](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-02-dossiers-partages-dc02) |
| `New-SmbShare` | Création des partages SMB (masqués et visibles) | [Phase 3](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-03-partages-dc01) |
| `New-DfsnRoot` | Création des racines d'espaces de noms DFS | [Phase 4](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-04-espaces-noms-dfs) |
| `New-DfsnFolder` | Création des dossiers virtuels DFS | [Phase 4](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-04-espaces-noms-dfs) |
| `New-DfsnFolderTarget` | Ajout de cibles supplémentaires aux dossiers DFS | [Phase 4](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-04-espaces-noms-dfs) |
| `New-DfsReplicationGroup` | Création des groupes de réplication | [Phase 5](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-05-replication-dfsr) |
| `New-DfsReplicatedFolder` | Ajout de dossiers répliqués aux groupes | [Phase 5](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-05-replication-dfsr) |
| `Add-DfsrMember` | Ajout de serveurs membres aux groupes de réplication | [Phase 5](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-05-replication-dfsr) |
| `Add-DfsrConnection` | Création des connexions de réplication entre serveurs | [Phase 5](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-05-replication-dfsr) |
| `Set-DfsrMembership` | Configuration du membership et du membre primaire | [Phase 5](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-05-replication-dfsr) |
| `Set-DfsReplicatedFolder` | Liaison du dossier répliqué avec l'espace de noms DFS | [Phase 5](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-05-replication-dfsr) |
| `Get-Acl` / `Set-Acl` | Configuration des permissions NTFS sur les homes | [Phase 6](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-06-homes) |
| `robocopy /MIR /COPYALL` | Copie miroir des homes vers DC02 avec permissions | [Phase 6](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-06-homes) |
| `Set-ADUser -HomeDirectory -HomeDrive` | Association du dossier personnel et du lecteur H: | [Phase 7](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-07-homedirectory) |
| `Get-DfsnRoot` / `Get-DfsnFolder` | Vérification des espaces de noms DFS | [Verification](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-08-verification-depannage) |
| `Get-DfsReplicationGroup` / `Get-DfsrState` | Vérification de la réplication DFS | [Verification](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-08-verification-depannage) |
| `Write-DfsrHealthReport` | Rapport de diagnostic de la réplication | [Verification](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-08-verification-depannage) |
