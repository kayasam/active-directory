---
title: "03 - Déployer la GPO \"Emplacement réseau Home\" - Fournil"
---

## Objectif

Ce document décrit le déploiement d'une stratégie de groupe (GPO) qui crée automatiquement un raccourci **"Mon Dossier Personnel"** dans les emplacements réseau de l'Explorateur Windows pour chaque utilisateur du domaine `ad.fournil.lab`. Ce raccourci pointe vers le répertoire personnel de l'utilisateur (`\\ad.fournil.lab\HOMES\<Entite>\<Login>`), tel que défini dans l'attribut `HomeDirectory` de son compte Active Directory.

La GPO s'applique à tous les utilisateurs de l'unité d'organisation `OU=Fournil,DC=ad,DC=fournil,DC=lab` et de ses sous-OU, y compris l'arborescence Utilisateurs.

**Serveurs concernés :**

| Rôle | Nom | Description |
|------|------|-------------|
| Contrôleur principal | DC01 | Contrôleur de domaine principal |
| Contrôleur secondaire | DC02 | Contrôleur de domaine secondaire |

---

## Phase 1 : Création du script de connexion

### Description

Cette phase crée le script PowerShell `Set-NetworkLocation.ps1` dans le dossier `C:\Deploy\`. Ce script sera exécuté à chaque ouverture de session utilisateur. Il lit l'attribut `HomeDirectory` du compte AD de l'utilisateur connecté et crée un raccourci réseau dans l'Explorateur Windows.

### Emplacement du script

```
C:\Deploy\Set-NetworkLocation.ps1
```

### Fonctionnement détaillé du script

#### Etape 1.1 : Récupération du répertoire personnel depuis Active Directory

```powershell
$homeDir = (Get-ADUser -Identity $env:USERNAME -Properties HomeDirectory).HomeDirectory
```

**Explication des paramètres :**

- `Get-ADUser` : Cmdlet du module ActiveDirectory qui interroge l'annuaire pour récupérer les informations d'un compte utilisateur.
- `-Identity $env:USERNAME` : Le paramètre `-Identity` accepte un identifiant unique (SamAccountName, DN, SID ou GUID). Ici, `$env:USERNAME` est une variable d'environnement Windows qui contient le nom de connexion de l'utilisateur actuellement connecté (par exemple `mlebrun`).
- `-Properties HomeDirectory` : Par défaut, `Get-ADUser` ne retourne qu'un sous-ensemble de propriétés. Le paramètre `-Properties` permet de demander explicitement des attributs supplémentaires. `HomeDirectory` est l'attribut AD qui stocke le chemin UNC du répertoire personnel (par exemple `\\ad.fournil.lab\HOMES\Boulangerie\mlebrun`).
- `.HomeDirectory` : L'accès à la propriété via la notation pointée extrait uniquement la valeur de l'attribut `HomeDirectory` du résultat.

#### Etape 1.2 : Sortie silencieuse si aucun répertoire personnel n'est défini

```powershell
if (-not $homeDir) { exit 0 }
```

**Explication :** Si l'attribut `HomeDirectory` est vide ou null (c'est-à-dire non renseigné dans Active Directory pour cet utilisateur), le script se termine immédiatement avec le code de sortie `0` (succès). Cela évite toute erreur et permet au script de fonctionner de manière transparente pour les comptes de service ou les utilisateurs sans répertoire personnel.

#### Etape 1.3 : Vérification d'idempotence

```powershell
$networkShortcuts = (New-Object -ComObject Shell.Application).Namespace(0x13).Self.Path
$shortcutFolder  = Join-Path $networkShortcuts "Mon Dossier Personnel"

