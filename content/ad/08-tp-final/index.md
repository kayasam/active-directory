---
title: "Le Fournil — Infrastructure Active Directory"
---

<nav class="chapter-resources" aria-label="Ressources du chapitre" data-course-key="ad/08-tp-final"><div class="resource-buttons"><a class="resource-button" data-resource-kind="markdown" href="https://cours.kaya.ovh/active-directory/ad/08-tp-final/"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 24"><rect x="1" y="1" width="30" height="22" rx="3" fill="none" stroke="#34495e" stroke-width="2"/><path d="M5 18V6h3l4 5 4-5h3v12h-3v-7l-4 5-4-5v7Z" fill="#34495e"/><path d="M23 6h3v7h3l-4.5 5-4.5-5h3Z" fill="#34495e"/></svg>
</span><span class="resource-label">Cours</span></a><a class="resource-button" data-resource-kind="tp" href="https://cours.kaya.ovh/active-directory/ad/08-tp-final/tp"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect x="2" y="4" width="28" height="24" rx="5" fill="#237b60"/><path d="m8 12 5 4-5 4m9 0h7" fill="none" stroke="#fff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/></svg>
</span><span class="resource-label">TP</span></a></div><div class="resource-actions"><a class="resource-download" download href="https://cours.kaya.ovh/active-directory/telechargements/ad/cours/08-tp-final.md">↓ Télécharger le cours (.md)</a><button type="button" class="support-focus-toggle" aria-pressed="false">Masquer les menus</button></div></nav>

> Bienvenue dans la documentation du projet **Fournil**.
> Ce vault Obsidian contient tout ce qu'il faut pour déployer et comprendre une infrastructure Active Directory complète.

---

## L'entreprise

Le Fournil est une boulangerie artisanale avec 30 employés répartis en 2 entités :
- **Laboratoire** : fabrication (boulangerie, patisserie, viennoiserie), approvisionnement, conditionnement, qualité, maintenance
- **Vente** : boutique, commercial, livraisons, ressources (secretariat, comptabilité, RH, informatique)

> Organigramme complet avec tous les salariés (cliquer pour agrandir) :

