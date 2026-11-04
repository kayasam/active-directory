---
title: "Phase 2 — Création et liaison de la GPO"
---

> Retour vers l'index : [Index GPO Manuel](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-manuel-00-index)
> Phase précédente : [GPO-01-Script-Connexion](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-manuel-gpo-01-script-connexion) | Phase suivante : [GPO-03-Deploiement-SYSVOL](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-manuel-gpo-03-deploiement-sysvol)

**Domaine** : `ad.fournil.lab` | **Serveur** : DC01

---

## Description

Cette phase crée l'objet de stratégie de groupe (GPO) dans Active Directory et le lie à l'OU `Fournil` pour qu'il s'applique à tous les utilisateurs.

## Etape 2.1 — Créer la GPO

```powershell
$gpo = New-GPO -Name "GPO_Emplacement_Home"
```

| Paramètre | Explication |
|-----------|-------------|
| `New-GPO` | Crée un nouvel objet GPO dans le domaine |
| `-Name "GPO_Emplacement_Home"` | Le nom qui apparaîtra dans la console GPMC (`gpmc.msc`) |
| `$gpo` | On garde l'objet en mémoire car on aura besoin de son GUID après |

> **Astuce** : le préfixe `GPO_` aide à identifier les GPO personnalisées parmi les GPO par défaut.

## Etape 2.2 — Vérifier les GPO déjà liées (facultatif)

```powershell
$ouTarget = "OU=Fournil,DC=ad,DC=fournil,DC=lab"
Get-GPInheritance -Target $ouTarget | Select-Object -ExpandProperty GpoLinks
```

| Paramètre | Explication |
|-----------|-------------|
| `Get-GPInheritance` | Récupère les infos d'héritage GPO d'une OU |
| `-Target` | Le chemin LDAP de l'OU (Distinguished Name) |
| `-ExpandProperty GpoLinks` | Affiche directement la liste des GPO liées |

> Cette commande sert juste à vérifier l'état avant d'ajouter le lien.

## Etape 2.3 — Lier la GPO à l'OU

```powershell
New-GPLink -Name "GPO_Emplacement_Home" -Target "OU=Fournil,DC=ad,DC=fournil,DC=lab" -LinkEnabled Yes
```

| Paramètre | Explication |
|-----------|-------------|
| `New-GPLink` | Crée un lien entre une GPO et une OU |
| `-Name` | Le nom exact de la GPO |
| `-Target` | L'OU cible en format LDAP |
| `-LinkEnabled Yes` | Active le lien immédiatement |

> **Portée** : la GPO s'applique à tous les utilisateurs dans `OU=Fournil` et **toutes ses sous-OUs** (héritage). Donc tous les 30 utilisateurs du Fournil sont concernés.