if (Test-Path (Join-Path $shortcutFolder "target.lnk")) { exit 0 }
```

**Explication des éléments :**

- `New-Object -ComObject Shell.Application` : Crée une instance de l'objet COM `Shell.Application`, qui donne accès aux fonctionnalités de l'Explorateur Windows via le modèle objet Shell.
- `.Namespace(0x13)` : La méthode `Namespace()` accepte un identifiant de dossier spécial Windows. La valeur hexadécimale `0x13` (décimale 19) correspond au dossier **Network Shortcuts** (Emplacements réseau). Ce dossier spécial se trouve physiquement à l'emplacement `%APPDATA%\Microsoft\Windows\Network Shortcuts`. C'est dans ce dossier que Windows Explorer affiche les raccourcis réseau de l'utilisateur.
- `.Self.Path` : Retourne le chemin complet du dossier sous forme de chaîne de caractères (par exemple `C:\Users\mlebrun\AppData\Roaming\Microsoft\Windows\Network Shortcuts`).
- `Join-Path` : Concatène des segments de chemin de manière sûre (gestion automatique des séparateurs `\`).
- `Test-Path` : Vérifie l'existence d'un fichier ou dossier. Si `target.lnk` existe déjà, le raccourci a déjà été créé lors d'une session précédente. Le script se termine sans rien faire. C'est le principe d'**idempotence** : exécuter le script plusieurs fois produit toujours le même résultat, sans duplication.

#### Etape 1.4 : Création du dossier de raccourci

```powershell
New-Item -Path $shortcutFolder -ItemType Directory -Force | Out-Null
```

**Explication :**

- `New-Item -Path $shortcutFolder -ItemType Directory` : Crée un nouveau dossier nommé `Mon Dossier Personnel` dans le répertoire Network Shortcuts.
- `-Force` : Crée le dossier même si des dossiers parents n'existent pas, et ne génère pas d'erreur si le dossier existe déjà.
- `| Out-Null` : Supprime la sortie de la commande (le script s'exécute en arrière-plan, aucune sortie n'est nécessaire).

#### Etape 1.5 : Création du fichier Desktop.ini

```powershell
$desktopIni = Join-Path $shortcutFolder "Desktop.ini"
@"
[.ShellClassInfo]
CLSID2={0AFACED1-E828-11D1-9187-B532F1E9575D}
Flags=2
ConfirmFileOp=0
"@ | Set-Content -Path $desktopIni -Encoding Unicode
```

**Explication détaillée :**

- `Desktop.ini` : Fichier de configuration spécial de Windows Explorer. Lorsqu'il est présent dans un dossier, il permet de personnaliser l'apparence et le comportement de ce dossier.
- `[.ShellClassInfo]` : Section d'en-tête standard du fichier `Desktop.ini`.
- `CLSID2={0AFACED1-E828-11D1-9187-B532F1E9575D}` : Ce **CLSID** (Class Identifier) est un identifiant unique enregistré dans Windows qui désigne un **"Network Place"** (Emplacement réseau). En assignant ce CLSID au dossier, on indique à l'Explorateur Windows qu'il doit afficher ce dossier comme un emplacement réseau avec l'icône appropriée (icône de dossier réseau), et non comme un simple dossier.
- `Flags=2` : Indique à Windows de ne pas ajouter de décoration d'icône supplémentaire.
- `ConfirmFileOp=0` : Désactive la boîte de dialogue de confirmation lors de la suppression ou du déplacement du dossier, ce qui simplifie les opérations.
- `-Encoding Unicode` : Le fichier `Desktop.ini` doit être encodé en **Unicode (UTF-16 LE)** pour être correctement interprété par Windows Explorer. Un encodage UTF-8 ou ANSI empêcherait Windows de lire le fichier.

#### Etape 1.6 : Création du raccourci target.lnk

```powershell
$wshShell = New-Object -ComObject WScript.Shell
$lnk      = $wshShell.CreateShortcut((Join-Path $shortcutFolder "target.lnk"))
$lnk.TargetPath = $homeDir
$lnk.Save()
```

**Explication :**

- `New-Object -ComObject WScript.Shell` : Crée une instance de l'objet COM Windows Script Host Shell, qui fournit des méthodes pour manipuler des raccourcis Windows (fichiers `.lnk`).
- `.CreateShortcut(...)` : Méthode qui crée (ou ouvre) un fichier raccourci `.lnk` à l'emplacement spécifié.
- `.TargetPath = $homeDir` : Définit la cible du raccourci, c'est-à-dire le chemin UNC du répertoire personnel de l'utilisateur (par exemple `\\ad.fournil.lab\HOMES\Boulangerie\mlebrun`).
- `.Save()` : Enregistre le raccourci sur le disque. Le fichier `target.lnk` est le fichier que Windows Explorer suit pour ouvrir l'emplacement réseau.

#### Etape 1.7 : Définition des attributs de fichier

```powershell
Set-ItemProperty -Path $desktopIni -Name Attributes -Value ([System.IO.FileAttributes]::System -bor [System.IO.FileAttributes]::Hidden)
Set-ItemProperty -Path $shortcutFolder -Name Attributes -Value ([System.IO.FileAttributes]::ReadOnly)
```

**Explication :**

- **Desktop.ini** reçoit les attributs **System** (Système) et **Hidden** (Caché). Ces deux attributs sont **obligatoires** pour que Windows Explorer prenne en compte le fichier `Desktop.ini`. Sans ces attributs, le fichier est ignoré et le dossier apparaît comme un dossier normal.
- L'opérateur `-bor` est l'opérateur **bitwise OR** de PowerShell. Il combine les deux drapeaux binaires `System` et `Hidden` en une seule valeur.
- **Le dossier** reçoit l'attribut **ReadOnly** (Lecture seule). Cet attribut signale à Windows Explorer qu'il doit lire le fichier `Desktop.ini` pour personnaliser l'affichage du dossier. Contrairement à ce que son nom suggère, cet attribut n'empêche pas réellement la modification du contenu du dossier ; il sert de déclencheur pour la lecture de `Desktop.ini`.

---

## Phase 2 : Création et liaison de la GPO

### Description

Cette phase crée l'objet de stratégie de groupe (GPO) dans Active Directory et le lie à l'unité d'organisation (OU) cible pour qu'il s'applique aux utilisateurs du domaine Fournil.

### Etape 2.1 : Création de la GPO

```powershell
$gpo = New-GPO -Name "GPO_Emplacement_Home"
```

**Explication des paramètres :**

- `New-GPO` : Cmdlet du module GroupPolicy qui crée un nouvel objet de stratégie de groupe dans le domaine Active Directory.
- `-Name "GPO_Emplacement_Home"` : Nom d'affichage de la GPO. Ce nom apparaîtra dans la console de gestion des stratégies de groupe (GPMC - `gpmc.msc`). Il est recommandé d'utiliser un nom explicite avec un préfixe `GPO_` pour identifier facilement les GPO personnalisées.
- La variable `$gpo` stocke l'objet retourné, qui contient notamment la propriété `Id` (le GUID unique de la GPO), nécessaire pour les étapes suivantes.

### Etape 2.2 : Vérification des liens GPO existants (facultatif)

```powershell
$ouTarget = "OU=Fournil,DC=ad,DC=fournil,DC=lab"
Get-GPInheritance -Target $ouTarget | Select-Object -ExpandProperty GpoLinks
```

**Explication des paramètres :**

- `Get-GPInheritance` : Cmdlet qui récupère les informations d'héritage des stratégies de groupe pour une OU donnée.
- `-Target $ouTarget` : Le chemin **Distinguished Name** (DN) de l'unité d'organisation cible. Le DN est le chemin LDAP complet de l'OU dans la hiérarchie Active Directory :
  - `OU=Fournil` : L'unité d'organisation nommée "fournil"
  - `DC=ad,DC=fournil,DC=lab` : Les composantes du domaine `ad.fournil.lab`
- `| Select-Object -ExpandProperty GpoLinks` : Filtre la sortie pour n'afficher que la propriété `GpoLinks`, qui contient la liste de toutes les GPO liées à cette OU. Le paramètre `-ExpandProperty` "déplie" la collection pour afficher directement les éléments plutôt que l'objet conteneur.

Cette commande est **facultative** et sert à vérifier l'état actuel avant d'ajouter un nouveau lien.

### Etape 2.3 : Liaison de la GPO à l'OU

```powershell
New-GPLink -Name "GPO_Emplacement_Home" -Target "OU=Fournil,DC=ad,DC=fournil,DC=lab" -LinkEnabled Yes
```

**Explication des paramètres :**

- `New-GPLink` : Cmdlet qui crée un lien entre une GPO et un conteneur Active Directory (site, domaine ou OU).
- `-Name "GPO_Emplacement_Home"` : Le nom de la GPO à lier (doit correspondre exactement au nom donné lors de la création).
- `-Target "OU=Fournil,DC=ad,DC=fournil,DC=lab"` : L'OU cible à laquelle la GPO sera liée.
- `-LinkEnabled Yes` : Active le lien immédiatement. Si la valeur était `No`, la GPO serait liée mais inactive (désactivée).

**Portée de la GPO :** La GPO s'applique à **tous les utilisateurs** situés dans l'OU `Fournil` et dans **toutes ses sous-OU** (héritage). Cela inclut l'arborescence `OU=Utilisateurs,OU=Fournil,...` et toutes les entités en dessous. Ainsi, chaque utilisateur du domaine Fournil bénéficiera du raccourci réseau lors de sa prochaine ouverture de session.

---

## Phase 3 : Déploiement dans SYSVOL

### Description

Cette phase copie le script de connexion `Set-NetworkLocation.ps1` dans le dossier SYSVOL de la GPO. SYSVOL est un partage réseau répliqué automatiquement entre tous les contrôleurs de domaine (DC01 et DC02), ce qui garantit que le script est accessible depuis n'importe quel contrôleur, quel que soit celui utilisé par le poste client pour l'authentification.

### Etape 3.1 : Construction du chemin SYSVOL

```powershell
$gpoId    = $gpo.Id.ToString("B").ToUpper()
$sysvolPath = "\\ad.fournil.lab\SYSVOL\ad.fournil.lab\Policies\$gpoId\User\Scripts\Logon"
```

**Explication détaillée :**

- `$gpo.Id` : Propriété de type `System.Guid` qui contient l'identifiant unique (GUID) de la GPO créée à la Phase 2.
- `.ToString("B")` : Le paramètre de format `"B"` convertit le GUID au format **avec accolades** (Braces format). Par exemple :
  - Sans format : `a1b2c3d4-e5f6-7890-abcd-ef1234567890`
  - Format `"B"` : `{a1b2c3d4-e5f6-7890-abcd-ef1234567890}`
  - Les accolades `{}` sont **obligatoires** car c'est la convention de nommage des dossiers de GPO dans SYSVOL.
- `.ToUpper()` : Convertit le GUID en majuscules (convention Active Directory pour les noms de dossiers dans SYSVOL). Exemple final : `{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}`.

**Structure du chemin SYSVOL :**

```
\\ad.fournil.lab\SYSVOL\ad.fournil.lab\Policies\{GPO-GUID}\User\Scripts\Logon\
│                │                      │         │          │    │       │
│                │                      │         │          │    │       └── Type : scripts de connexion (Logon)
│                │                      │         │          │    └── Dossier Scripts
│                │                      │         │          └── Configuration Utilisateur (pas Ordinateur)
│                │                      │         └── GUID unique de la GPO
│                │                      └── Dossier contenant toutes les GPO
│                └── Sous-dossier du domaine
└── Partage SYSVOL (répliqué entre DC01 et DC02)
```

### Etape 3.2 : Création du dossier de destination et copie du script

```powershell
New-Item -Path $sysvolPath -ItemType Directory -Force | Out-Null
Copy-Item -Path "C:\Deploy\Set-NetworkLocation.ps1" -Destination $sysvolPath -Force
```

**Explication :**

- `New-Item -Path $sysvolPath -ItemType Directory -Force` : Crée le dossier `Logon` ainsi que tous les dossiers parents nécessaires (`User`, `Scripts`). Le paramètre `-Force` est essentiel ici car il crée toute l'arborescence intermédiaire si elle n'existe pas.
- `Copy-Item -Path ... -Destination ... -Force` : Copie le script depuis `C:\Deploy\` vers le dossier SYSVOL. Le paramètre `-Force` écrase le fichier s'il existe déjà (utile en cas de mise à jour du script).

**Réplication SYSVOL :** Une fois le fichier copié sur DC01, le service de réplication (DFS-R ou FRS selon la configuration) le répliquera automatiquement vers DC02. Un délai de quelques minutes peut être nécessaire avant que le fichier soit disponible sur le contrôleur secondaire.

---

## Phase 4 : Enregistrement du script de connexion dans la GPO

### Description

Cette phase crée le fichier `psscripts.ini` qui indique à Windows quels scripts PowerShell exécuter lors de l'ouverture de session. Sans ce fichier, Windows ne sait pas qu'il doit exécuter `Set-NetworkLocation.ps1` ; la simple présence du script dans le dossier SYSVOL ne suffit pas.

### Etape 4.1 : Construction du chemin du fichier psscripts.ini

```powershell
$scriptsDir     = "\\ad.fournil.lab\SYSVOL\ad.fournil.lab\Policies\$gpoId\User\Scripts"
$psscriptsPath  = Join-Path $scriptsDir "psscripts.ini"
```

**Explication :** Le fichier `psscripts.ini` doit se trouver dans le dossier `Scripts` (un niveau au-dessus de `Logon`), et non dans le dossier `Logon` lui-même. C'est l'emplacement standard attendu par le moteur de stratégie de groupe de Windows.

### Etape 4.2 : Création du fichier psscripts.ini

```powershell
@"