![Organigramme-Fournil](https://cours.kaya.ovh/active-directory/assets/supports/15d16f367d0f04e71a4f.svg)

---

## Avant de commencer

> [!important] Élèves : commencez par ici
> → **[00.0-DEMARRER-ICI](https://cours.kaya.ovh/active-directory/ad/08-tp-final/tp/tp-00-0-demarrer-ici)** — 5 min : la mission, la maquette, le vocabulaire, l'ordre à suivre.
> Cette note d'accueil-ci est une **vue d'ensemble de la documentation**, pas un point de départ.

### Phase A — Monter le lab de zéro (≈ 3 h)

| # | Note | Contenu |
|---|------|---------|
| 1 | [00.1-Installer-les-VM](https://cours.kaya.ovh/active-directory/ad/08-tp-final/tp/tp-00-1-installer-les-vm) | Hyper-V, vSwitch interne + NAT, les 2 VM, installation de Windows Server 2025 |
| 1 bis | [00.1-VMware-Workstation](https://cours.kaya.ovh/active-directory/ad/08-tp-final/tp/tp-00-1-vmware-workstation) | Variante VMware Workstation : VMnet1 Host-only + NAT Windows + création automatisée des VM |
| 2 | [00.2-Preparer-les-Serveurs](https://cours.kaya.ovh/active-directory/ad/08-tp-final/tp/tp-00-2-preparer-les-serveurs) | PowerShell Direct : renommage, IP statique, fuseau, Windows Update |
| 3 | [00.3-Promouvoir-DC01](https://cours.kaya.ovh/active-directory/ad/08-tp-final/tp/tp-00-3-promouvoir-dc01) | Rôle AD DS + DNS, `Install-ADDSForest`, redirecteur DNS |
| 4 | [00.4-Joindre-DC02](https://cours.kaya.ovh/active-directory/ad/08-tp-final/tp/tp-00-4-joindre-dc02) | Jonction au domaine, `Install-ADDSDomainController`, test de réplication |
| 5 | [00.5-Poste-de-Travail](https://cours.kaya.ovh/active-directory/ad/08-tp-final/tp/tp-00-5-poste-de-travail) | Connexion VSCode en SSH sur DC01, ouverture du pare-feu |

> Le parcours complet en un schéma :

![Schema-Parcours-TP](https://cours.kaya.ovh/active-directory/assets/supports/069c4209301b6cc57a06.svg)

> La maquette qu'on monte :

![Schema-Montage-Lab](https://cours.kaya.ovh/active-directory/assets/supports/57c7f5c51af00acdf351.svg)

---

## Choisissez votre parcours

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   Vous débutez en AD/PowerShell ?                       │
│   → Parcours DÉBUTANT (commandes manuelles + TP)        │
│                                                         │
│   Vous connaissez les boucles PowerShell ?               │
│   → TP INTERMÉDIAIRE (CSV, sans fonctions)              │
│                                                         │
│   Vous êtes à l'aise avec les scripts ?                 │
│   → Parcours AVANCÉ (scripts automatisés + TP)          │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Parcours DÉBUTANT

> Commandes une par une, chaque paramètre expliqué, pas de script.
> Idéal pour apprendre Active Directory, DFS et les GPO.

### Étape 1 — Active Directory

> Créer les OUs, les groupes, les permissions NTFS et les utilisateurs.

| # | Note | Contenu |
|---|------|---------|
| 0 | [Index AD Manuel](https://cours.kaya.ovh/active-directory/ad/annexe/01-ad-manuel-00-index) | Vue d'ensemble des 6 étapes |
| 1 | [Manuel-01-Charger-Module-AD](https://cours.kaya.ovh/active-directory/ad/annexe/01-ad-manuel-manuel-01-charger-module-ad) | `Import-Module ActiveDirectory` |
| 2 | [Manuel-02-Creer-les-OUs](https://cours.kaya.ovh/active-directory/ad/annexe/01-ad-manuel-manuel-02-creer-les-ous) | Créer les OUs (Utilisateurs/Groupes/Ordinateurs + arborescence) |
| 3 | [Manuel-03-Creer-les-Groupes](https://cours.kaya.ovh/active-directory/ad/annexe/01-ad-manuel-manuel-03-creer-les-groupes) | Créer les groupes G_ (Global) et DL_ (DomainLocal) |
| 4 | [Manuel-04-Imbriquer-Groupes-AGDLP](https://cours.kaya.ovh/active-directory/ad/annexe/01-ad-manuel-manuel-04-imbriquer-groupes-agdlp) | Imbriquer les groupes selon le modèle AGDLP |
| 5 | [Manuel-05-Permissions-NTFS](https://cours.kaya.ovh/active-directory/ad/annexe/01-ad-manuel-manuel-05-permissions-ntfs) | Créer les dossiers et appliquer les permissions ACL |
| 6 | [Manuel-06-Creer-les-Utilisateurs](https://cours.kaya.ovh/active-directory/ad/annexe/01-ad-manuel-manuel-06-creer-les-utilisateurs) | Créer les 30 comptes et les ajouter aux groupes |

> **TP** : [01.TP-Debutant-AD](https://cours.kaya.ovh/active-directory/ad/08-tp-final/tp/tp-01-tp-debutant-ad)

### Étape 2 — DFS et Réplication

> Partager les dossiers, configurer DFS, la réplication et les homes.

| # | Note | Contenu |
|---|------|---------|
| 0 | [Index DFS Manuel](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-00-index) | Vue d'ensemble des 8 phases |
| 1 | [DFS-01-Installer-Roles](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-01-installer-roles) | Installer DFSn + DFSr sur DC01 et DC02 |
| 2 | [DFS-02-Dossiers-Partages-DC02](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-02-dossiers-partages-dc02) | Arborescence et partages cachés sur DC02 |
| 3 | [DFS-03-Partages-DC01](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-03-partages-dc01) | Partages cachés sur DC01 |
| 4 | [DFS-04-Espaces-Noms-DFS](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-04-espaces-noms-dfs) | Racines DFS, dossiers, cibles DC01+DC02 |
| 5 | [DFS-05-Replication-DFSr](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-05-replication-dfsr) | Groupes de réplication, connexions, membership |
| 6 | [DFS-06-Homes](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-06-homes) | Dossiers personnels, permissions, DFS HOMES |
| 7 | [DFS-07-HomeDirectory](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-07-homedirectory) | `Set-ADUser -HomeDirectory -HomeDrive H:` |
| 8 | [DFS-08-Verification-Depannage](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-08-verification-depannage) | Vérification et dépannage |

> **TP** : [02.TP-Debutant-DFS](https://cours.kaya.ovh/active-directory/ad/08-tp-final/tp/tp-02-tp-debutant-dfs)

### Étape 3 — GPO

> Créer une GPO qui ajoute un raccourci réseau dans l'Explorateur.

| # | Note | Contenu |
|---|------|---------|
| 0 | [Index GPO Manuel](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-manuel-00-index) | Vue d'ensemble des 5 phases |
| 1 | [GPO-01-Script-Connexion](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-manuel-gpo-01-script-connexion) | Le script de connexion (Shell.Application, Desktop.ini, CLSID) |
| 2 | [GPO-02-Creer-Lier-GPO](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-manuel-gpo-02-creer-lier-gpo) | Créer et lier la GPO à l'OU fournil |
| 3 | [GPO-03-Deploiement-SYSVOL](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-manuel-gpo-03-deploiement-sysvol) | Copier le script dans SYSVOL |
| 4 | [GPO-04-Enregistrer-Script](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-manuel-gpo-04-enregistrer-script) | psscripts.ini pour le script de connexion |
| 5 | [GPO-05-Verification-Depannage](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-manuel-gpo-05-verification-depannage) | Tests et dépannage |

> **TP** : [03.TP-Debutant-GPO](https://cours.kaya.ovh/active-directory/ad/08-tp-final/tp/tp-03-tp-debutant-gpo)

---

## Niveau INTERMÉDIAIRE — PowerShell AD

> Lire `orga-fournil.csv` et `utilisateurs-fournil.csv`, puis déployer l'AD avec des variables, des boucles et les commandes indispensables.
> Aucune fonction, aucun cache et aucune logique avancée.

> **TP** : [01.TP-Intermediaire-AD](https://cours.kaya.ovh/active-directory/ad/08-tp-final/tp/tp-01-tp-intermediaire-ad)

---

## Parcours AVANCÉ

> Écrire ses propres scripts PowerShell à partir des fichiers CSV.
> Idéal pour ceux qui sont à l'aise avec PowerShell et veulent automatiser le déploiement.

### Étape 1 — Scripter l'arborescence AD

> Écrire un script qui lit `orga-fournil.csv` et crée automatiquement les OUs, groupes, permissions NTFS et utilisateurs.

> **TP** : [01.TP-Avance-AD](https://cours.kaya.ovh/active-directory/ad/08-tp-final/tp/tp-01-tp-avance-ad)
> **Correction** : [Explication-Script-AD](https://cours.kaya.ovh/active-directory/ad/annexe/01-ad-script-explication-script-ad) (`01-AD-Arborescence.ps1`)

### Étape 2 — Scripter le déploiement DFS

> Écrire un script qui automatise les rôles DFS, les partages, les namespaces, la réplication et les homes.

> **TP** : [02.TP-Avance-DFS](https://cours.kaya.ovh/active-directory/ad/08-tp-final/tp/tp-02-tp-avance-dfs)
> **Correction** : [Explication-Script-DFS](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-script-explication-script-dfs) (`02-DFS-Deploiement.ps1`)

### Étape 3 — Scripter le déploiement GPO

> Écrire un script qui crée la GPO, déploie le script de connexion dans SYSVOL et configure psscripts.ini.

> **TP** : [03.TP-Avance-GPO](https://cours.kaya.ovh/active-directory/ad/08-tp-final/tp/tp-03-tp-avance-gpo)
> **Correction** : [Explication-Script-GPO](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-script-explication-script-gpo) (`03-GPO-Home.ps1`)

---

## Récapitulatif des fichiers

### Scripts (dans `C:\Deploy\`)

| Fichier | Usage |
|---------|-------|
| `00-Creer-VMware-Workstation.ps1` | Crée DC01 et DC02 sous VMware Workstation |
| `00-Deploiement-Complet.ps1` | **Tout en 1** — lance les 11 phases (pour la prod) |
| `01-AD-Arborescence.ps1` | AD seul — OUs, groupes, NTFS, utilisateurs |
| `02-DFS-Deploiement.ps1` | DFS seul — partages, namespaces, réplication, homes |
| `03-GPO-Home.ps1` | GPO seule — emplacement réseau |

### Données

| Fichier | Contenu |
|---------|---------|
| `orga-fournil.csv` | Organigramme : 31 lignes (Entreprise, Entité, Pôle, Service) |
| `utilisateurs-fournil.csv` | 30 employés (Prénom, Nom, Login, Email, etc.) |

---

## En cas de problème

| Symptôme | Solution |
|----------|---------|
| Module AD non trouvé | `Install-WindowsFeature RSAT-AD-PowerShell` |
| DC02 injoignable | `Resolve-DnsName DC02` — vérifier le DNS |
| GPO ne s'applique pas | `gpupdate /force` + **déconnexion/reconnexion** |
| DFS "erreur générale" | Vérifier le nom du serveur : `$env:COMPUTERNAME` |
| Permissions refusées | `(Get-Acl "C:\fournil\...").Access` |
| Utilisateur sans accès | `Get-ADPrincipalGroupMembership -Identity "login"` |
| Lecteur H: absent | `Get-ADUser login -Properties HomeDirectory` |
