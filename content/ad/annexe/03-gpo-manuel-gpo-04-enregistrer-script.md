---
title: "Phase 4 — Enregistrer le script de connexion dans la GPO"
---

> Retour vers l'index : [Index GPO Manuel](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-manuel-00-index)
> Phase précédente : [GPO-03-Deploiement-SYSVOL](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-manuel-gpo-03-deploiement-sysvol) | Phase suivante : [GPO-05-Verification-Depannage](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-manuel-gpo-05-verification-depannage)

**Domaine** : `ad.fournil.lab` | **Serveur** : DC01

---

## Description

Copier le script dans SYSVOL ne suffit pas. Il faut aussi créer un fichier `psscripts.ini` qui dit à Windows : "à la connexion, exécute ce script PowerShell". Sans ce fichier, le script est là mais Windows ne sait pas qu'il doit le lancer.

## Etape 4.1 — Construire le chemin du fichier

```powershell
$scriptsDir    = "\\ad.fournil.lab\SYSVOL\ad.fournil.lab\Policies\$gpoId\User\Scripts"
$psscriptsPath = Join-Path $scriptsDir "psscripts.ini"
```

> Le fichier `psscripts.ini` va dans le dossier `Scripts` (un niveau AU-DESSUS de `Logon`).

## Etape 4.2 — Créer le fichier psscripts.ini

```powershell
@"

[Logon]
0CmdLine=Set-NetworkLocation.ps1
0Parameters=
"@ | Set-Content -Path $psscriptsPath -Encoding Unicode
```

**Le format expliqué ligne par ligne :**

| Ligne | Explication |
|-------|-------------|
| *(ligne vide)* | Obligatoire au début (convention du format INI GPO) |
| `[Logon]` | Section "ouverture de session" (on peut aussi avoir `[Logoff]`) |
| `0CmdLine=Set-NetworkLocation.ps1` | Le `0` = c'est le 1er script (commence à 0). La valeur = le nom du fichier |
| `0Parameters=` | Paramètres à passer au script (ici aucun). Le `0` correspond au même script |
| `-Encoding Unicode` | **Obligatoire** — Windows refuse de lire le fichier s'il n'est pas en UTF-16 |

> **En résumé** : ce fichier dit à Windows "quand un utilisateur se connecte, lance `Set-NetworkLocation.ps1` sans paramètres".

**Équivalent dans l'interface graphique** (GPMC) :
1. Ouvrir `gpmc.msc` → éditer la GPO
2. **Configuration utilisateur** → **Stratégies** → **Paramètres Windows** → **Scripts** → **Ouverture de session**
3. Onglet **Scripts PowerShell** → **Ajouter** → sélectionner le script

Le fichier `psscripts.ini` fait exactement la même chose, mais en automatisé.