[Logon]
0CmdLine=Set-NetworkLocation.ps1
0Parameters=
"@ | Set-Content -Path $psscriptsPath -Encoding Unicode
```

**Explication détaillée du format :**

- **Ligne vide initiale** : Le fichier `psscripts.ini` doit commencer par une ligne vide. C'est une convention du format INI utilisé par le moteur GPO.
- `[Logon]` : Section qui regroupe les scripts à exécuter lors de l'**ouverture de session** (logon). D'autres sections possibles sont `[Logoff]` pour les scripts de fermeture de session.
- `0CmdLine=Set-NetworkLocation.ps1` : Le préfixe `0` indique qu'il s'agit du **premier script** (indexation à partir de zéro). Si l'on voulait ajouter un deuxième script, on utiliserait `1CmdLine=...`. La valeur est le nom du fichier script, relatif au dossier `Logon\`.
- `0Parameters=` : Paramètres à passer au script. Ici la valeur est vide car le script ne prend aucun paramètre. Le préfixe `0` correspond au même index que `0CmdLine`.
- `-Encoding Unicode` : Le fichier **doit impérativement** être encodé en **Unicode (UTF-16 LE avec BOM)**. C'est le format attendu par le moteur de stratégie de groupe de Windows. Un encodage différent (UTF-8, ANSI) empêchera Windows de lire le fichier et les scripts ne seront pas exécutés.

**Equivalence dans l'interface graphique :** La création de ce fichier `psscripts.ini` est l'équivalent de la configuration manuelle suivante dans la console GPMC (`gpmc.msc`) :

1. Ouvrir la GPO `GPO_Emplacement_Home` en édition
2. Naviguer vers : **Configuration utilisateur** > **Stratégies** > **Paramètres Windows** > **Scripts (ouverture/fermeture de session)**
3. Double-cliquer sur **Ouverture de session**
4. Onglet **Scripts PowerShell**
5. Cliquer sur **Ajouter** et sélectionner `Set-NetworkLocation.ps1`

Le script automatise cette configuration en écrivant directement le fichier INI, ce qui est plus rapide et reproductible.

---

## Vérification

Après l'exécution du script de déploiement, suivre ces étapes pour vérifier que la GPO fonctionne correctement.

### Etape V1 : Forcer la mise à jour des stratégies de groupe

Sur un **poste client** membre du domaine, ouvrir une invite de commandes ou PowerShell en tant qu'administrateur et exécuter :

```cmd
gpupdate /force
```

**Explication :** Cette commande force le poste client à télécharger et appliquer immédiatement les nouvelles stratégies de groupe depuis le contrôleur de domaine, sans attendre le cycle de rafraîchissement automatique (par défaut toutes les 90 minutes +/- 30 minutes).

> **Important :** `gpupdate /force` télécharge la GPO mais **les scripts de connexion utilisateur ne s'exécutent qu'à l'ouverture de session**. Il est donc nécessaire de se déconnecter puis se reconnecter pour que le script s'exécute.

### Etape V2 : Fermer et rouvrir la session

1. Se **déconnecter** de la session Windows (Démarrer > Déconnexion, ou `logoff` en ligne de commande).
2. Se **reconnecter** avec un compte utilisateur disposant d'un répertoire personnel. Par exemple, l'utilisateur `mlebrun`.

### Etape V3 : Vérifier dans l'Explorateur Windows

Ouvrir l'Explorateur Windows. Dans le volet de navigation à gauche, sous **Réseau** ou **Emplacements réseau**, un raccourci nommé **"Mon Dossier Personnel"** doit apparaître. En cliquant dessus, l'Explorateur doit ouvrir le répertoire personnel de l'utilisateur (par exemple `\\ad.fournil.lab\HOMES\Boulangerie\mlebrun`).

### Etape V4 : Vérification en ligne de commande

Si le raccourci n'apparaît pas immédiatement dans l'Explorateur, vérifier la présence des fichiers en ligne de commande :

```powershell
Test-Path "$env:APPDATA\Microsoft\Windows\Network Shortcuts\Mon Dossier Personnel\target.lnk"
```

Ou explorer le contenu du dossier :

```powershell
Get-ChildItem "$env:APPDATA\Microsoft\Windows\Network Shortcuts\Mon Dossier Personnel" -Force
```

Le paramètre `-Force` est nécessaire pour afficher les fichiers cachés et système (`Desktop.ini`).

**Résultat attendu :**

```
Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
-a-hs-         17/06/2026    10:00            xxx Desktop.ini
-a----         17/06/2026    10:00            xxx target.lnk
```

---

## Dépannage

### Le raccourci n'apparaît pas dans l'Explorateur

**1. Vérifier que l'attribut HomeDirectory est renseigné dans AD :**

```powershell
Get-ADUser -Identity mlebrun -Properties HomeDirectory | Select-Object SamAccountName, HomeDirectory
```

Si la colonne `HomeDirectory` est vide, le script se termine silencieusement sans créer de raccourci. Il faut d'abord définir le répertoire personnel de l'utilisateur dans Active Directory :

```powershell
Set-ADUser -Identity mlebrun -HomeDirectory "\\ad.fournil.lab\HOMES\Boulangerie\mlebrun"
```

**2. Vérifier que le dossier réseau cible est accessible :**

```powershell
Test-Path "\\ad.fournil.lab\HOMES\Boulangerie\mlebrun"
```

Si le partage n'est pas accessible, le raccourci sera créé mais ne fonctionnera pas. Vérifier les permissions NTFS et de partage sur le serveur de fichiers.

### Le script ne s'exécute pas à l'ouverture de session

**1. Vérifier la stratégie d'exécution PowerShell :**

```powershell
Get-ExecutionPolicy
```

Si la politique est `Restricted`, les scripts PowerShell ne peuvent pas s'exécuter. Configurer via GPO ou localement :

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
```

