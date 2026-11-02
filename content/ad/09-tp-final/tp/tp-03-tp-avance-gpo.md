---
title: "TP Avancé — Scripter le déploiement GPO"
---

<nav class="chapter-resources" aria-label="Ressources du chapitre" data-course-key="ad/09-tp-final"><div class="resource-buttons"><a class="resource-button" data-resource-kind="markdown" href="https://cours.kaya.ovh/active-directory/ad/09-tp-final/"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 24"><rect x="1" y="1" width="30" height="22" rx="3" fill="none" stroke="#34495e" stroke-width="2"/><path d="M5 18V6h3l4 5 4-5h3v12h-3v-7l-4 5-4-5v7Z" fill="#34495e"/><path d="M23 6h3v7h3l-4.5 5-4.5-5h3Z" fill="#34495e"/></svg>
</span><span class="resource-label">Cours</span></a><a class="resource-button" data-resource-kind="tp" href="https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect x="2" y="4" width="28" height="24" rx="5" fill="#237b60"/><path d="m8 12 5 4-5 4m9 0h7" fill="none" stroke="#fff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/></svg>
</span><span class="resource-label">TP</span></a></div><div class="resource-actions"><a class="resource-download" download href="https://cours.kaya.ovh/active-directory/telechargements/ad/tp/09-tp-final-tp-03-tp-avance-gpo.md">↓ Télécharger le TP (.md)</a><button type="button" class="support-focus-toggle" aria-pressed="false">Masquer les menus</button></div></nav>


> Durée estimée : 1h30
> Prérequis : TP Avancé DFS terminé (homes configurés)
> Niveau : Avancé — écriture de script, GPO, SYSVOL

---

## Contexte

Les utilisateurs du Fournil ont un dossier personnel accessible via `\\ad.fournil.lab\HOMES\<Entite>\<Login>` et un lecteur `H:`. Vous devez **écrire un script PowerShell** qui automatise le déploiement d'une GPO de script de connexion. Ce script crée un emplacement réseau "Mon Dossier Personnel" dans l'Explorateur de chaque utilisateur.

---

## Exercice 1 — Écrire le script de connexion

### Consigne

Écrivez un script `Set-NetworkLocation.ps1` qui, à chaque connexion d'un utilisateur :
1. Récupère son `HomeDirectory` depuis l'AD
2. Trouve le dossier "Emplacements réseau" de Windows
3. Crée un sous-dossier "Mon Dossier Personnel" dedans
4. Y place un raccourci (`target.lnk`) pointant vers le home
5. Y place un fichier `Desktop.ini` avec le bon CLSID pour que Windows affiche l'icône réseau
6. Ne fait rien si le raccourci existe déjà

### Questions

- Comment récupérer le HomeDirectory de l'utilisateur connecté ? (`Get-ADUser -Identity $env:USERNAME -Properties HomeDirectory`)
- Que représente `Namespace(0x13)` dans `Shell.Application` ?
- Qu'est-ce qu'un CLSID ? À quoi sert `{0AFACED1-E828-11D1-9187-B532F1E9575D}` ?
- Pourquoi vérifier `Test-Path "target.lnk"` avant de créer ?
- Pourquoi `Desktop.ini` doit avoir les attributs System + Hidden ?

> [!tip]- Indice sur Shell.Application
> ```powershell
> $ShellApp = New-Object -ComObject Shell.Application
> $NetworkFolder = $ShellApp.Namespace(0x13).Self.Path
> # 0x13 = dossier "Emplacements réseau" de l'utilisateur
> ```

> [!tip]- Indice sur le raccourci
> ```powershell
> $WScriptShell = New-Object -ComObject WScript.Shell
> $Shortcut = $WScriptShell.CreateShortcut("$NewLocation\target.lnk")
> $Shortcut.TargetPath = $NetworkLocationPath
> $Shortcut.Save()
> ```

---

## Exercice 2 — Créer et lier la GPO

### Consigne

Dans votre script de déploiement, écrivez le code qui :
1. Crée une GPO nommée `GPO_Emplacement_Home` (si elle n'existe pas)
2. La lie à l'OU `OU=fournil,DC=ad,DC=fournil,DC=lab` (si le lien n'existe pas)

### Questions

- Quelle est la différence entre **créer** une GPO (`New-GPO`) et la **lier** (`New-GPLink`) ?
- Pourquoi lier à `OU=fournil` et pas directement à `OU=Utilisateurs,OU=fournil` ?
- Comment vérifier si la GPO est déjà liée à une OU ?

### Vérification

```powershell
Get-GPO -Name "GPO_Emplacement_Home" | Select-Object DisplayName, Id
Get-GPInheritance -Target "OU=fournil,DC=ad,DC=fournil,DC=lab" |
    Select-Object -ExpandProperty GpoLinks
```

