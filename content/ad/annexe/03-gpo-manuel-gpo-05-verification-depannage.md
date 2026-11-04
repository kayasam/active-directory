---
title: "Vérification et Dépannage — GPO Emplacement Home"
---

> Retour vers l'index : [Index GPO Manuel](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-manuel-00-index)
> Phase précédente : [GPO-04-Enregistrer-Script](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-manuel-gpo-04-enregistrer-script)

**Domaine** : `ad.fournil.lab` | **Serveur** : DC01

---

## Vérification pas à pas

### V1 — Forcer la mise à jour des GPO

Sur un **poste client** membre du domaine, en admin :

```cmd
gpupdate /force
```

> Cette commande télécharge les GPO depuis le DC. Mais attention : **les scripts de connexion ne s'exécutent qu'à l'ouverture de session**, pas immédiatement.

### V2 — Se déconnecter et se reconnecter

1. **Déconnexion** : Démarrer → Déconnexion (ou `logoff` en commande)
2. **Reconnexion** avec un utilisateur qui a un home (ex: `mlebrun`)

### V3 — Vérifier dans l'Explorateur

Ouvrir l'Explorateur Windows. Dans le volet de gauche, sous **Réseau** ou **Emplacements réseau**, un raccourci **"Mon Dossier Personnel"** doit apparaître.

En cliquant dessus → ouvre `\\ad.fournil.lab\HOMES\Laboratoire\mlebrun`

### V4 — Vérifier en ligne de commande

Si le raccourci n'apparait pas visuellement, vérifier les fichiers :

```powershell
# Le raccourci existe ?
Test-Path "$env:APPDATA\Microsoft\Windows\Network Shortcuts\Mon Dossier Personnel\target.lnk"

# Voir le contenu (avec fichiers cachés)
Get-ChildItem "$env:APPDATA\Microsoft\Windows\Network Shortcuts\Mon Dossier Personnel" -Force
```

**Résultat attendu :**

```
Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
-a-hs-         17/06/2026    10:00            xxx Desktop.ini
-a----         17/06/2026    10:00            xxx target.lnk
```

---

## Dépannage

### Le raccourci n'apparait pas

**1. Le HomeDirectory est-il renseigné dans AD ?**

```powershell
Get-ADUser -Identity mlebrun -Properties HomeDirectory | Select-Object SamAccountName, HomeDirectory
```

Si la colonne `HomeDirectory` est vide, le script s'arrête silencieusement. Il faut d'abord configurer le home :

```powershell
Set-ADUser -Identity mlebrun -HomeDirectory "\\ad.fournil.lab\HOMES\Laboratoire\mlebrun"
```

**2. Le partage réseau est-il accessible ?**

```powershell
Test-Path "\\ad.fournil.lab\HOMES\Laboratoire\mlebrun"
```

Si `False` → problème de partage DFS ou de permissions.

---

### Le script ne s'exécute pas

**1. La politique d'exécution PowerShell le bloque ?**

```powershell
Get-ExecutionPolicy
```

Si `Restricted` → les scripts ne peuvent pas tourner. Corriger :

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
```

> Mieux : configurer via GPO dans **Configuration ordinateur → Modèles d'administration → Windows PowerShell → Activer l'exécution des scripts**.

**2. La GPO s'applique-t-elle bien ?**

Sur le poste client :

```cmd
gpresult /r /scope:user
```

Chercher `GPO_Emplacement_Home` dans la section **"Objets de stratégie de groupe appliqués"**. Si elle n'y est pas :
- L'utilisateur n'est pas dans `OU=Fournil` ou une sous-OU
- Le lien GPO est désactivé dans `gpmc.msc`
- Un filtre WMI ou de sécurité bloque la GPO

**3. Le script est-il bien dans SYSVOL sur les 2 DC ?**

```powershell
# Sur DC01
Test-Path "\\DC01\SYSVOL\ad.fournil.lab\Policies\$gpoId\User\Scripts\Logon\Set-NetworkLocation.ps1"

# Sur DC02
Test-Path "\\DC02\SYSVOL\ad.fournil.lab\Policies\$gpoId\User\Scripts\Logon\Set-NetworkLocation.ps1"
```

Si absent sur DC02 → problème de réplication SYSVOL.

**4. Rappel important :**

> Les scripts de connexion GPO ne s'exécutent **qu'à l'ouverture de session**. `gpupdate /force` ne les déclenche PAS. Il faut **se déconnecter puis se reconnecter**.

---

### Le dossier apparait comme un dossier normal (pas un emplacement réseau)

**1. Vérifier les attributs de Desktop.ini :**

```powershell
(Get-Item "$env:APPDATA\Microsoft\Windows\Network Shortcuts\Mon Dossier Personnel\Desktop.ini" -Force).Attributes
```

Doit contenir `Hidden, System`. Sinon corriger :

```powershell
$ini = Get-Item "$env:APPDATA\Microsoft\Windows\Network Shortcuts\Mon Dossier Personnel\Desktop.ini" -Force
$ini.Attributes = [System.IO.FileAttributes]::System -bor [System.IO.FileAttributes]::Hidden
```

**2. Vérifier l'attribut ReadOnly du dossier :**

```powershell
(Get-Item "$env:APPDATA\Microsoft\Windows\Network Shortcuts\Mon Dossier Personnel").Attributes
```

Doit contenir `ReadOnly, Directory`.

**3. Vérifier l'encodage de Desktop.ini :**

Le fichier doit être en UTF-16 LE (les 2 premiers octets = `FF FE`). Si recréé en UTF-8, Windows l'ignore.