> **Note :** Il est recommandé de configurer la politique d'exécution via une GPO dédiée (`Configuration ordinateur > Stratégies > Modèles d'administration > Composants Windows > Windows PowerShell > Activer l'exécution des scripts`) pour une application uniforme sur tout le domaine.

**2. Vérifier l'application de la GPO avec RSOP :**

Sur le poste client, ouvrir la console **Jeu de stratégie résultant** :

```cmd
rsop.msc
```

Naviguer vers : **Configuration utilisateur** > **Paramètres Windows** > **Scripts (ouverture/fermeture de session)** > **Ouverture de session**. Le script `Set-NetworkLocation.ps1` doit y apparaître. S'il n'apparaît pas :

- Vérifier que le compte utilisateur se trouve bien dans l'OU `OU=Fournil,DC=ad,DC=fournil,DC=lab` ou une sous-OU.
- Vérifier que le lien GPO est activé dans GPMC (`gpmc.msc`).
- Vérifier qu'aucun filtre WMI ou filtre de sécurité ne bloque l'application de la GPO.

On peut aussi utiliser `gpresult` pour un diagnostic plus détaillé :

```cmd
gpresult /r /scope:user
```

Cette commande affiche toutes les GPO appliquées à l'utilisateur actuel. Rechercher `GPO_Emplacement_Home` dans la section **Objets de stratégie de groupe appliqués**.

