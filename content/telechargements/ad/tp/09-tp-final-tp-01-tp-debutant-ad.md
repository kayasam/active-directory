# TP Débutant — Active Directory

> Durée : **2 h** · Niveau : Débutant — commandes manuelles, aucun script à écrire
> Prérequis : **[00.5-Poste-de-Travail](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-00-5-poste-de-travail)** terminé (checkpoint C validé)
> Fichiers fournis : `orga-fournil.csv`, `utilisateurs-fournil.csv` dans `C:\Deploy`

> [!important] Où est-ce que je tape tout ça ?
> 🖥️ **SUR DC01**, dans le terminal PowerShell de VSCode, ouvert **en administrateur**.
> Tout ce TP se fait sur DC01. DC02 n'intervient qu'au TP suivant.

---

## Le contexte

Vous êtes administrateur système de la boulangerie **Le Fournil**, 30 salariés, deux entités :

- le **Laboratoire** — la production : fabrication (boulangerie, pâtisserie, viennoiserie), approvisionnement, conditionnement, qualité-hygiène, maintenance
- la **Vente** — le commerce : boutique, commercial, livraisons, ressources (secrétariat, compta, RH, informatique)

Votre mission aujourd'hui : **construire l'annuaire à la main**, pour un seul service (`boulangerie`), en comprenant chaque commande. Le script qui fait la même chose pour les 30 salariés viendra après.

> L'organigramme complet : [Organigramme-Fournil](https://cours.kaya.ovh/active-directory/assets/supports/15d16f367d0f04e71a4f.svg)

---

## Ce que vous allez construire

