---
title: "Phase 3 — Déploiement dans SYSVOL"
---

> Retour vers l'index : [Index GPO Manuel](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-manuel-00-index)
> Phase précédente : [GPO-02-Creer-Lier-GPO](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-manuel-gpo-02-creer-lier-gpo) | Phase suivante : [GPO-04-Enregistrer-Script](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-manuel-gpo-04-enregistrer-script)

**Domaine** : `ad.fournil.lab` | **Serveur** : DC01

---

## Description

Cette phase copie le script `Set-NetworkLocation.ps1` dans le **SYSVOL** de la GPO.

**SYSVOL**, c'est quoi ?** C'est un partage réseau (`\\ad.fournil.lab\SYSVOL\`) qui est automatiquement répliqué entre tous les contrôleurs de domaine (DC01 et DC02). En mettant le script dedans, on s'assure que n'importe quel poste client pourra le télécharger, quel que soit le DC qui l'authentifie.

## Etape 3.1 — Construire le chemin SYSVOL

```powershell
$gpoId      = $gpo.Id.ToString("B").ToUpper()
$sysvolPath = "\\ad.fournil.lab\SYSVOL\ad.fournil.lab\Policies\$gpoId\User\Scripts\Logon"
```

| Élément | Explication |
|---------|-------------|
| `$gpo.Id` | Le GUID unique de la GPO (identifiant) |
| `.ToString("B")` | Format **B** = avec accolades `{...}` (obligatoire pour SYSVOL) |
| `.ToUpper()` | En majuscules (convention Active Directory) |

**Le chemin SYSVOL expliqué :**

```
\\ad.fournil.lab\SYSVOL\ad.fournil.lab\Policies\{GPO-GUID}\User\Scripts\Logon\
│                                                │          │    │       │
│                                                │          │    │       └── Scripts de connexion
│                                                │          │    └── Dossier Scripts
│                                                │          └── Config Utilisateur (pas Ordinateur)
│                                                └── GUID unique de la GPO
└── Partage SYSVOL (répliqué entre DC01 et DC02)
```

## Etape 3.2 — Créer le dossier et copier le script

```powershell
New-Item -Path $sysvolPath -ItemType Directory -Force | Out-Null
Copy-Item -Path "C:\Deploy\Set-NetworkLocation.ps1" -Destination $sysvolPath -Force
```

| Commande | Explication |
|----------|-------------|
| `New-Item ... -Force` | Crée le dossier `Logon` + tous les dossiers parents manquants |
| `Copy-Item ... -Force` | Copie le script, écrase si déjà présent |

> Après quelques minutes, le fichier sera automatiquement répliqué vers DC02 via SYSVOL.