> [!tip]- Indice sur la vérification du lien
> ```powershell
> $existingLink = Get-GPInheritance -Target $ouTarget |
>     Select-Object -ExpandProperty GpoLinks |
>     Where-Object { $_.DisplayName -eq $gpoName }
> if (-not $existingLink) {
>     New-GPLink -Name $gpoName -Target $ouTarget -LinkEnabled Yes
> }
> ```

---

## Exercice 3 — Déployer le script dans SYSVOL

### Consigne

Écrivez le code qui :
1. Récupère le GUID de la GPO
2. Construit le chemin SYSVOL : `\\ad.fournil.lab\SYSVOL\ad.fournil.lab\Policies\{GUID}\User\Scripts\Logon`
3. Crée le dossier `Logon` s'il n'existe pas
4. Copie `Set-NetworkLocation.ps1` dedans

### Questions

- Qu'est-ce que SYSVOL ? Pourquoi le script doit y être stocké ?
- Que fait `$gpo.Id.ToString("B").ToUpper()` ? Pourquoi le format `{...}` ?
- Pourquoi le chemin contient `User\Scripts\Logon` et pas `Machine\Scripts` ?
- Le script sera-t-il automatiquement répliqué sur DC02 ? Pourquoi ?

### Vérification

```powershell
$gpo = Get-GPO -Name "GPO_Emplacement_Home"
$gpoId = $gpo.Id.ToString("B").ToUpper()
Test-Path "\\ad.fournil.lab\SYSVOL\ad.fournil.lab\Policies\$gpoId\User\Scripts\Logon\Set-NetworkLocation.ps1"
```

> [!tip]- Indice sur la construction du chemin
> ```powershell
> $gpoId = $gpo.Id.ToString("B").ToUpper()
> $sysvolScriptPath = "\\$domainName\SYSVOL\$domainName\Policies\$gpoId\User\Scripts\Logon"
> 
> if (-not (Test-Path $sysvolScriptPath)) {
>     New-Item -Path $sysvolScriptPath -ItemType Directory -Force | Out-Null
> }
> Copy-Item -Path $localScriptPath -Destination $sysvolScriptPath -Force
> ```

---

## Exercice 4 — Enregistrer le script de connexion

### Consigne

Créez le fichier `psscripts.ini` dans `\\...\User\Scripts\` qui référence votre script comme script de connexion PowerShell :

```ini

[Logon]
0CmdLine=Set-NetworkLocation.ps1
0Parameters=
```

### Questions

- Quelle est la différence entre `psscripts.ini` (scripts PowerShell) et `scripts.ini` (scripts classiques) ?
- Pourquoi ce fichier doit être encodé en **Unicode** (UTF-16) ?
- Que signifie le `0` dans `0CmdLine=` ? (indice : c'est un index)
- Comment ajouter un 2ème script de connexion ?

### Vérification

```powershell
$gpo = Get-GPO -Name "GPO_Emplacement_Home"
$gpoId = $gpo.Id.ToString("B").ToUpper()
$iniPath = "\\ad.fournil.lab\SYSVOL\ad.fournil.lab\Policies\$gpoId\User\Scripts\psscripts.ini"
Get-Content $iniPath
```

> [!tip]- Indice sur l'encodage Unicode
> ```powershell
> $iniContent = @"
> 
> [Logon]
> 0CmdLine=$scriptName
> 0Parameters=
> "@
> $iniContent | Out-File -FilePath $psScriptsIniPath -Encoding Unicode
> ```

---

## Exercice 5 — Tester

### Consigne

1. Sur un poste client, forcez la mise à jour des GPO (`gpupdate /force`)
2. **Déconnectez-vous et reconnectez-vous** avec `mlebrun`
3. Vérifiez que "Mon Dossier Personnel" apparait dans l'Explorateur
4. Cliquez dessus — il doit ouvrir `\\ad.fournil.lab\HOMES\Laboratoire\mlebrun`

### Questions

- Pourquoi `gpupdate /force` ne suffit-il pas ? Pourquoi faut-il se reconnecter ?
- Où se trouve physiquement le raccourci sur le poste client ?

### Si ça ne marche pas

```powershell
# La GPO s'applique-t-elle ?
gpresult /r /scope:user

# Le HomeDirectory est-il configuré ?
Get-ADUser -Identity "mlebrun" -Properties HomeDirectory | Select-Object HomeDirectory

# Le script est-il dans SYSVOL ?
Get-ChildItem "\\DC01\SYSVOL\ad.fournil.lab\Policies\*\User\Scripts\Logon\*.ps1" -Recurse

# Le psscripts.ini existe-t-il ?
Get-ChildItem "\\DC01\SYSVOL\ad.fournil.lab\Policies\*\User\Scripts\psscripts.ini" -Recurse
```

> [!tip]- Besoin d'aide ? Cliquez ici
> Consultez : [GPO-05-Verification-Depannage](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-manuel-gpo-05-verification-depannage)

---

## Critère de réussite

Votre script doit être **idempotent** : une 2ème exécution ne recrée rien et n'écrase rien.

> La correction de ce TP : [Explication-Script-GPO](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-script-explication-script-gpo)