![Schema-Chaine-Exercices-AD](https://cours.kaya.ovh/active-directory/assets/supports/9a5053831470de9116a1.svg)

> [!tip] Lisez ce schéma avant de commencer
> Les 5 exercices ne sont pas indépendants : chacun s'appuie sur le précédent.
> Si vous ratez l'exercice 2, l'exercice 4 ne pourra pas fonctionner — et vous chercherez l'erreur au mauvais endroit.

---

# Exercice 0 — Échauffement guidé (10 min)

> [!note] Celui-là, on le fait ensemble
> Vous recopiez, vous observez, vous comprenez. Les exercices suivants seront à vous.

## 0.1 — Charger le module Active Directory

```powershell
Import-Module ActiveDirectory
```

> Aucune sortie = c'est bon. PowerShell ne dit rien quand tout va bien.

```powershell
# Vérifier que les commandes AD sont disponibles
Get-Command -Module ActiveDirectory | Measure-Object | Select-Object Count
```
> Attendu : environ **150** commandes.

## 0.2 — Récupérer le nom de votre domaine, automatiquement

Tous les chemins AD se terminent par `DC=ad,DC=fournil,DC=lab`. Plutôt que de le retaper 40 fois (et de faire des fautes de frappe), on le stocke dans une variable :

```powershell
$dn = (Get-ADDomain).DistinguishedName
$dn
```
> Attendu : `DC=ad,DC=fournil,DC=lab`

> [!warning] Gardez ce terminal ouvert
> `$dn` disparaît si vous fermez le terminal. Si vos commandes échouent plus tard avec un chemin bizarre, retapez simplement cette ligne.

## 0.3 — Comprendre un chemin AD (le DN)

Un objet AD s'identifie par son **Distinguished Name**, qui se lit **de droite à gauche**, du plus général au plus précis :

```
CN=mlebrun,OU=boulangerie,OU=fabrication,OU=Laboratoire,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab
└──┬───┘ └──────┬───────┘                                              └──────┬─────┘
 l'objet     son tiroir                                               le domaine
```

| Préfixe | Signification |
|---------|---------------|
| `DC=` | Domain Component — un morceau du nom DNS du domaine |
| `OU=` | Organizational Unit — un tiroir de rangement |
| `CN=` | Common Name — l'objet lui-même (utilisateur, groupe, ordinateur) |

## 0.4 — Créer votre première OU, ensemble

```powershell
New-ADOrganizationalUnit -Name "Fournil" -Path $dn -ProtectedFromAccidentalDeletion $false
```

Décortiquons :

| Paramètre | Ce qu'il fait |
|-----------|---------------|
| `-Name "Fournil"` | Le nom de l'OU à créer |
| `-Path $dn` | **Où** la créer — le conteneur parent. Ici, la racine du domaine. |
| `-ProtectedFromAccidentalDeletion $false` | Autorise sa suppression. En production on laisse `$true` ; en TP, `$false` vous permet de repartir de zéro. |

**Vérification :**

```powershell
Get-ADOrganizationalUnit -Filter 'Name -eq "Fournil"' | Select-Object Name, DistinguishedName
```

**Résultat attendu :**

```
Name     DistinguishedName
----     -----------------
fournil  OU=Fournil,DC=ad,DC=fournil,DC=lab
```

> [!success] Checkpoint 0
> Vous savez charger le module, lire un DN, créer une OU et vérifier qu'elle existe.
> **C'est 80 % du TP.** Le reste, c'est la même logique répétée.

> [!failure] `L'objet existe déjà` ?
> Pas grave, l'OU était déjà là. Passez à la suite.

> [!tip] Repartir de zéro à tout moment
> ```powershell
> Get-ADOrganizationalUnit -Filter 'Name -eq "Fournil"' |
>     Set-ADObject -ProtectedFromAccidentalDeletion $false -PassThru |
>     Remove-ADOrganizationalUnit -Recursive -Confirm:$false
> ```
> ⚠️ Supprime **tout** ce que vous avez créé sous `Fournil`. À n'utiliser qu'en TP.

---

# Exercice 1 — Créer les OUs

> Objectif : construire le meuble de rangement de l'annuaire.

![Schema-Structure-OUs](https://cours.kaya.ovh/active-directory/assets/supports/0148111e35e5100b08f6.svg)

### Consigne

1. Sous l'OU `Fournil` (déjà créée en exercice 0), créez 3 OUs : `Utilisateurs`, `Groupes`, `Ordinateurs`
2. Sous `Utilisateurs`, créez l'OU `Laboratoire`
3. Sous `Laboratoire`, créez les pôles : `fabrication`, `approvisionnement`, `conditionnement`, `qualite-hygiene`, `maintenance`
4. Sous `fabrication`, créez les services : `boulangerie`, `patisserie`, `viennoiserie`
5. Reproduisez la même arborescence sous l'OU `Groupes`

> [!tip] Indice — construire le `-Path` d'une sous-OU
> Le chemin d'une OU enfant, c'est `OU=<parent>,` + le chemin du parent.
> ```powershell
> $fournil = "OU=Fournil,$dn"
> New-ADOrganizationalUnit -Name "Utilisateurs" -Path $fournil -ProtectedFromAccidentalDeletion $false
>
> $users = "OU=Utilisateurs,$fournil"
> New-ADOrganizationalUnit -Name "Laboratoire" -Path $users -ProtectedFromAccidentalDeletion $false
> ```
> Pour les 3 services de `fabrication`, pensez à une **boucle** plutôt qu'à 3 copier-coller :
> ```powershell
> $fab = "OU=fabrication,OU=Laboratoire,$users"
> foreach ($svc in "boulangerie","patisserie","viennoiserie") {
>     New-ADOrganizationalUnit -Name $svc -Path $fab -ProtectedFromAccidentalDeletion $false
> }
> ```

### Questions

- Quelle est la commande pour créer une OU ?
- Que signifie le paramètre `-Path` ? Que se passe-t-il si le chemin indiqué n'existe pas encore ?
- Pourquoi séparer `Utilisateurs`, `Groupes` et `Ordinateurs` dans des OUs différentes ?

### Vérification

```powershell
Get-ADOrganizationalUnit -SearchBase "OU=Fournil,$dn" -Filter * |
    Select-Object Name, DistinguishedName | Sort-Object DistinguishedName
```

> **Résultat attendu :** au minimum **13 OUs** côté Utilisateurs
> (Fournil + Utilisateurs + Groupes + Ordinateurs + Laboratoire + 5 pôles + 3 services), plus l'arborescence dupliquée sous `Groupes`.

> [!failure] `Répertoire : objet introuvable`
> Votre `-Path` pointe vers une OU qui n'existe pas encore. On construit **toujours du parent vers l'enfant**.
> Affichez votre chemin avant de créer : `Write-Host $fab`.

> [!tip]- Besoin d'aide ? Cliquez ici
> Consultez la procédure : [Manuel-02-Creer-les-OUs](https://cours.kaya.ovh/active-directory/ad/annexe/01-ad-manuel-manuel-02-creer-les-ous)

---

# Exercice 2 — Créer les groupes de sécurité

> Objectif : fabriquer les badges. `G_` = le métier, `DL_` = le droit.

### Consigne

Pour le service `boulangerie`, créez 3 groupes de sécurité dans
`OU=boulangerie,OU=fabrication,OU=Laboratoire,OU=Groupes,OU=Fournil,...` :

| Nom | Portée | Rôle |
|-----|--------|------|
| `G_Laboratoire_fabrication_boulangerie` | **Global** | regroupe les personnes du service |
| `DL_Laboratoire_fabrication_boulangerie_L` | **DomainLocal** | portera le droit de **lecture** |
| `DL_Laboratoire_fabrication_boulangerie_M` | **DomainLocal** | portera le droit de **modification** |

> [!tip] Indice — la commande
> ```powershell
> New-ADGroup -Name "..." -GroupScope Global -GroupCategory Security -Path "..."
> ```
> Les portées possibles sont `Global`, `DomainLocal`, `Universal`.

### Questions

- Quelle est la différence entre un groupe **Global** et **DomainLocal** ?
- Pourquoi créer un groupe `_L` **et** un groupe `_M` au lieu d'un seul ?
- Que signifie `-GroupCategory Security` ? Quelle est l'autre valeur possible, et à quoi sert-elle ?

### Vérification

```powershell
Get-ADGroup -Filter * -SearchBase "OU=Groupes,OU=Fournil,$dn" |
    Where-Object { $_.Name -like "*boulangerie*" } |
    Select-Object Name, GroupScope | Sort-Object Name
```

**Résultat attendu — exactement 3 lignes :**

```
Name                                        GroupScope
----                                        ----------
DL_Laboratoire_fabrication_boulangerie_L    DomainLocal
DL_Laboratoire_fabrication_boulangerie_M    DomainLocal
G_Laboratoire_fabrication_boulangerie       Global
```

> [!success] Checkpoint 2
> 3 groupes, et surtout la **bonne portée** en face de chacun. Une portée fausse ici = l'exercice 3 impossible.

> [!tip]- Besoin d'aide ? Cliquez ici
> Consultez la procédure : [Manuel-03-Creer-les-Groupes](https://cours.kaya.ovh/active-directory/ad/annexe/01-ad-manuel-manuel-03-creer-les-groupes)

---

# Exercice 3 — Comprendre et appliquer l'AGDLP

> Objectif : relier les badges métier aux badges d'accès.

![Schema-AGDLP](https://cours.kaya.ovh/active-directory/assets/supports/d601b6a810e4e43f2353.svg)

> [!note] Étudiez ce schéma AVANT de taper quoi que ce soit
> L'AGDLP est le concept le plus important du TP — et celui qui bloque le plus de monde.
> En une phrase : **un utilisateur n'a jamais de droit personnel sur un dossier.** Il est dans un groupe `G_`, ce groupe `G_` est membre d'un groupe `DL_`, et c'est le `DL_` qui est écrit dans les permissions du dossier.

### Consigne

Imbriquez les groupes :

**a) La chaîne hiérarchique (du plus précis au plus général) :**
1. `G_Laboratoire_fabrication_boulangerie` → membre de `G_Laboratoire_fabrication`
2. `G_Laboratoire_fabrication` → membre de `G_Laboratoire`
3. `G_Laboratoire` → membre de `G_fournil`

**b) L'attribution des droits :**
4. `G_Laboratoire_fabrication_boulangerie` → membre de `DL_Laboratoire_fabrication_boulangerie_M` (**modification**)
5. `G_Laboratoire_fabrication` → membre de `DL_Laboratoire_fabrication_L` (**lecture**)

> [!tip] Indice — la commande
> ```powershell
> Add-ADGroupMember -Identity "<le groupe qui accueille>" -Members "<le groupe qui entre>"
> ```
> Attention au sens : `-Identity` c'est le **contenant**, `-Members` c'est le **contenu**.
> Vous devrez d'abord créer les groupes parents (`G_Laboratoire_fabrication`, `G_Laboratoire`, `G_fournil`) s'ils n'existent pas encore.

### Questions

- Que signifie AGDLP ? Détaillez chaque lettre.
- Pourquoi le **dernier** niveau va dans `_M` et les niveaux **parents** dans `_L` ?
- Un boulanger pourra-t-il modifier un fichier dans le dossier `fabrication` ? Pourquoi ?
- Que se passerait-il si on donnait directement les droits NTFS au groupe `G_` ?

### Schéma à compléter

```
mlebrun (compte)
  └── G_Laboratoire_fabrication_boulangerie    → DL_..._M → ________ sur boulangerie
        └── G_Laboratoire_fabrication          → DL_..._L → ________ sur fabrication
              └── G_Laboratoire                → DL_..._L → ________ sur Laboratoire
                    └── G_fournil
```

> Remplacez les `________` par le bon droit (Modification ou Lecture).

### Vérification

```powershell
Get-ADGroup "G_Laboratoire_fabrication_boulangerie" -Properties MemberOf |
    Select-Object -ExpandProperty MemberOf
```

**Résultat attendu :** deux lignes — `G_Laboratoire_fabrication` **et** `DL_Laboratoire_fabrication_boulangerie_M`.

> [!failure] `Impossible d'ajouter le membre : le type n'est pas correct`
> Vous essayez de mettre un groupe DomainLocal dans un groupe Global. **L'inverse est interdit par AD.**
> Le sens autorisé est toujours : Global **entre dans** DomainLocal. Jamais l'inverse.

> [!tip]- Besoin d'aide ? Cliquez ici
> Consultez la procédure : [Manuel-04-Imbriquer-Groupes-AGDLP](https://cours.kaya.ovh/active-directory/ad/annexe/01-ad-manuel-manuel-04-imbriquer-groupes-agdlp)

---

# Exercice 4 — Permissions NTFS

> Objectif : poser la serrure sur la porte. C'est ici que les groupes `DL_` prennent enfin un sens.

![Schema-Permissions-NTFS](https://cours.kaya.ovh/active-directory/assets/supports/8133a30adce77e3a9309.svg)

### Consigne

1. Créez le dossier `C:\fournil\Laboratoire\fabrication\boulangerie`
2. Sur ce dossier :
   - **Désactivez l'héritage** des permissions
   - **Supprimez** toutes les permissions héritées existantes
   - Ajoutez `Administrateurs` → **Contrôle total**
   - Ajoutez `SYSTEM` → **Contrôle total**
   - Ajoutez `DL_Laboratoire_fabrication_boulangerie_L` → **Lecture**
   - Ajoutez `DL_Laboratoire_fabrication_boulangerie_M` → **Modification**
3. Appliquez l'ACL modifiée sur le dossier

> [!tip] Indice — la mécanique en PowerShell
> On ne modifie jamais une ACL « en direct ». On la **lit**, on la **modifie en mémoire**, puis on la **réécrit** :
> ```powershell
> $acl = Get-Acl "C:\fournil\..."       # 1. lire
> $acl.SetAccessRuleProtection($true,$false)
> $acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) | Out-Null }
> $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
>     "DL_..._M", "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")
> $acl.AddAccessRule($rule)             # 2. modifier
> Set-Acl "C:\fournil\..." $acl         # 3. réécrire
> ```
> **Oublier le `Set-Acl` final est l'erreur la plus fréquente** : tout semble marcher, rien n'est appliqué.

### Questions

- Qu'est-ce qu'une ACL ? Et une ACE ?
- Que fait `SetAccessRuleProtection($true, $false)` ? Que signifient les deux paramètres ?
- Que signifie `ContainerInherit,ObjectInherit` dans un `FileSystemAccessRule` ?
- Pourquoi laisser `SYSTEM` en contrôle total ? Que casse-t-on si on l'enlève ?

### Vérification

```powershell
(Get-Acl "C:\fournil\Laboratoire\fabrication\boulangerie").Access |
    Select-Object IdentityReference, FileSystemRights, IsInherited | Format-Table -AutoSize
```

**Résultat attendu — exactement 4 lignes, toutes avec `IsInherited = False` :**

```
IdentityReference                             FileSystemRights  IsInherited
-----------------                             ----------------  -----------
BUILTIN\Administrateurs                       FullControl             False
NT AUTHORITY\SYSTEM                           FullControl             False
AD\DL_Laboratoire_fabrication_boulangerie_L   ReadAndExecute          False
AD\DL_Laboratoire_fabrication_boulangerie_M   Modify                  False
```

> [!failure] Il reste des lignes `IsInherited = True`
> L'héritage n'a pas été coupé : `SetAccessRuleProtection($true, $false)` n'a pas été appelé, ou le `Set-Acl` final a été oublié.

> [!failure] `Certains ou tous les identificateurs de références n'ont pas pu être traduits`
> Le nom du groupe est mal orthographié, ou le groupe n'existe pas. Vérifiez avec `Get-ADGroup "DL_..."`.

> [!tip]- Besoin d'aide ? Cliquez ici
> Consultez la procédure : [Manuel-05-Permissions-NTFS](https://cours.kaya.ovh/active-directory/ad/annexe/01-ad-manuel-manuel-05-permissions-ntfs)

---

# Exercice 5 — Créer un utilisateur

> Objectif : embaucher Marc et lui donner son badge. Dernière pièce du puzzle.

### Consigne

Créez le compte de **Marc Lebrun**, Chef Boulanger :

| Attribut | Valeur |
|----------|--------|
| Login (`SamAccountName`) | `mlebrun` |
| Nom affiché | `Marc Lebrun` |
| Email / UPN | `mlebrun@ad.fournil.lab` |
| Description | `Chef Boulanger` |
| Mot de passe | `a12345!` — **changement obligatoire à la 1ʳᵉ connexion** |
| OU | `boulangerie` sous `Utilisateurs` |
| Groupe | `G_Laboratoire_fabrication_boulangerie` |

> [!tip] Indice
> ```powershell
> $mdp = ConvertTo-SecureString "a12345!" -AsPlainText -Force
> New-ADUser -Name "Marc Lebrun" -SamAccountName "mlebrun" ... -AccountPassword $mdp -Enabled $true -ChangePasswordAtLogon $true
> Add-ADGroupMember -Identity "G_..." -Members "mlebrun"
> ```
> N'oubliez pas `-Enabled $true` : sans lui, le compte est créé **désactivé** et personne ne peut s'y connecter.

### Questions

- Pourquoi le mot de passe doit-il être un `SecureString` et non une chaîne normale ?
- Que fait `-ChangePasswordAtLogon $true` ?
- Quelle est la différence entre `-SamAccountName` et `-UserPrincipalName` ?
- Que se passe-t-il si le mot de passe ne respecte pas la stratégie de complexité du domaine ?

### Vérification

```powershell
Get-ADUser -Identity "mlebrun" -Properties Description, MemberOf, Enabled |
    Select-Object Name, SamAccountName, Description, Enabled,
        @{N='Groupes';E={($_.MemberOf | ForEach-Object { ($_ -split ',')[0] -replace 'CN=' }) -join ', '}}
```

**Résultat attendu :** `Enabled = True` et au moins `G_Laboratoire_fabrication_boulangerie` dans la colonne Groupes.

> [!failure] `Le mot de passe ne répond pas aux exigences`
> La stratégie du domaine exige 7 caractères minimum et 3 types de caractères. `a12345!` passe normalement — si ce n'est pas le cas, vérifiez la stratégie avec `Get-ADDefaultDomainPasswordPolicy`.

> [!tip]- Besoin d'aide ? Cliquez ici
> Consultez la procédure : [Manuel-06-Creer-les-Utilisateurs](https://cours.kaya.ovh/active-directory/ad/annexe/01-ad-manuel-manuel-06-creer-les-utilisateurs)

---

# Exercice 6 — Le test qui prouve tout

> [!important] C'est LE moment du TP
> Jusqu'ici vous avez vérifié des objets un par un. Maintenant on teste la **chaîne complète**, comme un vrai utilisateur.

## 6.1 — Le test grandeur nature

1. Sur DC01 (ou un poste du domaine), **ouvrez une session avec `mlebrun`** (changez le mot de passe quand c'est demandé)
2. Ouvrez `C:\fournil\Laboratoire\fabrication\boulangerie`
3. **Créez un fichier texte** → ✅ ça doit marcher
4. Remontez dans `C:\fournil\Laboratoire\fabrication`
5. **Essayez d'y créer un fichier** → ❌ ça doit être refusé, mais vous devez **voir** le contenu

> [!success] Les deux comportements sont corrects ?
> **Bravo — l'AGDLP fonctionne de bout en bout.** Vous avez compris le cœur d'Active Directory.

> [!failure] Accès refusé partout
> L'erreur est à l'exercice 3 (imbrication) ou 4 (NTFS). Diagnostiquez sans vous déconnecter :
> ```powershell
> whoami /groups | Select-String "DL_"
> ```
> Si aucun `DL_` n'apparaît, le jeton de sécurité ne contient pas les groupes → **déconnectez-vous et reconnectez-vous**.
> Un jeton Kerberos est calculé **à l'ouverture de session** : une modification de groupe n'est prise en compte qu'à la session suivante. C'est le piège classique.

## 6.2 — L'inventaire

Répondez à ces questions **en utilisant des commandes PowerShell** :

1. Combien d'OUs avez-vous créées au total sous `Fournil` ?
2. Combien de groupes globaux (`G_`) existent ?
3. Combien de groupes domaine local (`DL_`) existent ?
4. De quels groupes `mlebrun` est-il membre — **directs et hérités** ?
5. Quelles sont les permissions NTFS sur `C:\fournil\Laboratoire\fabrication\boulangerie` ?

> [!tip]- Les commandes, si vous séchez
> ```powershell
> # 1. Compter les OUs
> (Get-ADOrganizationalUnit -SearchBase "OU=Fournil,$dn" -Filter *).Count
>
> # 2. Compter les groupes G_
> (Get-ADGroup -Filter 'Name -like "G_*"' -SearchBase "OU=Groupes,OU=Fournil,$dn").Count
>
> # 3. Compter les groupes DL_
> (Get-ADGroup -Filter 'Name -like "DL_*"' -SearchBase "OU=Groupes,OU=Fournil,$dn").Count
>
> # 4. Groupes de mlebrun (directs + hérités)
> Get-ADPrincipalGroupMembership -Identity "mlebrun" | Select-Object Name, GroupScope
>
> # 5. Permissions
> (Get-Acl "C:\fournil\Laboratoire\fabrication\boulangerie").Access |
>     Select-Object IdentityReference, FileSystemRights
> ```

---

## Aide-mémoire — les erreurs les plus fréquentes

| Message | Cause réelle | Correction |
|---------|--------------|------------|
| `Le terme 'New-ADUser' n'est pas reconnu` | Module AD non chargé, ou terminal en `cmd.exe` | `Import-Module ActiveDirectory` |
| `Répertoire : objet introuvable` | `-Path` pointe vers une OU inexistante | Créer le parent d'abord ; afficher le chemin |
| `L'objet existe déjà` | Commande relancée deux fois | Sans gravité, continuez |
| `Le type de membre n'est pas correct` | DomainLocal mis dans un Global | Sens autorisé : Global → DomainLocal |
| `Les identificateurs n'ont pas pu être traduits` | Nom de groupe mal orthographié | `Get-ADGroup "<nom>"` pour vérifier |
| ACL non appliquée | `Set-Acl` final oublié | Lire → modifier → **réécrire** |
| Droits absents après connexion | Jeton Kerberos calculé à l'ouverture de session | **Déconnexion / reconnexion** |
| `Accès refusé` sur une commande AD | PowerShell pas lancé en administrateur | Relancer en admin |

---

## Bonus — Voir comment le script automatise tout ça

> Maintenant que vous avez fait chaque geste à la main, ouvrez `C:\Deploy\01-AD-Arborescence.ps1`
> et retrouvez, pour chacun de vos exercices, la fonction qui fait le même travail — mais pour les 30 salariés.

| Votre exercice | Fonction du script |
|----------------|-------------------|
| Exercice 1 — OUs | `New-OUIfNotExists` |
| Exercice 2 — Groupes | `New-GroupIfNotExists` |
| Exercice 3 — AGDLP | `Add-MemberToGroupSafe` |
| Exercice 4 — NTFS | `Set-NTFSPermissions` |
| Exercice 5 — Utilisateurs | `New-UserIfNotExists` |

> Explication détaillée du script : [Explication-Script-AD](https://cours.kaya.ovh/active-directory/ad/annexe/01-ad-script-explication-script-ad)

---

| ← Précédent | Suivant → |
|-------------|-----------|
| [00.5-Poste-de-Travail](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-00-5-poste-de-travail) | [02.TP-Debutant-DFS](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-02-tp-debutant-dfs) |

> Accueil : [00.0-DEMARRER-ICI](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-00-0-demarrer-ici)
