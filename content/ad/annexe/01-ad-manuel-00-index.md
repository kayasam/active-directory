---
title: "Procédure manuelle — Créer l'arborescence AD Fournil"
---

> Cette procédure permet de créer **à la main** toute l'infrastructure Active Directory.
> Chaque étape est une note séparée, avec les commandes copiables-collables et expliquées.
> C'est l'équivalent pas à pas du script `01-AD-Arborescence.ps1`.

**Domaine** : `ad.fournil.lab` | **Serveur** : DC01

> Voir l'organigramme complet : [Organigramme-Fournil](https://cours.kaya.ovh/active-directory/assets/supports/15d16f367d0f04e71a4f.svg)

---

## Étapes

| # | Note | Ce qu'on fait |
|---|------|---------------|
| 1 | [Manuel-01-Charger-Module-AD](https://cours.kaya.ovh/active-directory/ad/annexe/01-ad-manuel-manuel-01-charger-module-ad) | Charger le module PowerShell Active Directory |
| 2 | [Manuel-02-Creer-les-OUs](https://cours.kaya.ovh/active-directory/ad/annexe/01-ad-manuel-manuel-02-creer-les-ous) | Créer les OUs (Fournil, Utilisateurs/Groupes/Ordinateurs, arborescence) |
| 3 | [Manuel-03-Creer-les-Groupes](https://cours.kaya.ovh/active-directory/ad/annexe/01-ad-manuel-manuel-03-creer-les-groupes) | Créer les groupes de sécurité G_ et DL_ à chaque niveau |
| 4 | [Manuel-04-Imbriquer-Groupes-AGDLP](https://cours.kaya.ovh/active-directory/ad/annexe/01-ad-manuel-manuel-04-imbriquer-groupes-agdlp) | Imbriquer les groupes selon le modèle AGDLP |
| 5 | [Manuel-05-Permissions-NTFS](https://cours.kaya.ovh/active-directory/ad/annexe/01-ad-manuel-manuel-05-permissions-ntfs) | Créer les dossiers C:\fournil\... et appliquer les permissions |
| 6 | [Manuel-06-Creer-les-Utilisateurs](https://cours.kaya.ovh/active-directory/ad/annexe/01-ad-manuel-manuel-06-creer-les-utilisateurs) | Créer les 30 comptes et les ajouter aux groupes |

---

## Récapitulatif des commandes

| Étape | Commande clé | Ce qu'elle fait |
|-------|-------------|-----------------|
| 1 | `Import-Module ActiveDirectory` | Charge les commandes AD |
| 2 | `New-ADOrganizationalUnit -Name ... -Path ...` | Crée une OU |
| 3 | `New-ADGroup -Name ... -GroupScope ... -Path ...` | Crée un groupe de sécurité |
| 4 | `Add-ADGroupMember -Identity "parent" -Members "enfant"` | Imbrique un groupe ou utilisateur |
| 5 | `Get-Acl` / `Set-Acl` + `FileSystemAccessRule` | Gère les permissions NTFS |
| 6 | `New-ADUser -Name ... -SamAccountName ... -Path ...` | Crée un compte utilisateur |

> **Astuce** : pour éviter de taper tout ça à la main, lancez simplement `.\01-AD-Arborescence.ps1` qui fait tout automatiquement !