**3. Vérifier la réplication SYSVOL :**

Si la GPO s'applique sur un poste authentifié par DC01 mais pas sur un poste authentifié par DC02, il peut y avoir un problème de réplication. Vérifier la présence du script sur les deux contrôleurs :

```powershell
# Sur DC01
Test-Path "\\DC01\SYSVOL\ad.fournil.lab\Policies\$gpoId\User\Scripts\Logon\Set-NetworkLocation.ps1"

# Sur DC02
Test-Path "\\DC02\SYSVOL\ad.fournil.lab\Policies\$gpoId\User\Scripts\Logon\Set-NetworkLocation.ps1"
```

**4. Rappel important sur le moment d'exécution :**

Les scripts de connexion utilisateur configurés via GPO ne s'exécutent **qu'au moment de l'ouverture de session** (logon). La commande `gpupdate /force` met à jour la liste des GPO appliquées mais **ne déclenche pas l'exécution des scripts de connexion**. Il est impératif de fermer la session et de se reconnecter pour que le script s'exécute.

### Le fichier Desktop.ini n'est pas pris en compte

Si le dossier apparaît comme un dossier ordinaire au lieu d'un emplacement réseau :

1. Vérifier les attributs du fichier `Desktop.ini` :

```powershell
(Get-Item "$env:APPDATA\Microsoft\Windows\Network Shortcuts\Mon Dossier Personnel\Desktop.ini" -Force).Attributes
```

Le résultat doit contenir `Hidden, System`. Si ce n'est pas le cas, corriger :

```powershell
$ini = Get-Item "..." -Force
$ini.Attributes = [System.IO.FileAttributes]::System -bor [System.IO.FileAttributes]::Hidden
```

2. Vérifier l'attribut `ReadOnly` du dossier parent :

```powershell
(Get-Item "$env:APPDATA\Microsoft\Windows\Network Shortcuts\Mon Dossier Personnel").Attributes
```

Le résultat doit contenir `ReadOnly, Directory`.

3. Vérifier l'encodage du fichier `Desktop.ini` : ouvrir le fichier dans un éditeur hexadécimal et vérifier que les deux premiers octets sont `FF FE` (BOM UTF-16 LE).
