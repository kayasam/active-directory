---
title: "Phase 1 — Création du script de connexion"
---

> Retour vers l'index : [Index GPO Manuel](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-manuel-00-index)
> Phase suivante : [GPO-02-Creer-Lier-GPO](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-manuel-gpo-02-creer-lier-gpo)

**Domaine** : `ad.fournil.lab` | **Serveur** : DC01

---

## Description

Cette phase crée le script PowerShell `Set-NetworkLocation.ps1` dans le dossier `C:\Deploy\`. Ce script sera exécuté à chaque ouverture de session utilisateur. Il lit l'attribut `HomeDirectory` du compte AD de l'utilisateur connecté et crée un raccourci réseau dans l'Explorateur Windows.

**Emplacement du script :** `C:\Deploy\Set-NetworkLocation.ps1`

---

## Etape 1.1 — Récupérer le répertoire personnel depuis AD

```powershell
$homeDir = (Get-ADUser -Identity $env:USERNAME -Properties HomeDirectory).HomeDirectory
```

| Élément | Explication |
|---------|-------------|
| `Get-ADUser` | Interroge l'annuaire AD pour récupérer les infos d'un compte |
| `-Identity $env:USERNAME` | `$env:USERNAME` = le login de l'utilisateur connecté (ex: `mlebrun`) |
| `-Properties HomeDirectory` | Demande l'attribut `HomeDirectory` (pas retourné par défaut) |
| `.HomeDirectory` | Extrait juste la valeur du chemin (ex: `\\ad.fournil.lab\HOMES\Laboratoire\mlebrun`) |

## Etape 1.2 — Sortir si pas de home configuré

```powershell
if (-not $homeDir) { exit 0 }
```

> Si `HomeDirectory` est vide dans AD, le script s'arrête sans erreur. Ça protège les comptes de service ou les utilisateurs sans home.

## Etape 1.3 — Vérifier si le raccourci existe déjà (idempotence)

```powershell
$networkShortcuts = (New-Object -ComObject Shell.Application).Namespace(0x13).Self.Path
$shortcutFolder  = Join-Path $networkShortcuts "Mon Dossier Personnel"

if (Test-Path (Join-Path $shortcutFolder "target.lnk")) { exit 0 }
```

| Élément | Explication |
|---------|-------------|
| `Shell.Application` | Objet COM qui donne accès aux fonctions de l'Explorateur Windows |
| `.Namespace(0x13)` | `0x13` = le dossier spécial **"Emplacements réseau"** (Network Shortcuts). Physiquement c'est `%APPDATA%\Microsoft\Windows\Network Shortcuts` |
| `.Self.Path` | Retourne le chemin complet en texte |
| `Test-Path ... target.lnk` | Si le raccourci existe déjà, on ne refait rien |

> **Idempotence** : le script peut s'exécuter 100 fois, il ne crée le raccourci qu'une seule fois.

## Etape 1.4 — Créer le dossier du raccourci

```powershell
New-Item -Path $shortcutFolder -ItemType Directory -Force | Out-Null
```

> Crée un dossier `Mon Dossier Personnel` dans les emplacements réseau de l'utilisateur.

## Etape 1.5 — Créer le fichier Desktop.ini

```powershell
$desktopIni = Join-Path $shortcutFolder "Desktop.ini"
@"
[.ShellClassInfo]
CLSID2={0AFACED1-E828-11D1-9187-B532F1E9575D}
Flags=2
ConfirmFileOp=0
"@ | Set-Content -Path $desktopIni -Encoding Unicode
```

| Élément | Explication |
|---------|-------------|
| `Desktop.ini` | Fichier spécial Windows qui personnalise l'apparence d'un dossier |
| `[.ShellClassInfo]` | Section d'en-tête standard |
| `CLSID2={0AFACED1-...}` | Ce code dit à Windows : "affiche ce dossier comme un **emplacement réseau**" (avec l'icône réseau) |
| `Flags=2` | Pas de décoration d'icône supplémentaire |
| `-Encoding Unicode` | **Obligatoire** — Windows ignore le fichier s'il n'est pas en UTF-16 |

## Etape 1.6 — Créer le raccourci target.lnk

```powershell
$wshShell = New-Object -ComObject WScript.Shell
$lnk      = $wshShell.CreateShortcut((Join-Path $shortcutFolder "target.lnk"))
$lnk.TargetPath = $homeDir
$lnk.Save()
```

| Élément | Explication |
|---------|-------------|
| `WScript.Shell` | Objet COM pour manipuler les raccourcis Windows (.lnk) |
| `.CreateShortcut(...)` | Crée un fichier raccourci à l'emplacement donné |
| `.TargetPath = $homeDir` | La cible du raccourci = le home de l'utilisateur |
| `.Save()` | Enregistre le raccourci sur le disque |

## Etape 1.7 — Mettre les bons attributs

```powershell
Set-ItemProperty -Path $desktopIni -Name Attributes -Value ([System.IO.FileAttributes]::System -bor [System.IO.FileAttributes]::Hidden)
Set-ItemProperty -Path $shortcutFolder -Name Attributes -Value ([System.IO.FileAttributes]::ReadOnly)
```

| Cible | Attribut | Pourquoi |
|-------|----------|----------|
| `Desktop.ini` | System + Hidden | **Obligatoire** pour que Windows le lise. `-bor` = "OU binaire" (combine les 2 drapeaux) |
| Le dossier | ReadOnly | Dit à Windows de chercher un `Desktop.ini` dedans |
