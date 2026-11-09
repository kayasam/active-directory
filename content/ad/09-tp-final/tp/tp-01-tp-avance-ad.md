---
title: "TP Avancé — Scripter l'arborescence AD depuis un CSV"
---

<nav class="chapter-resources" aria-label="Ressources du chapitre" data-course-key="ad/09-tp-final"><div class="resource-buttons"><a class="resource-button" data-resource-kind="html" href="https://cours.kaya.ovh/active-directory/ad/09-tp-final/"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 28 32"><path d="M2 2h24l-2 25-10 3-10-3Z" fill="#e44d26"/><path d="M14 5v22l7-2 2-20Z" fill="#f16529"/><path d="M7 8h15l-.3 3H11l.3 3h10l-.8 9-6.5 2-6.5-2-.4-5h3l.2 2.6 3.7 1 3.7-1 .3-3.6H8Z" fill="#fff"/></svg>
</span><span class="resource-label">Projet guidé</span></a></div><div class="resource-actions"><a class="resource-download" download href="https://cours.kaya.ovh/active-directory/telechargements/ad/tp/09-tp-final-tp-01-tp-avance-ad.md">↓ Télécharger le TP (.md)</a><button type="button" class="support-focus-toggle" aria-pressed="false">Masquer les menus</button></div></nav>


> Durée estimée : 3h
> Prérequis : être à l'aise avec PowerShell et les cmdlets AD
> Fichiers fournis : `orga-fournil.csv`, `utilisateurs-fournil.csv`
> Niveau : Avancé — écriture de script, boucles, logique CSV

---

## Contexte

Même scénario que le TP Débutant : vous êtes administrateur système de la boulangerie **Le Fournil**. Mais cette fois, vous ne tapez pas les commandes une par une. Vous devez **écrire un script PowerShell** qui lit les fichiers CSV et crée automatiquement toute l'infrastructure AD.

> Consultez l'organigramme : [Organigramme-Fournil](https://cours.kaya.ovh/active-directory/assets/supports/15d16f367d0f04e71a4f.svg)

### Objectif

Votre script doit, en une seule exécution :
1. Créer toutes les OUs (Utilisateurs, Groupes, Ordinateurs + sous-OUs)
2. Créer tous les groupes de sécurité (G_ et DL_)
3. Imbriquer les groupes selon le modèle AGDLP
4. Créer les dossiers et appliquer les permissions NTFS
5. Créer tous les utilisateurs et les affecter à leur groupe

### Structure des CSV

Prenez le temps d'examiner les fichiers avant de coder.

**`orga-fournil.csv`** — structure organisationnelle :

```
Entreprise,Entite,Poles,Service
fournil,Laboratoire,fabrication,boulangerie
fournil,Laboratoire,fabrication,patisserie
fournil,Vente,boutique,accueil-boutique
...
```

> Certaines lignes n'ont pas de Service (ex: `qualite-hygiene`). Votre script doit gérer ce cas.

**`utilisateurs-fournil.csv`** — comptes utilisateurs :

```
Prenom,Nom,Entite,Pole,Service,Fonction,Login,MotDePasse,Email
Marc,Lebrun,Laboratoire,fabrication,boulangerie,Chef Boulanger,mlebrun,a12345!,...
```

---

## Exercice 1 — Variables et import CSV

### Consigne

