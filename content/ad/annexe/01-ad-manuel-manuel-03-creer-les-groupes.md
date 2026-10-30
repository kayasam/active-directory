---
title: "Etape 3 — Créer les groupes de sécurité"
---

> Retour vers l'index : [Index AD Manuel](https://cours.kaya.ovh/active-directory/ad/annexe/01-ad-manuel-00-index)
> Etape précédente : [Manuel-02-Creer-les-OUs](https://cours.kaya.ovh/active-directory/ad/annexe/01-ad-manuel-manuel-02-creer-les-ous) | Etape suivante : [Manuel-04-Imbriquer-Groupes-AGDLP](https://cours.kaya.ovh/active-directory/ad/annexe/01-ad-manuel-manuel-04-imbriquer-groupes-agdlp)

**Domaine** : `ad.fournil.lab` | **Serveur** : DC01

---

## Qu'est-ce qu'un groupe de sécurité ?

Un **groupe** permet de regrouper des utilisateurs pour leur donner des droits. Il existe 2 portées principales :

| Portée | Préfixe | Rôle | Peut contenir |
|--------|---------|------|---------------|
| **Global** | `G_` | Regrouper les utilisateurs par fonction | Utilisateurs et groupes du même domaine |
| **DomainLocal** | `DL_` | Donner accès aux ressources (dossiers) | Utilisateurs et groupes de n'importe quel domaine |

On crée **3 groupes par niveau** : un `G_` (global), un `DL_..._L` (lecture) et un `DL_..._M` (modification).

## La commande expliquée

```powershell
New-ADGroup -Name "G_fournil" -GroupCategory Security -GroupScope Global `
    -Path "OU=Groupes,OU=fournil,DC=ad,DC=fournil,DC=lab" `
    -Description "Groupe global pour fournil"
```

| Paramètre | Rôle |
|-----------|------|
| `-Name` | Nom du groupe |
| `-GroupCategory Security` | Groupe de sécurité (pas de distribution mail) |
| `-GroupScope Global` | Portée globale (regroupe des utilisateurs) |
| `-Path` | OU où créer le groupe |
| `-Description` | Texte libre pour documenter |

---

## Groupes au niveau Entreprise

```powershell
New-ADGroup -Name "G_fournil" -GroupCategory Security -GroupScope Global `
    -Path "OU=Groupes,OU=fournil,DC=ad,DC=fournil,DC=lab" `
    -Description "Groupe global pour fournil"

New-ADGroup -Name "DL_fournil_L" -GroupCategory Security -GroupScope DomainLocal `
    -Path "OU=Groupes,OU=fournil,DC=ad,DC=fournil,DC=lab" `
    -Description "Lecture sur fournil"

New-ADGroup -Name "DL_fournil_M" -GroupCategory Security -GroupScope DomainLocal `
    -Path "OU=Groupes,OU=fournil,DC=ad,DC=fournil,DC=lab" `
    -Description "Modification sur fournil"
```

## Groupes au niveau Entité (exemple Laboratoire)

```powershell
New-ADGroup -Name "G_Laboratoire" -GroupCategory Security -GroupScope Global `
    -Path "OU=Laboratoire,OU=Groupes,OU=fournil,DC=ad,DC=fournil,DC=lab" `
    -Description "Groupe global Laboratoire"

New-ADGroup -Name "DL_Laboratoire_L" -GroupCategory Security -GroupScope DomainLocal `
    -Path "OU=Laboratoire,OU=Groupes,OU=fournil,DC=ad,DC=fournil,DC=lab" `
    -Description "Lecture sur Laboratoire"

New-ADGroup -Name "DL_Laboratoire_M" -GroupCategory Security -GroupScope DomainLocal `
    -Path "OU=Laboratoire,OU=Groupes,OU=fournil,DC=ad,DC=fournil,DC=lab" `
    -Description "Modification sur Laboratoire"
```

## Groupes au niveau Pôle (exemple fabrication)

```powershell
New-ADGroup -Name "G_Laboratoire_fabrication" -GroupCategory Security -GroupScope Global `
    -Path "OU=fabrication,OU=Laboratoire,OU=Groupes,OU=fournil,DC=ad,DC=fournil,DC=lab" `
    -Description "Groupe global fabrication"

New-ADGroup -Name "DL_Laboratoire_fabrication_L" -GroupCategory Security -GroupScope DomainLocal `
    -Path "OU=fabrication,OU=Laboratoire,OU=Groupes,OU=fournil,DC=ad,DC=fournil,DC=lab" `
    -Description "Lecture sur fabrication"

New-ADGroup -Name "DL_Laboratoire_fabrication_M" -GroupCategory Security -GroupScope DomainLocal `
    -Path "OU=fabrication,OU=Laboratoire,OU=Groupes,OU=fournil,DC=ad,DC=fournil,DC=lab" `
    -Description "Modification sur fabrication"
```

## Groupes au niveau Service (exemple boulangerie)

```powershell
New-ADGroup -Name "G_Laboratoire_fabrication_boulangerie" -GroupCategory Security -GroupScope Global `
    -Path "OU=boulangerie,OU=fabrication,OU=Laboratoire,OU=Groupes,OU=fournil,DC=ad,DC=fournil,DC=lab" `
    -Description "Groupe global boulangerie"

New-ADGroup -Name "DL_Laboratoire_fabrication_boulangerie_L" -GroupCategory Security -GroupScope DomainLocal `
    -Path "OU=boulangerie,OU=fabrication,OU=Laboratoire,OU=Groupes,OU=fournil,DC=ad,DC=fournil,DC=lab" `
    -Description "Lecture sur boulangerie"

New-ADGroup -Name "DL_Laboratoire_fabrication_boulangerie_M" -GroupCategory Security -GroupScope DomainLocal `
    -Path "OU=boulangerie,OU=fabrication,OU=Laboratoire,OU=Groupes,OU=fournil,DC=ad,DC=fournil,DC=lab" `
    -Description "Modification sur boulangerie"
```

> **Répéter ce schéma** (G_ + DL_L + DL_M) pour chaque pôle et service des deux entités. Le script automatise ça pour les 31 lignes du CSV.

## Vérification

```powershell
Get-ADGroup -Filter * -SearchBase "OU=Groupes,OU=fournil,DC=ad,DC=fournil,DC=lab" |
    Select-Object Name, GroupScope | Sort-Object Name
```
