---
title: "Etape 1 — Charger le module Active Directory"
---

> Retour vers l'index : [Index AD Manuel](https://cours.kaya.ovh/active-directory/ad/annexe/01-ad-manuel-00-index)
> Etape suivante : [Manuel-02-Creer-les-OUs](https://cours.kaya.ovh/active-directory/ad/annexe/01-ad-manuel-manuel-02-creer-les-ous)

**Domaine** : `ad.fournil.lab` | **Serveur** : DC01

---

## Commande

Avant toute commande AD, il faut charger le module PowerShell :

```powershell
Import-Module ActiveDirectory
```

## Explications

- **Un module** est une bibliothèque de commandes. `ActiveDirectory` ajoute toutes les commandes qui commencent par `*-AD*` : `New-ADUser`, `New-ADGroup`, `Get-ADUser`, etc.
- Cette commande ne crée rien — elle rend simplement les commandes AD disponibles dans la session PowerShell.
- Il faut la lancer **une seule fois** au début de chaque session.

## Si ça ne marche pas

```powershell
# Installer le module (si pas encore installé)
Install-WindowsFeature RSAT-AD-PowerShell
```

## Vérification

```powershell
# Vérifier que le module est chargé
Get-Module ActiveDirectory
```

Si la commande retourne une ligne avec "ActiveDirectory", c'est bon.