En haut de votre script, définissez les variables de configuration :
- Le chemin du CSV organisation
- Le Distinguished Name de base (`DC=ad,DC=fournil,DC=lab`)
- Le nom de l'OU racine (`Fournil`)
- Les noms des 3 OUs de type : `Utilisateurs`, `Groupes`, `Ordinateurs`
- Le dossier racine des partages (`C:\`)

Puis importez le CSV dans une variable.

### Questions

- Pourquoi mettre ces valeurs dans des variables plutôt qu'en dur dans le code ?
- Quel paramètre de `Import-Csv` spécifie le séparateur ?
- Que contient chaque élément du tableau retourné par `Import-Csv` ?

> [!tip]- Besoin d'aide ? Cliquez ici
> ```powershell
> Import-Module ActiveDirectory
> $csvPath = ".\orga-fournil.csv"
> $baseDN = "DC=ad,DC=fournil,DC=lab"
> $csvContent = Import-Csv -Path $csvPath -Delimiter ','
> ```

---

## Exercice 2 — Créer les OUs depuis le CSV

### Consigne

Écrivez une fonction `New-OUIfNotExists` qui :
- Prend en paramètre un nom d'OU et un chemin parent
- Vérifie si l'OU existe déjà avant de la créer
- Retourne le Distinguished Name de l'OU (`OU=nom,chemin_parent`)

Puis parcourez le CSV pour créer la hiérarchie complète :
1. D'abord l'OU racine `Fournil`
2. Puis les 3 OUs de type (`Utilisateurs`, `Groupes`, `Ordinateurs`)
3. Pour chaque ligne du CSV : créer la chaîne Entité → Pôle → Service sous **chacune** des 3 OUs de type

### Questions

- Comment vérifier si une OU existe ? Quelle cmdlet utiliser ?
- Pourquoi créer les mêmes sous-OUs sous Utilisateurs, Groupes ET Ordinateurs ?
- Comment construire dynamiquement le chemin `OU=boulangerie,OU=fabrication,OU=Laboratoire,...` en itérant sur les colonnes du CSV ?
- Comment gérer les lignes où la colonne Service est vide ?

### Vérification

```powershell
(Get-ADOrganizationalUnit -SearchBase "OU=Fournil,DC=ad,DC=fournil,DC=lab" -Filter *).Count
```

> [!tip]- Indice sur la boucle
> Chaque ligne du CSV a 3 niveaux possibles : Entite, Poles, Service.
> Construisez un tableau `@()` avec les niveaux non-vides, puis itérez dessus :
> ```powershell
> $orgParts = @()
> if ($line.Entite -ne "") { $orgParts += $line.Entite }
> if ($line.Poles -ne "") { $orgParts += $line.Poles }
> if ($line.Service -ne "") { $orgParts += $line.Service }
> 
> $currentPath = $utilisateursBasePath
> foreach ($part in $orgParts) {
>     $currentPath = New-OUIfNotExists -ouName $part -parentPath $currentPath
> }
> ```

---

## Exercice 3 — Créer les groupes de sécurité

### Consigne

Écrivez une fonction `New-GroupIfNotExists` qui crée un groupe s'il n'existe pas.

Pour chaque niveau de la hiérarchie (Entité, Pôle, Service), créez 3 groupes :
- `G_<chemin>` — portée **Global**
- `DL_<chemin>_L` — portée **DomainLocal** (lecture)
- `DL_<chemin>_M` — portée **DomainLocal** (modification)

Exemples de noms attendus :
- Niveau Entité : `G_Laboratoire`, `DL_Laboratoire_L`, `DL_Laboratoire_M`
- Niveau Pôle : `G_Laboratoire_fabrication`, `DL_Laboratoire_fabrication_L`, ...
- Niveau Service : `G_Laboratoire_fabrication_boulangerie`, ...

N'oubliez pas le niveau Entreprise : `G_fournil`, `DL_fournil_L`, `DL_fournil_M`

### Questions

- Comment construire le nom du groupe à partir des éléments du CSV ? (ex: `"G_" + ($orgParts[0..$i] -join "_")`)
- Où créer chaque groupe ? Dans quelle OU sous `Groupes` ?
- Comment éviter de créer un groupe en double quand plusieurs lignes CSV partagent le même Pôle ?

### Vérification

```powershell
Get-ADGroup -Filter * -SearchBase "OU=Groupes,OU=Fournil,DC=ad,DC=fournil,DC=lab" |
    Select-Object Name, GroupScope | Sort-Object Name
```

> [!tip]- Indice sur la construction des noms
> Utilisez le slicing de tableau pour construire le nom progressivement :
> ```powershell
> for ($i = 0; $i -lt $orgParts.Count; $i++) {
>     $groupName = "G_" + ($orgParts[0..$i] -join "_")
>     $dlRead = "DL_" + ($orgParts[0..$i] -join "_") + "_L"
>     $dlModify = "DL_" + ($orgParts[0..$i] -join "_") + "_M"
>     # Créer les 3 groupes...
> }
> ```

---

## Exercice 4 — Imbrication AGDLP

> Etudiez ce schéma avant de commencer :

![Schema-AGDLP](https://cours.kaya.ovh/active-directory/assets/supports/d601b6a810e4e43f2353.svg)

### Consigne

Écrivez une fonction `Add-MemberToGroupSafe` qui ajoute un membre à un groupe s'il n'y est pas déjà.

Implémentez les 2 types d'imbrication :

**Imbrication G → G (hiérarchie)** :
- Le groupe enfant est membre du groupe parent
- Ex: `G_Laboratoire_fabrication_boulangerie` → membre de `G_Laboratoire_fabrication`
- Ex: `G_Laboratoire_fabrication` → membre de `G_Laboratoire`
- Ex: `G_Laboratoire` → membre de `G_fournil`

**Imbrication G → DL (permissions)** :
- Le dernier niveau (le plus précis) va dans `DL_..._M` (modification)
- Les niveaux parents vont dans `DL_..._L` (lecture)

### Questions

- Pourquoi le dernier niveau a la modification et les parents seulement la lecture ?
- Comment déterminer dans la boucle si on est au dernier niveau ? (`$i -eq $orgParts.Count - 1`)
- Que se passe-t-il si un boulanger essaie de modifier un fichier dans `\\...\Laboratoire\` ? (il a lecture via `G_Laboratoire`)

### Vérification

```powershell
Get-ADGroupMember -Identity "G_Laboratoire_fabrication" | Select-Object Name
Get-ADGroupMember -Identity "DL_Laboratoire_fabrication_boulangerie_M" | Select-Object Name
```

> [!tip]- Indice sur la logique G → DL
> ```powershell
> if ($i -eq $orgParts.Count - 1) {
>     # Dernier niveau → modification
>     Add-MemberToGroupSafe -memberName $groupName -groupName $dlModify
> } else {
>     # Niveau parent → lecture seule
>     Add-MemberToGroupSafe -memberName $groupName -groupName $dlRead
> }
> ```

---

## Exercice 5 — Dossiers et permissions NTFS

> Les 5 étapes à suivre :

![Schema-Permissions-NTFS](https://cours.kaya.ovh/active-directory/assets/supports/8133a30adce77e3a9309.svg)

### Consigne

Écrivez une fonction `Set-NTFSPermissions` qui, pour un chemin donné :
1. Crée le dossier s'il n'existe pas
2. Désactive l'héritage
3. Supprime toutes les permissions existantes
4. Ajoute : `Administrateurs` (contrôle total), `SYSTEM` (contrôle total)
5. Ajoute : le groupe `DL_..._L` en lecture, le groupe `DL_..._M` en modification

Appelez cette fonction pour chaque niveau de la hiérarchie en construisant le chemin à partir du CSV :
- `C:\fournil\Laboratoire`
- `C:\fournil\Laboratoire\fabrication`
- `C:\fournil\Laboratoire\fabrication\boulangerie`
- etc.

### Questions

- Quelle classe .NET permet de manipuler les ACL ? (`System.Security.AccessControl.FileSystemAccessRule`)
- Que fait `SetAccessRuleProtection($true, $false)` ?
- Que signifie `ContainerInherit,ObjectInherit` ?
- Comment construire le chemin du dossier progressivement dans la boucle ? (`Join-Path`)

### Vérification

```powershell
(Get-Acl "C:\fournil\Laboratoire\fabrication\boulangerie").Access |
    Select-Object IdentityReference, FileSystemRights | Format-Table
```

> [!tip]- Structure de la fonction
> ```powershell
> function Set-NTFSPermissions {
>     param ([string]$folderPath, [string]$dlGroupRead, [string]$dlGroupModify)
>     
>     if (-not (Test-Path $folderPath)) {
>         New-Item -Path $folderPath -ItemType Directory -Force | Out-Null
>     }
>     $acl = Get-Acl -Path $folderPath
>     $acl.SetAccessRuleProtection($true, $false)
>     # Supprimer les règles existantes...
>     # Ajouter les 4 nouvelles règles...
>     Set-Acl -Path $folderPath -AclObject $acl
> }
> ```

---

## Exercice 6 — Créer les utilisateurs depuis le CSV

### Consigne

Importez `utilisateurs-fournil.csv` et pour chaque utilisateur :
1. Construisez le chemin de l'OU cible (sous `Utilisateurs`)
2. Créez le compte avec `New-ADUser`
3. Ajoutez-le au groupe `G_` correspondant à son niveau le plus précis

Écrivez une fonction `New-UserIfNotExists` qui vérifie si le compte existe avant de le créer.

### Questions

- Comment construire le DN de l'OU à partir des colonnes Entite/Pole/Service ? (attention : l'ordre est inversé dans un DN)
- Pourquoi le mot de passe doit être un `SecureString` ? Comment convertir ?
- Comment gérer un utilisateur qui n'a pas de Service (ex: `Responsable Qualité` dans `qualite-hygiene`) ?

### Vérification

```powershell
Get-ADUser -Filter * -SearchBase "OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab" |
    Select-Object Name, SamAccountName | Sort-Object Name
```

> [!tip]- Indice sur le chemin DN inversé
> Le DN se lit du plus précis au plus général :
> ```powershell
> # Si Service=boulangerie, Pole=fabrication, Entite=Laboratoire
> # Le DN sera : OU=boulangerie,OU=fabrication,OU=Laboratoire,OU=Utilisateurs,OU=Fournil,DC=...
> $ouParts = @()
> if ($user.Service -ne "") { $ouParts += "OU=$($user.Service)" }
> if ($user.Pole -ne "") { $ouParts += "OU=$($user.Pole)" }
> if ($user.Entite -ne "") { $ouParts += "OU=$($user.Entite)" }
> $ouParts += "OU=Utilisateurs"
> $ouParts += "OU=Fournil"
> $userPath = ($ouParts -join ",") + ",$baseDN"
> ```

---

## Exercice 7 — Optimisation : le cache

### Consigne

Votre script parcourt le CSV ligne par ligne. Or, plusieurs lignes partagent la même Entité ou le même Pôle. Sans optimisation, votre script essaie de recréer les mêmes OUs et groupes à chaque passage.

Ajoutez un système de **cache** à votre script :
- Utilisez des hashtables (`@{}`) pour mémoriser les OUs et groupes déjà traités
- Avant de créer un objet, vérifiez d'abord le cache
- Si l'objet est dans le cache, passez au suivant sans interroger l'AD

### Questions

- Pourquoi un cache en hashtable est-il plus rapide qu'une requête AD à chaque fois ?
- Quelle portée de variable utiliser pour que le cache soit accessible dans les fonctions ? (`$script:`)
- Combien de requêtes AD économisez-vous avec le cache sur le CSV du Fournil ?

> [!tip]- Exemple de cache
> ```powershell
> $script:processedOUs = @{}
> 
> function New-OUIfNotExists {
>     param ([string]$ouName, [string]$parentPath)
>     $ouPath = "OU=$ouName,$parentPath"
>     if ($script:processedOUs.ContainsKey($ouPath)) { return $ouPath }
>     # ... créer l'OU ...
>     $script:processedOUs[$ouPath] = $true
>     return $ouPath
> }
> ```

---

## Exercice 8 — Vérification globale

### Consigne

Ajoutez un bloc de résumé à la fin de votre script qui affiche des compteurs :
- Nombre d'OUs créées / déjà existantes
- Nombre de groupes créés / déjà existants
- Nombre de membres ajoutés / déjà en place
- Nombre d'utilisateurs créés / déjà existants
- Nombre de dossiers créés / permissions appliquées
- Nombre d'erreurs

Puis exécutez votre script et vérifiez avec ces commandes :

```powershell
# Nombre total d'OUs
(Get-ADOrganizationalUnit -SearchBase "OU=Fournil,DC=ad,DC=fournil,DC=lab" -Filter *).Count

# Nombre de groupes G_ et DL_
(Get-ADGroup -Filter 'Name -like "G_*"' -SearchBase "OU=Groupes,OU=Fournil,DC=ad,DC=fournil,DC=lab").Count
(Get-ADGroup -Filter 'Name -like "DL_*"' -SearchBase "OU=Groupes,OU=Fournil,DC=ad,DC=fournil,DC=lab").Count

# Nombre d'utilisateurs
(Get-ADUser -Filter * -SearchBase "OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab").Count
```

### Critère de réussite

Votre script doit être **idempotent** : si vous l'exécutez 2 fois, la 2ème exécution ne doit rien créer (tout est "déjà existant").

---

## Bonus — Rendez votre script adaptable

Si on changeait les CSV pour un cabinet d'architectes au lieu d'une boulangerie, votre script devrait fonctionner **sans modifier les fonctions**. Seules les variables en haut du script et les CSV changeraient.

Vérifiez que c'est bien le cas :
- Les noms d'OUs, de groupes et de dossiers sont-ils tous construits dynamiquement depuis le CSV ?
- Y a-t-il des valeurs "fournil" en dur dans vos fonctions ?

> La correction de ce TP : [Explication-Script-AD](https://cours.kaya.ovh/active-directory/ad/annexe/01-ad-script-explication-script-ad)
